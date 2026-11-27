# Long-running jobs started by the agent in a separate process, so the agent keeps answering.
#   tasks.ps1 -Task InstallSunshine   install or update Sunshine (streaming server), give it a private
#                                      login, apply the hardening settings and start its service.
#   tasks.ps1 -Task SetupTailscale    install Tailscale (signature checked) and join the user's tailnet
#                                      with the one-time auth key the app sent (read from a protected file).
param([Parameter(Mandatory = $true)][string]$Task)

$ErrorActionPreference = 'Stop'
. (Join-Path $env:ProgramData 'PcRemote\common.ps1')
$ProgressPreference = 'SilentlyContinue'

function Install-Sunshine {
    $exe = Find-Sunshine
    if (-not $exe -or -not (Test-SunshineCurrent)) {
        Write-StreamState 'installing' 'download'
        $dl = Join-Path $Dir 'dl'
        New-Item -ItemType Directory -Path $dl -Force | Out-Null
        Log "Getting Sunshine (installed: '$(Get-SunshineVersion)', minimum $SunshineMinVersion)"
        Write-StreamState 'installing' 'install'
        try { $exe = Install-SunshinePackage }
        catch {
            if ($exe) { Log "Could not update Sunshine, keeping $(Get-SunshineVersion): $($_.Exception.Message)" }
            else { throw }
        }
        if (-not (Test-SunshineCurrent)) { Log "Warning: Sunshine $(Get-SunshineVersion) is still below $SunshineMinVersion" }
    }

    Write-StreamState 'installing' 'configure'
    $cfg = Read-Config
    if (-not $cfg.sunUser) {
        Set-ConfigValue $cfg 'sunUser' 'pcremote'
        Set-ConfigValue $cfg 'sunPass' (New-Secret 32)
        Save-Config $cfg
    }
    Initialize-SunshineService $exe
    Stop-Service -Name 'SunshineService' -Force -ErrorAction SilentlyContinue
    $p = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -Wait -PassThru -WindowStyle Hidden `
        -ArgumentList @('--creds', $cfg.sunUser, $cfg.sunPass)
    if ($p.ExitCode -ne 0) { Log "sunshine --creds exited with $($p.ExitCode)" }
    Set-SunshineConf $SunshineHardening | Out-Null
    Log 'Sunshine login set and hardening applied'
    Set-Service -Name 'SunshineService' -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name 'SunshineService'

    Write-StreamState 'installing' 'start'
    for ($i = 0; $i -lt 45; $i++) {
        Start-Sleep -Seconds 2
        try { Invoke-SunshineApi GET '/api/clients/list' | Out-Null; Write-StreamState 'ready'; Log 'Sunshine ready'; return } catch { }
    }
    throw 'Sunshine did not start answering.'
}

function Write-TsState([string]$state, [string]$err = '') {
    @{ state = $state; error = $err; at = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -Path $TsStatePath -Encoding UTF8
}

function Setup-Tailscale {
    if (-not (Test-Path $TsKeyPath)) { throw 'No auth key was provided.' }
    $key = (Get-Content $TsKeyPath -Raw).Trim()
    Remove-Item $TsKeyPath -Force -ErrorAction SilentlyContinue
    if ($key -notmatch '^tskey-[A-Za-z0-9-]+$') { throw 'The auth key does not look like a Tailscale key (tskey-...).' }

    $exe = Find-Tailscale
    if (-not $exe) {
        Write-TsState 'installing'
        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
        $url = "https://pkgs.tailscale.com/stable/tailscale-setup-latest-$arch.msi"
        $dl = Join-Path $Dir 'dl'
        New-Item -ItemType Directory -Path $dl -Force | Out-Null
        $msi = Join-Path $dl 'tailscale.msi'
        Log "Downloading Tailscale from $url"
        Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing -TimeoutSec 600
        Assert-Signed $msi 'Tailscale'
        Invoke-Msi $msi 'TS_UNATTENDEDMODE=always' 'tailscale-install.log'
        Remove-Item $msi -Force -ErrorAction SilentlyContinue
        for ($i = 0; $i -lt 30 -and -not (Find-Tailscale); $i++) { Start-Sleep -Seconds 1 }
        $exe = Find-Tailscale
        if (-not $exe) { throw 'Tailscale was installed but tailscale.exe was not found.' }
    }
    Start-Service -Name 'Tailscale' -ErrorAction SilentlyContinue

    Write-TsState 'joining'
    $name = ($env:COMPUTERNAME.ToLowerInvariant() -replace '[^a-z0-9-]', '-')
    Log 'Joining the tailnet (unattended)'
    # --unattended keeps the connection up before anyone logs in to Windows.
    # The key itself is never written to the log.
    $p = Start-Process -FilePath $exe -Wait -PassThru -WindowStyle Hidden -ArgumentList @(
        'up', '--unattended', "--authkey=$key", "--hostname=$name", '--accept-dns=false', '--timeout=60s')
    $key = $null
    if ($p.ExitCode -ne 0) { throw "tailscale up failed (code $($p.ExitCode)). The key may be used up or expired." }
    for ($i = 0; $i -lt 20; $i++) {
        $s = Get-TailscaleStatus
        if ($s.online -and $s.ip) { Write-TsState 'ready'; Log "Tailscale up: $($s.ip)"; Set-AgentFirewallScope; return }
        Start-Sleep -Seconds 1
    }
    throw 'Tailscale did not come online.'
}

function Install-Remote {
    Write-RemoteState 'installing' 'rustdesk'
    Install-RustDesk | Out-Null
    Write-RemoteState 'installing' 'configure'
    Set-RustDeskSecurity
    $cfg = Read-Config
    if ($cfg.wantSteam -and -not (Find-Steam)) { Write-RemoteState 'installing' 'steam'; Install-Steam | Out-Null }
    Write-RemoteState 'ready'
    Log "Remote control ready (RustDesk ID $(Get-RustDeskId))"
}

try {
    switch ($Task) {
        'InstallRemote' { Install-Remote }
        'InstallSunshine' { Install-Sunshine }
        'SetupTailscale' { Setup-Tailscale }
        default { throw "Unknown task $Task" }
    }
} catch {
    Log "Task $Task failed: $($_.Exception.Message)"
    if ($Task -eq 'InstallRemote') { Write-RemoteState 'error' '' $_.Exception.Message }
    elseif ($Task -eq 'SetupTailscale') { Write-TsState 'error' $_.Exception.Message; Remove-Item $TsKeyPath -Force -ErrorAction SilentlyContinue }
    else { Write-StreamState 'error' '' $_.Exception.Message }
    exit 1
}

# Long-running jobs started by the agent in a separate process, so the agent keeps answering.
#   tasks.ps1 -Task InstallSunshine   install or update Sunshine (streaming server), give it a private
#                                      login, apply the hardening settings and start its service.
#   tasks.ps1 -Task SetupTailscale    install Tailscale (signature checked) and join the user's tailnet
#                                      with the one-time auth key the app sent (read from a protected file).
param([Parameter(Mandatory = $true)][string]$Task)

$ErrorActionPreference = 'Stop'
. (Join-Path $env:ProgramData 'PcRemote\common.ps1')
$ProgressPreference = 'SilentlyContinue'

function Assert-Signed([string]$file, [string]$publisherPattern, [switch]$AllowUnsigned) {
    $sig = Get-AuthenticodeSignature -FilePath $file
    $subject = [string]$sig.SignerCertificate.Subject
    if ($sig.Status -eq 'Valid') {
        if ($publisherPattern -and $subject -notmatch $publisherPattern) { throw "Unexpected publisher: $subject" }
        Log "Signature OK: $subject"
        return
    }
    if ($AllowUnsigned -and $sig.Status -eq 'NotSigned') { Log 'Installer is not code-signed (downloaded over HTTPS from the official release)'; return }
    # A file that is signed but whose signature is broken or was tampered with is always refused.
    throw "Installer signature check failed ($($sig.Status)) $subject"
}

function Invoke-Msi([string]$file, [string]$extra, [string]$logName) {
    # 1618 = another installation is running (often Windows Update): wait and retry.
    for ($try = 1; $try -le 6; $try++) {
        $msiArgs = '/i "' + $file + '" /qn /norestart ' + $extra + ' /l*v "' + (Join-Path (Split-Path $file) $logName) + '"'
        $p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList $msiArgs
        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) { return }
        if ($p.ExitCode -ne 1618) { throw "Installer failed (msiexec code $($p.ExitCode)). Details: $logName" }
        Log "Another installation is running (1618), retry $try/6 in 60 seconds"
        Start-Sleep -Seconds 60
    }
    throw 'Another installation kept running (msiexec 1618). Try again later.'
}

function Get-SunshineInstaller([string]$dl) {
    # 1) The stable "latest" link for the MSI. 2) If its name changed: ask the GitHub API for the asset.
    $msi = Join-Path $dl 'Sunshine.msi'
    try {
        Invoke-WebRequest -Uri $SunshineMsiUrl -OutFile $msi -UseBasicParsing -TimeoutSec 900
        if ((Get-Item $msi).Length -gt 5MB) { return $msi }
    } catch { Log "Direct Sunshine download failed: $($_.Exception.Message)" }
    $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/LizardByte/Sunshine/releases/latest' -UseBasicParsing -TimeoutSec 60 `
        -Headers @{ 'User-Agent' = 'pc-remote-agent'; Accept = 'application/vnd.github+json' }
    $asset = @($rel.assets) | Where-Object { $_.name -match '(?i)windows' -and $_.name -match '(?i)amd64|x64|x86_64' -and $_.name -match '(?i)\.msi$' } | Select-Object -First 1
    if (-not $asset) { $asset = @($rel.assets) | Where-Object { $_.name -match '(?i)windows.*installer.*\.exe$' } | Select-Object -First 1 }
    if (-not $asset) { throw "No Windows installer found in Sunshine release $($rel.tag_name)." }
    if ($asset.browser_download_url -notmatch '^https://github\.com/') { throw 'Unexpected download address.' }
    $out = Join-Path $dl $asset.name
    Log "Downloading Sunshine $($rel.tag_name): $($asset.name)"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $out -UseBasicParsing -TimeoutSec 900
    if ((Get-Item $out).Length -lt 5MB) { throw 'The Sunshine download looks incomplete.' }
    return $out
}

function Install-Sunshine {
    $exe = Find-Sunshine
    if (-not $exe -or -not (Test-SunshineCurrent)) {
        Write-StreamState 'installing' 'download'
        $dl = Join-Path $Dir 'dl'
        New-Item -ItemType Directory -Path $dl -Force | Out-Null
        Log "Getting Sunshine (installed: '$(Get-SunshineVersion)', minimum $SunshineMinVersion)"
        $file = Get-SunshineInstaller $dl
        Assert-Signed $file '' -AllowUnsigned

        Write-StreamState 'installing' 'install'
        if ($file -match '(?i)\.msi$') { Invoke-Msi $file '' 'sunshine-install.log' }
        else {
            $p = Start-Process -FilePath $file -ArgumentList '/S' -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "Sunshine installer failed (code $($p.ExitCode))." }
        }
        Remove-Item $file -Force -ErrorAction SilentlyContinue
        for ($i = 0; $i -lt 20 -and -not (Find-Sunshine); $i++) { Start-Sleep -Seconds 1 }
        $exe = Find-Sunshine
        if (-not $exe) { throw 'Sunshine was installed but sunshine.exe was not found.' }
        if (-not (Test-SunshineCurrent)) { Log "Warning: Sunshine $(Get-SunshineVersion) is still below $SunshineMinVersion" }
    }

    Write-StreamState 'installing' 'configure'
    $cfg = Read-Config
    if (-not $cfg.sunUser) {
        Set-ConfigValue $cfg 'sunUser' 'pcremote'
        Set-ConfigValue $cfg 'sunPass' (New-Secret 32)
        Save-Config $cfg
    }
    $svc = Get-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
    if (-not $svc) {
        # The installer normally creates it; if its setup step did not run, run Sunshine's own scripts.
        $root = Split-Path $exe
        foreach ($script in 'install-service.bat', 'add-firewall-rule.bat') {
            $bat = Join-Path $root "scripts\$script"
            if (Test-Path $bat) { Log "Running Sunshine's $script"; Start-Process cmd.exe -ArgumentList "/c `"$bat`"" -Wait -WindowStyle Hidden }
        }
        $svc = Get-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
        if (-not $svc) { throw 'The Sunshine service was not created by the installer.' }
    }
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

try {
    switch ($Task) {
        'InstallSunshine' { Install-Sunshine }
        'SetupTailscale' { Setup-Tailscale }
        default { throw "Unknown task $Task" }
    }
} catch {
    Log "Task $Task failed: $($_.Exception.Message)"
    if ($Task -eq 'SetupTailscale') { Write-TsState 'error' $_.Exception.Message; Remove-Item $TsKeyPath -Force -ErrorAction SilentlyContinue }
    else { Write-StreamState 'error' '' $_.Exception.Message }
    exit 1
}

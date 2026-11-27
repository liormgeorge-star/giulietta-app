# Long-running jobs started by the agent in a separate process, so the agent keeps answering.
#   tasks.ps1 -Task InstallSunshine   downloads and installs Sunshine (the streaming server),
#                                      gives it a private login, and starts its service.
param([Parameter(Mandatory = $true)][string]$Task)

$ErrorActionPreference = 'Stop'
. (Join-Path $env:ProgramData 'PcRemote\common.ps1')

function Install-Sunshine {
    $exe = Find-Sunshine
    if (-not $exe) {
        Write-StreamState 'installing' 'download'
        $dl = Join-Path $Dir 'dl'
        New-Item -ItemType Directory -Path $dl -Force | Out-Null
        $msi = Join-Path $dl 'Sunshine.msi'
        Log "Downloading Sunshine from $SunshineMsiUrl"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $SunshineMsiUrl -OutFile $msi -UseBasicParsing -TimeoutSec 600
        if ((Get-Item $msi).Length -lt 5MB) { throw 'The Sunshine download looks incomplete.' }

        Write-StreamState 'installing' 'install'
        Log 'Installing Sunshine (silent)'
        $p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList (
            '/i "' + $msi + '" /qn /norestart /l*v "' + (Join-Path $dl 'sunshine-install.log') + '"')
        if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { throw "Sunshine installer failed (code $($p.ExitCode))." }
        Remove-Item $msi -Force -ErrorAction SilentlyContinue
        $exe = Find-Sunshine
        if (-not $exe) { throw 'Sunshine was installed but sunshine.exe was not found.' }
    }

    Write-StreamState 'installing' 'configure'
    $cfg = Read-Config
    if (-not $cfg.sunUser) {
        Set-ConfigValue $cfg 'sunUser' 'pcremote'
        Set-ConfigValue $cfg 'sunPass' (New-Secret 24)
        Save-Config $cfg
    }
    $svc = Get-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
    if ($svc) { Stop-Service -Name 'SunshineService' -Force -ErrorAction SilentlyContinue }
    Log 'Setting the Sunshine login used by PC Remote'
    $p = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -Wait -PassThru -WindowStyle Hidden `
        -ArgumentList @('--creds', $cfg.sunUser, $cfg.sunPass)
    if ($p.ExitCode -ne 0) { Log "sunshine --creds exited with $($p.ExitCode)" }

    if ($svc) {
        Set-Service -Name 'SunshineService' -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name 'SunshineService'
    } else {
        throw 'The Sunshine service is missing. Reinstall Sunshine.'
    }

    Write-StreamState 'installing' 'start'
    for ($i = 0; $i -lt 45; $i++) {
        Start-Sleep -Seconds 2
        try { Invoke-SunshineApi GET '/api/clients/list' | Out-Null; Write-StreamState 'ready'; Log 'Sunshine ready'; return } catch { }
    }
    throw 'Sunshine did not start answering.'
}

try {
    switch ($Task) {
        'InstallSunshine' { Install-Sunshine }
        default { throw "Unknown task $Task" }
    }
} catch {
    Log "Task $Task failed: $($_.Exception.Message)"
    Write-StreamState 'error' '' $_.Exception.Message
    exit 1
}

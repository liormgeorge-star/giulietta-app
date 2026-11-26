# PC Remote agent: a small HTTP server that lets the phone app shut down,
# restart or sleep this PC. Installed by install.ps1 and started at boot by a
# scheduled task running as SYSTEM. Only answers on the local network.

$ErrorActionPreference = 'Stop'
$Dir = Join-Path $env:ProgramData 'PcRemote'
$LogFile = Join-Path $Dir 'agent.log'

function Log($msg) {
    try {
        $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $msg
        Add-Content -Path $LogFile -Value $line -Encoding UTF8
        $f = Get-Item $LogFile
        if ($f.Length -gt 512KB) { Move-Item $LogFile "$LogFile.old" -Force }
    } catch { }
}

$cfg = Get-Content (Join-Path $Dir 'config.json') -Raw | ConvertFrom-Json
$Port = [int]$cfg.port
$Token = [string]$cfg.token

function Send-Json($ctx, [int]$code, $obj) {
    $res = $ctx.Response
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Compress))
        $res.StatusCode = $code
        $res.ContentType = 'application/json; charset=utf-8'
        $res.Headers['Access-Control-Allow-Origin'] = '*'
        $res.Headers['Access-Control-Allow-Headers'] = 'X-Token, Content-Type'
        $res.Headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
        $res.Headers['Cache-Control'] = 'no-store'
        $res.ContentLength64 = $bytes.Length
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } finally { $res.Close() }
}

function Get-LocalIPv4 {
    try {
        $a = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex ([int]$cfg.ifIndex) -ErrorAction Stop |
            Where-Object { $_.IPAddress -notlike '169.254.*' } | Select-Object -First 1
        if ($a) { return $a.IPAddress }
    } catch { }
    return ''
}

function Test-Token([string]$given) {
    if ([string]::IsNullOrEmpty($given) -or $given.Length -ne $Token.Length) { return $false }
    $diff = 0
    for ($i = 0; $i -lt $Token.Length; $i++) { $diff = $diff -bor ([int][char]$given[$i] -bxor [int][char]$Token[$i]) }
    return ($diff -eq 0)
}

function Start-Delayed([string]$command) {
    # Run the power action a few seconds later, so the phone gets its answer first.
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("Start-Sleep -Seconds 3; $command"))
    Start-Process -WindowStyle Hidden -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $enc"
}

function Invoke-Request($ctx) {
    $req = $ctx.Request
    $path = $req.Url.AbsolutePath.TrimEnd('/').ToLowerInvariant()
    if ($req.HttpMethod -eq 'OPTIONS') { Send-Json $ctx 200 @{ ok = $true }; return }

    # Anyone on the network may ask whether the PC is on; everything else needs the code.
    if ($path -eq '/ping') { Send-Json $ctx 200 @{ ok = $true }; return }

    if (-not (Test-Token $req.Headers['X-Token'])) {
        Log "Rejected $($req.HttpMethod) $path from $($req.RemoteEndPoint.Address): bad code"
        Start-Sleep -Milliseconds 800
        Send-Json $ctx 401 @{ ok = $false; error = 'bad-token' }
        return
    }

    switch ($path) {
        '/info' {
            Send-Json $ctx 200 @{ ok = $true; name = $env:COMPUTERNAME; mac = $cfg.mac; ip = (Get-LocalIPv4) }
        }
        '/shutdown' {
            if ($req.HttpMethod -ne 'POST') { Send-Json $ctx 405 @{ ok = $false }; return }
            Log "Shutdown requested from $($req.RemoteEndPoint.Address)"
            Send-Json $ctx 200 @{ ok = $true }
            # /s = full shutdown (Fast Startup is off, so Wake-on-LAN works). /t forces apps to close.
            Start-Delayed 'shutdown.exe /s /t 2'
        }
        '/restart' {
            if ($req.HttpMethod -ne 'POST') { Send-Json $ctx 405 @{ ok = $false }; return }
            Log "Restart requested from $($req.RemoteEndPoint.Address)"
            Send-Json $ctx 200 @{ ok = $true }
            Start-Delayed 'shutdown.exe /r /t 2'
        }
        '/sleep' {
            if ($req.HttpMethod -ne 'POST') { Send-Json $ctx 405 @{ ok = $false }; return }
            Log "Sleep requested from $($req.RemoteEndPoint.Address)"
            Send-Json $ctx 200 @{ ok = $true }
            Start-Delayed "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Application]::SetSuspendState('Suspend', `$false, `$false)"
        }
        default { Send-Json $ctx 404 @{ ok = $false; error = 'not-found' } }
    }
}

Log "Agent starting on port $Port"
while ($true) {
    $listener = New-Object System.Net.HttpListener
    try {
        $listener.Prefixes.Add("http://+:$Port/")
        $listener.Start()
        Log 'Listening'
        while ($listener.IsListening) {
            $ctx = $listener.GetContext()
            try { Invoke-Request $ctx } catch { Log "Request error: $($_.Exception.Message)"; try { $ctx.Response.Abort() } catch { } }
        }
    } catch {
        Log "Listener error: $($_.Exception.Message)"
    } finally {
        try { $listener.Close() } catch { }
    }
    Start-Sleep -Seconds 5
}

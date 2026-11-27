# PC Remote agent (run by launcher.ps1 as SYSTEM).
# Answers the phone app on the local network: power (shutdown, restart, sleep),
# streaming setup (Sunshine install and Moonlight pairing) and its own updates.

$ErrorActionPreference = 'Stop'
. (Join-Path $env:ProgramData 'PcRemote\common.ps1')

$cfg = Read-Config
$Port = [int]$cfg.port
$Token = [string]$cfg.token
$Version = Get-AgentVersion
$script:ExitCode = $null          # set to 3 to ask the launcher to apply a staged update
$script:LastUpdateCheck = (Get-Date).AddHours(-6).AddMinutes(2)   # first check ~2 minutes after start
$script:UpdateResult = ''

# ---------- HTTP helpers ----------

function Send-Json($ctx, [int]$code, $obj) {
    $res = $ctx.Response
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Compress -Depth 5))
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

function Read-Body($req) {
    if (-not $req.HasEntityBody) { return $null }
    $sr = New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)
    try { $t = $sr.ReadToEnd() } finally { $sr.Close() }
    if ([string]::IsNullOrWhiteSpace($t)) { return $null }
    try { $t | ConvertFrom-Json } catch { $null }
}

function Test-Token([string]$given) {
    if ([string]::IsNullOrEmpty($given) -or $given.Length -ne $Token.Length) { return $false }
    $diff = 0
    for ($i = 0; $i -lt $Token.Length; $i++) { $diff = $diff -bor ([int][char]$given[$i] -bxor [int][char]$Token[$i]) }
    return ($diff -eq 0)
}

function Start-Hidden([string]$command) {
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    Start-Process -WindowStyle Hidden -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $enc"
}

function Get-LocalIPv4 {
    try {
        $a = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex ([int]$cfg.ifIndex) -ErrorAction Stop |
            Where-Object { $_.IPAddress -notlike '169.254.*' } | Select-Object -First 1
        if ($a) { return $a.IPAddress }
    } catch { }
    return ''
}

# ---------- Streaming (Sunshine) ----------

function Start-SunshineInstall {
    $s = Read-StreamState
    if ($s -and $s.state -eq 'installing' -and ((Get-Date) - [datetime]$s.at).TotalMinutes -lt 20) { return }
    Write-StreamState 'installing' 'queued'
    Start-Process -WindowStyle Hidden -FilePath 'powershell.exe' -ArgumentList (
        '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + (Join-Path $Dir 'tasks.ps1') + '" -Task InstallSunshine')
    Log 'Started Sunshine install task'
}

function Get-StreamStatus {
    $c = Read-Config
    $installed = [bool](Find-Sunshine)
    $s = Read-StreamState
    $state = 'missing'
    if ($s -and $s.state -eq 'installing' -and ((Get-Date) - [datetime]$s.at).TotalMinutes -lt 20) { $state = 'installing' }
    elseif ($installed -and $c.sunUser) { $state = 'ready' }
    elseif ($s -and $s.state -eq 'error') { $state = 'error' }
    $out = [ordered]@{
        state = $state; step = $(if ($s) { $s.step } else { '' }); error = $(if ($s -and $state -eq 'error') { $s.error } else { '' })
        installed = $installed; version = (Get-SunshineVersion); uuid = ''; running = $false; paired = 0; pending = 0
    }
    if ($state -eq 'ready') {
        $out.uuid = Get-SunshineUuid
        $out.running = [bool]$out.uuid
        try {
            $list = Invoke-SunshineApi GET '/api/clients/list' -timeoutSec 4
            if ($list.named_certs) { $out.paired = @($list.named_certs).Count }
        } catch { }
        try {
            $p = Invoke-SunshineApi GET '/api/pin' -timeoutSec 4
            if ($p.PSObject.Properties['pairings'] -and $p.pairings) { $out.pending = @($p.pairings).Count }
        } catch { }
    }
    return $out
}

function Invoke-Pair([string]$pin) {
    if ($pin -notmatch '^\d{4}$') { return @{ ok = $false; error = 'bad-pin' } }
    $body = [ordered]@{ pin = $pin; name = 'Phone' }
    $newApi = $false
    try {
        $p = Invoke-SunshineApi GET '/api/pin' -timeoutSec 5
        if ($p.PSObject.Properties['pairings']) {
            $newApi = $true
            if (-not $p.pairings) { return @{ ok = $false; error = 'no-request' } }
            $list = @($p.pairings)
            $last = $list[$list.Count - 1]
            $body.pairing_id = [string]$last.id
            if ($last.name) { $body.name = [string]$last.name }
        }
    } catch { }   # older Sunshine: no pending list, the PIN alone is enough
    try {
        $r = Invoke-SunshineApi POST '/api/pin' $body -timeoutSec 40
        Log "Pairing result: $($r.status) (new api: $newApi)"
        if ($r.status -eq $true -or "$($r.status)" -eq 'true') { return @{ ok = $true } }
        return @{ ok = $false; error = 'wrong-pin' }
    } catch {
        Log "Pairing failed: $($_.Exception.Message)"
        return @{ ok = $false; error = 'failed' }
    }
}

# ---------- Self-update ----------

function Invoke-UpdateCheck {
    $script:LastUpdateCheck = Get-Date
    $tmp = Join-Path $env:TEMP ('pcr-' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $zip = Join-Path $tmp 'p.zip'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $ReleaseZipUrl -OutFile $zip -UseBasicParsing -TimeoutSec 60
        Expand-Archive -Path $zip -DestinationPath (Join-Path $tmp 'x') -Force
        $x = Join-Path $tmp 'x'
        $newV = [int](Get-Content (Join-Path $x 'version.txt') -Raw).Trim()
        if ($newV -le $Version) { $script:UpdateResult = 'current'; return $false }
        foreach ($f in 'agent.ps1', 'common.ps1', 'tasks.ps1', 'version.txt') {
            if (-not (Test-Path (Join-Path $x $f))) { throw "Update is missing $f" }
        }
        $u = Join-Path $Dir 'update'
        Remove-Item $u -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $u -Force | Out-Null
        foreach ($f in 'agent.ps1', 'common.ps1', 'tasks.ps1', 'version.txt') { Copy-Item (Join-Path $x $f) (Join-Path $u $f) -Force }
        Set-Content -Path (Join-Path $u 'ready.flag') -Value $newV
        Log "Update $Version -> $newV staged"
        $script:UpdateResult = "staged:$newV"
        return $true
    } catch {
        Log "Update check failed: $($_.Exception.Message)"
        $script:UpdateResult = 'failed'
        return $false
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------- Requests ----------

function Invoke-Request($ctx) {
    $req = $ctx.Request
    $path = $req.Url.AbsolutePath.TrimEnd('/').ToLowerInvariant()
    $post = $req.HttpMethod -eq 'POST'
    if ($req.HttpMethod -eq 'OPTIONS') { Send-Json $ctx 200 @{ ok = $true }; return }

    # Anyone on the network may ask whether the PC is on; everything else needs the pairing code.
    if ($path -eq '/ping') { Send-Json $ctx 200 @{ ok = $true; v = $Version }; return }

    if (-not (Test-Token $req.Headers['X-Token'])) {
        Log "Rejected $($req.HttpMethod) $path from $($req.RemoteEndPoint.Address): bad code"
        Start-Sleep -Milliseconds 800
        Send-Json $ctx 401 @{ ok = $false; error = 'bad-token' }
        return
    }
    if (@('/shutdown', '/restart', '/sleep', '/stream/install', '/stream/pair', '/update') -contains $path -and -not $post) {
        Send-Json $ctx 405 @{ ok = $false; error = 'use-post' }; return
    }
    $from = $req.RemoteEndPoint.Address

    switch ($path) {
        '/info' {
            Send-Json $ctx 200 @{ ok = $true; v = $Version; name = $env:COMPUTERNAME; mac = $cfg.mac; ip = (Get-LocalIPv4) }
        }
        '/status' {
            Send-Json $ctx 200 ([ordered]@{
                ok = $true; v = $Version; name = $env:COMPUTERNAME; mac = $cfg.mac; ip = (Get-LocalIPv4)
                stream = (Get-StreamStatus); update = $script:UpdateResult })
        }
        '/shutdown' {
            Log "Shutdown requested from $from"
            Send-Json $ctx 200 @{ ok = $true }
            Start-Hidden 'Start-Sleep -Seconds 3; shutdown.exe /s /t 2'
        }
        '/restart' {
            Log "Restart requested from $from"
            Send-Json $ctx 200 @{ ok = $true }
            Start-Hidden 'Start-Sleep -Seconds 3; shutdown.exe /r /t 2'
        }
        '/sleep' {
            Log "Sleep requested from $from"
            Send-Json $ctx 200 @{ ok = $true }
            Start-Hidden "Start-Sleep -Seconds 3; Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Application]::SetSuspendState('Suspend', `$false, `$false)"
        }
        '/stream/install' {
            Start-SunshineInstall
            Send-Json $ctx 200 @{ ok = $true }
        }
        '/stream/pair' {
            $b = Read-Body $req
            $pin = if ($b) { [string]$b.pin } else { '' }
            Log "Pairing requested from $from"
            Send-Json $ctx 200 (Invoke-Pair $pin)
        }
        '/update' {
            $staged = Invoke-UpdateCheck
            Send-Json $ctx 200 @{ ok = $true; v = $Version; result = $script:UpdateResult }
            if ($staged) { $script:ExitCode = 3 }
        }
        default { Send-Json $ctx 404 @{ ok = $false; error = 'not-found' } }
    }
}

function Invoke-Tick {
    if (((Get-Date) - $script:LastUpdateCheck).TotalHours -ge 6) {
        if (Invoke-UpdateCheck) { $script:ExitCode = 3 }
    }
}

# ---------- Main ----------

Log "Agent v$Version starting on port $Port"
if (-not (Find-Sunshine) -or -not $cfg.sunUser) { Start-SunshineInstall }

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$Port/")
$listener.Start()
Log 'Listening'
try {
    while ($null -eq $script:ExitCode) {
        $ar = $listener.BeginGetContext($null, $null)
        while (-not $ar.AsyncWaitHandle.WaitOne(1000)) {
            try { Invoke-Tick } catch { Log "Tick error: $($_.Exception.Message)" }
            if ($null -ne $script:ExitCode) { break }
        }
        if ($null -ne $script:ExitCode) { break }
        $ctx = $listener.EndGetContext($ar)
        try { Invoke-Request $ctx } catch { Log "Request error: $($_.Exception.Message)"; try { $ctx.Response.Abort() } catch { } }
    }
} finally {
    try { $listener.Close() } catch { }
}
Log "Agent exiting (code $script:ExitCode)"
exit $script:ExitCode

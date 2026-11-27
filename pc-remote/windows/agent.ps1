# PC Remote agent v3 (run by launcher.ps1 as SYSTEM).
# Answers the phone app on the home network and on the Tailscale network only (firewall).
#
# Security model
#  - Every request except /ping is signed with a key derived from the pairing code (PBKDF2 +
#    HMAC-SHA256). The pairing code itself never travels on the network.
#  - Each request carries a timestamp and a one-time nonce: old or replayed requests are refused.
#  - Request bodies are encrypted (AES-256-CBC); responses are signed so the app can tell a real
#    answer from a fake one.
#  - Repeated bad signatures from one address lock that address out for 15 minutes.
#  - Updates are applied only when the app (authenticated) supplies the exact SHA-256 of the
#    release package it was built with.

$ErrorActionPreference = 'Stop'
. (Join-Path $env:ProgramData 'PcRemote\common.ps1')

$cfg = Read-Config
$Port = [int]$cfg.port
$Version = Get-AgentVersion
if (-not $cfg.salt) { Set-ConfigValue $cfg 'salt' (ConvertTo-Hex ([byte[]](1..16 | ForEach-Object { Get-Random -Maximum 256 }))); Save-Config $cfg }
$Keys = New-AuthKeys ([string]$cfg.token) ([string]$cfg.salt)
$script:ExitCode = $null
$script:Nonces = @{}
$script:Fails = @{}
$script:TsCache = $null
$script:TsCacheAt = [datetime]::MinValue

$MaxBody = 16KB
$SkewMs = 120000

# ---------- HTTP ----------

function Send-Json($ctx, [int]$code, $obj, [string]$nonce = '') {
    $res = $ctx.Response
    try {
        $text = ($obj | ConvertTo-Json -Compress -Depth 6)
        $bytes = [Text.Encoding]::UTF8.GetBytes($text)
        $res.StatusCode = $code
        $res.ContentType = 'application/json; charset=utf-8'
        $res.Headers['Cache-Control'] = 'no-store'
        $res.Headers['X-Content-Type-Options'] = 'nosniff'
        if ($nonce) {
            $sig = ConvertTo-Hex (Get-HmacSha256 $Keys.mac ([Text.Encoding]::UTF8.GetBytes("resp`n$nonce`n$code`n$text")))
            $res.Headers['X-Sig'] = $sig
        }
        $res.ContentLength64 = $bytes.Length
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } finally { $res.Close() }
}

function Read-BodyText($req) {
    if (-not $req.HasEntityBody) { return '' }
    if ($req.ContentLength64 -gt $MaxBody) { throw 'too-large' }
    $ms = New-Object IO.MemoryStream
    $buf = New-Object byte[] 4096
    while (($n = $req.InputStream.Read($buf, 0, $buf.Length)) -gt 0) {
        $ms.Write($buf, 0, $n)
        if ($ms.Length -gt $MaxBody) { throw 'too-large' }
    }
    return [Text.Encoding]::UTF8.GetString($ms.ToArray())
}

function Get-NowMs { [long]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) }

function Test-Locked([string]$ip) {
    $f = $script:Fails[$ip]
    return ($f -and $f.until -gt (Get-Date))
}

function Add-Failure([string]$ip) {
    $now = Get-Date
    $f = $script:Fails[$ip]
    if (-not $f -or $f.first -lt $now.AddMinutes(-10)) { $f = @{ count = 0; first = $now; until = [datetime]::MinValue } }
    $f.count++
    if ($f.count -ge 8) { $f.until = $now.AddMinutes(15); Log "Locked out $ip for 15 minutes after repeated bad requests" }
    $script:Fails[$ip] = $f
}

function Test-Signature($req, [string]$body) {
    $ts = [string]$req.Headers['X-Ts']; $nonce = [string]$req.Headers['X-Nonce']; $sig = [string]$req.Headers['X-Sig']
    if ($ts -notmatch '^\d{10,16}$' -or $nonce -notmatch '^[0-9a-f]{32}$' -or $sig -notmatch '^[0-9a-f]{64}$') { return $null }
    $now = Get-NowMs
    if ([math]::Abs($now - [long]$ts) -gt $SkewMs) { return $null }
    if ($script:Nonces.ContainsKey($nonce)) { return $null }
    $msg = "$($req.HttpMethod)`n$($req.Url.AbsolutePath)`n$ts`n$nonce`n$body"
    $expect = ConvertTo-Hex (Get-HmacSha256 $Keys.mac ([Text.Encoding]::UTF8.GetBytes($msg)))
    if (-not (Test-ConstantTimeEqual $expect $sig)) { return $null }
    $script:Nonces[$nonce] = $now
    if ($script:Nonces.Count -gt 2000) {
        foreach ($k in @($script:Nonces.Keys)) { if ($now - $script:Nonces[$k] -gt 2 * $SkewMs) { $script:Nonces.Remove($k) } }
    }
    return $nonce
}

function Start-Hidden([string]$command) {
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    Start-Process -WindowStyle Hidden -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $enc"
}

function Start-Task([string]$name) {
    # Anything the task prints to stderr (even a failure to start) ends up in a file the app can show.
    $err = Join-Path $Dir "task-$name.err"
    Start-Process -FilePath 'powershell.exe' -RedirectStandardError $err -RedirectStandardOutput (Join-Path $Dir "task-$name.out") -ArgumentList (
        '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + (Join-Path $Dir 'tasks.ps1') + '" -Task ' + $name)
}

function Get-Diag {
    $out = [ordered]@{ ok = $true; v = $Version; log = @(Get-LogTail 80); taskErrors = @() }
    foreach ($f in Get-ChildItem -Path (Join-Path $Dir 'task-*.err') -ErrorAction SilentlyContinue) {
        $t = (Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue)
        if ($t -and $t.Trim()) { $out.taskErrors += ($f.Name + ': ' + $t.Trim().Substring(0, [math]::Min(1500, $t.Trim().Length))) }
    }
    $msiLog = Join-Path $Dir 'dl\sunshine-install.log'
    if (Test-Path $msiLog) {
        $out.msi = @(Get-Content $msiLog -ErrorAction SilentlyContinue | Where-Object { $_ -match 'Return value 3|Error \d+|error code|failed' } | Select-Object -Last 15)
    }
    $out.sunshine = [ordered]@{ exe = [string](Find-Sunshine); version = (Get-SunshineVersion); service = [string](Get-Service SunshineService -ErrorAction SilentlyContinue).Status }
    return $out
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

function Start-SunshineInstall([switch]$Force) {
    $s = Read-StreamState
    if ($s -and $s.state -eq 'installing' -and ((Get-Date) - [datetime]$s.at).TotalMinutes -lt 20) { return }
    if (-not $Force) {
        $c = Read-Config
        if ($c.sunTriedAt -and ((Get-Date) - [datetime]$c.sunTriedAt).TotalMinutes -lt 30) { return }
        Set-ConfigValue $c 'sunTriedAt' (Get-Date).ToString('o'); Save-Config $c
    }
    Write-StreamState 'installing' 'queued'
    Start-Task 'InstallSunshine'
    Log 'Started Sunshine install/update task'
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
        installed = $installed; version = (Get-SunshineVersion); secure = (Test-SunshineCurrent)
        uuid = ''; running = $false; paired = 0; pending = 0
    }
    if ($state -eq 'ready') {
        $out.uuid = Get-SunshineUuid
        $out.running = [bool]$out.uuid
        try { $list = Invoke-SunshineApi GET '/api/clients/list' -timeoutSec 4; if ($list.named_certs) { $out.paired = @($list.named_certs).Count } } catch { }
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
    try {
        $p = Invoke-SunshineApi GET '/api/pin' -timeoutSec 5
        if ($p.PSObject.Properties['pairings']) {
            if (-not $p.pairings) { return @{ ok = $false; error = 'no-request' } }
            $list = @($p.pairings)
            $last = $list[$list.Count - 1]
            $body.pairing_id = [string]$last.id
            if ($last.name) { $body.name = [string]$last.name }
        }
    } catch { }
    try {
        $r = Invoke-SunshineApi POST '/api/pin' $body -timeoutSec 40
        if ($r.status -eq $true -or "$($r.status)" -eq 'true') { Log 'Moonlight paired'; return @{ ok = $true } }
        return @{ ok = $false; error = 'wrong-pin' }
    } catch {
        Log "Pairing failed: $($_.Exception.Message)"
        return @{ ok = $false; error = 'failed' }
    }
}

# ---------- Tailscale ----------

function Get-TsStatusCached {
    if (((Get-Date) - $script:TsCacheAt).TotalSeconds -gt 10) {
        $script:TsCache = Get-TailscaleStatus
        $script:TsCacheAt = Get-Date
        try { $st = Get-Content $TsStatePath -Raw | ConvertFrom-Json } catch { $st = $null }
        $script:TsCache.setup = $(if ($st) { [string]$st.state } else { '' })
        $script:TsCache.error = $(if ($st -and $st.state -eq 'error') { [string]$st.error } else { '' })
        if ($st -and $st.state -in 'installing', 'joining' -and ((Get-Date) - [datetime]$st.at).TotalMinutes -gt 15) { $script:TsCache.setup = 'error'; $script:TsCache.error = 'timeout' }
    }
    return $script:TsCache
}

function Start-TailscaleSetup([string]$authKey) {
    if ($authKey -notmatch '^tskey-[A-Za-z0-9-]{10,200}$') { return @{ ok = $false; error = 'bad-key' } }
    Set-Content -Path $TsKeyPath -Value $authKey -Encoding ASCII -NoNewline
    @{ state = 'installing'; error = ''; at = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -Path $TsStatePath -Encoding UTF8
    $script:TsCacheAt = [datetime]::MinValue
    Start-Task 'SetupTailscale'
    Log 'Started Tailscale setup task'
    return @{ ok = $true }
}

# ---------- Self-update (only with the hash the app was built with) ----------

function Invoke-Update([string]$sha) {
    if ($sha -notmatch '^[0-9a-fA-F]{64}$') { return @{ ok = $false; error = 'no-hash' } }
    $tmp = Join-Path $env:TEMP ('pcr-' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $zip = Join-Path $tmp 'p.zip'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $ReleaseZipUrl -OutFile $zip -UseBasicParsing -TimeoutSec 60
        $got = (Get-FileHash -Path $zip -Algorithm SHA256).Hash
        if ($got -ne $sha.ToUpperInvariant()) { Log "Update refused: package hash $got does not match the app's"; return @{ ok = $false; error = 'hash-mismatch' } }
        Expand-Archive -Path $zip -DestinationPath (Join-Path $tmp 'x') -Force
        $x = Join-Path $tmp 'x'
        $newV = [int](Get-Content (Join-Path $x 'version.txt') -Raw).Trim()
        if ($newV -le $Version) { return @{ ok = $true; result = 'current' } }
        $files = 'agent.ps1', 'common.ps1', 'tasks.ps1', 'version.txt'
        foreach ($f in $files) { if (-not (Test-Path (Join-Path $x $f))) { throw "Update is missing $f" } }
        $u = Join-Path $Dir 'update'
        Remove-Item $u -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $u -Force | Out-Null
        foreach ($f in $files) { Copy-Item (Join-Path $x $f) (Join-Path $u $f) -Force }
        Set-Content -Path (Join-Path $u 'ready.flag') -Value $newV
        Log "Update $Version -> $newV staged (hash verified)"
        return @{ ok = $true; result = "staged:$newV" }
    } catch {
        Log "Update failed: $($_.Exception.Message)"
        return @{ ok = $false; error = 'failed' }
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------- Requests ----------

$PostOnly = @('/shutdown', '/restart', '/sleep', '/stream/install', '/stream/pair', '/stream/creds', '/update', '/tailscale/setup')

function Invoke-Request($ctx) {
    $req = $ctx.Request
    $ip = [string]$req.RemoteEndPoint.Address
    $path = $req.Url.AbsolutePath

    if ($req.HttpMethod -ne 'GET' -and $req.HttpMethod -ne 'POST') { Send-Json $ctx 405 @{ ok = $false }; return }

    # Anyone allowed by the firewall may ask whether the PC is on. It reveals no names or addresses.
    if ($path -eq '/ping') { Send-Json $ctx 200 @{ ok = $true; v = $Version; t = (Get-NowMs); s = [string]$cfg.salt }; return }

    if (Test-Locked $ip) { Send-Json $ctx 429 @{ ok = $false; error = 'locked' }; return }
    try { $body = Read-BodyText $req } catch { Add-Failure $ip; Send-Json $ctx 413 @{ ok = $false }; return }
    $nonce = Test-Signature $req $body
    if (-not $nonce) {
        Add-Failure $ip
        Log "Rejected $($req.HttpMethod) $path from ${ip}: bad signature"
        Send-Json $ctx 401 @{ ok = $false; error = 'bad-auth' }
        return
    }
    if ($PostOnly -contains $path -and $req.HttpMethod -ne 'POST') { Send-Json $ctx 405 @{ ok = $false } $nonce; return }
    $data = $null
    if ($body) { try { $data = Unprotect-Body $Keys.enc $body } catch { Send-Json $ctx 400 @{ ok = $false; error = 'bad-body' } $nonce; return } }

    switch ($path) {
        '/info' {
            Send-Json $ctx 200 @{ ok = $true; v = $Version; name = $env:COMPUTERNAME; mac = $cfg.mac; ip = (Get-LocalIPv4) } $nonce
        }
        '/status' {
            Send-Json $ctx 200 ([ordered]@{
                ok = $true; v = $Version; name = $env:COMPUTERNAME; mac = $cfg.mac; ip = (Get-LocalIPv4)
                stream = (Get-StreamStatus); tailscale = (Get-TsStatusCached) }) $nonce
        }
        '/shutdown' {
            Log "Shutdown requested from $ip"
            Send-Json $ctx 200 @{ ok = $true } $nonce
            Start-Hidden 'Start-Sleep -Seconds 3; shutdown.exe /s /t 2'
        }
        '/restart' {
            Log "Restart requested from $ip"
            Send-Json $ctx 200 @{ ok = $true } $nonce
            Start-Hidden 'Start-Sleep -Seconds 3; shutdown.exe /r /t 2'
        }
        '/sleep' {
            Log "Sleep requested from $ip"
            Send-Json $ctx 200 @{ ok = $true } $nonce
            Start-Hidden "Start-Sleep -Seconds 3; Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Application]::SetSuspendState('Suspend', `$false, `$false)"
        }
        '/stream/install' { Start-SunshineInstall -Force; Send-Json $ctx 200 @{ ok = $true } $nonce }
        '/diag' { Send-Json $ctx 200 (Get-Diag) $nonce }
        '/stream/creds' {
            $u = [string]$data.user; $pw = [string]$data.pass
            # No quotes or spaces (they are passed on a command line); sensible lengths.
            if ($u -notmatch '^[A-Za-z0-9._@-]{1,32}$') { Send-Json $ctx 200 @{ ok = $false; error = 'bad-user' } $nonce; break }
            if ($pw.Length -lt 8 -or $pw.Length -gt 128 -or $pw -match '[\s"]') { Send-Json $ctx 200 @{ ok = $false; error = 'bad-pass' } $nonce; break }
            Log "Sunshine login changed from $ip"
            try { $okApi = Set-SunshineCreds $u $pw; Send-Json $ctx 200 @{ ok = $true; verified = [bool]$okApi } $nonce }
            catch { Log "Sunshine login change failed: $($_.Exception.Message)"; Send-Json $ctx 200 @{ ok = $false; error = 'failed' } $nonce }
        }
        '/stream/pair' {
            Log "Pairing requested from $ip"
            Send-Json $ctx 200 (Invoke-Pair ([string]$data.pin)) $nonce
        }
        '/tailscale/setup' {
            Log "Tailscale setup requested from $ip"
            Send-Json $ctx 200 (Start-TailscaleSetup ([string]$data.authKey)) $nonce
        }
        '/update' {
            $r = Invoke-Update ([string]$data.sha256)
            $r.v = $Version
            Send-Json $ctx 200 $r $nonce
            if ($r.result -like 'staged:*') { $script:ExitCode = 3 }
        }
        default { Send-Json $ctx 404 @{ ok = $false; error = 'not-found' } $nonce }
    }
}

# ---------- Main ----------

Log "Agent v$Version starting on port $Port"
Set-AgentFirewallScope
# Older versions left the pairing code in a text file on the desktop; remove any copy.
Get-ChildItem -Path (Join-Path $env:SystemDrive 'Users\*\Desktop\PC Remote - pairing.txt') -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
if (-not (Find-Sunshine) -or -not $cfg.sunUser -or -not (Test-SunshineCurrent)) { Start-SunshineInstall }
elseif (Set-SunshineConf $SunshineHardening) {
    Log 'Applied Sunshine hardening settings'
    Restart-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$Port/")
$listener.Start()
Log 'Listening'
try {
    while ($null -eq $script:ExitCode) {
        $ar = $listener.BeginGetContext($null, $null)
        $ticks = 0
        while (-not $ar.AsyncWaitHandle.WaitOne(1000)) {
            $ticks++
            if (($ticks % 300) -eq 0) {
                try { if (-not (Find-Sunshine) -or -not (Test-SunshineCurrent)) { Start-SunshineInstall } } catch { Log "Retry check failed: $($_.Exception.Message)" }
            }
        }
        $ctx = $listener.EndGetContext($ar)
        try { Invoke-Request $ctx } catch { Log "Request error: $($_.Exception.Message)"; try { $ctx.Response.Abort() } catch { } }
    }
} finally {
    try { $listener.Close() } catch { }
}
Log "Agent exiting (code $script:ExitCode)"
exit $script:ExitCode

# Shared helpers for agent.ps1 and tasks.ps1 (dot-sourced).

$Dir = Join-Path $env:ProgramData 'PcRemote'
$CfgPath = Join-Path $Dir 'config.json'
$StreamStatePath = Join-Path $Dir 'stream-state.json'
$LogFile = Join-Path $Dir 'agent.log'
$ReleaseZipUrl = 'https://github.com/liormgeorge-star/giulietta-app/releases/download/pc-remote-latest/pc-remote-windows.zip'
$SunshineMsiUrl = 'https://github.com/LizardByte/Sunshine/releases/latest/download/Sunshine-Windows-AMD64-installer.msi'
# Sunshine releases older than this have published security fixes missing
# (CVE-2026-32253 auth bypass, May 2026; September 2026 pairing/DoS fixes).
$SunshineMinVersion = [version]'2026.906.222525'
$TsStatePath = Join-Path $Dir 'tailscale-state.json'
$TsKeyPath = Join-Path $Dir 'tailscale-key.tmp'
$FirewallRuleName = 'PC Remote Agent (TCP 8765)'
$TailscaleRange = '100.64.0.0/10'

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Sunshine's web API uses a self-signed certificate. Accept that only for localhost;
# every other HTTPS call (GitHub downloads) keeps normal certificate checking.
if (-not ('PcrTls' -as [type])) {
    Add-Type -TypeDefinition @'
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public static class PcrTls {
    public static bool Check(object sender, X509Certificate cert, X509Chain chain, SslPolicyErrors errors) {
        if (errors == SslPolicyErrors.None) return true;
        HttpWebRequest req = sender as HttpWebRequest;
        if (req != null) {
            string h = req.RequestUri.Host;
            if (h == "localhost" || h == "127.0.0.1") return true;
        }
        return false;
    }
    public static void Install() { ServicePointManager.ServerCertificateValidationCallback = Check; }
}
'@
}
[PcrTls]::Install()

function Log($msg) {
    try {
        Add-Content -Path $LogFile -Value ('{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $msg) -Encoding UTF8
        if ((Get-Item $LogFile).Length -gt 512KB) { Move-Item $LogFile "$LogFile.old" -Force }
    } catch { }
}

function Read-Config { Get-Content $CfgPath -Raw | ConvertFrom-Json }

function Save-Config($cfg) {
    $tmp = "$CfgPath.tmp"
    $cfg | ConvertTo-Json | Set-Content -Path $tmp -Encoding ASCII
    Move-Item $tmp $CfgPath -Force
}

function Set-ConfigValue($cfg, [string]$name, $value) {
    if ($cfg.PSObject.Properties[$name]) { $cfg.$name = $value }
    else { $cfg | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

function New-Secret([int]$length, [string]$chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789') {
    $bytes = New-Object byte[] $length
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

function Get-AgentVersion {
    try { [int](Get-Content (Join-Path $Dir 'version.txt') -Raw).Trim() } catch { 0 }
}

# ---------- Sunshine ----------

function Find-Sunshine {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Sunshine\sunshine.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Sunshine\sunshine.exe'))
    foreach ($key in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                     'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        Get-ItemProperty $key -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like 'Sunshine*' -and $_.InstallLocation } |
            ForEach-Object { $candidates += (Join-Path $_.InstallLocation 'sunshine.exe') }
    }
    # The service knows where Sunshine really lives (<root>\tools\sunshinesvc.exe).
    try {
        $svc = Get-CimInstance Win32_Service -Filter "Name='SunshineService'" -ErrorAction Stop
        if ($svc -and $svc.PathName) {
            if ($svc.PathName -match '^\s*"([^"]+)"') { $bin = $Matches[1] }
            elseif ($svc.PathName -match '^\s*(.+?\.exe)') { $bin = $Matches[1] }
            else { $bin = $svc.PathName.Trim() }
            $candidates += (Join-Path (Split-Path (Split-Path $bin)) 'sunshine.exe')
        }
    } catch { }
    foreach ($root in $env:ProgramFiles, ${env:ProgramFiles(x86)}) {
        if ($root) { Get-ChildItem -Path (Join-Path $root '*\Sunshine\sunshine.exe') -ErrorAction SilentlyContinue | ForEach-Object { $candidates += $_.FullName } }
    }
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    return $null
}

function Get-LogTail([int]$lines = 60) {
    try { return @(Get-Content $LogFile -Tail $lines -Encoding UTF8) } catch { return @() }
}

function Get-SunshineVersion {
    foreach ($key in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                     'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        $e = Get-ItemProperty $key -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Sunshine*' } | Select-Object -First 1
        if ($e) { return [string]$e.DisplayVersion }
    }
    return ''
}

function Invoke-SunshineApi([string]$method, [string]$path, $body = $null, [int]$timeoutSec = 10) {
    $cfg = Read-Config
    if (-not $cfg.sunUser) { throw 'no-credentials' }
    $pair = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($cfg.sunUser):$($cfg.sunPass)"))
    $params = @{
        Uri = "https://localhost:47990$path"; Method = $method; TimeoutSec = $timeoutSec; UseBasicParsing = $true
        Headers = @{ Authorization = "Basic $pair" }
    }
    if ($null -ne $body) {
        $params.Body = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Compress))
        $params.ContentType = 'application/json'
    }
    Invoke-RestMethod @params
}

function Get-SunshineUuid {
    try {
        $r = Invoke-WebRequest -Uri 'http://localhost:47989/serverinfo' -UseBasicParsing -TimeoutSec 3
        $x = [xml]$r.Content
        return [string]$x.root.uniqueid
    } catch { return '' }
}

function Read-StreamState {
    try { Get-Content $StreamStatePath -Raw | ConvertFrom-Json } catch { $null }
}

function Write-StreamState([string]$state, [string]$step = '', [string]$err = '') {
    @{ state = $state; step = $step; error = $err; at = (Get-Date).ToString('o') } |
        ConvertTo-Json | Set-Content -Path $StreamStatePath -Encoding UTF8
}

function Get-SunshineInstallDir {
    $exe = Find-Sunshine
    if ($exe) { return (Split-Path $exe) }
    return $null
}

function Test-SunshineCurrent {
    # True when the installed Sunshine has the 2026 security fixes.
    $v = Get-SunshineVersion
    if (-not $v) { return $false }
    try { return ([version]($v -replace '[^0-9.].*$', '')) -ge $SunshineMinVersion } catch { return $false }
}

function Set-SunshineConf {
    # Sets "key = value" lines in sunshine.conf. Returns $true when the file changed.
    param([hashtable]$Settings)
    $dir = Get-SunshineInstallDir
    if (-not $dir) { return $false }
    $conf = Join-Path $dir 'config\sunshine.conf'
    $lines = @()
    if (Test-Path $conf) { $lines = @(Get-Content $conf -Encoding UTF8) }
    $changed = $false
    foreach ($k in $Settings.Keys) {
        $want = "$k = $($Settings[$k])"
        $idx = -1
        for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match "^\s*$([regex]::Escape($k))\s*=") { $idx = $i; break } }
        if ($idx -ge 0) {
            if ($lines[$idx].Trim() -ne $want) { $lines[$idx] = $want; $changed = $true }
        } else { $lines += $want; $changed = $true }
    }
    if ($changed) {
        New-Item -ItemType Directory -Path (Split-Path $conf) -Force | Out-Null
        Set-Content -Path $conf -Value $lines -Encoding UTF8
    }
    return $changed
}

# Hardening applied to every Sunshine we manage:
#  - Web UI/API only from this PC (the agent talks to it on localhost).
#  - Stream encryption: when the client supports it on the LAN/VPN, always over the internet.
#  - UPnP off: never open router ports.
$SunshineHardening = @{
    origin_web_ui_allowed = 'pc'
    lan_encryption_mode   = '1'
    wan_encryption_mode   = '2'
    upnp                  = 'disabled'
}

# ---------- Tailscale ----------

function Find-Tailscale {
    foreach ($p in (Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'), (Join-Path ${env:ProgramFiles(x86)} 'Tailscale\tailscale.exe')) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}

function Get-TailscaleStatus {
    $exe = Find-Tailscale
    $out = [ordered]@{ installed = [bool]$exe; online = $false; ip = ''; name = ''; state = '' }
    if (-not $exe) { return $out }
    $ErrorActionPreference = 'Continue'   # tailscale.exe may write to stderr; that must not throw here
    try {
        $json = & $exe status --json 2>$null | Out-String
        $s = $json | ConvertFrom-Json
        $out.state = [string]$s.BackendState
        $out.online = ($s.BackendState -eq 'Running')
        if ($s.Self) {
            $out.ip = [string](@($s.Self.TailscaleIPs) | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)
            $out.name = [string]$s.Self.DNSName
        }
    } catch { }
    return $out
}

function Set-AgentFirewallScope {
    # The agent answers the home network and the Tailscale network (100.64.0.0/10) only.
    try {
        $rule = Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction Stop
        $rule | Get-NetFirewallAddressFilter | Set-NetFirewallAddressFilter -RemoteAddress @('LocalSubnet', $TailscaleRange) -ErrorAction Stop
    } catch { Log "Firewall scope update failed: $($_.Exception.Message)" }
}

# ---------- Request signing (protocol v3) ----------
# key    = PBKDF2-HMAC-SHA256(pairing code, "pcremote-v3:" + salt, 100000 iterations, 32 bytes)
# macKey = HMAC-SHA256(key, "mac"), encKey = HMAC-SHA256(key, "enc")
# request signature  = HMAC(macKey, METHOD \n path \n ts \n nonce \n body)
# response signature = HMAC(macKey, "resp" \n nonce \n status \n body)
# POST bodies carry {"iv","ct"}: AES-256-CBC(encKey) of the JSON payload.

function ConvertTo-Hex([byte[]]$b) { -join ($b | ForEach-Object { $_.ToString('x2') }) }

function Get-HmacSha256([byte[]]$key, [byte[]]$data) {
    $h = New-Object Security.Cryptography.HMACSHA256 -ArgumentList (, $key)
    try { return $h.ComputeHash($data) } finally { $h.Dispose() }
}

function New-AuthKeys([string]$token, [string]$saltHex) {
    $pw = [Text.Encoding]::UTF8.GetBytes($token)
    $salt = [Text.Encoding]::UTF8.GetBytes("pcremote-v3:$saltHex")
    $kdf = New-Object Security.Cryptography.Rfc2898DeriveBytes -ArgumentList $pw, $salt, 100000, ([Security.Cryptography.HashAlgorithmName]::SHA256)
    try { $k = $kdf.GetBytes(32) } finally { $kdf.Dispose() }
    return @{
        mac = Get-HmacSha256 $k ([Text.Encoding]::UTF8.GetBytes('mac'))
        enc = Get-HmacSha256 $k ([Text.Encoding]::UTF8.GetBytes('enc'))
    }
}

function Test-ConstantTimeEqual([string]$a, [string]$b) {
    if ($null -eq $a -or $null -eq $b -or $a.Length -ne $b.Length) { return $false }
    $d = 0
    for ($i = 0; $i -lt $a.Length; $i++) { $d = $d -bor ([int][char]$a[$i] -bxor [int][char]$b[$i]) }
    return ($d -eq 0)
}

function Unprotect-Body([byte[]]$encKey, [string]$bodyText) {
    $o = $bodyText | ConvertFrom-Json
    $aes = [Security.Cryptography.Aes]::Create()
    try {
        $aes.Mode = [Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = $encKey
        $aes.IV = [Convert]::FromBase64String([string]$o.iv)
        $ct = [Convert]::FromBase64String([string]$o.ct)
        $dec = $aes.CreateDecryptor()
        $plain = $dec.TransformFinalBlock($ct, 0, $ct.Length)
        return ([Text.Encoding]::UTF8.GetString($plain) | ConvertFrom-Json)
    } finally { $aes.Dispose() }
}

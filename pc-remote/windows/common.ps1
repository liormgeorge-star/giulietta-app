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

function Set-SunshineCreds([string]$user, [string]$pass) {
    # Sets the Sunshine Web UI login chosen by the user and keeps a copy for the agent,
    # so pairing from the app keeps working.
    $exe = Find-Sunshine
    if (-not $exe) { throw 'not-installed' }
    Stop-Service -Name 'SunshineService' -Force -ErrorAction SilentlyContinue
    $p = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -Wait -PassThru -WindowStyle Hidden `
        -ArgumentList ('--creds "' + $user + '" "' + $pass + '"')
    Start-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
    if ($p.ExitCode -ne 0) { throw "sunshine --creds exited with $($p.ExitCode)" }
    $cfg = Read-Config
    Set-ConfigValue $cfg 'sunUser' $user
    Set-ConfigValue $cfg 'sunPass' $pass
    Save-Config $cfg
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        try { Invoke-SunshineApi GET '/api/clients/list' -timeoutSec 3 | Out-Null; return $true } catch { }
    }
    return $false
}

# ---------- Installers (used by tasks.ps1 and install.ps1) ----------

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

function Invoke-Msi([string]$file, [string]$extra, [string]$logName, [switch]$Visible) {
    # 1618 = another installation is running (often Windows Update): wait and retry.
    for ($try = 1; $try -le 6; $try++) {
        $ui = if ($Visible) { '/passive' } else { '/qn' }
        $msiArgs = '/i "' + $file + '" ' + $ui + ' /norestart ' + $extra + ' /l*v "' + (Join-Path (Split-Path $file) $logName) + '"'
        $p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList $msiArgs
        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) { return }
        if ($p.ExitCode -ne 1618) { throw "Installer failed (msiexec code $($p.ExitCode)). Details: $logName" }
        Log "Another installation is running (1618), retry $try/6 in 60 seconds"
        Start-Sleep -Seconds 60
    }
    throw 'Another installation kept running (msiexec 1618). Try again later.'
}

function Get-SunshineInstaller([string]$dl) {
    $ProgressPreference = 'SilentlyContinue'   # the PS 5.1 progress bar makes downloads very slow
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

function Install-SunshinePackage([switch]$Visible) {
    # Downloads (signature-checked) and installs the current Sunshine. -Visible shows the progress bar.
    $dl = Join-Path $Dir 'dl'
    New-Item -ItemType Directory -Path $dl -Force | Out-Null
    $file = Get-SunshineInstaller $dl
    # Sunshine's installers are signed by its maintainer (David Lane, LizardByte).
    Assert-Signed $file 'David Lane|LizardByte' -AllowUnsigned
    Stop-SunshineForUpdate
    if ($file -match '(?i)\.msi$') {
        try { Invoke-Msi $file '' 'sunshine-install.log' -Visible:$Visible }
        catch {
            $first = $_.Exception.Message
            Log "Sunshine install failed: $first. $(Get-MsiFailureHint (Join-Path $dl 'sunshine-install.log'))"
            # An older Sunshine from the .exe (NSIS) installer blocks the MSI: remove it and try once more.
            if (Remove-OldSunshineExeInstall) {
                Stop-SunshineForUpdate
                Invoke-Msi $file '' 'sunshine-install.log' -Visible:$Visible
            } else { throw "$first $(Get-MsiFailureHint (Join-Path $dl 'sunshine-install.log'))" }
        }
    }
    else {
        $p = Start-Process -FilePath $file -ArgumentList '/S' -Wait -PassThru
        if ($p.ExitCode -ne 0) { throw "Sunshine installer failed (code $($p.ExitCode))." }
    }
    Remove-Item $file -Force -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 20 -and -not (Find-Sunshine); $i++) { Start-Sleep -Seconds 1 }
    $exe = Find-Sunshine
    if (-not $exe) { throw 'Sunshine was installed but sunshine.exe was not found.' }
    return $exe
}

function Initialize-SunshineService([string]$exe) {
    # Creates the Sunshine Windows service directly (the same thing Sunshine's install-service.bat does:
    # sc create SunshineService binPath= "<root>\tools\sunshinesvc.exe" start= auto), so we do not depend
    # on the installer's setup step, which can fail on some PCs.
    $root = Split-Path $exe
    $svcBin = Join-Path $root 'tools\sunshinesvc.exe'
    $svc = Get-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
    if (-not $svc) {
        if (-not (Test-Path $svcBin)) { throw "Sunshine's service program is missing: $svcBin" }
        Log "Creating the Sunshine service ($svcBin)"
        New-Service -Name 'SunshineService' -BinaryPathName ('"' + $svcBin + '"') -DisplayName 'Sunshine Service' `
            -Description 'Sunshine is a self-hosted game stream host for Moonlight.' -StartupType Automatic | Out-Null
        $svc = Get-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
        if (-not $svc) { throw 'Could not create the Sunshine service.' }
    } else {
        # Make sure an existing service points at this Sunshine and starts with Windows.
        $cim = Get-CimInstance Win32_Service -Filter "Name='SunshineService'" -ErrorAction SilentlyContinue
        if ($cim -and (Test-Path $svcBin) -and $cim.PathName -notlike "*$svcBin*") {
            Log "Pointing the Sunshine service at $svcBin"
            & sc.exe config SunshineService binPath= ('"' + $svcBin + '"') | Out-Null
        }
        Set-Service -Name 'SunshineService' -StartupType Automatic -ErrorAction SilentlyContinue
    }
    Set-SunshineFirewall $exe
}

function Set-SunshineFirewall([string]$exe) {
    # Streaming ports, open only to the home network and the private Tailscale network.
    $scope = @('LocalSubnet', $TailscaleRange)
    $rules = @(
        @{ Name = 'PC Remote - Sunshine TCP'; Protocol = 'TCP'; Ports = @('47984', '47989', '47990', '48010') },
        @{ Name = 'PC Remote - Sunshine UDP'; Protocol = 'UDP'; Ports = @('47998-48000', '48002', '48010') }
    )
    foreach ($r in $rules) {
        Get-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        New-NetFirewallRule -DisplayName $r.Name -Direction Inbound -Action Allow -Protocol $r.Protocol `
            -LocalPort $r.Ports -RemoteAddress $scope -Profile Any | Out-Null
    }
}

function Stop-SunshineForUpdate {
    # Running Sunshine locks its files; an update over it fails with msiexec 1603.
    Stop-Service -Name 'SunshineService' -Force -ErrorAction SilentlyContinue
    Get-Process -Name 'sunshine', 'sunshinesvc' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

function Remove-OldSunshineExeInstall {
    # Returns $true if an NSIS (.exe) Sunshine install was found and removed.
    foreach ($key in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                     'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        $e = Get-ItemProperty $key -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like 'Sunshine*' -and $_.UninstallString -and $_.UninstallString -notmatch '(?i)msiexec' } | Select-Object -First 1
        if ($e) {
            $exe = if ($e.UninstallString -match '^\s*"([^"]+)"') { $Matches[1] } else { ($e.UninstallString -split '\s+/')[0].Trim() }
            if (Test-Path $exe) {
                Log "Removing the older Sunshine (.exe installer) before installing the MSI"
                Stop-SunshineForUpdate
                Start-Process -FilePath $exe -ArgumentList '/S' -Wait | Out-Null
                Start-Sleep -Seconds 5
                return $true
            }
        }
    }
    return $false
}

function Get-MsiFailureHint([string]$logPath) {
    # The lines just before "Return value 3" in a verbose MSI log usually name the failing step.
    try {
        $lines = @(Get-Content $logPath -Encoding Unicode -ErrorAction Stop)
        if ($lines.Count -lt 5) { $lines = @(Get-Content $logPath -ErrorAction Stop) }
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match 'Return value 3') {
                $from = [math]::Max(0, $i - 6)
                return 'MSI: ' + ((($lines[$from..$i] | ForEach-Object { $_.Trim() }) -join ' | ') -replace '\s+', ' ')
            }
        }
    } catch { }
    return ''
}

# ---------- RustDesk (remote control) and Steam (games) ----------
$RemoteStatePath = Join-Path $Dir 'remote-state.json'

function Find-RustDesk {
    foreach ($p in (Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'), (Join-Path ${env:ProgramFiles(x86)} 'RustDesk\rustdesk.exe')) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}

function Find-Steam {
    foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam') {
        $p = (Get-ItemProperty $k -ErrorAction SilentlyContinue).InstallPath
        if ($p -and (Test-Path (Join-Path $p 'steam.exe'))) { return (Join-Path $p 'steam.exe') }
    }
    return $null
}

function Read-RemoteState { try { Get-Content $RemoteStatePath -Raw | ConvertFrom-Json } catch { $null } }
function Write-RemoteState([string]$state, [string]$step = '', [string]$err = '') {
    @{ state = $state; step = $step; error = $err; at = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -Path $RemoteStatePath -Encoding UTF8
}

function Invoke-RustDesk([string[]]$cliArgs, [int]$timeoutSec = 30) {
    # Runs rustdesk.exe with arguments and returns what it printed (it prints for --get-id / --option).
    $exe = Find-RustDesk
    if (-not $exe) { throw 'RustDesk is not installed.' }
    $out = Join-Path $Dir 'rustdesk-cli.out'
    Remove-Item $out -Force -ErrorAction SilentlyContinue
    $quoted = ($cliArgs | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $p = Start-Process -FilePath $exe -ArgumentList $quoted -RedirectStandardOutput $out -PassThru -WindowStyle Hidden
    if (-not $p.WaitForExit($timeoutSec * 1000)) { try { $p.Kill() } catch { } }
    try { return ((Get-Content $out -Raw -ErrorAction SilentlyContinue) -as [string]).Trim() } finally { Remove-Item $out -Force -ErrorAction SilentlyContinue }
}

function Get-RustDeskId {
    $id = ''
    try { $id = Invoke-RustDesk @('--get-id') 10 } catch { }
    if ($id -match '(\d{6,12})') { return $Matches[1] }
    # Some versions print nothing to a redirected console: read the service's config file instead.
    foreach ($f in "$env:WINDIR\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml",
                   "$env:WINDIR\System32\config\systemprofile\AppData\Roaming\RustDesk\config\RustDesk.toml") {
        if (Test-Path $f) {
            $m = Select-String -Path $f -Pattern "^\s*id\s*=\s*'?(\d{6,12})'?" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($m) { return $m.Matches[0].Groups[1].Value }
        }
    }
    return ''
}

function Get-RustDeskInstaller([string]$dl) {
    $ProgressPreference = 'SilentlyContinue'
    $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest' -UseBasicParsing -TimeoutSec 60 `
        -Headers @{ 'User-Agent' = 'pc-remote-agent'; Accept = 'application/vnd.github+json' }
    $asset = @($rel.assets) | Where-Object { $_.name -match '^rustdesk-[\d.]+-x86_64\.exe$' } | Select-Object -First 1
    if (-not $asset) { throw "No Windows .exe found in RustDesk release $($rel.tag_name)." }
    if ($asset.browser_download_url -notmatch '^https://github\.com/rustdesk/rustdesk/') { throw 'Unexpected download address.' }
    $out = Join-Path $dl $asset.name
    Log "Downloading RustDesk $($rel.tag_name)"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $out -UseBasicParsing -TimeoutSec 900
    if ((Get-Item $out).Length -lt 5MB) { throw 'The RustDesk download looks incomplete.' }
    return $out
}

function Install-RustDesk {
    # Installs RustDesk with its own installer (no Windows Installer/MSI involved), then makes sure
    # its Windows service exists and runs.
    if (-not (Find-RustDesk)) {
        $dl = Join-Path $Dir 'dl'
        New-Item -ItemType Directory -Path $dl -Force | Out-Null
        $file = Get-RustDeskInstaller $dl
        Assert-Signed $file '' -AllowUnsigned
        Log 'Installing RustDesk (silent)'
        Start-Process -FilePath $file -ArgumentList '--silent-install' -WindowStyle Hidden | Out-Null
        for ($i = 0; $i -lt 90 -and -not (Find-RustDesk); $i++) { Start-Sleep -Seconds 2 }
        for ($i = 0; $i -lt 30 -and -not (Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Seconds 2 }
        Remove-Item $file -Force -ErrorAction SilentlyContinue
    }
    $exe = Find-RustDesk
    if (-not $exe) { throw 'RustDesk did not finish installing.' }
    Initialize-RustDeskService $exe
    return $exe
}

function Initialize-RustDeskService([string]$exe) {
    # 1) RustDesk's own "--install-service". 2) If that did not create it: the same service by hand
    #    (RustDesk runs as  "<path>\rustdesk.exe" --service  under LocalSystem).
    if (-not (Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue)) {
        Log 'RustDesk service missing: running rustdesk.exe --install-service'
        try { Start-Process -FilePath $exe -ArgumentList '--install-service' -WindowStyle Hidden -Wait:$false | Out-Null } catch { }
        for ($i = 0; $i -lt 15 -and -not (Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Seconds 2 }
    }
    if (-not (Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue)) {
        Log 'Creating the RustDesk service directly'
        New-Service -Name 'RustDesk' -BinaryPathName ('"' + $exe + '" --service') -DisplayName 'RustDesk Service' `
            -Description 'RustDesk remote control (installed by PC Remote).' -StartupType Automatic | Out-Null
    }
    try { Set-Service -Name 'RustDesk' -StartupType Automatic -ErrorAction Stop } catch { Log "Could not set RustDesk service to automatic: $($_.Exception.Message)" }
    try { Start-Service -Name 'RustDesk' -ErrorAction Stop } catch { Log "Could not start the RustDesk service: $($_.Exception.Message)" }
    for ($i = 0; $i -lt 10; $i++) {
        if ((Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue).Status -eq 'Running') { return }
        Start-Sleep -Seconds 1
    }
    throw 'The RustDesk service did not start. Details are in the PC log.'
}

function Set-RustDeskSecurity {
    # Permanent password only (no temporary one-time codes), no click-to-accept needed for
    # unattended access, and direct connections (home network / Tailscale) on TCP 21118 only.
    Invoke-RustDesk @('--option', 'verification-method', 'use-permanent-password') | Out-Null
    Invoke-RustDesk @('--option', 'approve-mode', 'password') | Out-Null
    Invoke-RustDesk @('--option', 'direct-server', 'Y') | Out-Null
    Invoke-RustDesk @('--option', 'allow-remote-config-modification', 'N') | Out-Null
    Get-NetFirewallRule -DisplayName 'PC Remote - RustDesk direct' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    New-NetFirewallRule -DisplayName 'PC Remote - RustDesk direct' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 21118 `
        -RemoteAddress @('LocalSubnet', $TailscaleRange) -Profile Any | Out-Null
}

function Set-RustDeskPassword([string]$pass) {
    $r = Invoke-RustDesk @('--password', $pass)
    Log "RustDesk password set ($r)"
    $cfg = Read-Config; Set-ConfigValue $cfg 'rdPassSet' $true; Save-Config $cfg
}

function Install-Steam {
    if (Find-Steam) { return (Find-Steam) }
    $dl = Join-Path $Dir 'dl'
    New-Item -ItemType Directory -Path $dl -Force | Out-Null
    $file = Join-Path $dl 'SteamSetup.exe'
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri 'https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe' -OutFile $file -UseBasicParsing -TimeoutSec 600
    Assert-Signed $file 'Valve'
    Log 'Installing Steam (silent)'
    $p = Start-Process -FilePath $file -ArgumentList '/S' -Wait -PassThru
    Remove-Item $file -Force -ErrorAction SilentlyContinue
    if ($p.ExitCode -ne 0 -or -not (Find-Steam)) { throw "Steam installer failed (code $($p.ExitCode))." }
    return (Find-Steam)
}

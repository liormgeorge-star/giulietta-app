# Shared helpers for agent.ps1 and tasks.ps1 (dot-sourced).

$Dir = Join-Path $env:ProgramData 'PcRemote'
$CfgPath = Join-Path $Dir 'config.json'
$StreamStatePath = Join-Path $Dir 'stream-state.json'
$LogFile = Join-Path $Dir 'agent.log'
$ReleaseZipUrl = 'https://github.com/liormgeorge-star/giulietta-app/releases/download/pc-remote-latest/pc-remote-windows.zip'
$SunshineMsiUrl = 'https://github.com/LizardByte/Sunshine/releases/latest/download/Sunshine-Windows-AMD64-installer.msi'

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
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    return $null
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

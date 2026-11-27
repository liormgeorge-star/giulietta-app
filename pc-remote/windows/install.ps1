# PC Remote installer. Run through install.cmd (it asks for administrator rights).
# Safe to run again: keeps the same pairing code and updates the agent.

$ErrorActionPreference = 'Stop'
$Port = 8765
$TaskName = 'PC Remote Agent'
$RuleName = 'PC Remote Agent (TCP 8765)'
$Dir = Join-Path $env:ProgramData 'PcRemote'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Step($t) { Write-Host ''; Write-Host "== $t" -ForegroundColor Cyan }
function Ok($t) { Write-Host "   OK  $t" -ForegroundColor Green }
function Warn($t) { Write-Host "   !!  $t" -ForegroundColor Yellow }

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Write-Host 'Please run install.cmd (it asks for administrator rights).' -ForegroundColor Red; exit 1 }

# 1. Wired network adapter
Step 'Finding the wired network adapter'
$adapters = @(Get-NetAdapter -Physical | Where-Object {
    $_.Status -eq 'Up' -and $_.PhysicalMediaType -notmatch 'Native 802.11|Wireless' -and $_.InterfaceDescription -notmatch 'Wi-?Fi|Wireless|WLAN|Bluetooth' })
if ($adapters.Count -eq 0) {
    Write-Host 'No connected wired (Ethernet) adapter found. Plug in the network cable and run again.' -ForegroundColor Red
    exit 1
}
$nic = $adapters | Sort-Object -Property @{ Expression = { (Get-NetIPInterface -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).InterfaceMetric } } | Select-Object -First 1
$mac = ($nic.MacAddress -replace '-', ':').ToUpperInvariant()
$ip = (Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike '169.254.*' } | Select-Object -First 1).IPAddress
Ok "$($nic.Name) - $($nic.InterfaceDescription)"
Ok "MAC $mac   IP $ip"

# 2. Wake-on-LAN settings on the adapter
Step 'Turning on Wake-on-LAN on the adapter'
$changed = $false
try {
    Set-NetAdapterPowerManagement -Name $nic.Name -WakeOnMagicPacket Enabled -ErrorAction Stop
    Ok 'Wake on Magic Packet: enabled'
} catch { Warn "Could not set Wake on Magic Packet ($($_.Exception.Message))" }
try {
    $props = Get-NetAdapterAdvancedProperty -Name $nic.Name -ErrorAction Stop
    foreach ($p in $props) {
        $isWake = $p.DisplayName -match '(?i)magic packet|shutdown wake|wake on lan|wake-on-lan|wol'
        $isSaver = $p.DisplayName -match '(?i)energy.efficient|green ethernet|power saving mode|gigabit lite'
        if ($isWake) {
            $on = $p.ValidDisplayValues | Where-Object { $_ -match '^(?i)(enabled|on)$' } | Select-Object -First 1
            if ($on -and $p.DisplayValue -ne $on) {
                try {
                    Set-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName $p.DisplayName -DisplayValue $on -NoRestart -ErrorAction Stop
                    $changed = $true
                    Ok "$($p.DisplayName): $on"
                } catch { Warn "$($p.DisplayName): could not change ($($_.Exception.Message))" }
            } elseif ($on) { Ok "$($p.DisplayName): already $on" }
        } elseif ($isSaver) {
            $off = $p.ValidDisplayValues | Where-Object { $_ -match '^(?i)(disabled|off)$' } | Select-Object -First 1
            if ($off -and $p.DisplayValue -ne $off) {
                try {
                    Set-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName $p.DisplayName -DisplayValue $off -NoRestart -ErrorAction Stop
                    $changed = $true
                    Ok "$($p.DisplayName): $off (can block waking up)"
                } catch { Warn "$($p.DisplayName): could not change ($($_.Exception.Message))" }
            }
        }
    }
} catch { Warn "Could not read the adapter's advanced settings ($($_.Exception.Message))" }
if ($changed) {
    Write-Host '   ..  Restarting the adapter to apply (the network drops for a few seconds)'
    try { Restart-NetAdapter -Name $nic.Name -ErrorAction Stop; Start-Sleep -Seconds 8 }
    catch { Warn 'Could not restart the adapter. The new settings apply after the next reboot.' }
}
$ErrorActionPreference = 'Continue'
& powercfg.exe /deviceenablewake "$($nic.InterfaceDescription)" *> $null
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -eq 0) { Ok 'Adapter allowed to wake the computer' } else { Warn 'powercfg could not mark the adapter as a wake device (often fine)' }

# 3. Fast Startup off: with it on, "shut down" is really hibernation and Wake-on-LAN usually fails.
Step 'Turning off Fast Startup'
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0 -Type DWord
Ok 'Fast Startup: off'

# 4. Agent files and pairing code
Step 'Installing the agent'
New-Item -ItemType Directory -Path $Dir -Force | Out-Null
& icacls.exe $Dir /inheritance:r /grant:r 'SYSTEM:(OI)(CI)F' 'Administrators:(OI)(CI)F' | Out-Null
$cfgPath = Join-Path $Dir 'config.json'
$token = $null
$old = $null
if (Test-Path $cfgPath) { try { $old = Get-Content $cfgPath -Raw | ConvertFrom-Json; $token = $old.token } catch { } }
if (-not $token) {
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    $bytes = New-Object byte[] 8
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $token = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}
$cfgOut = [ordered]@{ port = $Port; token = $token; mac = $mac; ifIndex = $nic.ifIndex }
if ($old -and $old.sunUser) { $cfgOut.sunUser = $old.sunUser; $cfgOut.sunPass = $old.sunPass }
$cfgOut | ConvertTo-Json | Set-Content -Path $cfgPath -Encoding ASCII
Remove-Item (Join-Path $Dir 'update') -Recurse -Force -ErrorAction SilentlyContinue
foreach ($f in 'launcher.ps1', 'agent.ps1', 'common.ps1', 'tasks.ps1', 'version.txt') {
    Copy-Item (Join-Path $Here $f) (Join-Path $Dir $f) -Force
    Unblock-File (Join-Path $Dir $f) -ErrorAction SilentlyContinue
}
Ok "Files in $Dir"

# 5. Firewall: only devices on the local network can reach the agent.
Step 'Opening the firewall for the local network only'
Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port `
    -RemoteAddress LocalSubnet -Profile Any | Out-Null
Ok "TCP $Port allowed from the local network"

# 6. Start at boot, as SYSTEM, before anyone logs in.
Step 'Starting the agent at every boot'
Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue | ForEach-Object {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*PcRemote\agent.ps1*' -or $_.CommandLine -like '*PcRemote\launcher.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Dir\launcher.ps1`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
Start-ScheduledTask -TaskName $TaskName
Ok 'Scheduled task created and started'

Step 'Checking that the agent answers'
$up = $false
for ($i = 0; $i -lt 20 -and -not $up; $i++) {
    Start-Sleep -Seconds 1
    try { $up = (Invoke-RestMethod -Uri "http://127.0.0.1:$Port/ping" -TimeoutSec 2).ok } catch { }
}
if ($up) { Ok 'Agent is running. It now installs Sunshine (game streaming) in the background.' } else { Warn "Agent did not answer yet. Log: $Dir\agent.log" }

$info = @"
PC Remote - details for the phone app
--------------------------------------
Computer IP : $ip
Pairing code: $token
Port        : $Port
MAC address : $mac

Still to do by hand (once):
 - In the BIOS/UEFI setup, turn on "Wake on LAN" (may be called "Power On By PCI-E",
   "Resume by LAN" or similar), and turn off "ErP" / "Deep Sleep" if present.
 - In your router, reserve the IP $ip for this computer (DHCP reservation),
   so the address does not change.
"@
$infoPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'PC Remote - pairing.txt'
try { $info | Set-Content -Path $infoPath -Encoding UTF8 } catch { $infoPath = $null }

Write-Host ''
Write-Host '==========================================' -ForegroundColor Green
Write-Host "  Computer IP : $ip" -ForegroundColor White
Write-Host "  Pairing code: $token" -ForegroundColor White
Write-Host '==========================================' -ForegroundColor Green
Write-Host 'Enter these two in the phone app.'
if ($infoPath) { Write-Host "Saved to your desktop: $infoPath"; Start-Process notepad.exe -ArgumentList "`"$infoPath`"" }

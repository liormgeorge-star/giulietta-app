# Removes the PC Remote agent. Run through uninstall.cmd.
# Leaves the Wake-on-LAN and Fast Startup settings, and Sunshine, as they are
# (Sunshine can be removed from Settings > Apps).
$ErrorActionPreference = 'Continue'
$TaskName = 'PC Remote Agent'
Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*PcRemote\agent.ps1*' -or $_.CommandLine -like '*PcRemote\launcher.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Get-NetFirewallRule -DisplayName 'PC Remote Agent (TCP 8765)', 'PC Remote - Sunshine TCP', 'PC Remote - Sunshine UDP' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Remove-Item (Join-Path $env:ProgramData 'PcRemote') -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'PC Remote agent removed.' -ForegroundColor Green

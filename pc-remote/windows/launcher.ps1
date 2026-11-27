# PC Remote launcher. Started at boot by the scheduled task (as SYSTEM).
# Runs agent.ps1 and keeps it running. When the agent downloads a newer version
# it puts the files in .\update and exits; the launcher swaps them in and starts it again.
# This file itself is kept as small as possible so it rarely needs to change.

$Dir = Join-Path $env:ProgramData 'PcRemote'
$UpdateDir = Join-Path $Dir 'update'
$Log = Join-Path $Dir 'agent.log'

function Log($m) { try { Add-Content -Path $Log -Value ('{0:yyyy-MM-dd HH:mm:ss}  [launcher] {1}' -f (Get-Date), $m) } catch { } }

while ($true) {
    if (Test-Path (Join-Path $UpdateDir 'ready.flag')) {
        try {
            Get-ChildItem $UpdateDir -File | Where-Object { $_.Name -ne 'ready.flag' } |
                ForEach-Object { Copy-Item $_.FullName (Join-Path $Dir $_.Name) -Force }
            Log "Applied update $(Get-Content (Join-Path $Dir 'version.txt') -ErrorAction SilentlyContinue)"
        } catch { Log "Update failed: $($_.Exception.Message)" }
        Remove-Item $UpdateDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    $started = Get-Date
    $p = Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -PassThru -Wait -ArgumentList (
        '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + (Join-Path $Dir 'agent.ps1') + '"')
    Log "Agent exited with code $($p.ExitCode)"
    # Avoid a tight loop if the agent keeps crashing right away.
    if (((Get-Date) - $started).TotalSeconds -lt 20) { Start-Sleep -Seconds 15 } else { Start-Sleep -Seconds 1 }
}

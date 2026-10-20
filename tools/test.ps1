# Run the full test suite. Fails on any failing test OR any engine/script error
# in the output (a crashing test would otherwise be silently skipped).
$proj = Split-Path -Parent $PSScriptRoot
$log = & powershell -NoProfile -File (Join-Path $PSScriptRoot "godot.ps1") "res://tests/run_all.tscn", "--fixed-fps", "60" 2>&1 | Out-String
$code = $LASTEXITCODE
$log -split "`n" | Where-Object { $_ -match "PASS|FAIL|passed|ERROR|WARNING|at: |autoplay" }
$bad = ($log -match "SCRIPT ERROR|Parse Error|Compile Error") -or ($log -match "(?m)^ERROR:")
if ($code -ne 0 -or $bad -or ($log -notmatch "\d+ passed, 0 failed")) {
    Write-Output "TESTS FAILED (exit=$code, engine errors=$bad)"
    exit 1
}
Write-Output "TESTS OK"
exit 0

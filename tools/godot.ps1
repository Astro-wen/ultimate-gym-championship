# Run Godot headless with captured output.
# Usage: powershell -File tools/godot.ps1 [godot args...]
# Examples:
#   tools/godot.ps1 --import                         (refresh class cache / imports)
#   tools/godot.ps1 res://tests/run_all.tscn         (run tests, exit code 0 = pass)
#   tools/godot.ps1 --quit-after 300                 (smoke-run the main scene)
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GodotArgs)
$g = $env:GODOT_EXE
if (-not $g) { $g = "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" }
$proj = Split-Path -Parent $PSScriptRoot
$out = Join-Path $env:TEMP "ugc_godot_out.txt"
$err = Join-Path $env:TEMP "ugc_godot_err.txt"
$all = @("--headless", "--path", "`"$proj`"") + $GodotArgs
$p = Start-Process $g -ArgumentList $all -Wait -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
Get-Content $out
Get-Content $err
exit $p.ExitCode

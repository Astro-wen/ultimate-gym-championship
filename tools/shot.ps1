# Run the game windowed and save a screenshot.
# Usage: tools/shot.ps1 <out.png> [extra user args, e.g. --autostart --use=0 --shot-frames=90]
param([string]$OutPng, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Extra)
$g = $env:GODOT_EXE
if (-not $g) { $g = "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" }
$proj = Split-Path -Parent $PSScriptRoot
$out = Join-Path $env:TEMP "ugc_shot_out.txt"
$err = Join-Path $env:TEMP "ugc_shot_err.txt"
$all = @("--path", "`"$proj`"", "--", "--shot=`"$OutPng`"") + @($Extra | Where-Object { $_ })
$p = Start-Process $g -ArgumentList $all -Wait -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
Get-Content $out | Where-Object { $_ -notmatch "godot_ai" }
Get-Content $err
exit $p.ExitCode

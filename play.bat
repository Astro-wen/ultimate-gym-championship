@echo off
rem Launch Ultimate Gym Championship (needs Godot 4.7; set GODOT_EXE to override the path)
set "G=%GODOT_EXE%"
if "%G%"=="" set "G=D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
start "" "%G%" --path "%~dp0."

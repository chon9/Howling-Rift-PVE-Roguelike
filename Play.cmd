@echo off
setlocal EnableDelayedExpansion
rem Howling Rift launcher. Double-click: play in 3D (the default view).
rem   Play.cmd          run the game in 3D
rem   Play.cmd 2d       run the game in classic 2D (passes -- --view2d)
rem   Play.cmd editor   open the project in the Godot editor
set "RIFT_DIR=%~dp0."
set "RIFT_MODE=%~1"
if /i "!RIFT_MODE!"=="" set "RIFT_MODE=3d"
if /i "!RIFT_MODE!"=="3d" goto find_engine
if /i "!RIFT_MODE!"=="2d" goto find_engine
if /i "!RIFT_MODE!"=="editor" goto find_engine
echo Unknown option "%~1".
echo Usage: Play.cmd [3d ^| 2d ^| editor]
pause
exit /b 2

:find_engine
set "RIFT_ENGINE="
rem 1. K:\Godot_v4*_win64.exe (newest name first, console builds skipped)
for /f "delims=" %%F in ('dir /b /a-d /o-n "K:\Godot_v4*_win64.exe" 2^>nul') do (
  if not defined RIFT_ENGINE (
    set "RIFT_NAME=%%F"
    if /i "!RIFT_NAME:_console=!"=="!RIFT_NAME!" set "RIFT_ENGINE=K:\%%F"
  )
)
rem 2. K:\Godot\Godot_v4*_win64.exe
if not defined RIFT_ENGINE (
  for /f "delims=" %%F in ('dir /b /a-d /o-n "K:\Godot\Godot_v4*_win64.exe" 2^>nul') do (
    if not defined RIFT_ENGINE (
      set "RIFT_NAME=%%F"
      if /i "!RIFT_NAME:_console=!"=="!RIFT_NAME!" set "RIFT_ENGINE=K:\Godot\%%F"
    )
  )
)
rem 3. godot on PATH
if not defined RIFT_ENGINE (
  for /f "delims=" %%F in ('where godot 2^>nul') do (
    if not defined RIFT_ENGINE set "RIFT_ENGINE=%%F"
  )
)
if not defined RIFT_ENGINE (
  echo Godot 4.7 was not found.
  echo Looked for K:\Godot_v4*_win64.exe, K:\Godot\Godot_v4*_win64.exe and "godot" on PATH.
  echo Install Godot 4.7.2 to K:\ or add it to PATH, or open project.godot in Godot 4.7 and press F5.
  pause
  exit /b 1
)

if /i "!RIFT_MODE!"=="editor" (
  echo Opening the Howling Rift project in !RIFT_ENGINE!
  start "Howling Rift Editor" "!RIFT_ENGINE!" --path "!RIFT_DIR!" --editor
) else if /i "!RIFT_MODE!"=="2d" (
  echo Starting Howling Rift in classic 2D with !RIFT_ENGINE!
  start "Howling Rift" "!RIFT_ENGINE!" --path "!RIFT_DIR!" res://scenes/Main.tscn -- --view2d
) else (
  echo Starting Howling Rift in 3D with !RIFT_ENGINE!
  start "Howling Rift" "!RIFT_ENGINE!" --path "!RIFT_DIR!" res://scenes/Main.tscn
)
endlocal
exit /b 0

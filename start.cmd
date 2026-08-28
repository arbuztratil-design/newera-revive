@echo off
rem =====================================================================
rem  NewEra Revive - unified launcher for bare WinRE
rem  One entry point so you don't have to remember the script order.
rem
rem  Recommended flow after a crash:  1 (probe) -> 2 (network) -> 3 (repair)
rem  Or just press A to run the whole chain.
rem
rem  Russian UI text lives in lang\ru\*.txt (UTF-8, no BOM) and is printed
rem  via 'type' - the ONLY reliable way to render Cyrillic in WinRE. The
rem  .cmd body itself stays pure ASCII so the cmd parser never chokes.
rem
rem  Run inside WinRE:  Troubleshoot -> Advanced -> Command Prompt, then:
rem     X:\...\start.cmd
rem =====================================================================
setlocal enabledelayedexpansion
chcp 65001 >nul
title NewEra Revive - launcher

rem ---- WinRE PATH normalization (System32 is often not on PATH) ----
if not defined SystemRoot set "SystemRoot=X:\Windows"
set "SYS=%SystemRoot%\System32"
set "PATH=%SYS%;%SystemRoot%;%SYS%\Wbem;%PATH%"
set "HERE=%~dp0"

rem ---- red theme (ANSI). Degrades cleanly if VT is unavailable. ----
set "ESC="
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "R=" & set "R0=" & set "RD="
if defined ESC ( set "R=!ESC![1;91m" & set "R0=!ESC![0m" & set "RD=!ESC![31m" )

:menu
cls
echo !R!==========================================================!R0!
echo !R!            NewEra Revive  ::  main menu!R0!
echo !R!==========================================================!R0!
echo Your Windows won't boot? Go through the steps top to bottom.
echo.
echo     !R![1]!R0!  Probe environment       (diag.cmd)
echo     !R![2]!R0!  Bring up network        (winre-net.cmd)
echo     !R![3]!R0!  Run AI repair           (agent.cmd)
echo.
echo     !R![A]!R0!  Do it all: 1 -^> 2 -^> 3
echo     !R![Q]!R0!  Quit
echo !R!==========================================================!R0!
echo Choose 1 / 2 / 3 / A / Q:
set "PICK=" & set /p PICK="  "

if /i "!PICK!"=="1" ( call :run diag.cmd        & goto :menu )
if /i "!PICK!"=="2" ( call :run winre-net.cmd   & goto :menu )
if /i "!PICK!"=="3" ( call :run agent.cmd       & goto :menu )
if /i "!PICK!"=="A" goto :all
if /i "!PICK!"=="Q" goto :bye
if not defined PICK goto :menu
echo [!] Unknown choice: !PICK!
ping -n 2 127.0.0.1 >nul
goto :menu

:all
echo.
echo [*] Running the whole chain: environment -^> network -^> repair.
call :run diag.cmd
call :run winre-net.cmd
call :run agent.cmd
goto :menu

rem ---- run a sibling script if it exists, else report it missing ----
:run
if exist "%HERE%%~1" (
    echo.
    echo [*] Launching:
    echo   %~1
    echo ----------------------------------------------------------
    call "%HERE%%~1"
    echo ----------------------------------------------------------
    echo [i] Done. Back to the menu.
) else (
    echo [X] Not found next to start.cmd:
    echo   %~1  ^(%HERE%^)
    echo     Make sure the whole kit sits in one folder.
)
goto :eof

:bye
echo.
echo Done. Run start.cmd again any time to continue.
endlocal

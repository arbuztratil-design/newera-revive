@echo off
rem =====================================================================
rem  WinRE environment probe for NewEra Revive.
rem  Run this FIRST inside WinRE. It never exits silently - always pauses.
rem  Tell me the output (or photograph the screen).
rem =====================================================================
setlocal
chcp 65001 >nul
title NewEra Revive - environment probe

if not defined SystemRoot set "SystemRoot=X:\Windows"
set "SYS=%SystemRoot%\System32"
set "PATH=%SYS%;%SystemRoot%;%SYS%\Wbem;%PATH%"

echo ==========================================================
echo    NewEra Revive :: WinRE environment probe
echo ==========================================================
echo.

echo [0] Script folder ^(%%~dp0^):
echo     %~dp0
echo.

echo [1] Am I really in WinRE/WinPE?
if exist X:\Windows\System32\winpeshl.ini (echo     X:\...\winpeshl.ini present  =^> looks like WinPE/WinRE) else (echo     winpeshl.ini NOT found  =^> maybe a normal Windows, not WinRE)
echo     SystemDrive=%SystemDrive%   ^(in WinRE this is usually X:^)
echo.

echo [2] TEMP variable:
echo     TEMP=%TEMP%
if not defined TEMP echo     [!] TEMP is NOT defined - the agent must not rely on it.
if defined TEMP if not exist "%TEMP%\" echo     [!] TEMP path does not exist.
echo.

echo [3] Can I write to my own folder ^(the USB stick^)?
set "PROBE=%~dp0__wtest.tmp"
> "%PROBE%" echo test 2>nul
if exist "%PROBE%" (echo     WRITE OK: %~dp0 & del "%PROBE%" >nul 2>&1) else (echo     [!] CANNOT write next to the script.)
echo.

echo [4] Required tools:
call :chk curl.exe
call :chk jq.exe
call :chk diskpart.exe
call :chk bcdedit.exe
call :chk reg.exe
call :chk tasklist.exe
call :chk taskkill.exe
call :chk find.exe
call :chk findstr.exe
call :chk ping.exe
echo.

echo [5] jq.exe next to the script?
if exist "%~dp0jq.exe" (echo     found: %~dp0jq.exe) else (echo     [!] jq.exe MISSING next to the script.)
echo.

echo [6] curl.exe location:
if exist "%SYS%\curl.exe" (echo     found: %SYS%\curl.exe) else (echo     [!] curl.exe not in System32 ^(agent will copy it from the offline OS^).)
echo.

echo [7] Offline Windows search:
set "OFFWIN="
for %%d in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
    if not defined OFFWIN if exist "%%d:\Windows\System32\ntoskrnl.exe" set "OFFWIN=%%d:"
)
if defined OFFWIN (echo     found offline Windows at %OFFWIN%) else (echo     [!] offline Windows NOT found.)
echo.

echo [8] agent.ini next to the script?
if exist "%~dp0agent.ini" (echo     found agent.ini) else (echo     [!] agent.ini MISSING.)
echo.

echo ==========================================================
echo    Environment probe done. Tell me the lines marked [!].
echo ==========================================================
echo.
pause
goto :eof

:chk
rem check by real file path in System32 (WinRE often lacks 'where')
if exist "%SYS%\%1" (echo         ok      : %1) else (echo     [!] MISSING : %1  ^(not in %SYS%^))
goto :eof

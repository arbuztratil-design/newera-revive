@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
title NewEra Revive - Network Bootstrap

echo ==============================================
echo    NewEra Revive - WinRE network bootstrap (step 1)
echo ==============================================
echo.

REM ---- 0. Make sure we are inside WinRE / WinPE ----
wpeutil UpdateBootInfo >nul 2>&1
if errorlevel 9009 (
    echo ERROR: wpeutil.exe not found.
    echo This script must be run inside WinRE / WinPE only.
    goto :end
)

REM ---- 1. Start the WinPE network stack (TCP/IP, DHCP, WLAN svc) ----
echo [1/6] Initializing network stack...
wpeutil InitializeNetwork >nul 2>&1

REM ---- 2. Find the offline (broken) Windows installation ----
echo [2/6] Looking for offline Windows installation...
set "OFFWIN="
for %%d in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
    if not defined OFFWIN if exist "%%d:\Windows\System32\ntoskrnl.exe" set "OFFWIN=%%d:"
)
if defined OFFWIN (
    echo     Found Windows at !OFFWIN!\Windows
) else (
    echo     WARNING: offline Windows not found - driver import will be skipped
)

REM ---- 3. Load network (NIC / Wi-Fi) drivers ----
echo [3/6] Loading network drivers (this may take 1-3 minutes)...

REM 3a. Optional: "Drivers" folder next to this script (e.g. on the USB stick)
if exist "%~dp0Drivers" (
    for /f "delims=" %%I in ('dir /b /s "%~dp0Drivers\*.inf" 2^>nul') do (
        drvload "%%I" >nul 2>&1 && echo     + [usb] %%~nxI
    )
)

REM 3b. Import from the offline system's DriverStore.
REM     Only INF files of device class "Net" (GUID 4d36e972-...) are loaded.
if defined OFFWIN (
    for /f "delims=" %%I in ('dir /b /s "!OFFWIN!\Windows\System32\DriverStore\FileRepository\*.inf" 2^>nul') do (
        find /i "4d36e972-e325-11ce-bfc1-08002be10318" "%%I" >nul 2>&1 && (
            drvload "%%I" >nul 2>&1 && echo     + %%~nxI
        )
    )
)

REM ---- 4. Ask DHCP for an IP address ----
echo [4/6] Requesting IP address via DHCP...
net start dhcp >nul 2>&1
ipconfig /renew >nul 2>&1
ping -n 4 127.0.0.1 >nul

REM ---- 5. If no wired link - try Wi-Fi ----
echo [5/6] Checking connectivity...
ping -n 2 -w 2000 1.1.1.1 | find "TTL=" >nul
if not errorlevel 1 goto :online

echo     No wired connection. Trying Wi-Fi...
net start wlansvc >nul 2>&1
netsh wlan show interfaces 2>nul | find /i "Name" >nul
if errorlevel 1 (
    echo     No Wi-Fi adapter detected in WinRE.
    goto :final
)

set "SSID="
set "PASS="
set /p "SSID=    Wi-Fi network name (SSID): "
set /p "PASS=    Wi-Fi password: "

REM Build a WLAN profile (WPA2-PSK / AES, plain-text key)
set "WPROF=%TEMP%\winre-wifi.xml"
> "!WPROF!" (
    echo ^<?xml version="1.0"?^>
    echo ^<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1"^>
    echo   ^<name^>!SSID!^</name^>
    echo   ^<SSIDConfig^>^<SSID^>^<name^>!SSID!^</name^>^</SSID^>^</SSIDConfig^>
    echo   ^<connectionType^>ESS^</connectionType^>
    echo   ^<connectionMode^>auto^</connectionMode^>
    echo   ^<MSM^>^<security^>
    echo     ^<authEncryption^>
    echo       ^<authentication^>WPA2PSK^</authentication^>
    echo       ^<encryption^>AES^</encryption^>
    echo       ^<useOneX^>false^</useOneX^>
    echo     ^</authEncryption^>
    echo     ^<sharedKey^>
    echo       ^<keyType^>passPhrase^</keyType^>
    echo       ^<protected^>false^</protected^>
    echo       ^<keyMaterial^>!PASS!^</keyMaterial^>
    echo     ^</sharedKey^>
    echo   ^</security^>^</MSM^>
    echo ^</WLANProfile^>
)
netsh wlan add profile filename="!WPROF!" >nul 2>&1
netsh wlan connect name="!SSID!" >nul 2>&1
del /q "!WPROF!" >nul 2>&1
echo     Connecting to !SSID! ...
ping -n 8 127.0.0.1 >nul
ipconfig /renew >nul 2>&1

:final
ping -n 2 -w 2000 1.1.1.1 | find "TTL=" >nul
if errorlevel 1 (
    echo.
    echo RESULT: no internet. Possible reasons:
    echo   - NIC driver did not load: put the driver into a "Drivers"
    echo     folder next to this script and run it again
    echo   - no DHCP on the network, cable unplugged, wrong Wi-Fi password
    echo Diagnostics: ipconfig /all  and  netsh wlan show interfaces
    goto :end
)

:online
echo     IP connectivity: OK

REM ---- 6. HTTPS check (this is what the AI API will need) ----
echo [6/6] Testing HTTPS access...
set "SYS=%SystemRoot%\System32"
if not defined SystemRoot set "SYS=X:\Windows\System32"
set "CURLBIN="
if exist "%SYS%\curl.exe" set "CURLBIN=%SYS%\curl.exe"
if not defined CURLBIN if defined OFFWIN if exist "!OFFWIN!\Windows\System32\curl.exe" (
    copy /y "!OFFWIN!\Windows\System32\curl.exe" "%SYS%\" >nul 2>&1
    if exist "%SYS%\curl.exe" set "CURLBIN=%SYS%\curl.exe"
)
if not defined CURLBIN (
    echo     curl.exe not available - HTTPS test skipped
    goto :done
)
set "HTTP=000"
for /f %%H in ('"%CURLBIN%" -s -o nul -w "%%{http_code}" --connect-timeout 15 https://cc.freemodel.dev/v1/models 2^>nul') do set "HTTP=%%H"
if "!HTTP!"=="000" (
    echo     HTTPS: FAILED - check clock/date: "date" and "time" commands.
    echo     TLS breaks if CMOS clock is wrong.
) else (
    echo     HTTPS: OK ^(server answered with code !HTTP!^)
    echo.
    echo    ======= NETWORK READY FOR THE AI AGENT =======
)

:done
echo.
rem 'findstr' is absent in stock WinRE - just show the full (short) ipconfig.
ipconfig

:end
echo.
pause
endlocal
goto :eof

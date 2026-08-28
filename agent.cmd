@echo off
rem =====================================================================
rem  NewEra Revive for bare WinRE  --  cmd.exe + curl.exe + jq.exe
rem  No PowerShell / .NET / Python required. Works in stock WinRE.
rem
rem  Files needed next to this script (e.g. on the USB stick):
rem     agent.cmd   (this file)
rem     agent.ini   (endpoint / key / model)
rem     jq.exe      (single static binary - https://jqlang.github.io/jq/ , win64)
rem     curl.exe    (usually already in WinRE; auto-copied from the broken OS if missing)
rem
rem  Run inside WinRE:  Troubleshoot -> Advanced -> Command Prompt, then:
rem     X:\...\agent.cmd
rem  (run winre-net.cmd first if the network is not up yet)
rem =====================================================================
setlocal enabledelayedexpansion
chcp 65001 >nul
title NewEra Revive (cmd/curl)

rem  UI text below is plain ASCII English (printed via echo). The AI model still
rem  answers in Russian: the API returns UTF-8, so the console MUST be in 65001
rem  for 'type text.txt' to render Cyrillic. (chcp 866 here turns the model's
rem  answers into mojibake - 866 was only ever needed for the removed CP866
rem  lang files. The battle-tested pre-lang version used 65001.)

rem ---------- WinRE PATH normalization ----------
rem Stripped WinRE images often have a PATH that does NOT include System32,
rem so bare 'findstr'/'curl'/'reg' fail with "is not recognized". Force it.
if not defined SystemRoot set "SystemRoot=X:\Windows"
set "SYS=%SystemRoot%\System32"
set "PATH=%SYS%;%SystemRoot%;%SYS%\Wbem;%PATH%"
rem This WinRE image may LACK findstr.exe entirely, but find.exe is present.
rem The safety policy below uses find.exe + pure-cmd prefix checks, no findstr.
set "FIND=%SYS%\find.exe"
if not exist "%FIND%" set "FIND=find"

rem ---------- UI: ANSI color setup (style B: colored feed, header per step) ----
rem  Grab the ESC (0x1B) char via the classic prompt trick - it cannot be typed
rem  literally in a .cmd. Win10 conhost (what WinRE runs on) understands ANSI SGR.
rem  If VT is unavailable the codes would show as garbage, so 'ui=plain' in the
rem  ini (or auto-off) degrades to the previous plain output. All markers are
rem  ASCII ([AI]/>>>/[OK]) - non-ASCII breaks the limited WinRE console font.
rem  THEME: red. Chrome (header/AI voice/prefixes) is red; the verdict labels
rem  stay a green/yellow/red traffic light so the safety signal is never lost.
set "ESC="
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "C_RST=" & set "C_HDR=" & set "C_AI=" & set "C_OK=" & set "C_WARN=" & set "C_ERR=" & set "C_DIM="
if defined ESC (
    set "C_RST=!ESC![0m"
    set "C_HDR=!ESC![1;91m"
    set "C_AI=!ESC![91m"
    set "C_OK=!ESC![92m"
    set "C_WARN=!ESC![93m"
    set "C_ERR=!ESC![1;91m"
    set "C_DIM=!ESC![31m"
)
rem UI on by default; the ini 'ui=plain' switch below can turn colors off.
set "UI=tui"

set "HERE=%~dp0"
set "CFG=%HERE%agent.ini"
set "JQ=%HERE%jq.exe"
rem Pick a writable work dir. %TEMP% is often UNSET in WinRE, so fall back to
rem X:\Windows\Temp (RAM disk, always writable in WinRE), then the script folder.
set "WORK="
if defined TEMP if exist "%TEMP%\" set "WORK=%TEMP%\airepair"
if not defined WORK if exist "X:\Windows\Temp\" set "WORK=X:\Windows\Temp\airepair"
if not defined WORK set "WORK=%HERE%airepair"
mkdir "%WORK%" >nul 2>&1
if not exist "%WORK%\" (
    echo [X] Cannot create work dir: %WORK%
    echo     Check that the drive is writable.
    goto :end
)
echo [i] Work dir: %WORK%

rem ---------- Persistent store (survives reboot / agent restart) ----------
rem  The conversation history and log live in a folder NEXT TO THE SCRIPT (the
rem  USB stick), NOT in %WORK% which is usually the X: RAM disk wiped on reboot.
rem  That is what lets the agent "remember" across restarts and power cycles.
set "STORE=%HERE%airepair-store"
mkdir "%STORE%" >nul 2>&1
> "%STORE%\.wtest" echo ok 2>nul
if exist "%STORE%\.wtest" (
    del "%STORE%\.wtest" >nul 2>&1
) else (
    echo [!] Script folder is not writable - memory will NOT survive a reboot.
    set "STORE=%WORK%"
)
set "HIST=%STORE%\messages.json"
set "LOG=%STORE%\repair-log.txt"
echo [i] Persistent store: %STORE%
rem Append (>>), never overwrite - keep the log across sessions.
>> "%LOG%" echo === session start ===

rem ---------- 0. Preconditions ----------
if not exist "%CFG%" echo [X] agent.ini not found next to agent.cmd: %CFG% & goto :end
if not exist "%JQ%"  echo [X] jq.exe not found next to agent.cmd: %JQ% - get win64 jq from https://jqlang.github.io/jq/ & goto :end

rem ---------- 1. Read config from agent.ini ----------
set "BASE=" & set "MODEL=" & set "KEY=" & set "UA=" & set "RETRIES=" & set "DELAY=" & set "MAXSTEPS="
set "AUTO=" & set "BLOCKDESTRUCTIVE="
call :readini "endpoint"        BASE
call :readini "model"           MODEL
call :readini "key"             KEY
call :readini "useragent"       UA
call :readini "retries"         RETRIES
call :readini "retry_delay_sec" DELAY
call :readini "max_steps"       MAXSTEPS
call :readini "auto"            AUTO
call :readini "block_destructive" BLOCKDESTRUCTIVE
call :readini "ui"              UICFG
if /i "!UICFG!"=="plain" (
    set "UI=plain"
    set "C_RST=" & set "C_HDR=" & set "C_AI=" & set "C_OK=" & set "C_WARN=" & set "C_ERR=" & set "C_DIM="
)
if not defined RETRIES  set "RETRIES=10"
if not defined DELAY    set "DELAY=3"
if not defined MAXSTEPS set "MAXSTEPS=0"
if not defined AUTO     set "AUTO=1"
if not defined BLOCKDESTRUCTIVE set "BLOCKDESTRUCTIVE=1"
if not defined UA       set "UA=claude-cli/1.0 (external, cli)"
if "!BASE:~-1!"=="/" set "BASE=!BASE:~0,-1!"
if not defined KEY ( echo [X] No API key in agent.ini. & goto :end )
if "%KEY%"=="PASTE_YOUR_KEY_HERE" ( echo [X] Put your API key into agent.ini first. & goto :end )

rem ---------- 1b. Interactive setup: mode + user message ----------
rem  Lets the operator override the ini mode and describe the problem / ask a
rem  question in free text. All input is single delayed-expansion echo -> safe
rem  against &|<> injection (delayed expansion happens after cmd tokenizing).
echo.
echo ==========================================================
echo    NewEra Revive - session setup
echo ==========================================================

rem ---- Resume a previous session if a valid history exists on the stick ----
set "RESUME="
if exist "%HIST%" (
    "%JQ%" -e "type==\"array\" and length>0" "%HIST%" >nul 2>&1
    if not errorlevel 1 (
        rem read the message count via a temp file (for /f mangles the quoted jq path)
        "%JQ%" -r "length" "%HIST%" > "%WORK%\histlen.txt" 2>nul
        set "HISTLEN=0" & set /p HISTLEN=<"%WORK%\histlen.txt"
        echo A saved session was found on this stick.
        echo   ^(messages remembered:
        echo  !HISTLEN!^)
        echo   [C] Continue - keep all memory and carry on
        echo   [N] New      - archive it and start fresh
        echo Choose C / N ^(default C^):
        set "RSEL=" & set /p RSEL="  "
        if /i "!RSEL!"=="N" (
            set "STAMP=%RANDOM%"
            move /y "%HIST%" "%STORE%\messages-old-!STAMP!.json" >nul 2>&1
            echo   -^> Previous memory archived. Starting fresh.
        ) else (
            set "RESUME=1"
            echo   -^> Continuing from saved memory.
        )
        echo.
    )
)

rem  Continuing a saved session: keep last run's mode/safety, skip the whole
rem  wizard and the "describe the problem" prompt - the operator already set all
rem  that up before, re-asking every restart is the annoyance being fixed here.
if defined RESUME (
    set "UMSG=%WORK%\usermsg.txt"
    copy nul "!UMSG!" >nul 2>&1
    goto :after_setup
)

echo Control mode:
echo   [A] Automatic - the agent runs every command itself, no confirmation
echo   [M] Manual    - the agent asks y/n before each command, you are in charge
echo   [Enter]       - keep the config value (auto=
echo %AUTO%^)
echo Choose A / M:
set "MSEL=" & set /p MSEL="  "
if /i "!MSEL!"=="A" set "AUTO=1"
if /i "!MSEL!"=="M" set "AUTO=0"
if "%AUTO%"=="1" ( echo   -^> AUTOMATIC mode selected. ) else ( echo   -^> MANUAL mode selected. )
echo.
echo Safety level:
echo   [S] Safe      - block destructive commands (format, clean, recursive delete, cipher /w, writes to X:)
echo   [U] Unsafe    - FULL control, nothing is blocked (DANGEROUS, only if you know why)
echo   [Enter]       - keep the config value (block_destructive=
echo %BLOCKDESTRUCTIVE%^)
echo Choose S / U:
set "SSEL=" & set /p SSEL="  "
if /i "!SSEL!"=="S" set "BLOCKDESTRUCTIVE=1"
if /i "!SSEL!"=="U" set "BLOCKDESTRUCTIVE=0"
if "%BLOCKDESTRUCTIVE%"=="1" ( echo   -^> SAFE mode: destructive commands are hard-blocked. ) else ( echo   -^> UNSAFE mode: ALL commands allowed - hands fully untied. )
echo.
echo Describe the problem or ask a question (optional).
echo Type as many lines as you like, then an EMPTY line to finish.
echo Leave the first line empty to skip and let the agent diagnose on its own.
set "UMSG=%WORK%\usermsg.txt"
copy nul "%UMSG%" >nul 2>&1
:readmsg
set "LINE=" & set /p LINE="  > "
if defined LINE ( >>"%UMSG%" echo(!LINE! & goto :readmsg )
:after_setup

rem ---------- 2. Find the offline (broken) Windows ----------
set "OFFWIN="
for %%d in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
    if not defined OFFWIN if exist "%%d:\Windows\System32\ntoskrnl.exe" set "OFFWIN=%%d:"
)
rem  Short labels for the per-step status header (style B).
set "OW=%OFFWIN%"
if not defined OW set "OW=?"
if "%AUTO%"=="1" ( set "AUTOLBL=AUTO" ) else ( set "AUTOLBL=MANUAL" )
if "%BLOCKDESTRUCTIVE%"=="1" ( set "SAFELBL=SAFE" ) else ( set "SAFELBL=UNSAFE" )

rem ---------- 3. Locate curl.exe (no 'where' - may be absent in WinRE) ----------
set "CURL="
if exist "%SYS%\curl.exe" set "CURL=%SYS%\curl.exe"
if not defined CURL if exist "%WORK%\curl.exe" set "CURL=%WORK%\curl.exe"
if not defined CURL if defined OFFWIN if exist "%OFFWIN%\Windows\System32\curl.exe" (
    copy /y "%OFFWIN%\Windows\System32\curl.exe" "%WORK%\" >nul 2>&1
    if exist "%WORK%\curl.exe" set "CURL=%WORK%\curl.exe"
)
if not defined CURL echo [X] curl.exe not found in WinRE ^(%SYS%^) nor in the offline OS. & echo     Put curl.exe next to this script and retry. & goto :end
echo [i] Using curl: %CURL%

rem ---------- 4. Connectivity check: SKIPPED (proxy check disabled) ----------
echo [*] Skipping proxy check - will connect directly when needed.

rem ---------- 5. Collect diagnostics from the broken system ----------
echo [*] Collecting offline system diagnostics...
set "D=%WORK%\diag.txt"
> "%D%"  echo === WinRE AI Repair Agent diagnostics ===
if defined OFFWIN ( >> "%D%" echo Offline Windows: %OFFWIN% ) else ( >> "%D%" echo Offline Windows: NOT FOUND )
>> "%D%" echo --- disks/volumes (diskpart) ---
> "%WORK%\dp_in.txt" echo list disk
>> "%WORK%\dp_in.txt" echo list vol
diskpart /s "%WORK%\dp_in.txt" >> "%D%" 2>&1
>> "%D%" echo --- boot store (bcdedit /enum) ---
bcdedit /enum >> "%D%" 2>&1
rem Pre-mount the offline registry hives ONCE and keep them mounted for the whole
rem session, so the model can query/delete autostart values directly. The model is
rem told the exact mount points below. :finish unloads whatever stays mounted.
set "REGMOUNT="
if defined OFFWIN (
    reg load HKLM\OFFSOFT "%OFFWIN%\Windows\System32\config\SOFTWARE" >nul 2>&1
    if not errorlevel 1 set "REGMOUNT=1"
    reg load HKLM\OFFSYS "%OFFWIN%\Windows\System32\config\SYSTEM" >nul 2>&1
    if defined REGMOUNT call :dump_runkeys
)
goto :after_diag
:dump_runkeys
>> "%D%" echo --- offline Run keys [autostart malware often sits here] ---
reg query "HKLM\OFFSOFT\Microsoft\Windows\CurrentVersion\Run"     >> "%D%" 2>&1
reg query "HKLM\OFFSOFT\Microsoft\Windows\CurrentVersion\RunOnce" >> "%D%" 2>&1
goto :eof
:after_diag

rem ---------- 6. Static request pieces: tools.json + system.txt ----------
"%JQ%" -n "[{name:\"run_command\",description:\"Execute one cmd.exe command inside WinRE and return its output.\",input_schema:{type:\"object\",properties:{command:{type:\"string\",description:\"The exact cmd.exe command line\"}},required:[\"command\"]}}]" > "%WORK%\tools.json"

rem OW already set near the offline-Windows probe (used by both header and prompt).
(
echo IMPORTANT LANGUAGE RULE, highest priority: write EVERY human-readable
echo sentence in the RUSSIAN language. Never answer in English. Use only plain
echo ASCII punctuation, a normal hyphen, not an em-dash, because the WinRE
echo console font is limited. Command lines inside run_command stay in English.
echo.
echo You are a Windows repair agent running inside WinRE ^(Windows Recovery Environment^).
echo The user's Windows installation is broken ^(possibly by malware such as MEMZ: MBR overwritten,
echo registry autostart entries, damaged boot files^). Your job: diagnose and repair it.
echo.
echo Rules:
echo - The offline Windows is at %OW% ^(X: is the RAM-loaded WinRE itself - never repair X:^).
echo - The broken system's registry is ALREADY MOUNTED for you at these points:
echo     HKLM\OFFSOFT = offline SOFTWARE hive ^(HKLM\SOFTWARE of the broken OS^)
echo     HKLM\OFFSYS  = offline SYSTEM hive  ^(HKLM\SYSTEM of the broken OS^)
echo   To inspect/clean autostart, use HKLM\OFFSOFT, NOT plain HKLM. Example:
echo     reg query "HKLM\OFFSOFT\Microsoft\Windows\CurrentVersion\Run"
echo     reg delete "HKLM\OFFSOFT\Microsoft\Windows\CurrentVersion\Run" /v Evil /f
echo   NEVER query bare HKLM\Microsoft... - that is the empty WinRE registry.
echo   Do NOT reg unload these hives - the agent unloads them at the end.
echo - Work step by step: one command at a time, read its output before deciding the next.
echo - Prefer the least destructive fix: bootrec /fixmbr, bootrec /fixboot, bootrec /rebuildbcd,
echo   bcdboot, sfc /scannow /offbootdir= /offwindir=, dism /image: /cleanup-image,
echo   reg delete on HKLM\OFFSOFT to remove malicious autostart values.
echo - NEVER format or clean disks. NEVER delete user data.
echo - When the system should be repaired, reply with a final summary instead of a tool call.
echo.
echo SHELL SYNTAX - this is cmd.exe on WinRE, NOT bash. Obey strictly:
echo - No bash syntax: no heredoc ^(^<^<EOF^), no 'ls', no 2^>/dev/null, no ^|^| or ^&^&-chains as in bash.
echo - These tools are ABSENT in WinRE: findstr, where, tasklist, taskkill, more, powershell.
echo   Do NOT pipe to findstr or more. Use 'find' ^(present^) or just dump full output.
echo - diskpart takes a script file: write commands to a file, then diskpart /s file.txt.
echo - For offline registry: the hives are ALREADY mounted at HKLM\OFFSOFT and HKLM\OFFSYS.
echo   Just reg query / reg add / reg delete on them directly. Do NOT reg load or reg unload.
echo - Prefer one simple command per step. Avoid long for-loops and pipes.
) > "%WORK%\system.txt"

rem ---- Analyst knowledge base (lessons distilled from real infections) ----
(
echo.
echo === MALWARE PERSISTENCE CHECKLIST - inspect ALL of these, do not stop early ===
echo Malware hides its autostart in many places. Walk this list systematically:
echo 1. Run keys: HKLM\OFFSOFT\Microsoft\Windows\CurrentVersion\Run and RunOnce.
echo    Also per-user: load the user hive [see below] and check its ...\CurrentVersion\Run.
echo 2. Winlogon: HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion\Winlogon
echo    - Shell MUST be exactly 'explorer.exe'. Anything appended [wscript, a .vbs, a path] is malware.
echo    - Userinit MUST be 'C:\Windows\system32\userinit.exe,'. Extra entries after the comma are malware.
echo    - Check the Notify subkey too.
echo 3. IFEO hijack: HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion\Image File Execution Options
echo    A subkey named after a real exe [e.g. userinit.exe] with a 'Debugger' value redirects that program.
echo 4. Services: the SYSTEM hive is HKLM\OFFSYS. Offline it has NO CurrentControlSet link -
echo    use ControlSet001. Look at HKLM\OFFSYS\ControlSet001\Services for services whose
echo    ImagePath points into user/temp/appdata folders or the malware folder.
echo 5. Scheduled Tasks: schtasks does NOT work offline. Tasks are XML files under
echo    %OW%\Windows\System32\Tasks\ - list that tree and read suspicious task XML with 'type'.
echo 6. Startup folders: %OW%\Users\<name>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup
echo    and %OW%\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp.
echo 7. AppInit_DLLs: HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion\Windows, value AppInit_DLLs.
echo.
echo === LOADING A USER HIVE [HKCU of the broken OS] ===
echo Per-user malware [Run\..., wallpaper, disabled regedit] lives in each user's NTUSER.DAT.
echo List %OW%\Users, then: reg load HKLM\OFFUSER "%OW%\Users\<name>\NTUSER.DAT"
echo Inspect HKLM\OFFUSER\Software\Microsoft\Windows\CurrentVersion\Run etc, clean, then reg unload HKLM\OFFUSER.
echo.
echo === INFECTION-DATE ANCHOR - a powerful technique ===
echo Find the dropper or malware folder, note its timestamp [date AND time, e.g. 17.07.2026 15:38].
echo Legit Windows files share a build date [often the install date or a 2019 base date].
echo A SYSTEM file carrying the SAME timestamp as the malware is almost certainly a replaced/trojaned file.
echo Use 'dir' on suspect files and compare dates to spot hidden replacements.
echo.
echo === REPLACED SYSTEM FILES - detection and clean restore ===
echo Destructive malware can OVERWRITE a real system exe [seen in the wild: LogonUI.exe],
echo which breaks boot/logon even after you clean the registry.
echo - Suspect any core logon/shell exe whose size or date does not match a clean Windows:
echo   winlogon.exe userinit.exe explorer.exe LogonUI.exe sihost.exe csrss.exe wininit.exe services.exe lsass.exe dwm.exe.
echo - DO NOT trust the copy in C:\Windows\WinSxS - malware often infects the WinSxS copy too.
echo - Get a CLEAN original from the Windows install media if present [look for a volume with
echo   \sources\install.wim or install.esd]. Mount it read-only with DISM:
echo     dism /Get-WimInfo /WimFile:D:\sources\install.wim   [list indexes]
echo     dism /Mount-Wim /WimFile:D:\sources\install.wim /Index:N /MountDir:C:\wimmount /ReadOnly
echo   then copy the clean file from C:\wimmount\Windows\System32\... over the infected one
echo   [both in System32 AND in the matching WinSxS folder], then dism /Unmount-Wim /MountDir:C:\wimmount /Discard.
echo - After restoring, verify remaining core files by date to confirm nothing else was swapped.
echo - As a broad repair, offline SFC/DISM also help:
echo     sfc /scannow /offbootdir=%OW%\ /offwindir=%OW%\Windows
echo     dism /Image:%OW%\ /Cleanup-Image /RestoreHealth
) >> "%WORK%\system.txt"
if "%AUTO%"=="1" (
    >>"%WORK%\system.txt" echo - AUTONOMOUS MODE: your commands run automatically, there is NO human to confirm.
    >>"%WORK%\system.txt" echo   Act decisively. Do not ask questions - the user cannot answer mid-run. When the
    >>"%WORK%\system.txt" echo   repair is done, VERIFY it, then reply with a final summary and NO tool call to stop.
) else (
    >>"%WORK%\system.txt" echo - MANUAL MODE: a human operator confirms y/n before each command runs. You MAY ask
    >>"%WORK%\system.txt" echo   the operator a short question in your text - they will answer in the next turn.
    >>"%WORK%\system.txt" echo   Explain briefly WHY each command is needed. Proceed step by step.
)
if "%BLOCKDESTRUCTIVE%"=="1" (
    >>"%WORK%\system.txt" echo - Destructive commands ^(format, clean, del /s, cipher /w, X: writes^) are hard-blocked;
    >>"%WORK%\system.txt" echo   do not rely on them, use targeted fixes ^(reg add/delete, bootrec, bcdboot, sfc, dism^).
) else (
    >>"%WORK%\system.txt" echo - UNSAFE MODE: no command is blocked. You have full control. Be extremely careful:
    >>"%WORK%\system.txt" echo   never format or wipe user data, never touch the X: RAM disk. Prefer targeted fixes.
)
(
echo - Remember: ALL your text is in RUSSIAN, ASCII punctuation only.
) >> "%WORK%\system.txt"

rem ---------- 7. Seed the conversation ----------
rem  RESUME: history already exists on the stick - append a fresh "restarted"
rem  turn (new diagnostics + optional operator note) so the model sees the
rem  current state after the reboot/restart, WITHOUT losing prior memory.
rem  Fresh start: build messages.json from scratch.
set "HASMSG="
for %%A in ("%UMSG%") do if %%~zA gtr 0 set "HASMSG=1"
if defined RESUME (
    if defined HASMSG (
        "%JQ%" -n --rawfile umsg "%UMSG%" --rawfile diag "%D%" "{role:\"user\",content:(\"Answer ONLY in Russian. The agent was restarted or the machine rebooted - prior memory is preserved above. Operator note and fresh diagnostics follow.\n\n=== OPERATOR MESSAGE ===\n\"+$umsg+\"\n\n=== FRESH DIAGNOSTICS ===\n\"+$diag)}" > "%WORK%\seed.json"
    ) else (
        "%JQ%" -n --rawfile diag "%D%" "{role:\"user\",content:(\"Answer ONLY in Russian. The agent was restarted or the machine rebooted - prior memory is preserved above. Continue the repair. Fresh diagnostics after restart follow.\n\n=== FRESH DIAGNOSTICS ===\n\"+$diag)}" > "%WORK%\seed.json"
    )
    "%JQ%" --slurpfile s "%WORK%\seed.json" ". + $s" "%HIST%" > "%WORK%\messages.new" && move /y "%WORK%\messages.new" "%HIST%" >nul
) else (
    if defined HASMSG (
        "%JQ%" -n --rawfile umsg "%UMSG%" --rawfile diag "%D%" "[{role:\"user\",content:(\"Answer ONLY in Russian. The operator's message - their problem or question - is below. Address it directly. If it is a repair task, fix the system; if it is a question, answer it using the diagnostics and, when helpful, read-only commands.\n\n=== OPERATOR MESSAGE ===\n\"+$umsg+\"\n\n=== INITIAL DIAGNOSTICS ===\n\"+$diag)}]" > "%HIST%"
    ) else (
        "%JQ%" -n --rawfile diag "%D%" "[{role:\"user\",content:(\"Answer ONLY in Russian. Here is the initial diagnostics of the broken system. Analyze it and repair the system.\n\n\"+$diag)}]" > "%HIST%"
    )
)

rem ---------- 8. Agent loop ----------
rem  MAXSTEPS=0 means unlimited (run until the model stops calling tools).
set /a STEP=0
:loop
set /a STEP+=1
if not "%MAXSTEPS%"=="0" if %STEP% gtr %MAXSTEPS% ( echo. & echo [*] Reached max_steps ^(%MAXSTEPS%^). & goto :finish )
echo.
echo !C_HDR!===== Step %STEP% ^| !AUTOLBL! ^| !SAFELBL! ^| OS:!OW! =====!C_RST!
<nul set /p "=!C_DIM!"
<nul set /p "=[*] Asking the model..."
<nul set /p "=!C_RST!"
echo.

"%JQ%" -n --slurpfile msgs "%HIST%" --slurpfile tools "%WORK%\tools.json" --rawfile sys "%WORK%\system.txt" --arg model "%MODEL%" "{model:$model,max_tokens:2048,system:$sys,tools:$tools[0],messages:$msgs[0]}" > "%WORK%\body.json"

call :api_call
if not "%HTTP%"=="200" ( echo   [net] gave up after %RETRIES% attempts ^(last HTTP %HTTP%^). & goto :finish )

rem -- print any assistant text (Russian), tinted so it reads as the AI voice --
"%JQ%" -r "[.content[]|select(.type==\"text\")|.text]|join(\"\n\")" "%WORK%\resp.json" > "%WORK%\text.txt"
if defined ESC (
    <nul set /p "=!C_AI!"
    type "%WORK%\text.txt"
    <nul set /p "=!C_RST!"
    echo.
) else (
    type "%WORK%\text.txt"
)
type "%WORK%\text.txt" >> "%LOG%"

rem -- record the assistant turn verbatim (keeps thinking/tool_use blocks intact) --
"%JQ%" ".content" "%WORK%\resp.json" > "%WORK%\asst.json"
"%JQ%" --slurpfile c "%WORK%\asst.json" ". + [{role:\"assistant\",content:$c[0]}]" "%HIST%" > "%WORK%\messages.new" && move /y "%WORK%\messages.new" "%HIST%" >nul

rem -- is there a tool call? (select by TYPE, not name - proxy renames the tool) --
"%JQ%" -r "[.content[]|select(.type==\"tool_use\")][0].id // empty"            "%WORK%\resp.json" > "%WORK%\toolid.txt"
"%JQ%" -r "[.content[]|select(.type==\"tool_use\")][0].input.command // empty" "%WORK%\resp.json" > "%WORK%\cmd.txt"
set "TOOLID=" & set /p TOOLID=<"%WORK%\toolid.txt"
set "CMD="    & set /p CMD=<"%WORK%\cmd.txt"
rem  No command this turn = the model gave a text-only reply (question, summary,
rem  or done). Do NOT treat this as "stopped" - stay in the SAME conversation and
rem  let the operator type a follow-up (empty line = really quit). This is what
rem  makes it behave like a chat instead of restarting a fresh session each time.
if not defined TOOLID goto :chat

rem ---- loop guard: stop if the model repeats the SAME command 3x in a row ----
rem  In unattended auto mode a stuck model could otherwise loop forever.
if "!CMD!"=="!LASTCMD!" ( set /a SAMECOUNT+=1 ) else ( set "SAMECOUNT=0" )
set "LASTCMD=!CMD!"
if %SAMECOUNT% geq 2 (
    echo.
    echo [!] Model repeated the same command 3 times - stopping to avoid an infinite loop.
    goto :finish
)

echo.
echo !C_DIM!^>^>^>!C_RST! !CMD!
call :verdict
call :verdcolor
echo      !VCOL![verdict: %VERD%]!C_RST!
echo ^>^>^> !CMD! [%VERD%] >> "%LOG%"

rem ---- intercept findstr (ABSENT in WinRE) before wasting an API round-trip ----
rem  In the battle log the model tried findstr 3 times, each time hitting
rem  "not recognized" and retrying. Catch it here and hand back a precise hint.
rem  String-replace detection does NOT execute the command's metacharacters.
set "_r=!CMD:findstr=!"
if not "!_r!"=="!CMD!" (
    > "%WORK%\out.txt" echo NOTE: 'findstr' does not exist in WinRE. Do NOT use it.
    >> "%WORK%\out.txt" echo Use 'find' instead - but 'find' takes ONE quoted substring and does
    >> "%WORK%\out.txt" echo not support regex or multiple patterns. To match several terms, run
    >> "%WORK%\out.txt" echo one 'find' per term, or just dump the full output without a filter
    >> "%WORK%\out.txt" echo and read it yourself. Re-issue the command that way.
    echo     [intercepted: findstr not in WinRE - hint returned]
    echo ^>^>^> [intercepted findstr] >> "%LOG%"
    goto :feedback
)

rem ---- Execution policy ----
rem  AUTO=1: run everything without asking. forbidden is still blocked while
rem  BLOCKDESTRUCTIVE=1 (hard safety net vs format/clean/del /s/cipher/X: writes).
rem  BLOCKDESTRUCTIVE=0 (UNSAFE): even forbidden commands run - hands fully untied.
rem  AUTO=0: ask y/n for confirm; forbidden blocked unless UNSAFE.
if /i "%VERD%"=="forbidden" (
    if "%BLOCKDESTRUCTIVE%"=="1" (
        > "%WORK%\out.txt" echo BLOCKED by safety policy: destructive command refused. Choose a non-destructive alternative.
        echo      !C_ERR![BLOCKED - destructive]!C_RST!
    ) else (
        echo      !C_WARN![auto-run: destructive allowed by config]!C_RST!
        cmd /c "!CMD!" > "%WORK%\out.txt" 2>&1
    )
) else (
    if "%AUTO%"=="1" (
        echo      !C_DIM![auto-run]!C_RST!
        cmd /c "!CMD!" > "%WORK%\out.txt" 2>&1
    ) else if /i "%VERD%"=="confirm" (
        <nul set /p "=    !C_WARN!"
        <nul set /p "=Run this command? (y/n):"
        <nul set /p "=!C_RST!"
        set "ANS=" & set /p ANS="  "
        if /i "!ANS!"=="y" ( cmd /c "!CMD!" > "%WORK%\out.txt" 2>&1 ) else ( > "%WORK%\out.txt" echo User declined this command. Suggest an alternative. )
    ) else (
        cmd /c "!CMD!" > "%WORK%\out.txt" 2>&1
    )
)

rem ---- strip DISM progress bars from the output ----
rem  DISM mount/unmount prints ~100 lines of [=====N%=====] each. They flood the
rem  log and eat the tool_result budget. Every progress line contains '%'; no
rem  useful DISM line (Version/Index/Name/Size/completed) does. So drop '%' lines
rem  only when the command was a dism call.
set "_r=!CMD:dism=!"
if not "!_r!"=="!CMD!" (
    "%FIND%" /v "%%" < "%WORK%\out.txt" > "%WORK%\out.flt" 2>nul
    if exist "%WORK%\out.flt" (
        >> "%WORK%\out.flt" echo [progress bars omitted]
        move /y "%WORK%\out.flt" "%WORK%\out.txt" >nul
    )
)

:feedback
rem -- show the result on screen (result banner) and append to the log --
echo      !C_DIM![result]!C_RST!
type "%WORK%\out.txt"
type "%WORK%\out.txt" >> "%LOG%"

rem -- feed the result back. Keep head+tail so long dism/sfc output (verdict is
rem    usually at the END) is not lost to a naive first-8000-chars cut. --
"%JQ%" -n --arg id "!TOOLID!" --rawfile out "%WORK%\out.txt" "{role:\"user\",content:[{type:\"tool_result\",tool_use_id:$id,content:(if ($out|length)>8000 then ($out[0:5000]+\"\n\n...[output trimmed, middle omitted]...\n\n\"+$out[-3000:]) else $out end)}]}" > "%WORK%\tr.json"
"%JQ%" --slurpfile t "%WORK%\tr.json" ". + $t" "%HIST%" > "%WORK%\messages.new" && move /y "%WORK%\messages.new" "%HIST%" >nul
goto :loop

:chat
rem  Text-only reply from the model: keep the SAME conversation open. Prompt the
rem  operator for a follow-up (empty line = quit). No "stopped" banner, no new
rem  session, no re-run of the setup wizard - the history in %HIST% is preserved.
echo.
echo The agent replied and is waiting for you. Type a message to continue the chat.
echo Empty line - finish and exit.
set "MORE=" & set /p MORE="  you> "
if defined MORE (
    "%JQ%" -n --arg t "!MORE!" "{role:\"user\",content:[{type:\"text\",text:$t}]}" > "%WORK%\more.json"
    "%JQ%" --slurpfile u "%WORK%\more.json" ". + $u" "%HIST%" > "%WORK%\messages.new" && move /y "%WORK%\messages.new" "%HIST%" >nul
    set "SAMECOUNT=0" & set "LASTCMD="
    goto :loop
)

:summary
rem  Operator is quitting: before the real exit, ask the model for a FINAL
rem  REPORT of the whole session and show/log it. Text-only is requested; if
rem  the model still calls a tool, refuse it via tool_result and ask again
rem  (bounded retries so a stubborn model cannot loop forever). Any network
rem  failure just skips the report - quitting must never get stuck.
rem  NOTE: keep prompt texts free of ( ) and exclamation marks - parentheses
rem  break cmd block parsing, '!' is eaten by delayed expansion.
echo.
echo !C_HDR!===== FINAL REPORT =====!C_RST!
"%JQ%" -n "{role:\"user\",content:[{type:\"text\",text:\"The operator is closing the session. Write the FINAL REPORT of this whole session in Russian, ASCII punctuation only: 1 - what was wrong and what you diagnosed, 2 - what you fixed and how, 3 - what remains to do or verify after reboot. Plain text only, do NOT call any tool.\"}]}" > "%WORK%\more.json"
"%JQ%" --slurpfile u "%WORK%\more.json" ". + $u" "%HIST%" > "%WORK%\messages.new" && move /y "%WORK%\messages.new" "%HIST%" >nul
set /a SUMTRY=0
:summary_call
set /a SUMTRY+=1
if %SUMTRY% gtr 3 goto :finish
"%JQ%" -n --slurpfile msgs "%HIST%" --slurpfile tools "%WORK%\tools.json" --rawfile sys "%WORK%\system.txt" --arg model "%MODEL%" "{model:$model,max_tokens:2048,system:$sys,tools:$tools[0],messages:$msgs[0]}" > "%WORK%\body.json"
call :api_call
if not "%HTTP%"=="200" goto :finish
"%JQ%" -r "[.content[]|select(.type==\"text\")|.text]|join(\"\n\")" "%WORK%\resp.json" > "%WORK%\text.txt"
if defined ESC (
    <nul set /p "=!C_AI!"
    type "%WORK%\text.txt"
    <nul set /p "=!C_RST!"
    echo.
) else (
    type "%WORK%\text.txt"
)
echo ===== FINAL REPORT ===== >> "%LOG%"
type "%WORK%\text.txt" >> "%LOG%"
rem  record the assistant turn so the saved memory stays a valid conversation
"%JQ%" ".content" "%WORK%\resp.json" > "%WORK%\asst.json"
"%JQ%" --slurpfile c "%WORK%\asst.json" ". + [{role:\"assistant\",content:$c[0]}]" "%HIST%" > "%WORK%\messages.new" && move /y "%WORK%\messages.new" "%HIST%" >nul
rem  a tool_use here must get a tool_result anyway, or the next resume would be
rem  rejected by the API - refuse the command and ask for plain text again.
"%JQ%" -r "[.content[]|select(.type==\"tool_use\")][0].id // empty" "%WORK%\resp.json" > "%WORK%\toolid.txt"
set "TOOLID=" & set /p TOOLID=<"%WORK%\toolid.txt"
if defined TOOLID (
    "%JQ%" -n --arg id "!TOOLID!" "{role:\"user\",content:[{type:\"tool_result\",tool_use_id:$id,content:\"Session is over - the command was NOT executed. Write the plain-text final report now, no tool calls.\"}]}" > "%WORK%\tr.json"
    "%JQ%" --slurpfile t "%WORK%\tr.json" ". + $t" "%HIST%" > "%WORK%\messages.new" && move /y "%WORK%\messages.new" "%HIST%" >nul
    goto :summary_call
)
goto :finish

:finish
echo.
for %%H in (OFFSYS OFFSW OFFSOFT OFFSAM OFFSEC) do reg unload HKLM\%%H >nul 2>&1
echo === Agent finished. Full log:
echo   %LOG%
echo === Memory saved to:
echo   %HIST%
echo     The next run will offer to CONTINUE from here, even after a reboot.
goto :end

rem =====================================================================
rem  Subroutines
rem =====================================================================

rem ---- HTTP POST /v1/messages with retries (exponential backoff) ----
rem  Uses body.json, writes resp.json, sets HTTP.
:api_call
set /a _att=0
:api_retry
set /a _att+=1
set "HTTP=000"
"%CURL%" -s -S -o "%WORK%\resp.json" -w "%%{http_code}" --connect-timeout 30 --max-time 120 -X POST "%BASE%/v1/messages" -H "anthropic-version: 2023-06-01" -H "x-api-key: %KEY%" -H "content-type: application/json" -A "%UA%" --data-binary "@%WORK%\body.json" > "%WORK%\httpcode.txt" 2>nul
set /p HTTP=<"%WORK%\httpcode.txt"
if "%HTTP%"=="200" goto :eof
rem non-transient 4xx (bad key / bad request) - do not waste retries (429 = retry)
if %HTTP% geq 400 if %HTTP% lss 500 if not "%HTTP%"=="429" (
    echo   [net] HTTP %HTTP% - not retriable ^(check key/request^). Aborting.
    goto :eof
)
echo   [net] attempt %_att%/%RETRIES% failed ^(HTTP %HTTP%^)
if %_att% geq %RETRIES% goto :eof
set /a _w=%DELAY%
for /l %%i in (2,1,%_att%) do set /a _w*=2
if %_w% gtr 60 set "_w=60"
echo   [net] waiting %_w%s before retry...
ping -n %_w% 127.0.0.1 >nul
goto :api_retry

rem ---- safety verdict: reads CMD variable, sets VERD = forbidden|safe|confirm ----
rem  Pure cmd, no external tools. Forbidden = substring match via string-replace
rem  (does NOT execute the command's metachars, unlike echo|find). Safe = prefix.
rem  NOTE: 'reg delete' and single-file 'del /q|/f' are deliberately NOT forbidden -
rem  they are the core malware-removal actions (kill autostart values, drop the
rem  payload file). Only mass/irreversible wipes stay forbidden. Recursive deletes
rem  (del /s, rd /s) remain blocked so a bad pattern cannot nuke a whole tree.
:verdict
set "VERD=confirm"
rem --- forbidden: catastrophic, irreversible, wide-blast-radius operations only ---
for %%P in ("format " "clean" "cipher /w" "rd /s" "rmdir /s" "del /s") do (
    set "_r=!CMD:%%~P=!"
    if not "!_r!"=="!CMD!" set "VERD=forbidden"
)
rem --- never touch the WinRE RAM disk itself (X:) with a delete/reg-delete ---
set "_lc=!CMD!"
for %%P in ("del " "erase " "reg delete") do (
    set "_r=!CMD:%%~P=!"
    if not "!_r!"=="!CMD!" (
        if not "!CMD:X:\=!"=="!CMD!" set "VERD=forbidden"
        if not "!CMD:X:/=!"=="!CMD!" set "VERD=forbidden"
    )
)
if "%VERD%"=="forbidden" goto :eof
rem --- safe: read-only commands, matched by explicit-length prefix ---
if /i "!CMD:~0,4!"=="dir "        set "VERD=safe"
if /i "!CMD:~0,9!"=="reg query"   set "VERD=safe"
if /i "!CMD:~0,13!"=="bcdedit /enum" set "VERD=safe"
if /i "!CMD:~0,9!"=="ipconfig"    set "VERD=safe"
if /i "!CMD:~0,5!"=="ping "       set "VERD=safe"
if /i "!CMD:~0,9!"=="mountvol"    set "VERD=safe"
if /i "!CMD:~0,5!"=="wmic "       set "VERD=safe"
if /i "!CMD:~0,4!"=="vol "        set "VERD=safe"
if /i "!CMD:~0,4!"=="ver "        set "VERD=safe"
if /i "!CMD:~0,5!"=="type "       set "VERD=safe"
if /i "!CMD:~0,15!"=="sfc /verifyonly" set "VERD=safe"
rem a command containing a pipe/redirect to an EXECUTED second command is not "safe"
if not "!CMD:|=!"=="!CMD!" set "VERD=confirm"
goto :eof

rem ---- pick the ANSI color for the current VERD into VCOL ----
:verdcolor
if /i "%VERD%"=="safe"      ( set "VCOL=!C_OK!" & goto :eof )
if /i "%VERD%"=="forbidden" ( set "VCOL=!C_ERR!" & goto :eof )
set "VCOL=!C_WARN!"
goto :eof

rem ---- read one "key = value" from the ini into a variable ----
rem  %1 = key name, %2 = target variable name. Pure cmd, no findstr dependency
rem  (WinRE PATH may not resolve findstr). Skips ; and # comment lines.
:readini
set "__v="
for /f "usebackq tokens=1,* delims==" %%A in ("%CFG%") do (
    set "__k=%%A"
    set "__k=!__k: =!"
    if /i "!__k!"=="%~1" set "__v=%%B"
)
if defined __v for /f "tokens=* delims= " %%x in ("!__v!") do set "__v=%%x"
set "%~2=!__v!"
goto :eof

:end
echo.
echo [i] Agent stopped. Press any key to close the window.
pause >nul
endlocal
goto :eof

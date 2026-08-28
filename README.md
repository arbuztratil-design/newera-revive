# NewEra Revive

AI-powered Windows recovery agent that runs inside WinRE (Windows Recovery Environment). Uses Claude AI to diagnose and repair broken Windows installations autonomously.

## What It Does

Automatically repairs Windows systems that won't boot due to:
- Malware infections (MBR overwrites, registry persistence, rootkits)
- Corrupted boot files (BCD, bootmgr, winload.efi)
- Damaged system files (replaced trojaned executables)
- Registry damage (malicious autostart entries, IFEO hijacks)
- Boot sector issues (MBR/PBR corruption)

## Key Features

- AI-Powered: Uses Claude Sonnet API for intelligent diagnosis and repair decisions
- Works Offline: Runs entirely in WinRE without PowerShell/.NET/Python
- Safety First: Three-tier command safety policy (safe/confirm/forbidden)
- Persistent Memory: Conversation survives reboots (stored on USB stick)
- Network Bootstrap: Auto-loads NIC/WiFi drivers, configures DHCP/WiFi
- Russian UI: Full Cyrillic support with localized interface
- Color TUI: ANSI-colored terminal interface optimized for WinRE console
- Malware Toolkit: Built-in analyst knowledge base for infection detection

## Project Structure

    newera-revive/
    ├── start.cmd              # Main launcher menu
    ├── agent.cmd              # Core AI repair agent (cmd.exe version)
    ├── agent.ps1              # Alternative PowerShell-based agent
    ├── agent.ini              # Configuration file (API settings)
    ├── diag.cmd               # Environment probe/diagnostics
    ├── winre-net.cmd          # Network bootstrap for WinRE
    ├── jq.exe                 # JSON processor (static binary)
    └── lang/ru/               # Russian UI text files

## Quick Start

### Prerequisites

1. USB Flash Drive (FAT32 formatted)
2. Windows Installation Media or access to working Windows
3. Claude API Key from Anthropic or compatible proxy
4. jq.exe for Windows (included in release)

### Setup

1. Copy all files to your USB flash drive
2. Edit agent.ini with your API key and settings
3. Boot into WinRE:
   - Hold Shift + Restart, or
   - Boot from Windows installation media then Repair your computer, Troubleshoot, Command Prompt

### Usage

1. Insert USB drive in WinRE
2. Navigate to USB drive (usually X: is WinRE, find your USB letter)
3. Run: start.cmd
4. Follow the menu options

## How It Works

### Agent Loop

1. Collect Diagnostics: diskpart, bcdedit, registry hives, offline Windows detection
2. Send to AI: Diagnostics plus system prompt sent to Claude API
3. Receive Commands: AI suggests next repair step as cmd.exe command
4. Safety Check: Command classified as safe/confirm/forbidden
5. Execute: Run command (auto or with user confirmation)
6. Feedback: Send command output back to AI
7. Repeat: Continue until AI determines repair is complete

### Safety Policy

- safe: Auto-executed (dir, reg query, bcdedit /enum, ipconfig)
- confirm: Ask y/n in manual mode (bootrec, sfc, dism, reg delete)
- forbidden: Always blocked unless UNSAFE mode (format, clean, cipher /w, rd /s, writes to X:)

### Malware Detection Techniques

The agent includes built-in knowledge for detecting:
- Persistence mechanisms: Run keys, Winlogon Shell/Userinit, IFEO hijacks, services, scheduled tasks
- Infection-date anchor: Compare file timestamps to identify replaced system files
- User hive inspection: Load NTUSER.DAT to check per-user malware
- Clean file restoration: Mount install.wim to restore original system files

## Configuration

See agent.ini for all options including API endpoint, model selection, autonomous mode, safety settings, and UI preferences.

## Security Considerations

### What's Safe
- Read-only diagnostics never require confirmation
- Registry queries are always safe
- Offline Windows is at C/D/etc., never touches X: (WinRE RAM disk)

### What's Blocked by Default
- Disk formatting/cleaning commands
- Recursive deletion (del /s, rd /s)
- Cipher wipe operations
- Any writes to X: drive

### UNSAFE Mode Warning
Setting block_destructive = 0 removes ALL safety nets. Only use if you understand every command, have backups, and know why you need destructive operations.

## Session Persistence

The agent saves conversation history to airepair-store/messages.json on the USB stick:
- Survives reboots: Memory persists across power cycles
- Resume sessions: Choose Continue or New session on restart
- Archive old sessions: Automatically archived with timestamp
- Full logs: Complete command/output log in repair-log.txt

## Network Setup

If network isn't working in WinRE, run winre-net.cmd first. It will load NIC drivers, configure DHCP, support WiFi connection, and test HTTPS connectivity.

Place additional drivers in a Drivers/ folder next to the scripts if needed.

## Localization

Currently supports Russian (ru) with full UI localization in lang/ru/. AI responses forced to Russian language. ASCII-only punctuation for WinRE console compatibility.

## Troubleshooting

### Common Issues

**curl.exe not found**: Agent tries to copy from offline Windows automatically. Manually place curl.exe next to agent.cmd.

**Access is denied on diskpart/bcdedit**: Normal in WinRE, agent works around this. Try running from elevated prompt if not in WinRE.

**Proxy unreachable**: Check useragent in agent.ini (Cloudflare may block certain agents). Verify network with winre-net.cmd. Check date/time commands (TLS breaks with wrong clock).

**AI repeats same command**: Loop guard stops after 3 identical commands. Provide more context in operator message. Try manual mode to guide differently.

**Mojibake/garbled Cyrillic**: Ensure chcp 65001 is set (UTF-8). Use type command instead of echo for Russian text. Console font must support Unicode.

## License

This project uses a **Non-Commercial License** - free forever for personal and internal use.

**What this means:**
- Free for personal, educational, and internal company use
- Free to modify and share (non-commercially)
- Cannot sell the tool itself or create competing commercial products
- For commercial use, contact maintainers for separate licensing

See LICENSE and LICENSE-FAQ.md for full details.

## Contributing

Contributions welcome! See CONTRIBUTING.md for guidelines.

Areas for improvement:
- Additional language packs
- More diagnostic commands
- Enhanced malware detection patterns
- Better WiFi driver support
- GUI frontend option

## Disclaimer

This tool can make significant changes to your Windows installation. While it includes safety mechanisms:

- Always backup important data before running
- Review commands in manual mode before execution
- Use at your own risk - no warranty provided
- Not a substitute for professional data recovery services

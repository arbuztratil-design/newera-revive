# Installation Guide

This guide walks you through setting up NewEra Revive on a USB drive for Windows recovery.

## Prerequisites

### Hardware
- USB flash drive (4GB+ recommended, FAT32 formatted)
- Computer with Windows that needs repair
- Internet connection (for AI API access)

### Software
- Working Windows computer (to prepare the USB)
- Claude API key from Anthropic or compatible provider
- jq.exe for Windows (included in repository releases)

## Step-by-Step Installation

### Step 1: Prepare USB Drive

1. Insert USB flash drive into working computer
2. Format as FAT32 (required for WinRE compatibility):
   - Right-click USB drive in File Explorer
   - Select "Format"
   - Choose "FAT32" as file system
   - Click "Start"
3. Create a folder named `newera-revive` on the USB

### Step 2: Copy Files

Copy all files from this repository to the `newera-revive` folder on your USB:

```
newera-revive/
├── start.cmd
├── agent.cmd
├── agent.ps1
├── diag.cmd
├── winre-net.cmd
├── jq.exe
└── lang/
    └── ru/
        └── [text files]
```

**Note**: Do NOT copy `agent.ini` if it contains your real API key. Use the template instead.

### Step 3: Configure API Access

1. Copy `agent.ini.template` to `agent.ini`
2. Open `agent.ini` in a text editor
3. Replace `PASTE_YOUR_KEY_HERE` with your actual API key:
   ```ini
   key = sk-ant-api03-your-actual-key-here
   ```
4. Verify other settings:
   ```ini
   endpoint = https://api.anthropic.com
   model = <current-supported-model>
   auto = 1              ; Change to 0 for manual mode
   block_destructive = 1 ; Keep as 1 for safety
   ui = tui              ; Change to plain if colors don't work
   ```

**Important**: Never share your `agent.ini` file or commit it to version control!

### Step 4: Verify Setup

Run the environment probe to check everything is ready:

1. Open Command Prompt as Administrator
2. Navigate to USB drive:
   ```cmd
   D:
   cd \newera-revive
   ```
3. Run diagnostics:
   ```cmd
   diag.cmd
   ```
4. Review output for any `[!]` warnings

Common issues and fixes:
- **jq.exe missing**: Download from https://jqlang.github.io/jq/
- **curl.exe not found**: Will be auto-copied from offline Windows
- **TEMP not defined**: Normal in some environments, agent handles this

### Step 5: Test in Safe Environment (Optional)

Before using on a broken system, test in a VM:

1. Create a Windows VM
2. Break the boot process (e.g., delete BCD)
3. Boot into WinRE
4. Attach USB with NewEra Revive
5. Run `start.cmd` and verify functionality

## Using in WinRE

### Method 1: Advanced Startup

1. On broken Windows PC:
   - Hold Shift key while clicking Restart
   - Or: Settings → Update & Security → Recovery → Advanced startup → Restart now
2. Choose: Troubleshoot → Advanced options → Command Prompt
3. Insert USB drive
4. Find USB drive letter (usually not C:):
   ```cmd
   diskpart
   list volume
   exit
   ```
5. Navigate to scripts:
   ```cmd
   D:
   cd \newera-revive
   ```
6. Run launcher:
   ```cmd
   start.cmd
   ```

### Method 2: Installation Media

1. Create Windows installation USB/DVD
2. Boot from installation media
3. Select language and keyboard
4. Click "Repair your computer" (bottom left)
5. Choose: Troubleshoot → Advanced options → Command Prompt
6. Follow steps 3-6 from Method 1

### Method 3: Automatic Repair Failure

1. Let Windows fail to boot 3 times
2. Automatic Repair will trigger
3. Choose: Advanced options → Command Prompt
4. Follow steps 3-6 from Method 1

## Configuration Options

### Quick Reference

Edit `agent.ini` to customize behavior:

| Setting | Values | Default | Description |
|---------|--------|---------|-------------|
| endpoint | URL | models2.cldc.dev | API endpoint |
| model | string | claude-sonnet-5 | AI model name |
| key | string | required | Your API key |
| auto | 0 or 1 | 1 | Autonomous mode |
| block_destructive | 0 or 1 | 1 | Safety net |
| ui | tui or plain | tui | Interface style |
| retries | number | 10 | Retry attempts |
| max_steps | number | 0 | Max AI steps (0=unlimited) |

### Recommended Settings by Scenario

#### For Beginners (Safest)
```ini
auto = 0
block_destructive = 1
max_steps = 20
```

#### For Advanced Users
```ini
auto = 1
block_destructive = 1
max_steps = 0
```

#### For Experts (DANGEROUS)
```ini
auto = 1
block_destructive = 0
max_steps = 0
```

**Warning**: UNSAFE mode (`block_destructive = 0`) can permanently destroy data!

## Network Setup

If network doesn't work in WinRE:

1. Run network bootstrap first:
   ```cmd
   winre-net.cmd
   ```
2. Follow prompts to:
   - Load NIC drivers
   - Configure DHCP
   - Connect to WiFi (if needed)
3. Test connectivity when prompted

### Adding Custom Drivers

1. Create `Drivers` folder next to scripts on USB
2. Copy `.inf` files for your network adapter
3. `winre-net.cmd` will automatically load them

Example structure:
```
newera-revive/
├── Drivers/
│   ├── Intel-NIC/
│   │   └── e1d65x64.inf
│   └── Realtek-WiFi/
│       └── rtwlane.inf
├── agent.cmd
└── ...
```

## Troubleshooting Installation

### Problem: "agent.ini not found"

**Solution**: Copy `agent.ini.template` to `agent.ini` and configure it.

### Problem: "jq.exe not found"

**Solution**: 
1. Download jq from https://jqlang.github.io/jq/download/
2. Get Windows 64-bit static binary
3. Rename to `jq.exe`
4. Place next to `agent.cmd`

### Problem: "curl.exe not found"

**Solution**: Agent will try to copy from offline Windows automatically. If that fails:
1. Download curl for Windows
2. Place `curl.exe` next to other scripts

### Problem: Colors don't show

**Solution**: Change in `agent.ini`:
```ini
ui = plain
```

### Problem: Cyrillic shows as garbage

**Solution**: 
1. Ensure `chcp 65001` is set (already in scripts)
2. Console font must support Unicode
3. In WinRE, this should work automatically

### Problem: API connection fails

**Solution**:
1. Check internet: `ping 8.8.8.8`
2. Verify date/time: `date` and `time` commands
3. Check `useragent` in agent.ini
4. Try different endpoint if using proxy

## First Run Checklist

Before running on a critical system:

- [ ] USB drive formatted as FAT32
- [ ] All files copied correctly
- [ ] `agent.ini` configured with valid API key
- [ ] `diag.cmd` runs without errors
- [ ] Network connectivity verified
- [ ] Important data backed up (if possible)
- [ ] Understand safety policy settings
- [ ] Tested in non-critical environment (recommended)

## Next Steps

After successful installation:

1. Read the [README](README.md) for usage instructions
2. Review [SECURITY.md](SECURITY.md) for safety considerations
3. Check [CONTRIBUTING.md](CONTRIBUTING.md) if you want to help improve the project

## Getting Help

- **Documentation**: See README.md for detailed usage
- **Issues**: Report bugs on GitHub Issues
- **Discussions**: Ask questions in GitHub Discussions
- **Safety**: Review SECURITY.md before first use

---

**Remember**: Always have a backup plan. This tool is powerful but not infallible.

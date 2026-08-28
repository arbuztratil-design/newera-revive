# Changelog

All notable changes to NewEra Revive will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of NewEra Revive
- AI-powered Windows repair agent using Claude API
- Pure cmd.exe implementation for WinRE compatibility
- Three-tier command safety policy (safe/confirm/forbidden)
- Persistent conversation memory across reboots
- Network bootstrap with WiFi support
- Russian language UI localization
- ANSI-colored terminal interface
- Built-in malware detection knowledge base
- Session archive and resume functionality
- Loop guard against repeated commands
- DISM progress bar filtering
- Registry hive pre-mounting for offline access
- Infection-date anchor technique for malware detection
- Environment probe diagnostics tool
- Unified launcher menu system

### Security
- Destructive command blocking by default
- X: drive write protection
- API key isolation in config file
- Manual mode for command review
- Safety policy override requires explicit confirmation

## [1.0.0] - 2026-08-28

### Initial Release

First public version of NewEra Revive with core functionality:
- AI agent loop with Claude Sonnet integration
- Offline Windows detection and diagnostics
- Boot repair capabilities (bootrec, bcdedit, bcdboot)
- System file verification (sfc, dism)
- Registry cleanup for malware persistence
- Network initialization in WinRE
- Multi-session persistence on USB storage
- Comprehensive logging and session history

---

## Version Guidelines

### Semantic Versioning

- **MAJOR** version for incompatible API/config changes
- **MINOR** version for new features (backwards compatible)
- **PATCH** version for bug fixes and security updates

### What Each Component Means

- `agent.cmd` - Core agent, most critical component
- `agent.ps1` - PowerShell alternative (secondary)
- `start.cmd` - Launcher menu
- `diag.cmd` - Diagnostics tool
- `winre-net.cmd` - Network setup
- `lang/` - Localization files
- `jq.exe` - External dependency (not versioned here)

## Upgrade Notes

### From Previous Versions

This is the first public release. If you were using a private beta:

1. Backup your `airepair-store/` directory
2. Replace all script files with new versions
3. Update `agent.ini` with new configuration options
4. Review safety policy changes
5. Test in non-critical environment first

## Deprecation Notices

None at this time. All features are actively supported.

## Known Issues

See GitHub Issues for current known issues and workarounds.

## Migration Guide

Not applicable for initial release.

---

For questions about versioning or upgrades, please open an issue on GitHub.

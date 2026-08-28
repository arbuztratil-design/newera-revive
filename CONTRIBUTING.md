# Contributing to NewEra Revive

Thank you for your interest in contributing! This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites

- Windows environment for testing (preferably with WinRE access)
- Basic knowledge of batch scripting (cmd.exe)
- Understanding of Windows internals (registry, boot process, etc.)
- Claude API key for testing AI integration

### Development Setup

1. Fork the repository
2. Clone your fork locally
3. Create a feature branch: `git checkout -b feature/amazing-feature`
4. Test changes in actual WinRE environment when possible
5. Commit your changes: `git commit -m 'Add amazing feature'`
6. Push to the branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

## Project Structure

    newera-revive/
    ├── start.cmd              # Main launcher - keep simple and stable
    ├── agent.cmd              # Core AI agent - main development focus
    ├── agent.ps1              # PowerShell alternative - secondary priority
    ├── diag.cmd               # Environment diagnostics
    ├── winre-net.cmd          # Network bootstrap
    ├── jq.exe                 # JSON processor (external dependency)
    └── lang/                  # Localization files
        └── ru/                # Russian language pack

## Coding Standards

### Batch Script Style

- Use `@echo off` at the start of all scripts
- Enable delayed expansion: `setlocal enabledelayedexpansion`
- Set UTF-8 code page: `chcp 65001 >nul`
- Use descriptive variable names in UPPERCASE
- Add comments for complex logic
- Handle errors gracefully with `if errorlevel` checks
- Never assume PATH includes System32 - always use full paths or set PATH explicitly

### Safety First

When modifying command execution or safety policies:

- NEVER remove safety checks without thorough review
- Document why a command should be safe/forbidden
- Test extensively before changing verdict classifications
- Consider edge cases and potential misuse

### WinRE Compatibility

Remember that WinRE is a stripped-down environment:

- No PowerShell by default (agent.cmd must work without it)
- Missing tools: findstr, where, tasklist, taskkill, more
- Limited PATH - System32 often not included
- X: drive is RAM disk (wiped on reboot)
- Console has limited font support (ASCII preferred)
- ANSI support varies (provide plain fallback)

## Areas for Contribution

### High Priority

1. Additional Language Packs
   - Create new language directories under lang/
   - Translate all text files maintaining structure
   - Test with different console fonts

2. Enhanced Diagnostics
   - Add more read-only diagnostic commands
   - Improve offline Windows detection
   - Better hardware detection

3. Malware Detection
   - Additional persistence mechanism checks
   - Improved timestamp analysis
   - More file integrity verification methods

4. Driver Support
   - Better WiFi driver detection
   - Additional NIC driver sources
   - Automated driver extraction from install.wim

### Medium Priority

5. Error Handling
   - Better error messages
   - Recovery from failed operations
   - Rollback mechanisms

6. Performance
   - Faster diagnostic collection
   - Optimized API calls
   - Reduced memory usage

7. Documentation
   - More examples
   - Video tutorials
   - Troubleshooting guides

### Future Ideas

8. GUI Frontend
   - Optional graphical interface
   - Progress visualization
   - Interactive repair wizard

9. Multi-AI Support
   - Support for other LLM providers
   - Local model integration
   - Fallback mechanisms

10. Plugin System
    - Modular repair strategies
    - Custom diagnostic modules
    - Community-created extensions

## Testing Guidelines

### Before Submitting

- Test in actual WinRE environment (not just regular Windows)
- Verify no destructive commands run without proper safeguards
- Check UTF-8/Cyrillic rendering with chcp 65001
- Ensure scripts work without elevated privileges where intended
- Test both AUTO and MANUAL modes
- Verify session persistence across reboots

### Test Cases

1. Clean System: Agent should detect healthy system
2. Boot Issues: Test with corrupted BCD/boot files
3. Malware Simulation: Test registry cleanup (in VM!)
4. Network Issues: Test driver loading and WiFi setup
5. Edge Cases: No offline Windows found, no network, etc.

## Pull Request Process

1. Update documentation if changing functionality
2. Add tests/examples if applicable
3. Ensure no sensitive data (API keys, personal info) in commits
4. Reference any related issues
5. Describe what you changed and why
6. Include before/after screenshots for UI changes

## Code Review Checklist

Reviewers will check:

- [ ] Safety mechanisms intact
- [ ] WinRE compatibility maintained
- [ ] Error handling present
- [ ] Documentation updated
- [ ] No hardcoded paths or assumptions
- [ ] Cyrillic/UTF-8 handling correct
- [ ] No sensitive data exposed
- [ ] Backwards compatible where possible

## Security Considerations

- Never commit API keys or credentials
- Review all command execution paths
- Validate user input thoroughly
- Consider privilege escalation risks
- Test in isolated environment first

## License

By contributing, you agree that your contributions will be licensed under the same Non-Commercial License as the project. See LICENSE file for details.

For commercial licensing inquiries, contact the maintainers.

## Communication

- Use GitHub Issues for bugs and feature requests
- Use Discussions for questions and ideas
- Be respectful and constructive
- Help others learn Windows internals

---

Thank you for helping make Windows recovery accessible to everyone!

# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

**DO NOT** open a public GitHub issue for security vulnerabilities.

Instead:
1. Email: [security contact needed]
2. Include detailed description
3. Provide steps to reproduce
4. Attach proof-of-concept if applicable
5. Allow reasonable time for response and fix

### What to Include

- Type of vulnerability (e.g., command injection, privilege escalation)
- Full path of affected file(s)
- Step-by-step reproduction instructions
- Potential impact assessment
- Suggested fix if you have one

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 1 week
- **Fix Development**: 1-4 weeks depending on severity
- **Public Disclosure**: After fix is released

## Security Features

### Built-in Safeguards

1. **Command Safety Policy**
   - Three-tier verdict system (safe/confirm/forbidden)
   - Destructive commands blocked by default
   - X: drive (WinRE RAM disk) write protection

2. **Configuration Protection**
   - API keys stored in separate config file
   - Config file excluded from version control (.gitignore)
   - Template provided without real credentials

3. **Session Isolation**
   - Each session independent
   - No persistent background processes
   - Registry hives unloaded on exit

### Known Limitations

1. **Not Sandboxed**
   - Runs with user privileges in WinRE
   - Can execute any cmd.exe command if allowed by safety policy
   - Should only be run by trusted users

2. **AI Trust Model**
   - Relies on Claude API for decision making
   - AI could theoretically suggest harmful commands
   - Safety policy provides second layer of defense

3. **Network Exposure**
   - Requires internet access for AI API
   - Uses HTTPS for all API communication
   - API key transmitted with each request

### Best Practices

#### For Users

- **Always review commands** in manual mode before execution
- **Backup important data** before running repairs
- **Use official releases** from trusted sources
- **Verify checksums** of downloaded files
- **Never share** your agent.ini file
- **Run in WinRE** not regular Windows when possible
- **Check API endpoint** is legitimate

#### For Developers

- **Never commit** API keys or credentials
- **Review safety policies** before modifying command execution
- **Test in VM** before testing on real systems
- **Document security implications** of new features
- **Use least privilege** principle where possible
- **Validate all inputs** from user and AI

## Common Attack Vectors

### 1. Malicious AI Responses

**Risk**: Compromised AI endpoint sends destructive commands

**Mitigation**:
- Safety policy blocks known destructive patterns
- Manual mode requires user confirmation
- Loop guard prevents repeated harmful commands

### 2. Configuration Tampering

**Risk**: Modified agent.ini points to malicious endpoint

**Mitigation**:
- Verify endpoint URL before use
- Check file integrity with checksums
- Keep backup of working configuration

### 3. Driver Injection

**Risk**: Malicious drivers loaded via winre-net.cmd

**Mitigation**:
- Only loads drivers from offline Windows DriverStore
- Optional Drivers/ folder should contain verified drivers only
- drvload requires elevated privileges (already in WinRE)

### 4. Session Hijacking

**Risk**: Conversation history manipulated between sessions

**Mitigation**:
- History stored locally on USB stick
- No cloud synchronization
- Archive old sessions with timestamps

## Security Checklist Before Use

- [ ] Downloaded from official repository
- [ ] Verified file checksums
- [ ] Reviewed agent.ini settings
- [ ] API endpoint is legitimate
- [ ] Running in WinRE environment
- [ ] Important data backed up
- [ ] Understand safety policy settings
- [ ] Manual mode enabled for first use

## Responsible Disclosure

We appreciate responsible disclosure of security issues. Contributors who report valid security vulnerabilities will be acknowledged (with permission) in release notes.

## Updates

Security updates will be:
1. Released as patch versions (1.x.Y)
2. Clearly marked in changelog
3. Announced in repository
4. Backported to supported versions

Stay updated by watching the repository or checking releases regularly.

## Contact

For security questions or concerns:
- Open a private security advisory on GitHub
- Do NOT discuss vulnerabilities in public issues

---

**Remember**: This tool has powerful capabilities. Always use it responsibly and understand what each command does before execution.

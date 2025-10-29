# CJC.VPN - Tailscale & SSH Management Toolkit

Consolidated PowerShell toolkit for managing Tailscale mesh VPN and SSH access across Windows, macOS, and Linux machines. Features automated installation, diagnostics, repair, and comprehensive testing across all machines in your Tailscale account.

## Quick Start

### Prerequisites
- PowerShell Core (pwsh) installed
- Tailscale installed and account configured
- Administrator privileges for firewall configuration

### Installation

```powershell
# 1. Run installation script
.\Install-Tailscale.ps1

# 2. Reload PowerShell profile
. $PROFILE

# 3. Generate SSH key (if not already done)
ssh-keygen -t ed25519 -N ""

# 4. Test remote access
RSSH <your-machine> "Get-Date"
```

## Master Scripts

### 1. Install-Tailscale.ps1
Unified installation script for SSH, Tailscale, and remote access functionality.

**Features:**
- Cross-platform SSH installation (Windows/macOS/Linux)
- RSSH function installation to PowerShell profile
- Automatic platform detection
- Firewall configuration

**Usage:**
```powershell
# Automatic platform detection
.\Install-Tailscale.ps1

# Skip SSH installation
.\Install-Tailscale.ps1 -SkipSSH

# Skip profile setup
.\Install-Tailscale.ps1 -SkipProfile

# Verbose output
.\Install-Tailscale.ps1 -Verbose
```

**What it installs:**
- **Windows:** OpenSSH Server feature, firewall rules, SSH service auto-start
- **macOS:** Remote Login (SSH) enabled, .ssh directory configured
- **Linux:** Installation instructions for openssh-server package

---

### 2. Repair-Tailscale.ps1
Diagnostic and repair utility for common Tailscale connectivity issues.

**Features:**
- Three-phase automated workflow (Diagnostics → Repairs → Verification)
- Tests Tailscale connectivity, ICMP blocking, SSH service, RSSH functionality
- Auto-fixes Windows Firewall ICMP rules
- Detects and suggests fixes for ESET firewall issues
- Optional automatic repair mode

**Usage:**
```powershell
# Interactive diagnostic mode (shows issues, prompts for fixes)
.\Repair-Tailscale.ps1

# Automatic repair mode (fixes everything automatically)
.\Repair-Tailscale.ps1 -Auto

# With verbose output
.\Repair-Tailscale.ps1 -Verbose
```

**What it checks:**
1. **Tailscale Status:** Is Tailscale running and authenticated?
2. **ICMP Blocking:** Can machines ping each other over Tailscale?
3. **SSH Service:** Is SSH server running?
4. **RSSH Function:** Is the remote SSH helper available?

**Common fixes applied:**
- Re-authenticates Tailscale if disconnected
- Adds Windows Firewall ICMP rule for Tailscale subnet (100.64.0.0/10)
- Suggests ESET firewall rule configuration (requires manual setup)

---

### 3. Audit-Tailscale.ps1
Comprehensive testing and audit tool for all machines in Tailscale account.

**Features:**
- Tests all machines with three connectivity methods
- Live progress display during testing
- Color-coded results (✓ pass, ✗ fail)
- Detailed summary grid with statistics
- JSON audit reports with timestamps

**Usage:**
```powershell
# Test all machines (from this machine only)
.\Audit-Tailscale.ps1

# Interactive mode with options
.\Audit-Tailscale.ps1 -Interactive

# Generate audit report
.\Audit-Tailscale.ps1 -GenerateReport

# Verbose output
.\Audit-Tailscale.ps1 -Verbose
```

**What it tests per machine:**
1. **Tailscale Ping:** Uses Tailscale's internal ping (fastest, direct connection)
2. **Regular Ping:** Ping over Tailscale network (validates routing)
3. **RSSH Connectivity:** Executes `winget upgrade --all --silent` via remote SSH

**Output:**
```
CONNECTIVITY SUMMARY
─────────────────────────────────────────────────────────
Machine                  Tailscale Ping    Regular Ping    RSSH (Winget)
─────────────────────────────────────────────────────────
CJC-2015-MGMT-3          ✓                 ✓               ✓
CJC-2021-MGMT-3          ✓                 ✓               ✓
DT-2020-RES-1            ✓                 ✓               ✓
─────────────────────────────────────────────────────────
Total: 3/3 machines online | Avg response: 15ms
```

---

## RSSH Function (Remote SSH)

Dynamic remote command execution with automatic hostname resolution.

### Installation
Automatically installed by `Install-Tailscale.ps1` to your PowerShell profile.

### Syntax
```powershell
RSSH <hostname> <command>
```

### Hostname Resolution (Three-Tier Lookup)
1. **Tailscale Status:** Looks up hostname in `tailscale status` output
2. **DNS Resolution:** Uses system DNS to resolve hostname to IP
3. **mDNS Fallback:** Attempts hostname.local resolution

### Examples

**Execute PowerShell command:**
```powershell
RSSH cjc-2015-mgmt-3 "Get-Date"
RSSH cjc-2021-mgmt-3 "Get-Service sshd"
```

**Run remote script:**
```powershell
RSSH dt-2020-res-1 "& 'C:\Scripts\Maintenance.ps1'"
```

**Install software via winget:**
```powershell
RSSH cjc-2015-mgmt-3 "winget upgrade --all --silent"
```

**Bulk operations:**
```powershell
$machines = @("cjc-2015-mgmt-3", "cjc-2021-mgmt-3", "dt-2020-res-1")
foreach ($machine in $machines) {
    RSSH $machine "Get-WmiObject Win32_OperatingSystem | Select-Object Caption, Version"
}
```

### SSH Key Setup
RSSH requires Ed25519 SSH keys in `~/.ssh/id_ed25519`:

```powershell
# Generate key if needed
ssh-keygen -t ed25519 -N ""

# Copy public key to remote machines
ssh-copy-id -i ~/.ssh/id_ed25519.pub mathew.burkitt@<remote-ip>
```

---

## Architecture & Concepts

### Tailscale Network
- **VPN Type:** Mesh VPN using WireGuard protocol
- **IP Range:** 100.64.0.0/10 (Carrier-Grade NAT range)
- **Authentication:** Requires valid Tailscale account
- **Status Check:** `tailscale status` shows all connected machines

### Firewall Considerations

#### Windows Firewall
- Automatically configured by `Install-Tailscale.ps1`
- ICMP rule added for Tailscale subnet (100.64.0.0/10)
- SSH port 22 rule added for remote access

#### ESET Endpoint Security
- Blocks ICMP by default with built-in rule
- Must create higher-priority rule allowing 100.64.0.0/10 traffic
- **Manual Configuration Required:**
  1. Open ESET Endpoint Security
  2. Go to Advanced Setup → Firewall → Rules
  3. Create new rule above "Block ICMP communication":
     - Name: "Allow Tailscale 100.64.0.0/10"
     - Action: Allow
     - Protocol: Any (or ICMP if only ICMP needed)
     - Remote host: 100.64.0.0/10

#### macOS
- SSH enabled automatically by `Install-Tailscale.ps1`
- System Firewall allows SSH by default

### SSH Access Model
- **Authentication:** Ed25519 key-based (no passwords)
- **User Account:** Standard user account (mathew.burkitt)
- **Execution Context:** Runs as user, respects user permissions
- **Connection Timeout:** 5 seconds (non-aggressive)
- **StrictHostKeyChecking:** Disabled for automation (change if needed)

---

## Troubleshooting

### Issue: Machines shown offline in Tailscale status

**Symptoms:**
- `tailscale status` shows machines as "Offline" or "Idle"
- Machines are actually online (visible in Splashtop, etc.)
- Tailscale ping fails but machines respond to other pings

**Solutions:**
1. Run `.\Repair-Tailscale.ps1` for automated diagnostics
2. Check ICMP blocking: Run `ping <machine-ip>`
3. If ESET is installed:
   - Verify "Block ICMP communication" rule is below the Tailscale allow rule
   - Or disable the block rule temporarily for testing
4. Restart Tailscale: `tailscale down && tailscale up`

---

### Issue: SSH connection refused

**Symptoms:**
- RSSH function fails with connection refused
- SSH service not running on remote machine

**Solutions:**
1. Verify SSH service is running: `Get-Service sshd`
2. Re-run `Install-Tailscale.ps1` on remote machine
3. Check firewall allows port 22 on target machine
4. Verify SSH key is in `~/.ssh/id_ed25519`

---

### Issue: RSSH hostname not resolving

**Symptoms:**
- "Could not resolve hostname to an IP address" error
- Hostname partially correct or machine name uses different format

**Solutions:**
1. Check exact machine name: `tailscale status | grep -i machinename`
2. Use full hostname from Tailscale status output
3. Verify machine is online: `tailscale ping <machine>`
4. Try IP directly: `ssh mathew.burkitt@<ip>`

---

### Issue: Firewall blocking Tailscale traffic

**Symptoms:**
- Tailscale connects but ping fails
- "No route to host" errors
- Regular ping fails but Tailscale status shows online

**Solutions:**
1. Disable third-party firewalls temporarily for testing
2. Check ESET rules: Advanced Setup → Firewall → Rules
3. Verify Windows Firewall ICMP rule exists
4. Run `Repair-Tailscale.ps1 -Auto` to fix Windows Firewall

---

## Common Tasks

### Deploy software across all machines
```powershell
# First, run audit to verify connectivity
.\Audit-Tailscale.ps1

# Then deploy to all machines
$machines = @(tailscale status | Where-Object { $_ -like "100.*" } | ForEach-Object { ($_ -split '\s+')[0] })
foreach ($ip in $machines) {
    $hostname = (tailscale status | Where-Object { $_ -like "$ip*" } | ForEach-Object { ($_ -split '\s+')[1] })
    Write-Host "Deploying to $hostname ($ip)..."
    RSSH $hostname "winget install <package-name> --silent"
}
```

### Check system info on all machines
```powershell
$machines = @("cjc-2015-mgmt-3", "cjc-2021-mgmt-3", "dt-2020-res-1")
foreach ($machine in $machines) {
    Write-Host "`n=== $machine ===" -ForegroundColor Cyan
    RSSH $machine "Get-WmiObject Win32_OperatingSystem | Select-Object CSName, Caption, Version"
}
```

### Audit with JSON report
```powershell
.\Audit-Tailscale.ps1 -GenerateReport
# Report saved as <hostname>-audit.<timestamp>.json
```

---

## Script Consolidation

This toolkit represents a consolidation of 20+ fragmented scripts into 3 authoritative masters:

**Consolidated FROM:**
- Install-SSH-Windows.ps1, Install-SSH-macOS.ps1, Setup-SSH.ps1, Setup-PowerShellProfile.ps1
- Fix-TailscaleFirewall.ps1, Fix-ESET-Tailscale.ps1, refresh-tailscale.ps1
- Verify-Tailscale.ps1, Verify-Tailscale-AllToAll.ps1, Test-TailscaleConnectivity.ps1, Test-AllMachines.ps1
- SSH-SETUP-README.md, POWERSHELL-PROFILE-SETUP.md, VERIFY-TAILSCALE-README.md, SSH-REMOTE-ACCESS.md

**Consolidated INTO:**
- `Install-Tailscale.ps1` (installation and setup)
- `Repair-Tailscale.ps1` (diagnostics and repair)
- `Audit-Tailscale.ps1` (comprehensive testing)
- `README.md` (unified documentation)

---

## Requirements

- PowerShell Core (v7+) - `pwsh` command
- Tailscale installed and configured
- SSH client/server (OpenSSH)
- Administrator privileges for firewall/service configuration
- SSH key pair (Ed25519 recommended)

---

## Support & Troubleshooting

For issues:
1. Run `.\Repair-Tailscale.ps1` for automated diagnostics
2. Run `.\Audit-Tailscale.ps1` to test all machines
3. Check Tailscale dashboard: https://login.tailscale.com/admin/machines
4. Verify Tailscale version: `tailscale version`

## License

Internal CJC infrastructure tooling.

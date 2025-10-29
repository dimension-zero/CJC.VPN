# PowerShell Profile Setup: Dynamic Remote SSH (RSSH)

This guide explains how to set up the RSSH function for easily executing commands on remote machines without typing SSH commands manually.

---

## What You Get

After setup, you can execute remote commands with a single function:

```powershell
# Hostname-based execution (auto-resolves via Tailscale or DNS)
RSSH CJC-2015-MGMT-3 "winget upgrade --all --silent"
RSSH cjc-2021-tech-1 Get-Process
RSSH dt-2020-imac-001 "ls -la"

# Or use IP directly
RSSH 100.91.158.121 "Get-Date"
```

Instead of manually typing:
```powershell
ssh mathew.burkitt@100.91.158.121 powershell -Command "winget upgrade --all --silent"
```

---

## Installation

### Step 1: Run the Setup Script

```powershell
cd C:\Users\mathew.burkitt\source\repos\CJC\CJC.VPN
.\Setup-PowerShellProfile.ps1 -SSHUser "mathew.burkitt" -SSHKey "$HOME\.ssh\id_ed25519"
```

### Step 2: Reload Your Profile

```powershell
# Reload the current PowerShell session
. $PROFILE

# Or close and reopen Windows Terminal
```

### Step 3: Verify Installation

```powershell
# Test a simple command
RSSH cjc-2015-mgmt-3 "Get-Date"

# Should output:
# Executing on cjc-2015-mgmt-3 (100.91.158.121): Get-Date
# ────────────────────────────────────────────────────────────────────────────────
# Tuesday, October 29, 2025 3:45:23 PM
# ────────────────────────────────────────────────────────────────────────────────
```

---

## How RSSH Resolves Hostnames

The RSSH function uses a three-step resolution process:

1. **Tailscale Status**: Checks `tailscale status` for machine matching the hostname
2. **DNS Resolution**: Uses system DNS to resolve hostname to IP
3. **Local Domain**: Tries appending `.local` suffix for mDNS resolution

This means it works with:
- Tailscale machine names (e.g., `cjc-2015-mgmt-3`)
- Full FQDNs (e.g., `cjc-2015-mgmt-3.example.com`)
- IP addresses directly (e.g., `100.91.158.121`)
- mDNS names (e.g., `cjc-2015-mgmt-3.local`)

---

## Usage Examples

All examples use the `RSSH` function with hostname resolution. Hostnames are case-insensitive.

### Windows Commands

```powershell
# Check running processes
RSSH cjc-2015-mgmt-3 Get-Process

# Get system info
RSSH cjc-2021-tech-1 systeminfo

# List files
RSSH cjc-2015-mgmt-3 "dir C:\Windows"

# Run PowerShell script
RSSH dt-2020-imac-001 "& 'C:\Scripts\update.ps1'"
```

### macOS/Linux Commands

```powershell
# Check processes
RSSH dt-2020-imac-001 ps aux

# List files
RSSH dt-2020-imac-001 "ls -la /Users/mathew.burkitt"

# Check disk usage
RSSH dt-2020-imac-001 "du -sh ~"

# Get system uptime
RSSH dt-2020-imac-001 uptime
```

### Software Management

```powershell
# Windows - Upgrade all packages
RSSH cjc-2015-mgmt-3 winget upgrade --all --silent

# macOS - Upgrade Homebrew packages
RSSH dt-2020-imac-001 "brew upgrade"

# Check Windows Update status
RSSH cjc-2021-tech-1 "Get-WindowsUpdate"
```

### Network Commands

```powershell
# Ping from remote machine
RSSH cjc-2015-mgmt-3 "ping 8.8.8.8"

# Check network config
RSSH cjc-2021-tech-1 ipconfig

# Traceroute
RSSH dt-2020-imac-001 "traceroute google.com"
```

### System Administration

```powershell
# Restart a machine
RSSH cjc-2015-mgmt-3 "Restart-Computer -Force"

# Install a program
RSSH cjc-2021-tech-1 'winget install "Visual Studio Code"'

# Check disk space
RSSH cjc-2015-mgmt-3 "Get-Volume"

# View event logs
RSSH cjc-2021-tech-1 "Get-EventLog -LogName System -Newest 10"

# By IP address
RSSH 100.91.158.121 "Get-Date"
```

---

## How It Works

### Architecture

```
Your Local PowerShell Session
         ↓
   RSSH Function
         ↓
   Resolve Hostname
     (Tailscale/DNS)
         ↓
   SSH over Tailscale Network
         ↓
Remote Machine (PowerShell/Shell)
         ↓
   Execute command
         ↓
   Return output
         ↓
Your Local Session (displays output)
```

### Hostname Resolution Strategy

1. **Tailscale First**: Looks for hostname in `tailscale status` output (fastest for Tailscale machines)
2. **DNS Fallback**: Uses system DNS resolver for hostnames not in Tailscale
3. **mDNS Suffix**: Tries `.local` suffix for local network machines

This three-pronged approach means RSSH works with:
- Tailscale machine names
- DNS-registered hostnames
- Local mDNS (`.local`) names
- Direct IP addresses

### Security

- ✅ **SSH Key Authentication**: Uses your Ed25519 SSH key, never sends passwords
- ✅ **Encrypted**: All communication encrypted over Tailscale network
- ✅ **Authenticated**: SSH verifies remote server's key
- ✅ **No Agent Required**: Doesn't require special agents on remote machines
- ✅ **Works Cross-Platform**: Windows, macOS, Linux all supported
- ✅ **Dynamic Resolution**: No hardcoded machine names or IPs

---

## Customizing RSSH

The RSSH function is fully dynamic and works with any hostname. No customization needed!

However, if you want to customize the SSH user or key, edit your profile:

```powershell
# Edit your PowerShell profile
notepad $PROFILE
```

Find this line and modify if needed:
```powershell
ssh -i "$SSHKey" ... "mathew.burkitt@$ip" ...
```

Change `mathew.burkitt` to your SSH username if different.

---

## Troubleshooting

### "Could not resolve hostname to an IP address"

```powershell
# Check if machine is in Tailscale network
tailscale status

# Verify hostname spelling (case-insensitive)
RSSH cjc-2015-mgmt-3 "Get-Date"  # Should work

# Try with IP directly if hostname fails
RSSH 100.91.158.121 "Get-Date"
```

### "Permission denied (publickey)"

```powershell
# Verify SSH key exists
ls ~/.ssh/id_ed25519

# Verify SSH key is on remote machine's authorized_keys
RSSH cjc-2015-mgmt-3 "cat ~/.ssh/authorized_keys"

# Copy your public key if missing
type ~/.ssh/id_ed25519.pub | ssh mathew.burkitt@100.91.158.121 "cat >> ~/.ssh/authorized_keys"
```

### "Connection timed out"

```powershell
# Verify machine is actually online
tailscale status

# Check Tailscale connectivity to machine
tailscale ping cjc-2015-mgmt-3

# Verify SSH service is running on remote
RSSH cjc-2015-mgmt-3 "Get-Service sshd | Select-Object Status"  # Windows
RSSH dt-2020-imac-001 "sudo systemctl status ssh"  # Linux/macOS
```

### Command doesn't work on remote

Remember: **The command runs on the REMOTE machine**, not your local machine.

```powershell
# ❌ WRONG - tries to find file locally
RSSH cjc-2015-mgmt-3 "C:\file.txt"

# ✅ RIGHT - file path interpreted on remote
RSSH cjc-2015-mgmt-3 "Get-Item C:\file.txt"
```

### SSH is taking a long time

RSSH has a 5-second timeout by default. For longer operations:

```powershell
# Option 1: Run command in background on remote
RSSH machine "Start-Process powershell -ArgumentList '-Command', 'long-running-command' -NoWait"

# Option 2: Use Windows Task Scheduler or cron on the remote machine
```

---

## Advanced Usage

### Piping Between Local and Remote

```powershell
# Get processes from remote, filter locally
RSSH cjc-2015-mgmt-3 "Get-Process" | Where-Object { $_.CPU -gt 100 }

# Run command on remote, save output locally
RSSH cjc-2015-mgmt-3 "ipconfig" | Out-File ~/remote-ipconfig.txt
```

### Combining Multiple Machines

```powershell
# Check all machines
@("cjc-2015-mgmt-3", "cjc-2021-tech-1", "dt-2020-imac-001") | ForEach-Object {
    Write-Host "Checking $_..."
    RSSH $_ "Get-Process | Measure-Object"
}
```

### Running Scripts Remotely

```powershell
# Download and run script
RSSH cjc-2015-mgmt-3 "powershell -Command (Invoke-WebRequest -Uri https://example.com/script.ps1).Content | Invoke-Expression"

# Or embed script in RSSH call
RSSH cjc-2015-mgmt-3 'Get-Process | Where-Object {$_.CPU -gt 50} | Select-Object Name, CPU'
```

### Creating Reusable Remote Commands

```powershell
# Define a function that uses RSSH
function Update-RemoteMachine {
    param([string]$Machine)
    RSSH $Machine "winget upgrade --all --silent"
    RSSH $Machine "Get-HotFix | Select-Object -First 5"
}

# Use it on any machine
Update-RemoteMachine -Machine cjc-2015-mgmt-3
```

---

## Profile Backup

The setup script automatically backs up your existing profile:
- Located at: `$PROFILE.backup.YYYYMMDD-HHMMSS`
- Can restore if something breaks:
  ```powershell
  Copy-Item $PROFILE.backup.YYYYMMDD-HHMMSS $PROFILE
  ```

---

## Uninstalling

To remove RSSH:

1. **Open your profile:**
   ```powershell
   notepad $PROFILE
   ```

2. **Delete the section starting with:**
   ```
   # ========== Dynamic Remote SSH Function (RSSH) ==========
   ```

3. **Save and reload:**
   ```powershell
   . $PROFILE
   ```

---

## Notes

- **Timeouts**: Default SSH timeout is 5 seconds (ConnectTimeout). For long-running commands, redirect output or run in background.
- **Long-Running Commands**: For background tasks, consider using Windows Task Scheduler or Linux cron instead.
- **Cross-Platform**: macOS and Linux use different commands (e.g., `ls` vs `dir`, `brew` vs `apt`), so craft commands accordingly.
- **Output Encoding**: Some binary output may not display correctly. Redirect to file if needed.
- **Hostname Flexibility**: RSSH works with Tailscale names, DNS names, mDNS names, and IP addresses - whichever resolves first.
- **No Hardcoded Data**: RSSH is purely dynamic with no machine lists to maintain.
# PowerShell Profile Setup: Remote Machine Shortcuts

This guide explains how to set up PowerShell shortcuts for easily executing commands on remote Tailscale machines without typing SSH commands manually.

---

## What You Get

After setup, you can execute remote commands like this:

```powershell
# Simple shortcut (machine-specific)
cjc2015 winget upgrade --all --silent
cjc2021 Get-Process
dt2020imac ls -la

# Or use the generic remote function
remote cjc-2015-mgmt-3 "winget upgrade --all --silent"
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
cjc2015 "Get-Date"

# Should output:
# Executing on cjc-2015-mgmt-3 (100.91.158.121): Get-Date
# ────────────────────────────────────────────────────────────────────────────────
# Tuesday, October 29, 2025 3:45:23 PM
# ────────────────────────────────────────────────────────────────────────────────
```

---

## Available Machine Shortcuts

| Shortcut | Machine | Hostname | IP |
|----------|---------|----------|-----|
| `cjc2015` | CJC-2015-MGMT-3 | cjc-2015-mgmt-3 | 100.91.158.121 |
| `cjc2021` | CJC-2021-TECH-1 | cjc-2021-tech-1 | 100.94.7.13 |
| `cjcjewel` | CJC-JEWEL-VB | cjc-jewel-vb | 100.86.232.24 |
| `dt2020res` | DT-2020-RES-1 | dt-2020-res-1 | 100.102.20.69 |
| `dt2020imac` | DT-2020-iMac-001 | dt-2020-imac-001 | 100.112.141.18 |

---

## Usage Examples

### Windows Commands

```powershell
# Check running processes
cjc2015 Get-Process

# Get system info
cjc2021 systeminfo

# List files
cjc2015 "dir C:\Windows"

# Run PowerShell script
dt2020imac "& 'C:\Scripts\update.ps1'"
```

### macOS/Linux Commands

```powershell
# Check processes
dt2020imac ps aux

# List files
dt2020imac "ls -la /Users/mathew.burkitt"

# Check disk usage
dt2020imac "du -sh ~"

# Get system uptime
dt2020imac uptime
```

### Software Management

```powershell
# Windows - Upgrade all packages
cjc2015 winget upgrade --all --silent

# macOS - Upgrade Homebrew packages
dt2020imac "brew upgrade"

# Check Windows Update status
cjc2021 "Get-WindowsUpdate"
```

### Network Commands

```powershell
# Ping from remote machine
cjc2015 "ping 8.8.8.8"

# Check network config
cjc2021 ipconfig

# Traceroute
dt2020imac "traceroute google.com"
```

### System Administration

```powershell
# Restart a machine
cjc2015 "Restart-Computer -Force"

# Install a program
cjc2021 'winget install "Visual Studio Code"'

# Check disk space
cjc2015 "Get-Volume"

# View event logs
cjc2021 "Get-EventLog -LogName System -Newest 10"
```

---

## How It Works

### Architecture

```
Your Local PowerShell Session
         ↓
   Invoke-RemoteTailscale Function
         ↓
   Parse hostname & command
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

### Security

- ✅ **SSH Key Authentication**: Uses your Ed25519 SSH key, never sends passwords
- ✅ **Encrypted**: All communication encrypted over Tailscale network
- ✅ **Authenticated**: SSH verifies remote server's key
- ✅ **No Agent Required**: Doesn't require special agents on remote machines
- ✅ **Works Cross-Platform**: Windows, macOS, Linux all supported

---

## Customizing Shortcuts

To add more machine shortcuts or change names:

1. **Edit your PowerShell profile:**
   ```powershell
   notepad $PROFILE
   ```

2. **Find this section:**
   ```powershell
   # Create shortcuts for your Tailscale machines
   New-MachineShortcut -Name 'cjc2015' -Hostname 'cjc-2015-mgmt-3'
   ```

3. **Add or modify shortcuts:**
   ```powershell
   New-MachineShortcut -Name 'myalias' -Hostname 'actual-machine-name'
   ```

4. **Save and reload:**
   ```powershell
   . $PROFILE
   ```

---

## Troubleshooting

### "Machine not found in Tailscale network"

```powershell
# Verify machine is online
tailscale status

# Machine must appear in the list
# Check spelling matches exactly
```

### "Permission denied (publickey)"

```powershell
# Verify SSH key exists
ls ~/.ssh/id_ed25519

# Verify SSH key is on remote machine
remote cjc-2015-mgmt-3 "cat ~/.ssh/authorized_keys | grep $(cat ~/.ssh/id_ed25519.pub)"
```

### "Connection timed out"

```powershell
# Verify machine is actually online
tailscale status | grep cjc-2015

# Check Tailscale connectivity
tailscale ping cjc-2015-mgmt-3

# Verify SSH service is running on remote
cjc2015 "Get-Service sshd | Select-Object Status"  # Windows
dt2020imac "sudo systemctl status ssh"  # Linux/macOS
```

### Command doesn't work on remote

Remember: **The command runs on the REMOTE machine**, not your local machine.

```powershell
# ❌ WRONG - tries to find file locally
cjc2015 "C:\file.txt"

# ✅ RIGHT - file path interpreted on remote
cjc2015 "Get-Item C:\file.txt"
```

---

## Advanced Usage

### Piping Between Local and Remote

```powershell
# Get processes from remote, filter locally
cjc2015 Get-Process | Where-Object { $_.CPU -gt 100 }

# Run command on remote, save output locally
cjc2015 "ipconfig" | Out-File ~/remote-ipconfig.txt
```

### Combining Multiple Machines

```powershell
# Check status on all machines
"cjc2015", "cjc2021", "dt2020imac" | ForEach-Object {
    Write-Host "Checking $_..."
    Invoke-Expression "$_ 'Get-Process | Measure-Object'"
}
```

### Running Scripts Remotely

```powershell
# Upload and run script
cjc2015 "Invoke-WebRequest -Uri https://example.com/script.ps1 | Invoke-Expression"

# Or use a local script
cjc2015 "$(cat C:\scripts\update.ps1)"
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

To remove the shortcuts:

1. **Open your profile:**
   ```powershell
   notepad $PROFILE
   ```

2. **Delete the section starting with:**
   ```
   # ========== Tailscale Remote Command Shortcuts ==========
   ```

3. **Save and reload:**
   ```powershell
   . $PROFILE
   ```

---

## Notes

- **Timeouts**: Default SSH timeout is 5 seconds. For longer operations, increase the timeout in the profile.
- **Long-Running Commands**: For background tasks, consider using Windows Task Scheduler or Linux cron instead.
- **Cross-Platform**: macOS and Linux versions use different paths (e.g., `ls` vs `dir`), so craft commands accordingly.
- **Output Encoding**: Some binary output may not display correctly. Redirect to file if needed.
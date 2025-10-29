# Verify-Tailscale Scripts

Comprehensive Tailscale connectivity auditing with two approaches:

## 1. Verify-Tailscale.ps1 (Local Testing)

Tests connectivity from the local machine to all Tailscale machines in the account.

**Usage:**
```powershell
.\Verify-Tailscale.ps1 -TailnetName "catherinejones.com"
```

**What it does:**
- Retrieves all machines in your Tailscale account
- Tests both `tailscale ping` and regular `ping` to each machine
- Displays console report with pass/partial/fail status
- Saves timestamped JSON report: `catherinejones.com-audit.YYYYMMDD-HHMMSS.json`

**Output:**
```
Testing to cjc-2015-mgmt-3 (100.91.158.121)... ✅ PASS
  Tailscale Ping: ✅ YES - pong - Latency: 1ms
  Regular Ping:   ✅ YES - reply received - Latency: 2ms
```

**Limitations:**
- One-directional testing (from this machine to all others)
- Cannot verify connectivity FROM remote machines back to this machine

---

## 2. Verify-Tailscale-AllToAll.ps1 (SSH-Based Testing)

Tests connectivity between all machine pairs using SSH remote execution.

**Prerequisites:**
- SSH must be configured on all target machines
- SSH keys must be deployed
- SSH user credentials configured

**Usage:**
```powershell
.\Verify-Tailscale-AllToAll.ps1 -TailnetName "catherinejones.com" `
  -SSHUser "mathew.burkitt" `
  -SSHKey "$HOME\.ssh\id_ed25519"
```

**What it does:**
- For each machine, SSH into it
- Run ping tests FROM that machine to all others
- Creates all-to-all connectivity matrix
- Saves timestamped JSON report: `catherinejones.com-audit-alltoall.YYYYMMDD-HHMMSS.json`

**Output:**
```
Source: cjc-2015-mgmt-3 (100.91.158.121)
  Testing to dt-2020-res-1 (100.102.20.69)... ✅
  Testing to cjc-2021-tech-1 (100.94.7.13)... ✅
```

---

## How All-to-All Testing Works

**The Challenge:** How does a single script test connectivity between all machine pairs?

**The Solution:** SSH Remote Execution

1. **Enumerate machines**: `tailscale status` gets list of all machines
2. **For each machine**:
   - SSH into that machine
   - Run ping tests FROM that machine to all others
   - Collect results
3. **Aggregate**: Combine all results into all-to-all matrix

**Example Matrix:**
```
       dt-2020-res-1  cjc-2015-mgmt-3  cjc-2021-tech-1
dt-2020-res-1     -        ✅              ✅
cjc-2015-mgmt-3   ✅       -               ✅
cjc-2021-tech-1   ✅       ✅              -
```

---

## JSON Report Format

Both scripts save timestamped JSON reports:

```json
{
  "Tailnet": "catherinejones.com",
  "Timestamp": "2025-10-28T17:45:00.0000000Z",
  "MachineCount": 5,
  "PassCount": 4,
  "PartialCount": 1,
  "FailCount": 0,
  "Results": [
    {
      "Source": "local",
      "Target": "cjc-2015-mgmt-3",
      "TargetIP": "100.91.158.121",
      "TargetStatus": "active",
      "TailscalePing": {
        "Success": true,
        "Latency": 1,
        "Message": "pong"
      },
      "RegularPing": {
        "Success": true,
        "Latency": 2,
        "Message": "reply received"
      },
      "OverallStatus": "PASS",
      "Timestamp": "2025-10-28T17:45:02.0000000Z"
    }
  ]
}
```

---

## Choosing the Right Script

| Scenario | Script | Notes |
|----------|--------|-------|
| Quick local audit | `Verify-Tailscale.ps1` | Fast, doesn't require SSH |
| Full all-to-all audit | `Verify-Tailscale-AllToAll.ps1` | Requires SSH on all machines |
| Specific machine pair | Either | Modify for specific targets |
| Continuous monitoring | Both | Run with task scheduler |

---

## Scheduling Audits

**Windows Task Scheduler:**
```powershell
$trigger = New-ScheduledTaskTrigger -Daily -At 8:00am
$action = New-ScheduledTaskAction -Execute "pwsh" -Argument "C:\path\to\Verify-Tailscale.ps1"
Register-ScheduledTask -TaskName "Tailscale-Audit" -Trigger $trigger -Action $action -RunLevel Highest
```

**Cron (macOS/Linux):**
```bash
0 8 * * * /opt/homebrew/bin/pwsh /path/to/Verify-Tailscale.ps1
```

---

## Troubleshooting

**SSH connection timeout:**
- Verify SSH is running on target machines
- Check firewall rules allow SSH on port 22
- Verify SSH keys are deployed

**Ping returns "no response":**
- Check ESET/firewall ICMP rules
- Verify machine is actually online
- Check Tailscale status on target machine

**JSON file not created:**
- Verify write permissions to current directory
- Check disk space
- Verify script completed without errors
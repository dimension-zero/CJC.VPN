#!/usr/bin/env pwsh
# Setup PowerShell Profile with remote machine shortcuts
# Adds convenient commands for executing commands on Tailscale machines

param(
    [Parameter(Mandatory=$false)]
    [string]$SSHUser = "mathew.burkitt",
    [Parameter(Mandatory=$false)]
    [string]$SSHKey = "$HOME\.ssh\id_ed25519"
)

function Write-Log {
    param([string]$Message, [ValidateSet("INFO", "WARN", "SUCCESS")]$Level = "INFO")
    $colors = @{ INFO = "White"; WARN = "Yellow"; SUCCESS = "Green" }
    Write-Host "[$Level] $Message" -ForegroundColor $colors[$Level]
}

# Get PowerShell profile path
$profilePath = $PROFILE
$profileDir = Split-Path $profilePath

# Ensure profile directory exists
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Create profile content
$profileContent = @"
# ========== Tailscale Remote Command Shortcuts ==========
# Added by Setup-PowerShellProfile.ps1

# Core function for executing remote commands via SSH
function Invoke-RemoteTailscale {
    param(
        [Parameter(Mandatory=`$true, Position=0)]
        [string]`$ComputerName,

        [Parameter(Mandatory=`$true, Position=1, ValueFromRemainingArguments=`$true)]
        [string[]]`$Command
    )

    # Join command parts
    `$cmdString = `$Command -join ' '

    # Get IP address from tailscale status
    `$machineInfo = tailscale status | Where-Object { `$_ -like "*`$ComputerName*" }
    if (-not `$machineInfo) {
        Write-Error "Machine '\$ComputerName' not found in Tailscale network"
        return
    }

    `$ip = (`$machineInfo -split '\s+')[0]

    Write-Host "Executing on \$ComputerName (\$ip): \$cmdString" -ForegroundColor Cyan
    Write-Host "─" * 80

    # Execute via SSH
    ssh -i "$SSHKey" -o ConnectTimeout=5 "mathew.burkitt@`$ip" powershell -Command "`$cmdString"

    Write-Host "─" * 80
}

# Alias for easier invocation
Set-Alias -Name 'remote' -Value 'Invoke-RemoteTailscale' -Force

# ========== Machine-Specific Shortcuts ==========
# These make it easier to run commands on specific machines

# Function to create machine shortcut
function New-MachineShortcut {
    param([string]`$Name, [string]`$Hostname)

    `$function = @"
        param([Parameter(ValueFromRemainingArguments=``$true)][string[]]`$Cmd)
        Invoke-RemoteTailscale '$Hostname' `@Cmd
    `"@

    Set-Item -Path "Function:global:\$Name" -Value ([ScriptBlock]::Create(`$function)) -Force
}

# Create shortcuts for your Tailscale machines
# Syntax: New-MachineShortcut -Name "shortcut" -Hostname "full-hostname"

New-MachineShortcut -Name 'cjc2015' -Hostname 'cjc-2015-mgmt-3'
New-MachineShortcut -Name 'cjc2021' -Hostname 'cjc-2021-tech-1'
New-MachineShortcut -Name 'cjcjewel' -Hostname 'cjc-jewel-vb'
New-MachineShortcut -Name 'dt2020res' -Hostname 'dt-2020-res-1'
New-MachineShortcut -Name 'dt2020imac' -Hostname 'dt-2020-imac-001'

# ========== Usage Examples ==========
#
# Using the generic remote function:
#   remote cjc-2015-mgmt-3 "winget upgrade --all --silent"
#   remote cjc-2021-tech-1 Get-Process
#   remote dt-2020-imac-001 "ls -la"
#
# Using machine-specific shortcuts:
#   cjc2015 winget upgrade --all --silent
#   cjc2021 Get-Process
#   dt2020imac ls -la
#
# ==========================================

Write-Host "Tailscale remote shortcuts loaded!" -ForegroundColor Green
Write-Host "Usage: cjc2015 <command>  OR  remote cjc-2015-mgmt-3 <command>" -ForegroundColor Cyan
"@

# Backup existing profile if it exists
if (Test-Path $profilePath) {
    $backupPath = "$profilePath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $profilePath $backupPath
    Write-Log "Backed up existing profile to: $backupPath" "WARN"
}

# Check if shortcuts already exist in profile
if ((Test-Path $profilePath) -and (Get-Content $profilePath | Select-String "Tailscale Remote Command Shortcuts")) {
    Write-Log "Remote shortcuts already exist in profile. Skipping addition." "WARN"
    exit 0
}

# Append to profile
Add-Content -Path $profilePath -Value "`n$profileContent"

Write-Log "PowerShell profile updated successfully!" "SUCCESS"
Write-Log "Profile location: $profilePath" "INFO"
Write-Log ""
Write-Log "Usage Examples:" "INFO"
Write-Log "  cjc2015 winget upgrade --all --silent" "INFO"
Write-Log "  remote cjc-2015-mgmt-3 'Get-Process'" "INFO"
Write-Log ""
Write-Log "Reload your PowerShell session to activate the shortcuts." "INFO"
Write-Log "Or run: . `$PROFILE" "INFO"
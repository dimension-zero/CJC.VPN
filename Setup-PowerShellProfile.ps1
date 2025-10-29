#!/usr/bin/env pwsh
# Setup PowerShell Profile with dynamic RSSH function
# Adds convenient remote SSH execution via Tailscale

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
# ========== Dynamic Remote SSH Function (RSSH) ==========
# Added by Setup-PowerShellProfile.ps1
# Usage: RSSH hostname command
# Resolves hostname to IP via DNS or Tailscale, then executes via SSH

function RSSH {
    param(
        [Parameter(Mandatory=`$true, Position=0, HelpMessage="Hostname or machine name")]
        [string]`$Hostname,

        [Parameter(Mandatory=`$true, Position=1, ValueFromRemainingArguments=`$true, HelpMessage="Command to execute")]
        [string[]]`$Command
    )

    # Join command parts
    `$cmdString = `$Command -join ' '

    # Try to resolve IP address
    `$ip = `$null

    # Method 1: Try Tailscale status first (for Tailscale machines)
    `$tailscaleStatus = @(tailscale status 2>``$null)
    if (`$tailscaleStatus) {
        `$machineInfo = `$tailscaleStatus | Where-Object { `$_ -like "*`$Hostname*" }
        if (`$machineInfo) {
            `$ip = (`$machineInfo -split '\s+')[0]
        }
    }

    # Method 2: If not found in Tailscale, try DNS resolution
    if (-not `$ip) {
        try {
            `$dnsResult = [System.Net.Dns]::GetHostAddresses(`$Hostname) 2>``$null
            if (`$dnsResult) {
                `$ip = `$dnsResult[0].IPAddressToString
            }
        }
        catch {
            # DNS resolution failed, try adding domain
        }
    }

    # Method 3: Try with local domain suffix
    if (-not `$ip) {
        try {
            `$fqdn = "`$Hostname.local"
            `$dnsResult = [System.Net.Dns]::GetHostAddresses(`$fqdn) 2>``$null
            if (`$dnsResult) {
                `$ip = `$dnsResult[0].IPAddressToString
                `$Hostname = `$fqdn
            }
        }
        catch {
            # Still failed
        }
    }

    # If still no IP, error out
    if (-not `$ip) {
        Write-Error "Could not resolve '\$Hostname' to an IP address. Check hostname or Tailscale status."
        return
    }

    Write-Host "Executing on \$Hostname (\$ip): \$cmdString" -ForegroundColor Cyan
    Write-Host "─" * 80

    # Execute via SSH
    ssh -i "$SSHKey" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "mathew.burkitt@`$ip" powershell -Command "`$cmdString"

    Write-Host "─" * 80
}

# ========== Usage Examples ==========
#
# RSSH cjc-2015-mgmt-3 "winget upgrade --all --silent"
# RSSH cjc-2021-tech-1 Get-Process
# RSSH dt-2020-imac-001 "ls -la"
# RSSH 100.91.158.121 "Get-Date"
#
# ==========================================

Write-Host "Remote SSH function (RSSH) loaded!" -ForegroundColor Green
Write-Host "Usage: RSSH <hostname> <command>" -ForegroundColor Cyan
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
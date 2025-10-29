#!/usr/bin/env pwsh
# Repair and Troubleshoot Tailscale Connectivity
# Consolidated repair script for diagnosing and fixing common Tailscale issues

param(
    [Parameter(Mandatory=$false)]
    [switch]$Auto = $false,

    [Parameter(Mandatory=$false)]
    [switch]$Verbose = $false
)

function Write-Log {
    param([string]$Message, [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "TEST")]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $colors = @{ INFO = "White"; WARN = "Yellow"; ERROR = "Red"; SUCCESS = "Green"; TEST = "Cyan" }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colors[$Level]
}

function Get-TailscaleStatus {
    try {
        $status = tailscale status 2>&1
        return $status
    }
    catch {
        return $null
    }
}

function Test-TailscaleConnectivity {
    Write-Log "Testing Tailscale connectivity..." "TEST"

    $status = Get-TailscaleStatus
    if (-not $status) {
        Write-Log "Tailscale status command failed" "ERROR"
        return $false
    }

    if ($status -like "*Logged out*" -or $status -like "*Offline*") {
        Write-Log "Tailscale not authenticated or disconnected" "WARN"
        return $false
    }

    Write-Log "Tailscale status OK" "SUCCESS"
    return $true
}

function Repair-TailscaleAuthentication {
    Write-Log "Attempting Tailscale re-authentication..." "INFO"

    try {
        tailscale up
        Write-Log "Re-authentication successful" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Re-authentication failed: $_" "ERROR"
        return $false
    }
}

function Repair-WindowsFirewall {
    Write-Log "Configuring Windows Firewall for Tailscale..." "INFO"

    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Skipping firewall fix - requires administrator privileges" "WARN"
        return $false
    }

    try {
        # Add ICMP rule for Tailscale network
        netsh advfirewall firewall add rule name="ICMP Allow Tailscale" protocol=icmpv4:8,any dir=in action=allow remoteip=100.64.0.0/10 2>&1 | Out-Null

        # Add general connectivity rule
        netsh advfirewall firewall add rule name="Tailscale Network Allow" dir=in action=allow remoteip=100.64.0.0/10 2>&1 | Out-Null

        Write-Log "Windows Firewall configured for Tailscale" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Windows Firewall configuration failed: $_" "ERROR"
        return $false
    }
}

function Test-ICMP-Blocking {
    Write-Log "Checking for ICMP blocking..." "TEST"

    try {
        # Try to ping Tailscale network
        $machineIP = (tailscale status | Select-Object -First 1) -match '100\.' | % { ($_ -split '\s+')[0] }

        if ($machineIP) {
            $ping = ping $machineIP -n 1 -w 1000
            if ($ping -like "*Received = 1*") {
                Write-Log "ICMP working correctly" "SUCCESS"
                return $true
            }
            else {
                Write-Log "ICMP appears to be blocked" "WARN"
                return $false
            }
        }
    }
    catch {
        Write-Log "ICMP test inconclusive: $_" "WARN"
    }

    return $null
}

function Suggest-ESET-Fix {
    Write-Log "ESET Endpoint Security detected - manual configuration needed" "WARN"
    Write-Log ""
    Write-Log "To fix ESET blocking Tailscale:" "INFO"
    Write-Log "1. Open ESET Endpoint Security" "INFO"
    Write-Log "2. Go to Advanced Setup → Firewall → Rules" "INFO"
    Write-Log "3. Create new rule:" "INFO"
    Write-Log "   - Name: Allow Tailscale 100.64.0.0/10 ICMP" "INFO"
    Write-Log "   - Action: Allow" "INFO"
    Write-Log "   - Protocol: ICMP" "INFO"
    Write-Log "   - Remote host: 100.64.0.0/10" "INFO"
    Write-Log "4. Make sure this rule is ABOVE the 'Block ICMP communication' rule" "INFO"
    Write-Log ""
}

function Test-SSH-Service {
    Write-Log "Checking SSH service..." "TEST"

    try {
        if ($PSVersionTable.Platform -eq "Unix") {
            # macOS/Linux
            $result = sudo systemctl status ssh 2>&1
            if ($result -like "*active*") {
                Write-Log "SSH service is running" "SUCCESS"
                return $true
            }
        }
        else {
            # Windows
            $sshService = Get-Service sshd -ErrorAction SilentlyContinue
            if ($sshService.Status -eq "Running") {
                Write-Log "SSH service is running" "SUCCESS"
                return $true
            }
            else {
                Write-Log "SSH service is not running" "WARN"
                return $false
            }
        }
    }
    catch {
        Write-Log "SSH service check inconclusive: $_" "WARN"
        return $null
    }
}

function Test-RSHConnectivity {
    Write-Log "Testing RSSH functionality..." "TEST"

    try {
        if (-not (Get-Command RSSH -ErrorAction SilentlyContinue)) {
            Write-Log "RSSH function not loaded" "WARN"
            Write-Log "Run: . `$PROFILE" "INFO"
            return $false
        }

        Write-Log "RSSH function available" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "RSSH test failed: $_" "ERROR"
        return $false
    }
}

function Test-Connectivity-To-Machine {
    param([string]$IP, [string]$Hostname)

    Write-Log "Testing connectivity to $Hostname ($IP)..." "TEST"

    try {
        $ping = ping $IP -n 1 -w 1000
        if ($ping -like "*Received = 1*") {
            Write-Log "Ping successful" "SUCCESS"
            return $true
        }
        else {
            Write-Log "Ping failed - no response" "WARN"
            return $false
        }
    }
    catch {
        Write-Log "Ping test error: $_" "ERROR"
        return $false
    }
}

# ==================== Main Execution ====================

Write-Host ""
Write-Log "Starting Tailscale Diagnostic and Repair" "INFO"
Write-Host ""

# Get initial status
Write-Log "Phase 1: Diagnostics" "INFO"
Write-Host "─" * 80
Write-Host ""

$tailscaleOK = Test-TailscaleConnectivity
$icmpOK = Test-ICMP-Blocking
$sshOK = Test-SSH-Service
$rsshOK = Test-RSHConnectivity

Write-Host ""
Write-Log "Diagnostic Results:" "INFO"
Write-Log "  Tailscale: $(if ($tailscaleOK) { 'OK' } else { 'FAILED' })" "INFO"
Write-Log "  ICMP:      $(if ($icmpOK -eq $null) { 'UNKNOWN' } elseif ($icmpOK) { 'OK' } else { 'BLOCKED' })" "INFO"
Write-Log "  SSH:       $(if ($sshOK -eq $null) { 'UNKNOWN' } elseif ($sshOK) { 'OK' } else { 'STOPPED' })" "INFO"
Write-Log "  RSSH:      $(if ($rsshOK) { 'OK' } else { 'NOT AVAILABLE' })" "INFO"

# Attempt repairs if -Auto flag or if issues detected
if ($Auto -or -not $tailscaleOK -or ($icmpOK -eq $false) -or ($sshOK -eq $false)) {
    Write-Host ""
    Write-Log "Phase 2: Automatic Repairs" "INFO"
    Write-Host "─" * 80
    Write-Host ""

    if (-not $tailscaleOK) {
        Repair-TailscaleAuthentication | Out-Null
    }

    if ($PSVersionTable.Platform -ne "Unix") {
        Repair-WindowsFirewall | Out-Null
    }

    if ($icmpOK -eq $false -and $PSVersionTable.Platform -eq "Unix") {
        Suggest-ESET-Fix
    }

    # Re-test after repairs
    Write-Host ""
    Write-Log "Re-testing after repairs..." "INFO"
    $tailscaleOK = Test-TailscaleConnectivity
    $icmpOK = Test-ICMP-Blocking
}

# Final status
Write-Host ""
Write-Log "Phase 3: Final Status" "INFO"
Write-Host "─" * 80
Write-Host ""

$status = Get-TailscaleStatus
if ($status) {
    Write-Host "Tailscale Status:" -ForegroundColor Cyan
    $status | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" }
}

Write-Host ""
if ($tailscaleOK -and ($icmpOK -ne $false)) {
    Write-Log "Tailscale connectivity appears healthy" "SUCCESS"
}
else {
    Write-Log "Tailscale issues detected - review output above" "WARN"
    Write-Log "For ESET firewall issues, see manual fix above" "INFO"
}

Write-Host ""
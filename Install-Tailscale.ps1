#!/usr/bin/env pwsh
# Install and Configure Tailscale with SSH Support
# Consolidated installation script for Windows, macOS, and Linux

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Windows", "macOS", "Linux")]
    [string]$Platform = $null,

    [Parameter(Mandatory=$false)]
    [string]$SSHUser = "mathew.burkitt",

    [Parameter(Mandatory=$false)]
    [switch]$SkipSSH = $false,

    [Parameter(Mandatory=$false)]
    [switch]$SkipProfile = $false
)

function Write-Log {
    param([string]$Message, [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colors = @{ INFO = "White"; WARN = "Yellow"; ERROR = "Red"; SUCCESS = "Green" }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colors[$Level]
}

function Detect-Platform {
    if ($PSVersionTable.Platform -eq "Unix") {
        if ($IsMacOS) { return "macOS" }
        elseif ($IsLinux) { return "Linux" }
    }
    else {
        return "Windows"
    }
}

function Install-SSH-Windows {
    Write-Log "Installing SSH on Windows..." "INFO"

    # Check if running as admin
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Skipping SSH install - requires administrator privileges" "WARN"
        return $false
    }

    try {
        # Install OpenSSH Server feature
        $sshFeature = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
        if ($sshFeature.State -ne 'Installed') {
            Write-Log "Adding OpenSSH Server feature..." "INFO"
            Add-WindowsCapability -Online -Name $sshFeature.Name | Out-Null
        }

        # Start and configure SSH service
        Write-Log "Configuring SSH service..." "INFO"
        Start-Service sshd -ErrorAction SilentlyContinue
        Set-Service -Name sshd -StartupType Automatic

        # Configure Windows Firewall
        Write-Log "Configuring Windows Firewall..." "INFO"
        New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue | Out-Null

        # Create .ssh directory if needed
        $sshDir = "$env:USERPROFILE\.ssh"
        if (-not (Test-Path $sshDir)) {
            New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        }

        Write-Log "SSH installation complete" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "SSH installation failed: $_" "ERROR"
        return $false
    }
}

function Install-SSH-macOS {
    Write-Log "Enabling SSH on macOS..." "INFO"

    try {
        # Enable Remote Login (SSH)
        sudo systemsetup -setremotelogin on 2>&1 | Out-Null

        # Create .ssh directory if needed
        mkdir -p ~/.ssh 2>&1 | Out-Null
        chmod 700 ~/.ssh 2>&1 | Out-Null

        Write-Log "SSH configuration complete" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "SSH configuration failed: $_" "ERROR"
        return $false
    }
}

function Install-SSH-Linux {
    Write-Log "Installing SSH on Linux..." "INFO"

    try {
        # This would depend on the distro
        Write-Log "Please install openssh-server using your package manager" "WARN"
        Write-Log "Ubuntu/Debian: sudo apt-get install openssh-server" "INFO"
        Write-Log "RHEL/CentOS: sudo yum install openssh-server" "INFO"
        return $true
    }
    catch {
        Write-Log "SSH installation failed: $_" "ERROR"
        return $false
    }
}

function Install-RSSH-Profile {
    Write-Log "Installing RSSH function to PowerShell profile..." "INFO"

    try {
        $profilePath = $PROFILE
        $profileDir = Split-Path $profilePath

        # Ensure profile directory exists
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }

        # Check if RSSH already exists
        if ((Test-Path $profilePath) -and (Get-Content $profilePath | Select-String "function RSSH")) {
            Write-Log "RSSH already installed in profile" "WARN"
            return $true
        }

        # Backup existing profile
        if (Test-Path $profilePath) {
            $backupPath = "$profilePath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $profilePath $backupPath
            Write-Log "Backed up existing profile to: $backupPath" "INFO"
        }

        # Create RSSH function content
        $rsshFunction = @'
# ========== Dynamic Remote SSH Function (RSSH) ==========
# Remote SSH helper for executing commands on Tailscale machines

function RSSH {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Hostname,

        [Parameter(Mandatory=$true, Position=1, ValueFromRemainingArguments=$true)]
        [string[]]$Command
    )

    $cmdString = $Command -join ' '
    $ip = $null

    # Try Tailscale status first
    $tailscaleStatus = @(tailscale status 2>$null)
    if ($tailscaleStatus) {
        $machineInfo = $tailscaleStatus | Where-Object { $_ -like "*$Hostname*" }
        if ($machineInfo) {
            $ip = ($machineInfo -split '\s+')[0]
        }
    }

    # Try DNS resolution
    if (-not $ip) {
        try {
            $dnsResult = [System.Net.Dns]::GetHostAddresses($Hostname) 2>$null
            if ($dnsResult) {
                $ip = $dnsResult[0].IPAddressToString
            }
        }
        catch { }
    }

    # Try mDNS suffix
    if (-not $ip) {
        try {
            $fqdn = "$Hostname.local"
            $dnsResult = [System.Net.Dns]::GetHostAddresses($fqdn) 2>$null
            if ($dnsResult) {
                $ip = $dnsResult[0].IPAddressToString
            }
        }
        catch { }
    }

    if (-not $ip) {
        Write-Error "Could not resolve '$Hostname' to an IP address"
        return
    }

    Write-Host "Executing on $Hostname ($ip): $cmdString" -ForegroundColor Cyan
    Write-Host "─" * 80

    $sshKey = "$HOME\.ssh\id_ed25519"
    ssh -i $sshKey -o ConnectTimeout=5 -o StrictHostKeyChecking=no "mathew.burkitt@$ip" powershell -Command "$cmdString"

    Write-Host "─" * 80
}

Write-Host "RSSH function loaded" -ForegroundColor Green
'@

        # Write RSSH to profile
        Add-Content -Path $profilePath -Value "`n$rsshFunction"

        Write-Log "RSSH function installed to profile" "SUCCESS"
        Write-Log "Profile location: $profilePath" "INFO"
        Write-Log "Reload PowerShell to activate: . `$PROFILE" "INFO"
        return $true
    }
    catch {
        Write-Log "RSSH installation failed: $_" "ERROR"
        return $false
    }
}

# ==================== Main Execution ====================

Write-Host ""
Write-Log "Starting Tailscale and SSH Installation" "INFO"
Write-Host ""

# Detect platform if not specified
if (-not $Platform) {
    $Platform = Detect-Platform
    Write-Log "Detected platform: $Platform" "INFO"
}

# Install SSH if not skipped
if (-not $SkipSSH) {
    Write-Host ""
    Write-Log "SSH Installation" "INFO"
    Write-Host "─" * 80

    $sshSuccess = switch ($Platform) {
        "Windows" { Install-SSH-Windows }
        "macOS" { Install-SSH-macOS }
        "Linux" { Install-SSH-Linux }
        default { Write-Log "Unknown platform: $Platform" "ERROR"; $false }
    }

    if ($sshSuccess) {
        Write-Log "SSH installation successful" "SUCCESS"
    }
    else {
        Write-Log "SSH installation skipped or failed" "WARN"
    }
}

# Install RSSH to profile if not skipped
if (-not $SkipProfile) {
    Write-Host ""
    Write-Log "PowerShell Profile Setup" "INFO"
    Write-Host "─" * 80

    $profileSuccess = Install-RSSH-Profile
    if ($profileSuccess) {
        Write-Log "Profile setup successful" "SUCCESS"
    }
    else {
        Write-Log "Profile setup failed" "WARN"
    }
}

Write-Host ""
Write-Log "Installation complete" "SUCCESS"
Write-Host ""
Write-Log "Next steps:" "INFO"
Write-Log "1. Generate SSH key: ssh-keygen -t ed25519" "INFO"
Write-Log "2. Reload PowerShell: . `$PROFILE" "INFO"
Write-Log "3. Test RSSH: RSSH <hostname> 'Get-Date'" "INFO"
Write-Host ""
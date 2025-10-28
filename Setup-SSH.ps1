#!/usr/bin/env pwsh
# Unified SSH Setup Script for Windows and macOS

param(
    [Parameter(Mandatory=$false)]
    [string]$Email = "technology@catherinejones.com"
)

# Function to log messages
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

# Detect operating system
$OSPlatform = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription

# SSH Key Generation Function
function Generate-SSHKey {
    $sshDir = if ($IsWindows) {
        Join-Path $env:USERPROFILE ".ssh"
    } else {
        Join-Path $HOME ".ssh"
    }

    # Ensure .ssh directory exists
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir | Out-Null
    }

    $keyPath = Join-Path $sshDir "id_ed25519"

    # Generate SSH key with specified email
    Write-Log "Generating SSH key for $Email"
    ssh-keygen -t ed25519 -f $keyPath -N '' -C $Email

    # Return the public key path
    return "$keyPath.pub"
}

# SSH Server Configuration Function
function Configure-SSHServer {
    if ($IsWindows) {
        # Windows-specific SSH server configuration
        Write-Log "Configuring Windows SSH Server..."

        # Enable OpenSSH Server feature
        $sshFeature = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
        if ($sshFeature.State -ne 'Installed') {
            Add-WindowsCapability -Online -Name $sshFeature.Name
        }

        # Start and configure SSH service
        Start-Service sshd
        Set-Service -Name sshd -StartupType Automatic

        # Configure Windows Firewall
        New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    }
    elseif ($IsMacOS) {
        # macOS-specific SSH server configuration
        Write-Log "Configuring macOS SSH Server..."

        # Enable Remote Login (SSH)
        sudo systemsetup -setremotelogin on

        # Secure SSH configuration
        sudo sed -i '' 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        sudo sed -i '' 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        sudo sed -i '' 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

        # Restart SSH service
        sudo launchctl stop com.openssh.sshd
        sudo launchctl start com.openssh.sshd
    }
}

# Main Execution
try {
    Write-Log "Detected OS: $OSPlatform"

    # Generate SSH Key
    $pubKeyPath = Generate-SSHKey

    # Configure SSH Server
    Configure-SSHServer

    # Display public key for manual distribution
    Write-Log "SSH Public Key Contents:"
    Get-Content $pubKeyPath

    Write-Log "SSH setup complete. Please manually add the public key to authorized_keys on target machines."
}
catch {
    Write-Error "An error occurred during SSH setup: $_"
    exit 1
}
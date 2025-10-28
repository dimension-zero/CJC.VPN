#!/usr/bin/env pwsh
# macOS SSH Server Installation and Configuration Script

# Function to log messages
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

try {
    # Check for Homebrew (package manager)
    Write-Log "Checking for Homebrew..."
    $homebrewPath = $(which brew)
    if (-not $homebrewPath) {
        Write-Log "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    }

    # Update Homebrew
    Write-Log "Updating Homebrew..."
    brew update

    # Enable Remote Login (SSH)
    Write-Log "Enabling Remote Login (SSH)..."
    sudo systemsetup -setremotelogin on

    # Configure SSH security
    Write-Log "Configuring SSH security..."
    sudo sed -i '' 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i '' 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i '' 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

    # Ensure .ssh directory exists with correct permissions
    Write-Log "Setting up SSH directory..."
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    touch ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys

    # Restart SSH service
    Write-Log "Restarting SSH service..."
    sudo launchctl stop com.openssh.sshd
    sudo launchctl start com.openssh.sshd

    # Configure firewall to allow SSH
    Write-Log "Configuring macOS firewall..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/sshd
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /usr/sbin/sshd

    Write-Log "SSH server installation and configuration complete."
    Write-Log "Next steps:"
    Write-Log "1. Generate an SSH key on the machine you'll connect from"
    Write-Log "2. Copy the public key to ~/.ssh/authorized_keys on this machine"
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
#!/usr/bin/env pwsh
# Windows SSH Server Installation and Configuration Script

# Require administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as an Administrator"
    exit 1
}

# Function to log messages
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

try {
    # Enable OpenSSH Server feature
    Write-Log "Checking and installing OpenSSH Server feature..."
    $sshFeature = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

    if ($sshFeature.State -ne 'Installed') {
        Write-Log "Installing OpenSSH Server feature..."
        Add-WindowsCapability -Online -Name $sshFeature.Name
    }

    # Start and configure SSH service
    Write-Log "Configuring SSH service..."
    Start-Service sshd
    Set-Service -Name sshd -StartupType Automatic

    # Configure Windows Firewall
    Write-Log "Configuring Windows Firewall..."
    New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22

    # Configure SSH server security
    Write-Log "Configuring SSH server security..."
    # Enable key-based authentication
    $sshConfigPath = "$env:ProgramData\ssh\sshd_config"
    $sshConfig = Get-Content $sshConfigPath

    # Modify SSH config to improve security
    $updatedConfig = $sshConfig | ForEach-Object {
        switch ($_) {
            { $_ -like "PasswordAuthentication *" } { "PasswordAuthentication no" }
            { $_ -like "PubkeyAuthentication *" } { "PubkeyAuthentication yes" }
            default { $_ }
        }
    }

    # Backup and update SSH config
    Copy-Item $sshConfigPath "$sshConfigPath.bak"
    $updatedConfig | Set-Content $sshConfigPath

    # Generate SSH host keys if not exist
    if (-not (Test-Path "$env:ProgramData\ssh\ssh_host_rsa_key")) {
        Write-Log "Generating SSH host keys..."
        Start-Process "ssh-keygen.exe" -ArgumentList "-A" -Wait
    }

    # Restart SSH service to apply changes
    Write-Log "Restarting SSH service..."
    Restart-Service sshd

    # Create an authorized_keys file for key-based authentication
    $authorizedKeysPath = "$env:UserProfile\.ssh\authorized_keys"
    if (-not (Test-Path (Split-Path $authorizedKeysPath))) {
        New-Item -ItemType Directory -Path (Split-Path $authorizedKeysPath) -Force
    }
    New-Item -ItemType File -Path $authorizedKeysPath -Force

    Write-Log "SSH server installation and configuration complete."
    Write-Log "Next steps:"
    Write-Log "1. Generate an SSH key on the machine you'll connect from"
    Write-Log "2. Copy the public key to $authorizedKeysPath on this machine"
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
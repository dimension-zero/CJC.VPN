#!/usr/bin/env pwsh
# Fix Windows Firewall for Tailscale Connectivity

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
    Write-Log "Configuring Windows Firewall for Tailscale connectivity..."

    # Add ICMP rule for Tailscale network
    Write-Log "Adding ICMP rule for Tailscale network (100.64.0.0/10)..."
    netsh advfirewall firewall add rule name="ICMP Allow Tailscale" protocol=icmpv4:8,any dir=in action=allow remoteip=100.64.0.0/10

    # Add general connectivity rule for Tailscale
    Write-Log "Adding general connectivity rule for Tailscale..."
    netsh advfirewall firewall add rule name="Tailscale Network Allow" dir=in action=allow remoteip=100.64.0.0/10

    # Enable file and printer sharing for Tailscale network
    Write-Log "Enabling file and printer sharing for Tailscale network..."
    netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes profile=any

    # Test connectivity
    Write-Log "Testing Tailscale connectivity..."
    $status = tailscale status
    Write-Host $status

    Write-Log "Firewall configuration complete."
    Write-Log "Please run this script on the target machine as well."
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
#!/usr/bin/env pwsh
# Cross-platform Tailscale Connection Refresh Script

# Determine the current operating system
$OSPlatform = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription

# Function to log messages
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

# Function to check Tailscale installation
function Test-TailscaleInstalled {
    $tailscaleCommands = @('tailscale', '/usr/local/bin/tailscale', 'C:\Program Files\Tailscale\tailscale.exe')

    foreach ($cmd in $tailscaleCommands) {
        try {
            $result = Get-Command $cmd -ErrorAction Stop
            return $cmd
        }
        catch {
            continue
        }
    }

    return $null
}

# Main script execution
try {
    # Find Tailscale executable
    $tailscaleCmd = Test-TailscaleInstalled
    if (-not $tailscaleCmd) {
        Write-Log "Error: Tailscale is not installed on this system."
        exit 1
    }

    # Log system details
    Write-Log "Operating System: $OSPlatform"
    Write-Log "Tailscale Command: $tailscaleCmd"

    # Check current Tailscale status
    Write-Log "Checking current Tailscale status..."
    $statusOutput = & $tailscaleCmd status
    Write-Log "Current Status: $statusOutput"

    # Attempt to reconnect
    Write-Log "Attempting to reconnect Tailscale..."
    $upOutput = & $tailscaleCmd up

    # Verify new status
    $newStatus = & $tailscaleCmd status
    Write-Log "New Status: $newStatus"

    # Check for any connection issues
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Warning: Tailscale connection may have issues. Please check authentication."
        Write-Log "Authentication URL: https://login.tailscale.com/a/$(& $tailscaleCmd netcheck | Select-String -Pattern 'a/(\w+)' | % { $_.Matches.Groups[1].Value })"
        exit 1
    }

    Write-Log "Tailscale connection refreshed successfully."
}
catch {
    Write-Log "Error: $_"
    exit 1
}
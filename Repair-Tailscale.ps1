#!/usr/bin/env pwsh
# Comprehensive Tailscale Repair and Synchronization Script

param(
    [Parameter(Mandatory=$false)]
    [string]$Hostname,
    [Parameter(Mandatory=$false)]
    [switch]$ForceLogin = $false
)

# Logging function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

# Tailscale Repair Function
function Repair-TailscaleConnection {
    try {
        # Verify Tailscale installation
        $tailscaleCmd = Get-Command tailscale -ErrorAction Stop

        # Check current status
        Write-Log "Checking Tailscale status..."
        $status = & $tailscaleCmd status

        # Force login if requested or device is logged out
        if ($ForceLogin -or ($status -like "*Logged out*")) {
            Write-Log "Initiating Tailscale login process..."
            $loginOutput = & $tailscaleCmd login

            Write-Log "Login URL: $loginOutput"
            Write-Log "Please complete login in a web browser."

            # Provide guidance for manual login
            if ($Hostname) {
                Write-Log "On machine $Hostname, open the provided URL to complete authentication."
            }

            return
        }

        # Bring Tailscale up if not connected
        if ($status -like "*Stopped*" -or $status -like "*Disconnected*") {
            Write-Log "Attempting to bring Tailscale up..."
            & $tailscaleCmd up
        }

        # Run network check
        Write-Log "Running Tailscale network check..."
        $netcheck = & $tailscaleCmd netcheck

        # Display final status
        $finalStatus = & $tailscaleCmd status
        Write-Log "Final Tailscale Status:"
        Write-Host $finalStatus

        # List current devices
        Write-Log "Current Tailscale Devices:"
        & $tailscaleCmd list

        Write-Log "Tailscale repair process complete."
    }
    catch {
        Write-Error "Error during Tailscale repair: $_"
        exit 1
    }
}

# Execute the repair function
Repair-TailscaleConnection
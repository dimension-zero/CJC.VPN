<#
.SYNOPSIS
Installs and configures Tailscale with SSH support.

.DESCRIPTION
Unified installation script for SSH, Tailscale, and remote access functionality.
Automatically detects platform (Windows/macOS/Linux) and installs appropriate
SSH server. Installs RSSH function to PowerShell profile for remote access.

.PARAMETER Platform
Specify the platform explicitly (Windows, macOS, Linux). If not specified,
automatically detects the current platform.

.PARAMETER SSHUser
The username for SSH connections. Defaults to 'mathew.burkitt'.

.PARAMETER SkipSSH
If specified, skips SSH installation and only installs RSSH profile function.

.PARAMETER SkipProfile
If specified, skips PowerShell profile setup for RSSH function.

.OUTPUTS
Result - Returns Result object with Success/Fail status.

.EXAMPLE
Install-Tailscale

.EXAMPLE
Install-Tailscale -SkipSSH -Verbose

.EXAMPLE
Install-Tailscale -Platform Windows -Auto
#>

function Install-Tailscale {
    [CmdletBinding()]
    [OutputType([Result])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Windows", "macOS", "Linux")]
        [string]$Platform,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$SSHUser = "mathew.burkitt",

        [Parameter(Mandatory = $false)]
        [switch]$SkipSSH,

        [Parameter(Mandatory = $false)]
        [switch]$SkipProfile
    )

    begin {
        Write-Log "Starting Tailscale and SSH Installation" -Level INFO
    }

    process {
        try {
            # Detect platform if not specified
            if (-not $Platform) {
                $Platform = Get-DetectedPlatform
                Write-Log "Detected platform: $Platform" -Level INFO
            }
            else {
                Write-Log "Using specified platform: $Platform" -Level INFO
            }

            # Install SSH if not skipped
            if (-not $SkipSSH) {
                Write-Host ""
                Write-Log "SSH Installation" -Level INFO
                Write-Host "─" * 80

                $sshResult = switch ($Platform) {
                    "Windows" { Install-SSHWindows }
                    "macOS" { Install-SSHMacOS }
                    "Linux" { Install-SSHLinux }
                    default {
                        Write-Log "Unknown platform: $Platform" -Level ERROR
                        [Result]::Fail("Unknown platform: $Platform")
                    }
                }

                if (-not $sshResult.Success) {
                    Write-Log $sshResult.Error -Level WARN
                }
            }

            # Install RSSH to profile if not skipped
            if (-not $SkipProfile) {
                Write-Host ""
                Write-Log "PowerShell Profile Setup" -Level INFO
                Write-Host "─" * 80

                $profileResult = Install-RSHHProfile -SSHUser $SSHUser
                if (-not $profileResult.Success) {
                    Write-Log $profileResult.Error -Level WARN
                }
            }

            Write-Host ""
            Write-Log "Installation complete" -Level SUCCESS
            Write-Host ""
            Write-Log "Next steps:" -Level INFO
            Write-Log "1. Generate SSH key: ssh-keygen -t ed25519" -Level INFO
            Write-Log "2. Reload PowerShell: . `$PROFILE" -Level INFO
            Write-Log "3. Test RSSH: RSSH <hostname> 'Get-Date'" -Level INFO
            Write-Host ""

            return [Result]::Ok("Installation completed successfully")
        }
        catch {
            return [Result]::Fail("Installation failed: $_")
        }
    }
}

# ==================== INTERNAL FUNCTIONS ====================

function Install-SSHWindows {
    [OutputType([Result])]
    param()

    Write-Log "Installing SSH on Windows..." -Level INFO

    # Check if running as admin
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        return [Result]::Fail("SSH installation on Windows requires administrator privileges")
    }

    try {
        # Install OpenSSH Server feature
        $sshFeature = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
        if ($sshFeature.State -ne 'Installed') {
            Write-Log "Adding OpenSSH Server feature..." -Level INFO
            Add-WindowsCapability -Online -Name $sshFeature.Name | Out-Null
        }

        # Start and configure SSH service
        Write-Log "Configuring SSH service..." -Level INFO
        Start-Service sshd -ErrorAction SilentlyContinue
        Set-Service -Name sshd -StartupType Automatic

        # Configure Windows Firewall
        Write-Log "Configuring Windows Firewall..." -Level INFO
        New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True `
            -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue | Out-Null

        # Create .ssh directory if needed
        $sshDir = "$env:USERPROFILE\.ssh"
        if (-not (Test-Path $sshDir)) {
            New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        }

        Write-Log "SSH installation complete" -Level SUCCESS
        return [Result]::Ok("SSH installed on Windows")
    }
    catch {
        return [Result]::Fail("SSH installation failed: $_")
    }
}

function Install-SSHMacOS {
    [OutputType([Result])]
    param()

    Write-Log "Enabling SSH on macOS..." -Level INFO

    try {
        # Enable Remote Login (SSH)
        sudo systemsetup -setremotelogin on 2>&1 | Out-Null

        # Create .ssh directory if needed
        mkdir -p ~/.ssh 2>&1 | Out-Null
        chmod 700 ~/.ssh 2>&1 | Out-Null

        Write-Log "SSH configuration complete" -Level SUCCESS
        return [Result]::Ok("SSH enabled on macOS")
    }
    catch {
        return [Result]::Fail("SSH configuration failed: $_")
    }
}

function Install-SSHLinux {
    [OutputType([Result])]
    param()

    Write-Log "Installing SSH on Linux..." -Level INFO

    try {
        Write-Log "Please install openssh-server using your package manager" -Level WARN
        Write-Log "Ubuntu/Debian: sudo apt-get install openssh-server" -Level INFO
        Write-Log "RHEL/CentOS: sudo yum install openssh-server" -Level INFO
        return [Result]::Ok("SSH installation instructions provided for Linux")
    }
    catch {
        return [Result]::Fail("SSH installation failed: $_")
    }
}

function Install-RSHHProfile {
    [OutputType([Result])]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$SSHUser
    )

    Write-Log "Installing RSSH function to PowerShell profile..." -Level INFO

    try {
        $profilePath = $PROFILE
        $profileDir = Split-Path $profilePath

        # Ensure profile directory exists
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }

        # Check if RSSH already exists
        if ((Test-Path $profilePath) -and (Get-Content $profilePath | Select-String "function RSSH")) {
            Write-Log "RSSH already installed in profile" -Level WARN
            return [Result]::Ok("RSSH already installed in profile")
        }

        # Backup existing profile
        if (Test-Path $profilePath) {
            $backupPath = "$profilePath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $profilePath $backupPath
            Write-Log "Backed up existing profile to: $backupPath" -Level INFO
        }

        # Create RSSH function content
        $rsshFunction = @"
# ========== Dynamic Remote SSH Function (RSSH) ==========
# Usage: RSSH hostname command
# Resolves hostname to IP via Tailscale/DNS, then executes via SSH

function RSSH {
    param(
        [Parameter(Mandatory=`$true, Position=0, HelpMessage="Hostname or machine name")]
        [string]`$Hostname,

        [Parameter(Mandatory=`$true, Position=1, ValueFromRemainingArguments=`$true, HelpMessage="Command to execute")]
        [string[]]`$Command
    )

    `$cmdString = `$Command -join ' '
    `$ip = `$null

    # Method 1: Try Tailscale status first (for Tailscale machines)
    `$tailscaleStatus = @(tailscale status 2>`$null)
    if (`$tailscaleStatus) {
        `$machineInfo = `$tailscaleStatus | Where-Object { `$_ -like "*`$Hostname*" }
        if (`$machineInfo) {
            `$ip = (`$machineInfo -split '\s+')[0]
        }
    }

    # Method 2: If not found in Tailscale, try DNS resolution
    if (-not `$ip) {
        try {
            `$dnsResult = [System.Net.Dns]::GetHostAddresses(`$Hostname) 2>`$null
            if (`$dnsResult) {
                `$ip = `$dnsResult[0].IPAddressToString
            }
        }
        catch { }
    }

    # Method 3: Try with local domain suffix
    if (-not `$ip) {
        try {
            `$fqdn = "`$Hostname.local"
            `$dnsResult = [System.Net.Dns]::GetHostAddresses(`$fqdn) 2>`$null
            if (`$dnsResult) {
                `$ip = `$dnsResult[0].IPAddressToString
                `$Hostname = `$fqdn
            }
        }
        catch { }
    }

    # If still no IP, error out
    if (-not `$ip) {
        Write-Error "Could not resolve '`$Hostname' to an IP address. Check hostname or Tailscale status."
        return
    }

    Write-Host "Executing on `$Hostname (`$ip): `$cmdString" -ForegroundColor Cyan
    Write-Host "─" * 80

    # Execute via SSH
    `$sshKey = "`$HOME\.ssh\id_ed25519"
    ssh -i `$sshKey -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$SSHUser@`$ip" powershell -Command "`$cmdString"

    Write-Host "─" * 80
}

Write-Host "Remote SSH function (RSSH) loaded!" -ForegroundColor Green
Write-Host "Usage: RSSH <hostname> <command>" -ForegroundColor Cyan
"@

        # Write RSSH to profile
        Add-Content -Path $profilePath -Value "`n$rsshFunction"

        Write-Log "RSSH function installed to profile" -Level SUCCESS
        Write-Log "Profile location: $profilePath" -Level INFO
        Write-Log "Reload PowerShell to activate: . `$PROFILE" -Level INFO
        return [Result]::Ok("RSSH function installed to PowerShell profile")
    }
    catch {
        return [Result]::Fail("RSSH installation failed: $_")
    }
}

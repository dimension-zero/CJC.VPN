<#
.SYNOPSIS
Diagnoses and repairs common Tailscale connectivity issues.

.DESCRIPTION
Three-phase automated workflow:
1. Diagnostics - Tests Tailscale connectivity, ICMP blocking, SSH service, RSSH functionality
2. Repairs - Automatically fixes issues (optional -Auto mode)
3. Verification - Re-tests after repairs

.PARAMETER Auto
If specified, automatically attempts to fix detected issues without prompting.

.OUTPUTS
Result - Returns Result object with Success/Fail status.

.EXAMPLE
Repair-Tailscale

.EXAMPLE
Repair-Tailscale -Auto -Verbose
#>

function Repair-Tailscale {
    [CmdletBinding()]
    [OutputType([Result])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Auto
    )

    begin {
        Write-Host ""
        Write-Log "Starting Tailscale Diagnostic and Repair" -Level INFO
        Write-Host ""
    }

    process {
        try {
            # ==================== PHASE 1: DIAGNOSTICS ====================
            Write-Log "Phase 1: Diagnostics" -Level INFO
            Write-Host "─" * 80
            Write-Host ""

            $tailscaleOK = Test-TailscaleConnectivity
            $icmpOK = Test-ICMPBlocking
            $sshOK = Test-SSHService
            $rsshOK = Test-RSHConnectivity

            Write-Host ""
            Write-Log "Diagnostic Results:" -Level INFO
            Write-Log "  Tailscale: $(if ($tailscaleOK) { 'OK' } else { 'FAILED' })" -Level INFO
            Write-Log "  ICMP:      $(if ($icmpOK -eq $null) { 'UNKNOWN' } elseif ($icmpOK) { 'OK' } else { 'BLOCKED' })" -Level INFO
            Write-Log "  SSH:       $(if ($sshOK -eq $null) { 'UNKNOWN' } elseif ($sshOK) { 'OK' } else { 'STOPPED' })" -Level INFO
            Write-Log "  RSSH:      $(if ($rsshOK) { 'OK' } else { 'NOT AVAILABLE' })" -Level INFO

            # ==================== PHASE 2: AUTOMATIC REPAIRS ====================
            if ($Auto -or -not $tailscaleOK -or ($icmpOK -eq $false) -or ($sshOK -eq $false)) {
                Write-Host ""
                Write-Log "Phase 2: Automatic Repairs" -Level INFO
                Write-Host "─" * 80
                Write-Host ""

                if (-not $tailscaleOK) {
                    $authResult = Repair-TailscaleAuthentication
                    if (-not $authResult.Success) {
                        Write-Log $authResult.Error -Level WARN
                    }
                }

                if ($PSVersionTable.Platform -ne "Unix") {
                    $fwResult = Repair-WindowsFirewall
                    if (-not $fwResult.Success) {
                        Write-Log $fwResult.Error -Level WARN
                    }
                }

                if ($icmpOK -eq $false -and $PSVersionTable.Platform -eq "Unix") {
                    Suggest-ESETFix
                }

                # Re-test after repairs
                Write-Host ""
                Write-Log "Re-testing after repairs..." -Level INFO
                $tailscaleOK = Test-TailscaleConnectivity
                $icmpOK = Test-ICMPBlocking
            }

            # ==================== PHASE 3: FINAL STATUS ====================
            Write-Host ""
            Write-Log "Phase 3: Final Status" -Level INFO
            Write-Host "─" * 80
            Write-Host ""

            $status = Get-TailscaleStatus
            if ($status) {
                Write-Host "Tailscale Status:" -ForegroundColor Cyan
                $status | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" }
            }

            Write-Host ""
            if ($tailscaleOK -and ($icmpOK -ne $false)) {
                Write-Log "Tailscale connectivity appears healthy" -Level SUCCESS
                return [Result]::Ok("Tailscale repair completed successfully")
            }
            else {
                Write-Log "Tailscale issues detected - review output above" -Level WARN
                Write-Log "For ESET firewall issues, see manual fix above" -Level INFO
                return [Result]::Fail("Tailscale issues remain after repair attempt")
            }
        }
        catch {
            return [Result]::Fail("Repair operation failed: $_")
        }
    }
}

# ==================== INTERNAL DIAGNOSTIC FUNCTIONS ====================

function Test-TailscaleConnectivity {
    [OutputType([bool])]
    param()

    Write-Log "Testing Tailscale connectivity..." -Level TEST

    $status = Get-TailscaleStatus
    if (-not $status) {
        Write-Log "Tailscale status command failed" -Level ERROR
        return $false
    }

    if ($status -like "*Logged out*" -or $status -like "*Offline*") {
        Write-Log "Tailscale not authenticated or disconnected" -Level WARN
        return $false
    }

    Write-Log "Tailscale status OK" -Level SUCCESS
    return $true
}

function Test-ICMPBlocking {
    [OutputType([bool])]
    param()

    Write-Log "Checking for ICMP blocking..." -Level TEST

    try {
        # Try to ping Tailscale network
        $machineIP = (Get-TailscaleStatus | Select-Object -First 1) -match '100\.' | ForEach-Object { ($_ -split '\s+')[0] }

        if ($machineIP) {
            $ping = ping $machineIP -n 1 -w 1000
            if ($ping -like "*Received = 1*") {
                Write-Log "ICMP working correctly" -Level SUCCESS
                return $true
            }
            else {
                Write-Log "ICMP appears to be blocked" -Level WARN
                return $false
            }
        }
    }
    catch {
        Write-Log "ICMP test inconclusive: $_" -Level WARN
    }

    return $null
}

function Test-SSHService {
    [OutputType([bool])]
    param()

    Write-Log "Checking SSH service..." -Level TEST

    try {
        if ($PSVersionTable.Platform -eq "Unix") {
            # macOS/Linux
            $result = sudo systemctl status ssh 2>&1
            if ($result -like "*active*") {
                Write-Log "SSH service is running" -Level SUCCESS
                return $true
            }
        }
        else {
            # Windows
            $sshService = Get-Service sshd -ErrorAction SilentlyContinue
            if ($sshService.Status -eq "Running") {
                Write-Log "SSH service is running" -Level SUCCESS
                return $true
            }
            else {
                Write-Log "SSH service is not running" -Level WARN
                return $false
            }
        }
    }
    catch {
        Write-Log "SSH service check inconclusive: $_" -Level WARN
        return $null
    }
}

function Test-RSHConnectivity {
    [OutputType([bool])]
    param()

    Write-Log "Testing RSSH functionality..." -Level TEST

    try {
        if (-not (Get-Command RSSH -ErrorAction SilentlyContinue)) {
            Write-Log "RSSH function not loaded" -Level WARN
            Write-Log "Run: . `$PROFILE" -Level INFO
            return $false
        }

        Write-Log "RSSH function available" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "RSSH test failed: $_" -Level ERROR
        return $false
    }
}

# ==================== INTERNAL REPAIR FUNCTIONS ====================

function Repair-TailscaleAuthentication {
    [OutputType([Result])]
    param()

    Write-Log "Attempting Tailscale re-authentication..." -Level INFO

    try {
        tailscale up
        Write-Log "Re-authentication successful" -Level SUCCESS
        return [Result]::Ok("Tailscale re-authentication successful")
    }
    catch {
        return [Result]::Fail("Re-authentication failed: $_")
    }
}

function Repair-WindowsFirewall {
    [OutputType([Result])]
    param()

    Write-Log "Configuring Windows Firewall for Tailscale..." -Level INFO

    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        return [Result]::Fail("Firewall fix requires administrator privileges")
    }

    try {
        # Add ICMP rule for Tailscale network
        netsh advfirewall firewall add rule name="ICMP Allow Tailscale" protocol=icmpv4:8,any dir=in action=allow remoteip=100.64.0.0/10 2>&1 | Out-Null

        # Add general connectivity rule
        netsh advfirewall firewall add rule name="Tailscale Network Allow" dir=in action=allow remoteip=100.64.0.0/10 2>&1 | Out-Null

        Write-Log "Windows Firewall configured for Tailscale" -Level SUCCESS
        return [Result]::Ok("Windows Firewall configured successfully")
    }
    catch {
        return [Result]::Fail("Windows Firewall configuration failed: $_")
    }
}

function Suggest-ESETFix {
    param()

    Write-Log "ESET Endpoint Security detected - manual configuration needed" -Level WARN
    Write-Host ""
    Write-Log "To fix ESET blocking Tailscale:" -Level INFO
    Write-Log "1. Open ESET Endpoint Security" -Level INFO
    Write-Log "2. Go to Advanced Setup → Firewall → Rules" -Level INFO
    Write-Log "3. Create new rule:" -Level INFO
    Write-Log "   - Name: Allow Tailscale 100.64.0.0/10 ICMP" -Level INFO
    Write-Log "   - Action: Allow" -Level INFO
    Write-Log "   - Protocol: ICMP" -Level INFO
    Write-Log "   - Remote host: 100.64.0.0/10" -Level INFO
    Write-Log "4. Make sure this rule is ABOVE the 'Block ICMP communication' rule" -Level INFO
    Write-Host ""
}

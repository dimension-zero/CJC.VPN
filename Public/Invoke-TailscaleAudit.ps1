<#
.SYNOPSIS
Comprehensive testing and audit of all machines in Tailscale account.

.DESCRIPTION
Tests all machines with three connectivity methods:
1. Tailscale ping (uses Tailscale's internal ping)
2. Regular ping (ping over Tailscale network)
3. SSH connectivity via RSSH function

Produces color-coded results, summary grid, and optional JSON audit report.

.PARAMETER GenerateReport
If specified, generates timestamped JSON audit report.

.PARAMETER SSHUser
Username for SSH connections. Defaults to 'mathew.burkitt'.

.OUTPUTS
Result - Returns Result object with Success/Fail status.

.EXAMPLE
Invoke-TailscaleAudit

.EXAMPLE
Invoke-TailscaleAudit -GenerateReport -Verbose
#>

function Invoke-TailscaleAudit {
    [CmdletBinding()]
    [OutputType([Result])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$GenerateReport,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$SSHUser = "mathew.burkitt"
    )

    begin {
        Write-Host ""
        Write-Log "Starting Comprehensive Tailscale Machine Tests" -Level INFO
        Write-Host ""
    }

    process {
        try {
            # Get all machines
            $machines = Get-TailscaleMachinesAudit
            if ($machines.Count -eq 0) {
                return [Result]::Fail("No machines found in Tailscale account")
            }

            # Display machines
            Write-Host "Machines to test:" -ForegroundColor Cyan
            foreach ($m in $machines) {
                $status = switch ($m.Status) {
                    "active" { "🟢" }
                    "idle" { "🟡" }
                    "offline" { "🔴" }
                    default { "⚪" }
                }
                Write-Host "  $status $($m.Hostname) ($($m.IP)) [$($m.Status)]"
            }
            Write-Host ""

            # Run tests
            $results = @()
            foreach ($machine in $machines) {
                Write-Host ""
                Write-Log "Testing $($machine.Hostname) ($($machine.IP))" -Level TEST
                Write-Host "─" * 80

                # Test 1: Tailscale Ping
                Write-Host "  [1/3] Tailscale ping..." -NoNewline
                $tsPing = Test-TailscalePingAudit -IP $machine.IP -Hostname $machine.Hostname
                $tsStatus = if ($tsPing.Success) { "✅" } else { "❌" }
                Write-Host " $tsStatus $($tsPing.Message)"

                # Test 2: Regular Ping
                Write-Host "  [2/3] Regular ping..." -NoNewline
                $regPing = Test-RegularPingAudit -IP $machine.IP -Hostname $machine.Hostname
                $regStatus = if ($regPing.Success) { "✅" } else { "❌" }
                Write-Host " $regStatus $($regPing.Message)"

                # Test 3: SSH/RSSH
                Write-Host "  [3/3] SSH (winget)..." -NoNewline
                $sshTest = Test-WingetUpgradeAudit -IP $machine.IP -Hostname $machine.Hostname
                $sshStatus = if ($sshTest.Success) { "✅" } else { "❌" }
                Write-Host " $sshStatus $($sshTest.Message)"

                $results += [ConnectivityResult]@{
                    Hostname             = $machine.Hostname
                    IP                   = $machine.IP
                    TailscalePing        = if ($tsPing.Success) { [TestStatus]::Pass } else { [TestStatus]::Fail }
                    RegularPing          = if ($regPing.Success) { [TestStatus]::Pass } else { [TestStatus]::Fail }
                    SSHConnection        = if ($sshTest.Success) { [TestStatus]::Pass } else { [TestStatus]::Fail }
                    Timestamp            = Get-Date
                }
            }

            # Summary Grid
            Write-Host ""
            Write-Host ""
            Write-Log "CONNECTIVITY SUMMARY" -Level INFO
            Write-Host "─" * 100
            Write-Host "{0,-30} {0,-20} {0,-20} {0,-20}" -f "Machine", "Tailscale Ping", "Regular Ping", "SSH (Winget)"
            Write-Host "─" * 100

            $passCount = 0
            foreach ($result in $results) {
                $ts = if ($result.TailscalePing -eq [TestStatus]::Pass) { "✓ Pass" } else { "✗ Fail" }
                $reg = if ($result.RegularPing -eq [TestStatus]::Pass) { "✓ Pass" } else { "✗ Fail" }
                $ssh = if ($result.SSHConnection -eq [TestStatus]::Pass) { "✓ Pass" } else { "✗ Fail" }

                Write-Host "{0,-30} {1,-20} {2,-20} {3,-20}" -f $result.Hostname, $ts, $reg, $ssh

                if ($result.IsHealthy()) {
                    $passCount++
                }
            }

            Write-Host "─" * 100
            Write-Log "Total: $passCount/$($results.Count) machines fully healthy" -Level SUCCESS

            # Generate report if requested
            if ($GenerateReport) {
                $reportPath = Export-AuditReport -Results $results
                Write-Log "Audit report saved: $reportPath" -Level SUCCESS
            }

            Write-Host ""
            return [Result]::Ok("Audit completed: $passCount/$($results.Count) machines healthy")
        }
        catch {
            return [Result]::Fail("Audit failed: $_")
        }
    }
}

# ==================== INTERNAL AUDIT FUNCTIONS ====================

function Get-TailscaleMachinesAudit {
    [OutputType([System.Object[]])]
    param()

    Write-Log "Retrieving Tailscale machines..." -Level INFO

    try {
        $output = Get-TailscaleStatus
        if (-not $output) {
            return @()
        }

        $machines = @()
        foreach ($line in $output) {
            $parts = $line -split '\s+' | Where-Object { $_ }
            if ($parts.Count -ge 2 -and $parts[0] -match '^100\.') {
                $machines += @{
                    IP       = $parts[0]
                    Hostname = $parts[1]
                    Status   = if ($line -like "*offline*") { "offline" } elseif ($line -like "*active*") { "active" } else { "idle" }
                }
            }
        }

        Write-Log "Found $($machines.Count) machines" -Level SUCCESS
        return $machines
    }
    catch {
        Write-Log "Failed to retrieve machines: $_" -Level ERROR
        return @()
    }
}

function Test-TailscalePingAudit {
    [OutputType([System.Collections.Hashtable])]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$IP,

        [ValidateNotNullOrEmpty()]
        [string]$Hostname
    )

    try {
        $output = tailscale ping $IP 2>&1
        if ($output -like "*pong*") {
            return @{ Success = $true; Message = "pong" }
        }
        else {
            return @{ Success = $false; Message = "no response" }
        }
    }
    catch {
        return @{ Success = $false; Message = "error" }
    }
}

function Test-RegularPingAudit {
    [OutputType([System.Collections.Hashtable])]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$IP,

        [ValidateNotNullOrEmpty()]
        [string]$Hostname
    )

    try {
        $ping = ping $IP -n 1 -w 2000
        if ($ping -like "*Received = 1*") {
            return @{ Success = $true; Message = "reply" }
        }
        else {
            return @{ Success = $false; Message = "timeout" }
        }
    }
    catch {
        return @{ Success = $false; Message = "error" }
    }
}

function Test-WingetUpgradeAudit {
    [OutputType([System.Collections.Hashtable])]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$IP,

        [ValidateNotNullOrEmpty()]
        [string]$Hostname
    )

    try {
        # Check if RSSH is available
        if (-not (Get-Command RSSH -ErrorAction SilentlyContinue)) {
            return @{ Success = $false; Message = "RSSH not available" }
        }

        # Run winget upgrade (suppress output)
        $null = & { RSSH $Hostname "winget upgrade --all --silent" 2>&1 } | Out-Null

        # Check exit code - 0 or -1603 (no updates) indicate success
        $success = ($LASTEXITCODE -le 0 -or $LASTEXITCODE -eq -1603)
        return @{ Success = $success; Message = "exit: $LASTEXITCODE" }
    }
    catch {
        return @{ Success = $false; Message = "error" }
    }
}

function Export-AuditReport {
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Object[]]$Results
    )

    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $hostname = $env:COMPUTERNAME
        $reportPath = "$PSScriptRoot\$hostname-audit.$timestamp.json"

        $report = @{
            Timestamp = Get-Date
            Hostname  = $hostname
            Results   = $Results | ConvertTo-Json
            Summary   = @{
                Total     = $Results.Count
                Healthy   = @($Results | Where-Object { $_.IsHealthy() }).Count
                Partial   = @($Results | Where-Object { -not $_.IsHealthy() }).Count
            }
        }

        $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath
        return $reportPath
    }
    catch {
        Write-Log "Failed to generate report: $_" -Level WARN
        return $null
    }
}

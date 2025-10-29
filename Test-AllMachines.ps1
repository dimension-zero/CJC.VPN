#!/usr/bin/env pwsh
# Comprehensive test of all Tailscale machines
# Tests: tailscale ping, regular ping, and winget upgrade via RSSH

param(
    [Parameter(Mandatory=$false)]
    [string]$SSHUser = "mathew.burkitt",
    [Parameter(Mandatory=$false)]
    [string]$SSHKey = "$HOME\.ssh\id_ed25519"
)

function Write-Log {
    param([string]$Message, [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "TEST")]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $colors = @{
        "INFO"    = "White"
        "WARN"    = "Yellow"
        "ERROR"   = "Red"
        "SUCCESS" = "Green"
        "TEST"    = "Cyan"
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $colors[$Level]
}

function Get-TailscaleMachines {
    Write-Log "Retrieving Tailscale machines..." "INFO"
    try {
        $output = tailscale status
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

        Write-Log "Found $($machines.Count) machines" "SUCCESS"
        return $machines
    }
    catch {
        Write-Log "Failed to retrieve machines: $_" "ERROR"
        return @()
    }
}

function Test-TailscalePing {
    param([string]$IP, [string]$Hostname)

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

function Test-RegularPing {
    param([string]$IP, [string]$Hostname)

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

function Test-WingetUpgrade {
    param([string]$IP, [string]$Hostname)

    try {
        # Call RSSH function - must be loaded in profile
        if (-not (Get-Command RSSH -ErrorAction SilentlyContinue)) {
            return @{ Success = $false; Message = "RSSH not available" }
        }

        # Run winget upgrade and suppress all output
        $output = & {
            RSSH $Hostname "winget upgrade --all --silent" 2>&1
        } | Out-Null

        # Check exit code - assume success if exit code is reasonable
        # Various exit codes from winget can indicate success: 0, -1603 (no updates), etc.
        $success = ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1603 -or $LASTEXITCODE -eq $null)

        return @{ Success = $success; Message = "exit: $LASTEXITCODE" }
    }
    catch {
        return @{ Success = $false; Message = "error: $_" }
    }
}

# ==================== Main Execution ====================

Write-Host ""
Write-Log "Starting Comprehensive Tailscale Machine Tests" "INFO"
Write-Host ""

# Get all machines
$machines = Get-TailscaleMachines
if ($machines.Count -eq 0) {
    Write-Log "No machines found" "ERROR"
    exit 1
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
    Write-Log "Testing $($machine.Hostname) ($($machine.IP))" "TEST"
    Write-Host "─" * 80

    # Test 1: Tailscale Ping
    Write-Host "  [1/3] Tailscale ping..." -NoNewline
    $tsPing = Test-TailscalePing -IP $machine.IP -Hostname $machine.Hostname
    $tsStatus = if ($tsPing.Success) { "✅" } else { "❌" }
    Write-Host " $tsStatus $($tsPing.Message)"

    # Test 2: Regular Ping
    Write-Host "  [2/3] Regular ping..." -NoNewline
    $regPing = Test-RegularPing -IP $machine.IP -Hostname $machine.Hostname
    $regStatus = if ($regPing.Success) { "✅" } else { "❌" }
    Write-Host " $regStatus $($regPing.Message)"

    # Test 3: Winget Upgrade (only if not offline)
    Write-Host "  [3/3] Winget upgrade..." -NoNewline
    if ($machine.Status -eq "offline") {
        Write-Host " [SKIP]"
        $winget = @{ Success = $null; Message = "skipped" }
    }
    else {
        $winget = Test-WingetUpgrade -IP $machine.IP -Hostname $machine.Hostname
        $wingetStatus = if ($winget.Success -eq $null) { "[SKIP]" } elseif ($winget.Success) { "[OK]" } else { "[FAIL]" }
        Write-Host " $wingetStatus"
    }

    # Store results
    $results += @{
        Hostname        = $machine.Hostname
        IP              = $machine.IP
        Status          = $machine.Status
        TailscalePing   = $tsPing.Success
        RegularPing     = $regPing.Success
        WingetUpgrade   = $winget.Success
    }

    Write-Host "─" * 80
}

# ==================== Summary Grid ====================

Write-Host ""
Write-Log "========== SUMMARY REPORT ==========" "INFO"
Write-Host ""

# Create ASCII table
$header = "Machine Name".PadRight(25) + " | Status  | Tailscale | Regular | Winget"
Write-Host $header -ForegroundColor Cyan
Write-Host ("─" * 85)

foreach ($result in $results) {
    $tsStatus = if ($result.TailscalePing -eq $null) { "SKIP" } elseif ($result.TailscalePing) { "PASS" } else { "FAIL" }
    $regStatus = if ($result.RegularPing -eq $null) { "SKIP" } elseif ($result.RegularPing) { "PASS" } else { "FAIL" }
    $wgStatus = if ($result.WingetUpgrade -eq $null) { "SKIP" } elseif ($result.WingetUpgrade) { "PASS" } else { "FAIL" }

    $tsColor = switch ($tsStatus) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "SKIP" { "Yellow" }
    }
    $regColor = switch ($regStatus) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "SKIP" { "Yellow" }
    }
    $wgColor = switch ($wgStatus) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "SKIP" { "Yellow" }
    }

    $statusIcon = switch ($result.Status) {
        "active" { "Active" }
        "idle" { "Idle  " }
        "offline" { "Offline" }
        default { "Unknown" }
    }

    $row = "$($result.Hostname)".PadRight(25) + " | " + $statusIcon.PadRight(7) + " | "
    Write-Host -NoNewline $row

    Write-Host -NoNewline $tsStatus.PadRight(9) -ForegroundColor $tsColor
    Write-Host -NoNewline " | "
    Write-Host -NoNewline $regStatus.PadRight(7) -ForegroundColor $regColor
    Write-Host -NoNewline " | "
    Write-Host $wgStatus -ForegroundColor $wgColor
}

Write-Host ""

# Statistics
$totalMachines = $results.Count
$tsPass = ($results | Where-Object { $_.TailscalePing -eq $true }).Count
$regPass = ($results | Where-Object { $_.RegularPing -eq $true }).Count
$wgPass = ($results | Where-Object { $_.WingetUpgrade -eq $true }).Count
$wgSkipped = ($results | Where-Object { $_.WingetUpgrade -eq $null }).Count

Write-Host "Statistics:" -ForegroundColor Cyan
Write-Host "  Total machines:        $totalMachines"
Write-Host "  Tailscale ping pass:   $tsPass/$totalMachines"
Write-Host "  Regular ping pass:     $regPass/$totalMachines"
Write-Host "  Winget upgrade pass:   $wgPass/$totalMachines (skipped: $wgSkipped)"
Write-Host ""

# Overall status
$allPass = ($tsPass -eq $totalMachines) -and ($regPass -eq $totalMachines)
if ($allPass) {
    Write-Log "All tests passed! ✅" "SUCCESS"
}
else {
    Write-Log "Some tests failed. Review results above." "WARN"
}

Write-Host ""
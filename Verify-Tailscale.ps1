#!/usr/bin/env pwsh
# Verify-Tailscale: Comprehensive Tailscale connectivity audit
# Tests all-to-all connectivity using Tailscale and regular ping
# Generates console output and timestamped JSON report

param(
    [Parameter(Mandatory=$false)]
    [string]$TailnetName = "catherinejones.com",
    [Parameter(Mandatory=$false)]
    [switch]$AllToAll = $false
)

# ==================== Configuration ====================
$ErrorActionPreference = "SilentlyContinue"

function Write-Log {
    param([string]$Message, [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = @{
        "INFO"    = "White"
        "WARN"    = "Yellow"
        "ERROR"   = "Red"
        "SUCCESS" = "Green"
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color[$Level]
}

function Get-TailscaleMachines {
    Write-Log "Retrieving Tailscale machine list..."
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

        Write-Log "Found $($machines.Count) machines in tailnet" "SUCCESS"
        return $machines
    }
    catch {
        Write-Log "Failed to retrieve machines: $_" "ERROR"
        return @()
    }
}

function Test-TailscalePing {
    param([string]$TargetIP, [string]$TargetHostname)

    try {
        $output = tailscale ping $TargetIP 2>&1

        if ($output -like "*pong*") {
            $latency = $output -replace '.*\s(\d+)ms.*', '$1'
            return @{
                Success = $true
                Latency = if ($latency -match '^\d+$') { [int]$latency } else { 0 }
                Message = "pong"
            }
        }
        else {
            return @{
                Success = $false
                Latency = 0
                Message = "no response"
            }
        }
    }
    catch {
        return @{
            Success = $false
            Latency = 0
            Message = "error: $_"
        }
    }
}

function Test-RegularPing {
    param([string]$TargetIP, [string]$TargetHostname)

    try {
        $ping = ping $TargetIP -n 2 -w 1000

        if ($ping -like "*Received = 1*" -or $ping -like "*Received = 2*") {
            $latency = $ping -match '\d+ms' | ForEach-Object { $_ -replace '.*time[<=]*(\d+)ms.*', '$1' } | Select-Object -First 1
            return @{
                Success = $true
                Latency = if ($latency -match '^\d+$') { [int]$latency } else { 0 }
                Message = "reply received"
            }
        }
        else {
            return @{
                Success = $false
                Latency = 0
                Message = "no response"
            }
        }
    }
    catch {
        return @{
            Success = $false
            Latency = 0
            Message = "error: $_"
        }
    }
}

function Test-FromLocalMachine {
    param([array]$Machines)

    Write-Log "Testing connectivity from local machine to all targets..."
    Write-Host ""

    $results = @()

    foreach ($target in $Machines) {
        Write-Host "Testing to $($target.Hostname) ($($target.IP))..." -NoNewline

        $tailscalePing = Test-TailscalePing -TargetIP $target.IP -TargetHostname $target.Hostname
        $regularPing = Test-RegularPing -TargetIP $target.IP -TargetHostname $target.Hostname

        $status = if ($tailscalePing.Success -and $regularPing.Success) { "✅ PASS" }
                  elseif ($tailscalePing.Success) { "⚠️  PARTIAL" }
                  else { "❌ FAIL" }

        Write-Host " $status"

        $results += @{
            Source           = "local"
            SourceIP         = (tailscale status | Select-Object -First 1).Split()[0]
            Target           = $target.Hostname
            TargetIP         = $target.IP
            TargetStatus     = $target.Status
            TailscalePing    = @{
                Success = $tailscalePing.Success
                Latency = $tailscalePing.Latency
                Message = $tailscalePing.Message
            }
            RegularPing      = @{
                Success = $regularPing.Success
                Latency = $regularPing.Latency
                Message = $regularPing.Message
            }
            OverallStatus    = if ($tailscalePing.Success -and $regularPing.Success) { "PASS" } elseif ($tailscalePing.Success) { "PARTIAL" } else { "FAIL" }
            Timestamp        = Get-Date -Format "o"
        }
    }

    return $results
}

function Generate-Report {
    param([array]$Results)

    Write-Host ""
    Write-Log "========== CONNECTIVITY REPORT ==========" "INFO"
    Write-Host ""

    # Summary statistics
    $passed = ($Results | Where-Object { $_.OverallStatus -eq "PASS" }).Count
    $partial = ($Results | Where-Object { $_.OverallStatus -eq "PARTIAL" }).Count
    $failed = ($Results | Where-Object { $_.OverallStatus -eq "FAIL" }).Count

    Write-Host "Summary:"
    Write-Host "  ✅ PASS:    $passed machines (both Tailscale & regular ping working)"
    Write-Host "  ⚠️  PARTIAL: $partial machines (Tailscale ping only)"
    Write-Host "  ❌ FAIL:    $failed machines (no connectivity)"
    Write-Host ""

    # Detailed results
    Write-Host "Detailed Results:"
    Write-Host ""

    foreach ($result in $Results | Sort-Object Target) {
        Write-Host "Target: $($result.Target) ($($result.TargetIP)) [Status: $($result.TargetStatus)]"
        Write-Host "  Tailscale Ping: $(if ($result.TailscalePing.Success) { '✅ YES' } else { '❌ NO' }) - $($result.TailscalePing.Message) - Latency: $($result.TailscalePing.Latency)ms"
        Write-Host "  Regular Ping:   $(if ($result.RegularPing.Success) { '✅ YES' } else { '❌ NO' }) - $($result.RegularPing.Message) - Latency: $($result.RegularPing.Latency)ms"
        Write-Host "  Overall:        $($result.OverallStatus)"
        Write-Host ""
    }
}

function Save-JSONReport {
    param([array]$Results, [string]$TailnetName)

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $filename = "$TailnetName-audit.$timestamp.json"
    $filepath = Join-Path (Get-Location) $filename

    $report = @{
        Tailnet       = $TailnetName
        Timestamp     = Get-Date -Format "o"
        MachineCount  = $Results.Count
        PassCount     = ($Results | Where-Object { $_.OverallStatus -eq "PASS" }).Count
        PartialCount  = ($Results | Where-Object { $_.OverallStatus -eq "PARTIAL" }).Count
        FailCount     = ($Results | Where-Object { $_.OverallStatus -eq "FAIL" }).Count
        Results       = $Results
    }

    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $filepath

    Write-Log "JSON report saved: $filepath" "SUCCESS"
    return $filepath
}

# ==================== Main Execution ====================
Write-Host ""
Write-Log "Starting Tailscale Connectivity Audit" "INFO"
Write-Log "Tailnet: $TailnetName" "INFO"
Write-Host ""

# Get all machines
$machines = Get-TailscaleMachines
if ($machines.Count -eq 0) {
    Write-Log "No machines found. Exiting." "ERROR"
    exit 1
}

# Display machine list
Write-Host "Machines in tailnet:"
foreach ($machine in $machines) {
    $statusIcon = switch ($machine.Status) {
        "active" { "🟢" }
        "idle" { "🟡" }
        "offline" { "🔴" }
        default { "⚪" }
    }
    Write-Host "  $statusIcon $($machine.Hostname) ($($machine.IP)) - $($machine.Status)"
}
Write-Host ""

# Run tests
$results = Test-FromLocalMachine -Machines $machines

# Generate console report
Generate-Report -Results $results

# Save JSON report
$jsonPath = Save-JSONReport -Results $results -TailnetName $TailnetName

Write-Host ""
Write-Log "Audit complete!" "SUCCESS"
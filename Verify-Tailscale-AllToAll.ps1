#!/usr/bin/env pwsh
# Verify-Tailscale-AllToAll: All-to-all connectivity testing
# Uses SSH to remotely execute tests on each machine
# Requires SSH to be configured on all target machines

param(
    [Parameter(Mandatory=$false)]
    [string]$TailnetName = "catherinejones.com",
    [Parameter(Mandatory=$false)]
    [string]$SSHUser = "mathew.burkitt",
    [Parameter(Mandatory=$false)]
    [string]$SSHKey = "$HOME\.ssh\id_ed25519"
)

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

function Test-SSHConnection {
    param([string]$TargetIP, [string]$SSHUser, [string]$SSHKey)

    try {
        $result = ssh -i $SSHKey -o ConnectTimeout=2 -o StrictHostKeyChecking=no "$SSHUser@$TargetIP" "echo 'OK'" 2>&1
        return $result -eq "OK"
    }
    catch {
        return $false
    }
}

function Invoke-RemoteTest {
    param([string]$SourceIP, [string]$TargetIP, [string]$SSHUser, [string]$SSHKey)

    try {
        $testScript = "tailscale ping $TargetIP | grep pong; ping -c 2 -W 1 $TargetIP | grep 'packets received'"
        $result = ssh -i $SSHKey -o ConnectTimeout=2 "$SSHUser@$SourceIP" $testScript 2>&1

        return @{
            TailscalePing = $result -like "*pong*"
            RegularPing   = $result -like "*2 received*" -or $result -like "*1 received*"
        }
    }
    catch {
        return @{
            TailscalePing = $false
            RegularPing   = $false
        }
    }
}

function Test-AllToAll {
    param([array]$Machines, [string]$SSHUser, [string]$SSHKey)

    Write-Log "Testing all-to-all connectivity via SSH..."
    Write-Host ""

    $results = @()
    $machineCount = $Machines.Count

    for ($i = 0; $i -lt $machineCount; $i++) {
        $source = $Machines[$i]

        # Check SSH connectivity
        Write-Host "Source: $($source.Hostname) ($($source.IP))" -ForegroundColor Cyan
        $sshAvailable = Test-SSHConnection -TargetIP $source.IP -SSHUser $SSHUser -SSHKey $SSHKey

        if (-not $sshAvailable) {
            Write-Host "  ⚠️  SSH not available on source, skipping" -ForegroundColor Yellow
            continue
        }

        # Test to all targets
        foreach ($target in $Machines) {
            if ($source.IP -eq $target.IP) { continue } # Skip self

            Write-Host "  Testing to $($target.Hostname) ($($target.IP))..." -NoNewline

            $testResult = Invoke-RemoteTest -SourceIP $source.IP -TargetIP $target.IP -SSHUser $SSHUser -SSHKey $SSHKey

            $status = if ($testResult.TailscalePing -and $testResult.RegularPing) { "✅" }
                      elseif ($testResult.TailscalePing) { "⚠️ " }
                      else { "❌" }

            Write-Host " $status"

            $results += @{
                Source        = $source.Hostname
                SourceIP      = $source.IP
                Target        = $target.Hostname
                TargetIP      = $target.IP
                TailscalePing = $testResult.TailscalePing
                RegularPing   = $testResult.RegularPing
                Status        = if ($testResult.TailscalePing -and $testResult.RegularPing) { "PASS" }
                                elseif ($testResult.TailscalePing) { "PARTIAL" }
                                else { "FAIL" }
                Timestamp     = Get-Date -Format "o"
            }
        }
    }

    return $results
}

# ==================== Main Execution ====================
Write-Host ""
Write-Log "Starting All-to-All Tailscale Connectivity Audit" "INFO"
Write-Log "Tailnet: $TailnetName" "INFO"
Write-Host ""

# Get all machines
$machines = Get-TailscaleMachines
if ($machines.Count -eq 0) {
    Write-Log "No machines found. Exiting." "ERROR"
    exit 1
}

# Run all-to-all tests
$results = Test-AllToAll -Machines $machines -SSHUser $SSHUser -SSHKey $SSHKey

# Save results
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$filename = "$TailnetName-audit-alltoall.$timestamp.json"

$report = @{
    Tailnet   = $TailnetName
    Timestamp = Get-Date -Format "o"
    Type      = "AllToAll"
    Results   = $results
}

$report | ConvertTo-Json -Depth 10 | Set-Content -Path $filename

Write-Log "All-to-all audit complete! Results saved to: $filename" "SUCCESS"
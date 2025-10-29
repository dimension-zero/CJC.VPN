# Type-safe Result<T> pattern for explicit error handling
# Based on functional programming patterns to avoid exceptions for control flow

class Result {
    [bool]$Success
    [object]$Value
    [string]$Error
    [DateTime]$Timestamp

    # Constructor for success
    Result([bool]$success, [object]$value, [string]$error) {
        $this.Success = $success
        $this.Value = $value
        $this.Error = $error
        $this.Timestamp = Get-Date
    }

    # Static factory method for successful results
    static [Result] Ok([object]$value) {
        return [Result]::new($true, $value, $null)
    }

    # Static factory method for failed results
    static [Result] Fail([string]$error) {
        return [Result]::new($false, $null, $error)
    }

    # Unwrap value or throw if failed
    [object] Unwrap() {
        if (-not $this.Success) {
            throw "Called Unwrap() on failed Result: $($this.Error)"
        }
        return $this.Value
    }

    # Get value or return default
    [object] UnwrapOr([object]$default) {
        if ($this.Success) {
            return $this.Value
        }
        return $default
    }

    # Chain operations (monadic bind)
    [Result] Then([scriptblock]$operation) {
        if (-not $this.Success) {
            return $this
        }

        try {
            $result = & $operation $this.Value
            if ($result -is [Result]) {
                return $result
            }
            return [Result]::Ok($result)
        }
        catch {
            return [Result]::Fail("Operation failed: $_")
        }
    }

    # Map over value
    [Result] Map([scriptblock]$transform) {
        if (-not $this.Success) {
            return [Result]::Fail($this.Error)
        }

        try {
            $newValue = & $transform $this.Value
            return [Result]::Ok($newValue)
        }
        catch {
            return [Result]::Fail("Transform failed: $_")
        }
    }

    # Convert to string representation
    [string] ToString() {
        if ($this.Success) {
            return "Result::Ok($($this.Value))"
        }
        return "Result::Fail($($this.Error))"
    }
}

# Type-safe enum for operations
enum TailscaleOperation {
    Install
    Repair
    Audit
    Unknown
}

# Type-safe enum for test results
enum TestStatus {
    Pass
    Fail
    Skip
    Unknown
}

# Structured result for connectivity tests
class ConnectivityResult {
    [ValidateNotNullOrEmpty()]
    [string]$Hostname

    [string]$IP

    [TestStatus]$TailscalePing
    [nullable[int]]$TailscalePingLatency

    [TestStatus]$RegularPing
    [nullable[int]]$RegularPingLatency

    [TestStatus]$SSHConnection

    [DateTime]$Timestamp = (Get-Date)

    # Summary property
    [bool] IsHealthy() {
        return ($this.TailscalePing -eq [TestStatus]::Pass -and
                $this.RegularPing -eq [TestStatus]::Pass -and
                $this.SSHConnection -eq [TestStatus]::Pass)
    }
}

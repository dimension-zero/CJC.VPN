<#
.SYNOPSIS
Pester tests for CJC.Tailscale module

.DESCRIPTION
Comprehensive test suite covering:
- Module import and function availability
- Type safety and Result<T> pattern
- Critical path functionality
- Error handling
#>

#Requires -Module Pester

# Import module
$ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\CJC.Tailscale.psd1'
Import-Module -Name $ModulePath -Force

Describe "CJC.Tailscale Module" {
    Context "Module Imports Successfully" {
        It "Should import the module" {
            Get-Module CJC.Tailscale | Should -Not -BeNullOrEmpty
        }

        It "Should export Install-Tailscale function" {
            Get-Command -Module CJC.Tailscale -Name Install-Tailscale | Should -Not -BeNullOrEmpty
        }

        It "Should export Repair-Tailscale function" {
            Get-Command -Module CJC.Tailscale -Name Repair-Tailscale | Should -Not -BeNullOrEmpty
        }

        It "Should export Invoke-TailscaleAudit function" {
            Get-Command -Module CJC.Tailscale -Name Invoke-TailscaleAudit | Should -Not -BeNullOrEmpty
        }
    }

    Context "Type Definitions" {
        It "Should define Result class" {
            [Result] | Should -Not -BeNullOrEmpty
        }

        It "Should define TailscaleOperation enum" {
            [TailscaleOperation] | Should -Not -BeNullOrEmpty
        }

        It "Should define TestStatus enum" {
            [TestStatus] | Should -Not -BeNullOrEmpty
        }

        It "Should define ConnectivityResult class" {
            [ConnectivityResult] | Should -Not -BeNullOrEmpty
        }
    }

    Context "Result<T> Pattern" {
        It "Should create successful Result" {
            $result = [Result]::Ok("test value")
            $result.Success | Should -Be $true
            $result.Value | Should -Be "test value"
        }

        It "Should create failed Result" {
            $result = [Result]::Fail("test error")
            $result.Success | Should -Be $false
            $result.Error | Should -Be "test error"
        }

        It "Result::Ok should have null Error" {
            $result = [Result]::Ok("value")
            $result.Error | Should -BeNullOrEmpty
        }

        It "Result::Fail should have null Value" {
            $result = [Result]::Fail("error")
            $result.Value | Should -BeNullOrEmpty
        }

        It "Result.Unwrap() should return value on success" {
            $result = [Result]::Ok(42)
            $result.Unwrap() | Should -Be 42
        }

        It "Result.Unwrap() should throw on failure" {
            $result = [Result]::Fail("error message")
            { $result.Unwrap() } | Should -Throw
        }

        It "Result.UnwrapOr() should return value on success" {
            $result = [Result]::Ok(42)
            $result.UnwrapOr(99) | Should -Be 42
        }

        It "Result.UnwrapOr() should return default on failure" {
            $result = [Result]::Fail("error")
            $result.UnwrapOr(99) | Should -Be 99
        }

        It "Result.Then() should chain operations on success" {
            $result = [Result]::Ok(5).Then({ [Result]::Ok($_ * 2) })
            $result.Value | Should -Be 10
        }

        It "Result.Then() should skip operation on failure" {
            $result = [Result]::Fail("error").Then({ [Result]::Ok("value") })
            $result.Success | Should -Be $false
        }

        It "Result.Map() should transform value on success" {
            $result = [Result]::Ok(5).Map({ $_ * 2 })
            $result.Value | Should -Be 10
        }

        It "Result.Map() should preserve failure" {
            $result = [Result]::Fail("error").Map({ $_ * 2 })
            $result.Success | Should -Be $false
        }

        It "Result should include timestamp" {
            $before = Get-Date
            $result = [Result]::Ok("value")
            $after = Get-Date

            $result.Timestamp | Should -BeGreaterThanOrEqual $before
            $result.Timestamp | Should -BeLessThanOrEqual $after
        }
    }

    Context "Enums and Type Safety" {
        It "TailscaleOperation enum should have expected values" {
            [TailscaleOperation]::Install | Should -Be 0
            [TailscaleOperation]::Repair | Should -Be 1
            [TailscaleOperation]::Audit | Should -Be 2
        }

        It "TestStatus enum should have expected values" {
            [TestStatus]::Pass | Should -Be 0
            [TestStatus]::Fail | Should -Be 1
            [TestStatus]::Skip | Should -Be 2
        }

        It "Should not allow invalid enum values" {
            { [TailscaleOperation]'InvalidValue' } | Should -Throw
        }
    }

    Context "ConnectivityResult Type Safety" {
        It "Should create ConnectivityResult with all properties" {
            $result = [ConnectivityResult]@{
                Hostname        = "test-machine"
                IP              = "100.64.1.1"
                TailscalePing   = [TestStatus]::Pass
                RegularPing     = [TestStatus]::Pass
                SSHConnection   = [TestStatus]::Pass
            }

            $result.Hostname | Should -Be "test-machine"
            $result.IP | Should -Be "100.64.1.1"
        }

        It "IsHealthy() should return true when all tests pass" {
            $result = [ConnectivityResult]@{
                Hostname        = "machine"
                TailscalePing   = [TestStatus]::Pass
                RegularPing     = [TestStatus]::Pass
                SSHConnection   = [TestStatus]::Pass
            }

            $result.IsHealthy() | Should -Be $true
        }

        It "IsHealthy() should return false when any test fails" {
            $result = [ConnectivityResult]@{
                Hostname        = "machine"
                TailscalePing   = [TestStatus]::Pass
                RegularPing     = [TestStatus]::Fail
                SSHConnection   = [TestStatus]::Pass
            }

            $result.IsHealthy() | Should -Be $false
        }

        It "Should require non-empty Hostname" {
            { [ConnectivityResult]@{ Hostname = "" } } | Should -Throw
        }

        It "Should include Timestamp automatically" {
            $before = Get-Date
            $result = [ConnectivityResult]@{ Hostname = "test" }
            $after = Get-Date

            $result.Timestamp | Should -BeGreaterThanOrEqual $before
            $result.Timestamp | Should -BeLessThanOrEqual $after
        }
    }

    Context "Write-Log Function" {
        It "Should execute without error" {
            { Write-Log "Test message" -Level INFO } | Should -Not -Throw
        }

        It "Should accept all valid levels" {
            @("INFO", "WARN", "ERROR", "SUCCESS", "TEST", "DEBUG") | ForEach-Object {
                { Write-Log "Test" -Level $_ } | Should -Not -Throw
            }
        }

        It "Should accept pipeline input" {
            { "Test message" | Write-Log -Level INFO } | Should -Not -Throw
        }

        It "Should support NoNewline parameter" {
            { Write-Log "Test" -NoNewline } | Should -Not -Throw
        }

        It "Should require non-empty Message" {
            { Write-Log "" } | Should -Throw
        }
    }

    Context "Get-TailscaleStatus Function" {
        It "Should return null or array" {
            $status = Get-TailscaleStatus
            if ($status) {
                $status | Should -BeOfType @('System.Object[]', 'System.String')
            }
        }

        It "Should not throw on error" {
            { Get-TailscaleStatus } | Should -Not -Throw
        }
    }

    Context "Get-DetectedPlatform Function" {
        It "Should return a valid platform string" {
            $platform = Get-DetectedPlatform
            $platform | Should -BeIn @("Windows", "macOS", "Linux", "Unix")
        }

        It "Should return Windows on Windows systems" {
            if ($PSVersionTable.Platform -ne "Unix") {
                $platform = Get-DetectedPlatform
                $platform | Should -Be "Windows"
            }
        }

        It "Should return consistent results" {
            $platform1 = Get-DetectedPlatform
            $platform2 = Get-DetectedPlatform
            $platform1 | Should -Be $platform2
        }
    }

    Context "Function Signatures" {
        It "Install-Tailscale should return Result" {
            $cmd = Get-Command Install-Tailscale
            $cmd.OutputType.Name | Should -Contain "Result"
        }

        It "Repair-Tailscale should return Result" {
            $cmd = Get-Command Repair-Tailscale
            $cmd.OutputType.Name | Should -Contain "Result"
        }

        It "Invoke-TailscaleAudit should return Result" {
            $cmd = Get-Command Invoke-TailscaleAudit
            $cmd.OutputType.Name | Should -Contain "Result"
        }
    }

    Context "Parameter Validation" {
        It "Install-Tailscale should accept Platform parameter" {
            (Get-Command Install-Tailscale).Parameters.Keys | Should -Contain "Platform"
        }

        It "Install-Tailscale should accept SkipSSH parameter" {
            (Get-Command Install-Tailscale).Parameters.Keys | Should -Contain "SkipSSH"
        }

        It "Repair-Tailscale should accept Auto parameter" {
            (Get-Command Repair-Tailscale).Parameters.Keys | Should -Contain "Auto"
        }

        It "Invoke-TailscaleAudit should accept GenerateReport parameter" {
            (Get-Command Invoke-TailscaleAudit).Parameters.Keys | Should -Contain "GenerateReport"
        }
    }
}

Describe "CJC.Tailscale Module Code Quality" {
    Context "PSScriptAnalyzer Validation" {
        It "Should have PSScriptAnalyzer settings file" {
            $settingsPath = Join-Path -Path $PSScriptRoot -ChildPath '..\PSScriptAnalyzerSettings.psd1'
            Test-Path $settingsPath | Should -Be $true
        }

        It "Public functions should not have PSScriptAnalyzer errors" -Skip:(-not (Get-Module PSScriptAnalyzer -ErrorAction SilentlyContinue)) {
            $publicPath = Join-Path -Path $PSScriptRoot -ChildPath '..\Public'
            $settingsPath = Join-Path -Path $PSScriptRoot -ChildPath '..\PSScriptAnalyzerSettings.psd1'

            $results = Invoke-ScriptAnalyzer -Path $publicPath -Settings $settingsPath -Severity Error
            $results | Should -BeNullOrEmpty
        }

        It "Private functions should not have PSScriptAnalyzer errors" -Skip:(-not (Get-Module PSScriptAnalyzer -ErrorAction SilentlyContinue)) {
            $privatePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Private'
            $settingsPath = Join-Path -Path $PSScriptRoot -ChildPath '..\PSScriptAnalyzerSettings.psd1'

            $results = Invoke-ScriptAnalyzer -Path $privatePath -Settings $settingsPath -Severity Error
            $results | Should -BeNullOrEmpty
        }
    }

    Context "Module Structure" {
        It "Should have Public directory" {
            Test-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\Public') | Should -Be $true
        }

        It "Should have Private directory" {
            Test-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\Private') | Should -Be $true
        }

        It "Should have Classes directory" {
            Test-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\Classes') | Should -Be $true
        }

        It "Should have module manifest" {
            Test-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\CJC.Tailscale.psd1') | Should -Be $true
        }

        It "Should have module loader" {
            Test-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\CJC.Tailscale.psm1') | Should -Be $true
        }
    }

    Context "Help Documentation" {
        It "Install-Tailscale should have help" {
            $help = Get-Help Install-Tailscale
            $help.Name | Should -Not -BeNullOrEmpty
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It "Repair-Tailscale should have help" {
            $help = Get-Help Repair-Tailscale
            $help.Name | Should -Not -BeNullOrEmpty
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It "Invoke-TailscaleAudit should have help" {
            $help = Get-Help Invoke-TailscaleAudit
            $help.Name | Should -Not -BeNullOrEmpty
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }
    }
}

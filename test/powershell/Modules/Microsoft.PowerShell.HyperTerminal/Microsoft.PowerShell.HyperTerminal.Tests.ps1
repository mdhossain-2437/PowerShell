# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe "Microsoft.PowerShell.HyperTerminal Module" -Tags "CI" {

    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '..' '..' '..' '..' 'src' 'Modules' 'Shared' 'Microsoft.PowerShell.HyperTerminal'
        Import-Module $modulePath -Force
    }

    Context "Module Structure" {
        It "Module should be importable" {
            $module = Get-Module Microsoft.PowerShell.HyperTerminal
            $module | Should -Not -BeNullOrEmpty
            $module.Name | Should -BeExactly 'Microsoft.PowerShell.HyperTerminal'
        }

        It "Module should export expected functions" {
            $expectedFunctions = @(
                'Test-HyperTerminal',
                'Get-HyperPlugin',
                'Install-HyperPlugin',
                'Remove-HyperPlugin',
                'Get-HyperConfiguration',
                'Set-HyperConfiguration',
                'Enable-HyperShellIntegration',
                'Start-HyperPower',
                'Stop-HyperPower',
                'Get-HyperPowerOption',
                'Set-HyperPowerOption'
            )

            $module = Get-Module Microsoft.PowerShell.HyperTerminal
            foreach ($funcName in $expectedFunctions) {
                $module.ExportedFunctions.Keys | Should -Contain $funcName
            }
        }
    }

    Context "Test-HyperTerminal" {
        It "Should return false when TERM_PROGRAM is not set to Hyper" {
            $originalValue = $env:TERM_PROGRAM
            try {
                $env:TERM_PROGRAM = 'SomeOtherTerminal'
                Test-HyperTerminal | Should -BeFalse
            }
            finally {
                $env:TERM_PROGRAM = $originalValue
            }
        }

        It "Should return true when TERM_PROGRAM is Hyper" {
            $originalValue = $env:TERM_PROGRAM
            try {
                $env:TERM_PROGRAM = 'Hyper'
                Test-HyperTerminal | Should -BeTrue
            }
            finally {
                $env:TERM_PROGRAM = $originalValue
            }
        }

        It "Should return false when TERM_PROGRAM is not set" {
            $originalValue = $env:TERM_PROGRAM
            try {
                $env:TERM_PROGRAM = $null
                Test-HyperTerminal | Should -BeFalse
            }
            finally {
                $env:TERM_PROGRAM = $originalValue
            }
        }
    }

    Context "Get-HyperPlugin" {
        It "Should return a warning when config file does not exist" {
            $originalHome = $env:HOME
            try {
                $env:HOME = (Join-Path $TestDrive 'nonexistent')
                $result = Get-HyperPlugin 3>&1
                $result | Should -Not -BeNullOrEmpty
            }
            finally {
                $env:HOME = $originalHome
            }
        }
    }

    Context "Get-HyperConfiguration with test config" {
        BeforeAll {
            $script:testConfigHome = Join-Path $TestDrive 'HyperConfigTest'
            New-Item -Path $script:testConfigHome -ItemType Directory -Force | Out-Null

            $testConfigContent = @'
module.exports = {
  config: {
    fontSize: 14,
    fontFamily: '"Fira Code", monospace',
    cursorShape: 'BLOCK',
    shell: '/usr/bin/pwsh',
  },
  plugins: [
    'hyperpower',
    'hyper-search'
  ],
};
'@
            Set-Content -Path (Join-Path $script:testConfigHome '.hyper.js') -Value $testConfigContent
        }

        It "Should parse plugins from config content" {
            $originalHome = $env:HOME
            try {
                $env:HOME = $script:testConfigHome

                $config = Get-HyperConfiguration
                $config | Should -Not -BeNullOrEmpty
                $config.plugins | Should -Contain 'hyperpower'
                $config.plugins | Should -Contain 'hyper-search'
                $config.fontSize | Should -Be 14
            }
            finally {
                $env:HOME = $originalHome
            }
        }

        It "Should retrieve specific setting" {
            $originalHome = $env:HOME
            try {
                $env:HOME = $script:testConfigHome

                $fontSize = Get-HyperConfiguration -Setting 'fontSize'
                $fontSize | Should -Be 14
            }
            finally {
                $env:HOME = $originalHome
            }
        }
    }

    Context "Install-HyperPlugin and Remove-HyperPlugin with test config" {
        BeforeEach {
            $script:testInstallHome = Join-Path $TestDrive 'HyperInstallTest'
            New-Item -Path $script:testInstallHome -ItemType Directory -Force | Out-Null

            $testConfigContent = @'
module.exports = {
  config: {
    fontSize: 14,
  },
  plugins: [
    'existing-plugin'
  ],
};
'@
            Set-Content -Path (Join-Path $script:testInstallHome '.hyper.js') -Value $testConfigContent
        }

        It "Should add a new plugin" {
            $originalHome = $env:HOME
            try {
                $env:HOME = $script:testInstallHome

                Install-HyperPlugin -Name 'hyperpower' -Confirm:$false

                $content = Get-Content -Path (Join-Path $script:testInstallHome '.hyper.js') -Raw
                $content | Should -Match 'hyperpower'
            }
            finally {
                $env:HOME = $originalHome
            }
        }

        It "Should warn when plugin is already installed" {
            $originalHome = $env:HOME
            try {
                $env:HOME = $script:testInstallHome

                $result = Install-HyperPlugin -Name 'existing-plugin' -Confirm:$false 3>&1
                $result | Should -Not -BeNullOrEmpty
            }
            finally {
                $env:HOME = $originalHome
            }
        }

        It "Should remove an existing plugin" {
            $originalHome = $env:HOME
            try {
                $env:HOME = $script:testInstallHome

                Remove-HyperPlugin -Name 'existing-plugin' -Confirm:$false

                $content = Get-Content -Path (Join-Path $script:testInstallHome '.hyper.js') -Raw
                $content | Should -Not -Match "'existing-plugin'"
            }
            finally {
                $env:HOME = $originalHome
            }
        }
    }

    Context "Set-HyperConfiguration" {
        BeforeEach {
            $script:testSetHome = Join-Path $TestDrive 'HyperSetTest'
            New-Item -Path $script:testSetHome -ItemType Directory -Force | Out-Null

            $testConfigContent = @'
module.exports = {
  config: {
    fontSize: 14,
    fontFamily: '"Fira Code", monospace',
    cursorShape: 'BLOCK',
  },
  plugins: [],
};
'@
            Set-Content -Path (Join-Path $script:testSetHome '.hyper.js') -Value $testConfigContent
        }

        It "Should update fontSize setting" {
            $originalHome = $env:HOME
            try {
                $env:HOME = $script:testSetHome

                Set-HyperConfiguration -Setting 'fontSize' -Value '18' -Confirm:$false

                $content = Get-Content -Path (Join-Path $script:testSetHome '.hyper.js') -Raw
                $content | Should -Match 'fontSize\s*:\s*18'
            }
            finally {
                $env:HOME = $originalHome
            }
        }

        It "Should update cursorShape setting" {
            $originalHome = $env:HOME
            try {
                $env:HOME = $script:testSetHome

                Set-HyperConfiguration -Setting 'cursorShape' -Value 'BEAM' -Confirm:$false

                $content = Get-Content -Path (Join-Path $script:testSetHome '.hyper.js') -Raw
                $content | Should -Match "cursorShape\s*:\s*'BEAM'"
            }
            finally {
                $env:HOME = $originalHome
            }
        }
    }

    Context "Enable-HyperShellIntegration" {
        It "Should warn when not running in Hyper terminal" {
            $originalValue = $env:TERM_PROGRAM
            try {
                $env:TERM_PROGRAM = 'NotHyper'
                $result = Enable-HyperShellIntegration 3>&1
                $result | Should -Not -BeNullOrEmpty
            }
            finally {
                $env:TERM_PROGRAM = $originalValue
            }
        }
    }

    Context "HyperPower - Get-HyperPowerOption" {
        It "Should return all options as a PSCustomObject" {
            $options = Get-HyperPowerOption
            $options | Should -Not -BeNullOrEmpty
            $options.PSObject.Properties.Name | Should -Contain 'MaxParticles'
            $options.PSObject.Properties.Name | Should -Contain 'ParticleGravity'
            $options.PSObject.Properties.Name | Should -Contain 'ParticleAlphaFadeout'
            $options.PSObject.Properties.Name | Should -Contain 'Colors'
            $options.PSObject.Properties.Name | Should -Contain 'WowMode'
            $options.PSObject.Properties.Name | Should -Contain 'WowColors'
            $options.PSObject.Properties.Name | Should -Contain 'ParticleChars'
            $options.PSObject.Properties.Name | Should -Contain 'FrameIntervalMs'
            $options.PSObject.Properties.Name | Should -Contain 'Enabled'
        }

        It "Should return default values matching hyperpower constants" {
            $options = Get-HyperPowerOption
            $options.MaxParticles | Should -Be 500
            $options.ParticleGravity | Should -Be 0.075
            $options.ParticleAlphaFadeout | Should -Be 0.96
            $options.AlphaMinThreshold | Should -Be 0.1
            $options.Enabled | Should -BeFalse
            $options.WowMode | Should -BeFalse
        }

        It "Should return specific option by name" {
            $gravity = Get-HyperPowerOption -Name 'ParticleGravity'
            $gravity | Should -Be 0.075
        }

        It "Should return default particle velocity ranges matching hyperpower" {
            $vx = Get-HyperPowerOption -Name 'ParticleVelocityX'
            $vy = Get-HyperPowerOption -Name 'ParticleVelocityY'
            $vx[0] | Should -Be -1
            $vx[1] | Should -Be 1
            $vy[0] | Should -Be -3.5
            $vy[1] | Should -Be -1.5
        }

        It "Should have default colors defined" {
            $colors = Get-HyperPowerOption -Name 'Colors'
            $colors | Should -Not -BeNullOrEmpty
            $colors.Count | Should -BeGreaterThan 0
            $colors[0].R | Should -BeOfType [int]
            $colors[0].G | Should -BeOfType [int]
            $colors[0].B | Should -BeOfType [int]
        }

        It "Should have wow colors defined with at least 4 colors" {
            $wowColors = Get-HyperPowerOption -Name 'WowColors'
            $wowColors | Should -Not -BeNullOrEmpty
            $wowColors.Count | Should -BeGreaterOrEqual 4
        }

        It "Should have default particle characters" {
            $chars = Get-HyperPowerOption -Name 'ParticleChars'
            $chars | Should -Not -BeNullOrEmpty
            $chars.Count | Should -BeGreaterThan 0
        }

        It "Should have spawn range of 5-10 matching hyperpower PARTICLE_NUM_RANGE" {
            $numRange = Get-HyperPowerOption -Name 'ParticleNumRange'
            $numRange[0] | Should -Be 5
            $numRange[1] | Should -Be 10
        }
    }

    Context "HyperPower - Set-HyperPowerOption" {
        AfterEach {
            # Reset to defaults and clean up any timers/handlers
            & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                Stop-AnimationLoop
                Unregister-HyperPowerKeyHandlers
                $script:HyperPowerOptions = $null
                Initialize-HyperPowerState
            }
        }

        It "Should update WowMode option" {
            Set-HyperPowerOption -Name 'WowMode' -Value $true
            Get-HyperPowerOption -Name 'WowMode' | Should -BeTrue
        }

        It "Should update ParticleGravity option" {
            Set-HyperPowerOption -Name 'ParticleGravity' -Value 0.2
            Get-HyperPowerOption -Name 'ParticleGravity' | Should -Be 0.2
        }

        It "Should update MaxParticles option" {
            Set-HyperPowerOption -Name 'MaxParticles' -Value 200
            Get-HyperPowerOption -Name 'MaxParticles' | Should -Be 200
        }

        It "Should update ParticleChars option" {
            Set-HyperPowerOption -Name 'ParticleChars' -Value @('x', 'o', '+')
            $chars = Get-HyperPowerOption -Name 'ParticleChars'
            $chars | Should -Contain 'x'
            $chars | Should -Contain 'o'
            $chars | Should -Contain '+'
        }

        It "Should update Colors option" {
            $newColors = @(
                @{ R = 0; G = 255; B = 0 },
                @{ R = 0; G = 200; B = 0 }
            )
            Set-HyperPowerOption -Name 'Colors' -Value $newColors
            $colors = Get-HyperPowerOption -Name 'Colors'
            $colors[0].G | Should -Be 255
            $colors[1].G | Should -Be 200
        }

        It "Should update FrameIntervalMs option" {
            Set-HyperPowerOption -Name 'FrameIntervalMs' -Value 100
            Get-HyperPowerOption -Name 'FrameIntervalMs' | Should -Be 100
        }
    }

    Context "HyperPower - Particle Creation (New-Particle)" {
        It "Should create a particle with correct position" {
            $particle = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                New-Particle -X 15 -Y 10 -Color @{ R = 255; G = 100; B = 0 }
            }
            $particle | Should -Not -BeNullOrEmpty
            $particle.X | Should -Be 15
            $particle.Y | Should -Be 10
        }

        It "Should create a particle with alpha of 1.0" {
            $particle = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                New-Particle -X 0 -Y 0 -Color @{ R = 255; G = 255; B = 255 }
            }
            $particle.Alpha | Should -Be 1.0
        }

        It "Should create a particle with correct color" {
            $particle = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                New-Particle -X 0 -Y 0 -Color @{ R = 128; G = 64; B = 32 }
            }
            $particle.Color.R | Should -Be 128
            $particle.Color.G | Should -Be 64
            $particle.Color.B | Should -Be 32
        }

        It "Should create a particle with velocity within configured ranges" {
            $particle = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                New-Particle -X 0 -Y 0 -Color @{ R = 255; G = 255; B = 255 }
            }
            # Default velocity ranges: X=[-1,1], Y=[-3.5,-1.5]
            $particle.VelocityX | Should -BeGreaterOrEqual -1.0
            $particle.VelocityX | Should -BeLessOrEqual 1.0
            $particle.VelocityY | Should -BeGreaterOrEqual -3.5
            $particle.VelocityY | Should -BeLessOrEqual -1.5
        }

        It "Should assign a character from ParticleChars" {
            $particle = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                New-Particle -X 0 -Y 0 -Color @{ R = 255; G = 255; B = 255 }
            }
            $chars = Get-HyperPowerOption -Name 'ParticleChars'
            $particle.Char | Should -BeIn $chars
        }
    }

    Context "HyperPower - Particle Physics (Update-ParticlePhysics)" {
        BeforeAll {
            $script:testOpts = @{
                ParticleGravity      = 0.075
                ParticleAlphaFadeout = 0.96
                AlphaMinThreshold    = 0.1
                MaxParticles         = 500
            }
        }

        It "Should apply gravity to particle velocity" {
            $particles = [System.Collections.ArrayList]::new()
            [void]$particles.Add(@{
                X = 10.0; Y = 10.0; Alpha = 1.0
                Color = @{R=255;G=255;B=255}
                VelocityX = 0.0; VelocityY = 0.0
                Char = '.'
            })

            $resultList = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                param($p, $o)
                Update-ParticlePhysics -ParticleList $p -Option $o
            } $particles $script:testOpts

            # PowerShell unwraps single-element ArrayList, so handle both cases
            $result = if ($resultList -is [System.Collections.ArrayList]) { $resultList[0] } else { $resultList }
            $result.VelocityY | Should -Be 0.075
        }

        It "Should update particle position by velocity" {
            $particles = [System.Collections.ArrayList]::new()
            [void]$particles.Add(@{
                X = 10.0; Y = 10.0; Alpha = 1.0
                Color = @{R=255;G=255;B=255}
                VelocityX = 2.0; VelocityY = -1.0
                Char = '.'
            })

            $resultList = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                param($p, $o)
                Update-ParticlePhysics -ParticleList $p -Option $o
            } $particles $script:testOpts

            $result = if ($resultList -is [System.Collections.ArrayList]) { $resultList[0] } else { $resultList }
            $result.X | Should -Be 12.0
            # Y = 10 + (-1 + 0.075) = 10 - 0.925 = 9.075
            $result.Y | Should -BeGreaterThan 9.0
            $result.Y | Should -BeLessThan 10.0
        }

        It "Should apply alpha fadeout" {
            $particles = [System.Collections.ArrayList]::new()
            [void]$particles.Add(@{
                X = 10.0; Y = 10.0; Alpha = 1.0
                Color = @{R=255;G=255;B=255}
                VelocityX = 0.0; VelocityY = 0.0
                Char = '.'
            })

            $resultList = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                param($p, $o)
                Update-ParticlePhysics -ParticleList $p -Option $o
            } $particles $script:testOpts

            $result = if ($resultList -is [System.Collections.ArrayList]) { $resultList[0] } else { $resultList }
            $result.Alpha | Should -Be 0.96
        }

        It "Should remove particles below alpha threshold" {
            $particles = [System.Collections.ArrayList]::new()
            [void]$particles.Add(@{
                X = 10.0; Y = 10.0; Alpha = 0.05
                Color = @{R=255;G=255;B=255}
                VelocityX = 0.0; VelocityY = 0.0
                Char = '.'
            })

            $result = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                param($p, $o)
                Update-ParticlePhysics -ParticleList $p -Option $o
            } $particles $script:testOpts

            $result.Count | Should -Be 0
        }

        It "Should trim particles to MaxParticles limit" {
            $particles = [System.Collections.ArrayList]::new()
            $limitOpts = @{
                ParticleGravity      = 0.075
                ParticleAlphaFadeout = 0.96
                AlphaMinThreshold    = 0.1
                MaxParticles         = 3
            }

            for ($i = 0; $i -lt 5; $i++) {
                [void]$particles.Add(@{
                    X = [double]$i; Y = 10.0; Alpha = 1.0
                    Color = @{R=255;G=255;B=255}
                    VelocityX = 0.0; VelocityY = 0.0
                    Char = '.'
                })
            }

            $result = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                param($p, $o)
                Update-ParticlePhysics -ParticleList $p -Option $o
            } $particles $limitOpts

            $result.Count | Should -Be 3
        }

        It "Should eventually fade all particles to zero over many frames" {
            $particles = [System.Collections.ArrayList]::new()
            for ($i = 0; $i -lt 10; $i++) {
                [void]$particles.Add(@{
                    X = [double]$i; Y = 10.0; Alpha = 1.0
                    Color = @{R=255;G=255;B=255}
                    VelocityX = 0.0; VelocityY = -2.0
                    Char = '.'
                })
            }

            # Run 200 frames - all particles should fade out
            $current = $particles
            for ($frame = 0; $frame -lt 200; $frame++) {
                $current = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                    param($p, $o)
                    Update-ParticlePhysics -ParticleList $p -Option $o
                } $current $script:testOpts
                if ($current.Count -eq 0) { break }
            }

            $current.Count | Should -Be 0
        }
    }

    Context "HyperPower - ANSI Color Conversion" {
        It "Should produce valid ANSI RGB escape sequence at full alpha" {
            $result = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                ConvertTo-AnsiColorString -Color @{ R = 255; G = 100; B = 0 } -Alpha 1.0
            }
            $result | Should -Match '^\x1b\[38;2;\d+;\d+;\d+m$'
            $result | Should -BeLike '*255;100;0*'
        }

        It "Should scale colors by alpha for brightness fading" {
            $result = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                ConvertTo-AnsiColorString -Color @{ R = 200; G = 100; B = 50 } -Alpha 0.5
            }
            $result | Should -Match '^\x1b\[38;2;\d+;\d+;\d+m$'
            # At 0.5 alpha: R=100, G=50, B=25
            $result | Should -BeLike '*100;50;25*'
        }

        It "Should clamp colors to 0-255 range" {
            $result = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                ConvertTo-AnsiColorString -Color @{ R = 300; G = -10; B = 128 } -Alpha 1.0
            }
            $result | Should -Match '^\x1b\[38;2;\d+;\d+;\d+m$'
            # R should be clamped to 255, G to 0
            $result | Should -BeLike '*255;0;128*'
        }
    }

    Context "HyperPower - Particle Display Character" {
        It "Should return particle char when alpha is high" {
            $result = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                Get-ParticleDisplayChar -Particle @{ Alpha = 0.9; Char = '*' }
            }
            $result | Should -Be '*'
        }

        It "Should return dot when alpha is medium" {
            $result = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                Get-ParticleDisplayChar -Particle @{ Alpha = 0.5; Char = '*' }
            }
            $result | Should -Be '.'
        }

        It "Should return dot when alpha is low" {
            $result = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                Get-ParticleDisplayChar -Particle @{ Alpha = 0.2; Char = '*' }
            }
            $result | Should -Be '.'
        }
    }

    Context "HyperPower - Start and Stop" {
        AfterEach {
            # Always clean up
            Stop-HyperPower
            & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                $script:HyperPowerOptions = $null
                Initialize-HyperPowerState
            }
        }

        It "Should enable the Enabled flag when started" {
            # Start-HyperPower may warn about PSReadLine in CI, but should still set flags
            Start-HyperPower 3>&1 | Out-Null
            Get-HyperPowerOption -Name 'Enabled' | Should -BeTrue
        }

        It "Should disable the Enabled flag when stopped" {
            # Suppress PSReadLine warnings in CI (3>&1 redirects warning stream)
            Start-HyperPower 3>&1 | Out-Null
            Stop-HyperPower
            Get-HyperPowerOption -Name 'Enabled' | Should -BeFalse
        }

        It "Should enable WowMode when started with -WowMode" {
            # Suppress PSReadLine warnings in CI (3>&1 redirects warning stream)
            Start-HyperPower -WowMode 3>&1 | Out-Null
            Get-HyperPowerOption -Name 'WowMode' | Should -BeTrue
        }

        It "Should disable WowMode when stopped" {
            # Suppress PSReadLine warnings in CI (3>&1 redirects warning stream)
            Start-HyperPower -WowMode 3>&1 | Out-Null
            Stop-HyperPower
            Get-HyperPowerOption -Name 'WowMode' | Should -BeFalse
        }

        It "Should clear particles when stopped" {
            # Add some test particles
            & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                $script:HyperPowerOptions.Enabled = $true
                for ($i = 0; $i -lt 5; $i++) {
                    [void]$script:HyperPowerParticles.Add(@{
                        X = 10.0; Y = 10.0; Alpha = 1.0
                        Color = @{R=255;G=255;B=255}
                        VelocityX = 0.0; VelocityY = 0.0; Char = '.'
                    })
                }
            }

            Stop-HyperPower

            $particleCount = & (Get-Module Microsoft.PowerShell.HyperTerminal) {
                $script:HyperPowerParticles.Count
            }
            $particleCount | Should -Be 0
        }
    }
}

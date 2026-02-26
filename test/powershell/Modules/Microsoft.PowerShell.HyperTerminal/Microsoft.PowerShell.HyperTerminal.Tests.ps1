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
                'Enable-HyperShellIntegration'
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
}

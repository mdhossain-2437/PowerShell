# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Set-StrictMode -Version 3.0

#region HyperPower Particle Effect Engine

# Default configuration for the particle effect, matching hyperpower's behavior.
$script:HyperPowerDefaults = @{
    MaxParticles         = 500
    ParticleNumRange     = @(5, 10)
    ParticleGravity      = 0.075
    ParticleAlphaFadeout = 0.96
    ParticleVelocityX    = @(-1.0, 1.0)
    ParticleVelocityY    = @(-3.5, -1.5)
    AlphaMinThreshold    = 0.1
    Colors               = @(
        @{ R = 255; G = 255; B = 80 }
        @{ R = 255; G = 200; B = 40 }
        @{ R = 255; G = 150; B = 0 }
        @{ R = 255; G = 100; B = 20 }
    )
    WowMode              = $false
    WowColors            = @(
        @{ R = 255; G = 50;  B = 50 }
        @{ R = 50;  G = 255; B = 50 }
        @{ R = 50;  G = 100; B = 255 }
        @{ R = 255; G = 255; B = 50 }
        @{ R = 255; G = 50;  B = 255 }
        @{ R = 50;  G = 255; B = 255 }
        @{ R = 255; G = 165; B = 0 }
        @{ R = 200; G = 50;  B = 255 }
    )
    ParticleChars        = @('.', '*', '+', 'o')
    FrameIntervalMs      = 50
    Enabled              = $false
}

# Live state
$script:HyperPowerOptions = $null
$script:HyperPowerParticles = $null
$script:HyperPowerTimer = $null
$script:HyperPowerKeyHandlersRegistered = $false
$script:HyperPowerRandom = [System.Random]::new()

# Printable character set for key handler registration (built once, shared)
$script:PrintableChars = @()
for ($i = [int][char]'a'; $i -le [int][char]'z'; $i++) { $script:PrintableChars += [char]$i }
for ($i = [int][char]'A'; $i -le [int][char]'Z'; $i++) { $script:PrintableChars += [char]$i }
for ($i = [int][char]'0'; $i -le [int][char]'9'; $i++) { $script:PrintableChars += [char]$i }
$script:PrintableChars += @(' ', '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '-', '_', '=', '+',
    '[', ']', '{', '}', '\', '|', ';', ':', "'", '"', ',', '<', '.', '>', '/', '?', '`', '~')

function Initialize-HyperPowerState
{
    <#
    .SYNOPSIS
        Initializes or resets the particle engine state.
    #>
    [CmdletBinding()]
    param()

    if ($null -eq $script:HyperPowerOptions)
    {
        $script:HyperPowerOptions = @{}
        foreach ($key in $script:HyperPowerDefaults.Keys)
        {
            $script:HyperPowerOptions[$key] = $script:HyperPowerDefaults[$key]
        }
    }

    $script:HyperPowerParticles = [System.Collections.ArrayList]::new()
}

function New-Particle
{
    <#
    .SYNOPSIS
        Creates a new particle at the given terminal coordinates.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [int] $X,

        [Parameter(Mandatory)]
        [int] $Y,

        [Parameter(Mandatory)]
        [hashtable] $Color
    )

    $opts = $script:HyperPowerOptions
    $vxRange = $opts.ParticleVelocityX
    $vyRange = $opts.ParticleVelocityY
    $rng = $script:HyperPowerRandom

    return @{
        X        = [double]$X
        Y        = [double]$Y
        Alpha    = 1.0
        Color    = $Color
        VelocityX = $vxRange[0] + ($rng.NextDouble() * ($vxRange[1] - $vxRange[0]))
        VelocityY = $vyRange[0] + ($rng.NextDouble() * ($vyRange[1] - $vyRange[0]))
        Char     = $opts.ParticleChars[$rng.Next($opts.ParticleChars.Count)]
    }
}

function Add-ParticlesAtCursor
{
    <#
    .SYNOPSIS
        Spawns a batch of particles at the current cursor position.
    #>
    [CmdletBinding()]
    param()

    if ($null -eq $script:HyperPowerOptions -or -not $script:HyperPowerOptions.Enabled)
    {
        return
    }

    $particles = $script:HyperPowerParticles
    $opts = $script:HyperPowerOptions

    # Get cursor position
    $cursorX = [Console]::CursorLeft
    $cursorY = [Console]::CursorTop

    # Determine colors to use
    $colorSet = if ($opts.WowMode) { $opts.WowColors } else { $opts.Colors }

    # Spawn particles
    $rng = $script:HyperPowerRandom
    $numRange = $opts.ParticleNumRange
    $count = $numRange[0] + $rng.Next($numRange[1] - $numRange[0] + 1)

    for ($i = 0; $i -lt $count; $i++)
    {
        $color = $colorSet[$i % $colorSet.Count]
        $particle = New-Particle -X $cursorX -Y $cursorY -Color $color
        if ($particles.Count -lt $opts.MaxParticles)
        {
            [void]$particles.Add($particle)
        }
    }
}

function Update-ParticlePhysics
{
    <#
    .SYNOPSIS
        Updates particle positions and alpha values for one frame.
    .DESCRIPTION
        Applies gravity, velocity, and alpha fadeout to all active particles.
        Removes particles that have faded below the threshold.
    .OUTPUTS
        System.Collections.ArrayList of updated particles.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.ArrayList] $ParticleList,

        [Parameter(Mandatory)]
        [hashtable] $Option
    )

    $updatedParticles = [System.Collections.ArrayList]::new()

    foreach ($p in $ParticleList)
    {
        # Apply gravity
        $p.VelocityY += $Option.ParticleGravity

        # Update position
        $p.X += $p.VelocityX
        $p.Y += $p.VelocityY

        # Apply alpha fadeout
        $p.Alpha *= $Option.ParticleAlphaFadeout

        # Keep particle if still visible
        if ($p.Alpha -gt $Option.AlphaMinThreshold)
        {
            [void]$updatedParticles.Add($p)
        }
    }

    # Trim to max particles (keep newest)
    if ($updatedParticles.Count -gt $Option.MaxParticles)
    {
        $startIndex = $updatedParticles.Count - $Option.MaxParticles
        $trimmed = [System.Collections.ArrayList]::new()
        for ($i = $startIndex; $i -lt $updatedParticles.Count; $i++)
        {
            [void]$trimmed.Add($updatedParticles[$i])
        }

        return $trimmed
    }

    return $updatedParticles
}

function Get-ParticleDisplayChar
{
    <#
    .SYNOPSIS
        Returns the display character for a particle based on its alpha value.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Particle
    )

    $alpha = $Particle.Alpha

    if ($alpha -gt 0.7)
    {
        return $Particle.Char
    }
    else
    {
        return '.'
    }
}

function ConvertTo-AnsiColorString
{
    <#
    .SYNOPSIS
        Converts an RGB color hashtable and alpha to an ANSI escape sequence.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Color,

        [Parameter(Mandatory)]
        [double] $Alpha
    )

    # Scale RGB by alpha for brightness fading
    $r = [Math]::Max(0, [Math]::Min(255, [int]($Color.R * $Alpha)))
    $g = [Math]::Max(0, [Math]::Min(255, [int]($Color.G * $Alpha)))
    $b = [Math]::Max(0, [Math]::Min(255, [int]($Color.B * $Alpha)))

    return "`e[38;2;${r};${g};${b}m"
}

function Render-ParticleFrame
{
    <#
    .SYNOPSIS
        Renders one frame of the particle animation to the terminal.
    #>
    [CmdletBinding()]
    param()

    $particles = $script:HyperPowerParticles
    $opts = $script:HyperPowerOptions

    if ($null -eq $particles -or $particles.Count -eq 0)
    {
        return
    }

    $bufferWidth = [Console]::BufferWidth
    $bufferHeight = [Console]::BufferHeight

    # Build the complete frame as a single string to minimize flicker
    $frameBuilder = [System.Text.StringBuilder]::new()

    # Save cursor position
    [void]$frameBuilder.Append("`e7")

    foreach ($p in $particles)
    {
        $col = [Math]::Round($p.X)
        $row = [Math]::Round($p.Y)

        # Bounds check - only render particles within the visible terminal area
        if ($col -ge 0 -and $col -lt $bufferWidth -and $row -ge 0 -and $row -lt $bufferHeight)
        {
            $colorSeq = ConvertTo-AnsiColorString -Color $p.Color -Alpha $p.Alpha
            $displayChar = Get-ParticleDisplayChar -Particle $p

            # Move cursor to particle position (1-based), draw character
            $ansiRow = $row + 1
            $ansiCol = $col + 1
            [void]$frameBuilder.Append("`e[${ansiRow};${ansiCol}H")
            [void]$frameBuilder.Append($colorSeq)
            [void]$frameBuilder.Append($displayChar)
        }
    }

    # Reset color and restore cursor position
    [void]$frameBuilder.Append("`e[0m")
    [void]$frameBuilder.Append("`e8")

    # Write the entire frame at once
    [Console]::Write($frameBuilder.ToString())

    # Update physics for next frame
    $script:HyperPowerParticles = Update-ParticlePhysics -ParticleList $particles -Option $opts
}

function Start-AnimationLoop
{
    <#
    .SYNOPSIS
        Starts the background animation timer for particle rendering.
    #>
    [CmdletBinding()]
    param()

    if ($null -ne $script:HyperPowerTimer)
    {
        return
    }

    $timer = [System.Timers.Timer]::new($script:HyperPowerOptions.FrameIntervalMs)
    $timer.AutoReset = $true

    Register-ObjectEvent -InputObject $timer -EventName Elapsed -SourceIdentifier 'HyperPowerAnimation' -Action {
        try
        {
            # Only render if the module context is available
            $moduleContext = $Event.MessageData
            if ($null -ne $moduleContext)
            {
                & (Get-Module Microsoft.PowerShell.HyperTerminal) { Render-ParticleFrame }
            }
        }
        catch
        {
            # Silently ignore rendering errors to avoid disrupting the shell
        }
    } -MessageData $PSScriptRoot | Out-Null

    $timer.Start()
    $script:HyperPowerTimer = $timer
}

function Stop-AnimationLoop
{
    <#
    .SYNOPSIS
        Stops the background animation timer.
    #>
    [CmdletBinding()]
    param()

    if ($null -ne $script:HyperPowerTimer)
    {
        $script:HyperPowerTimer.Stop()
        $script:HyperPowerTimer.Dispose()
        $script:HyperPowerTimer = $null
    }

    # Unregister the event
    Get-EventSubscriber -SourceIdentifier 'HyperPowerAnimation' -ErrorAction SilentlyContinue |
        Unregister-Event -ErrorAction SilentlyContinue

    Get-Job -Name 'HyperPowerAnimation' -ErrorAction SilentlyContinue |
        Remove-Job -Force -ErrorAction SilentlyContinue
}

function Register-HyperPowerKeyHandlers
{
    <#
    .SYNOPSIS
        Registers PSReadLine key handlers to trigger particle spawning on keystrokes.
    #>
    [CmdletBinding()]
    param()

    if ($script:HyperPowerKeyHandlersRegistered)
    {
        return
    }

    # Check if PSReadLine is available
    $psReadLine = Get-Module PSReadLine -ErrorAction SilentlyContinue
    if ($null -eq $psReadLine)
    {
        Write-Warning "PSReadLine module is not loaded. HyperPower keyboard integration unavailable."
        return
    }

    # Register a handler for common printable characters
    foreach ($charKey in $script:PrintableChars)
    {
        try
        {
            Set-PSReadLineKeyHandler -Chord $charKey -ScriptBlock {
                param($key, $arg)
                # Insert the character normally
                [Microsoft.PowerShell.PSConsoleReadLine]::SelfInsert($key, $arg)
                # Spawn particles
                & (Get-Module Microsoft.PowerShell.HyperTerminal) { Add-ParticlesAtCursor }
            } -Description 'HyperPower particle effect' -ErrorAction SilentlyContinue
        }
        catch
        {
            # Some keys may not be bindable, skip them
        }
    }

    $script:HyperPowerKeyHandlersRegistered = $true
}

function Unregister-HyperPowerKeyHandlers
{
    <#
    .SYNOPSIS
        Removes PSReadLine key handlers for particle spawning.
    #>
    [CmdletBinding()]
    param()

    if (-not $script:HyperPowerKeyHandlersRegistered)
    {
        return
    }

    $psReadLine = Get-Module PSReadLine -ErrorAction SilentlyContinue
    if ($null -eq $psReadLine)
    {
        return
    }

    foreach ($charKey in $script:PrintableChars)
    {
        try
        {
            Remove-PSReadLineKeyHandler -Chord $charKey -ErrorAction SilentlyContinue
        }
        catch
        {
            # Ignore errors for keys that weren't bound
        }
    }

    $script:HyperPowerKeyHandlersRegistered = $false
}

# Initialize state on module load
Initialize-HyperPowerState

#endregion HyperPower Particle Effect Engine

#region Private Helpers

function Get-HyperConfigPath
{
    <#
    .SYNOPSIS
        Returns the path to the Hyper terminal configuration file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Hyper stores its configuration at ~/.hyper.js on all platforms
    $homePath = $env:HOME
    if ([string]::IsNullOrEmpty($homePath))
    {
        $homePath = $env:USERPROFILE
    }

    if ([string]::IsNullOrEmpty($homePath))
    {
        return $null
    }

    return Join-Path $homePath '.hyper.js'
}

function Read-HyperConfigContent
{
    <#
    .SYNOPSIS
        Reads the raw content of the Hyper configuration file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $configPath = Get-HyperConfigPath

    if (-not (Test-Path -Path $configPath))
    {
        return $null
    }

    return Get-Content -Path $configPath -Raw
}

function Get-PluginFromContent
{
    <#
    .SYNOPSIS
        Parses the plugins array from Hyper config content.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string] $Content
    )

    $pluginList = @()

    if ($Content -match 'plugins\s*:\s*\[([^\]]*)\]')
    {
        $pluginBlock = $Matches[1]
        $regexMatchResult = [regex]::Matches($pluginBlock, '''([^'']+)''|"([^"]+)"')

        foreach ($entry in $regexMatchResult)
        {
            $pluginName = if ($entry.Groups[1].Success) { $entry.Groups[1].Value } else { $entry.Groups[2].Value }
            $pluginList += $pluginName
        }
    }

    return $pluginList
}

#endregion Private Helpers

#region Public Functions

function Test-HyperTerminal
{
    <#
    .SYNOPSIS
        Tests whether the current PowerShell session is running inside Hyper terminal.
    .DESCRIPTION
        Detects Hyper terminal by checking the TERM_PROGRAM environment variable,
        which Hyper sets to 'Hyper' when launching a shell session.
    .EXAMPLE
        if (Test-HyperTerminal) { Write-Host 'Running in Hyper!' }
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $env:TERM_PROGRAM -eq 'Hyper'
}

function Get-HyperPlugin
{
    <#
    .SYNOPSIS
        Gets the list of installed Hyper terminal plugins.
    .DESCRIPTION
        Reads the Hyper terminal configuration file (.hyper.js) and returns
        the list of plugins defined in the plugins array.
    .EXAMPLE
        Get-HyperPlugin
    .EXAMPLE
        Get-HyperPlugin | Where-Object Name -eq 'hyperpower'
    .OUTPUTS
        PSCustomObject with Name property
    #>
    [CmdletBinding()]
    param()

    $content = Read-HyperConfigContent

    if ($null -eq $content)
    {
        $configPath = Get-HyperConfigPath
        Write-Warning "Hyper configuration file not found at '$configPath'. Is Hyper terminal installed?"
        return
    }

    $pluginNames = Get-PluginFromContent -Content $content

    foreach ($name in $pluginNames)
    {
        [PSCustomObject]@{
            PSTypeName = 'Microsoft.PowerShell.HyperTerminal.PluginInfo'
            Name       = $name
        }
    }
}

function Install-HyperPlugin
{
    <#
    .SYNOPSIS
        Installs a Hyper terminal plugin by adding it to the configuration.
    .DESCRIPTION
        Adds the specified plugin name to the plugins array in Hyper's
        configuration file (.hyper.js). Common plugins include 'hyperpower',
        'hyper-search', 'hyper-pane', 'hyper-opacity', and 'hypercwd'.
    .PARAMETER Name
        The name of the Hyper plugin to install (npm package name).
    .EXAMPLE
        Install-HyperPlugin -Name 'hyperpower'
    .EXAMPLE
        Install-HyperPlugin -Name 'hyper-search'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $configPath = Get-HyperConfigPath
    $content = Read-HyperConfigContent

    if ($null -eq $content)
    {
        Write-Error "Hyper configuration file not found at '$configPath'. Please install Hyper terminal first (https://hyper.is/)."
        return
    }

    $existingPlugins = Get-PluginFromContent -Content $content

    if ($existingPlugins -contains $Name)
    {
        Write-Warning "Plugin '$Name' is already installed."
        return
    }

    if ($PSCmdlet.ShouldProcess($configPath, "Add plugin '$Name'"))
    {
        if ($content -match '(plugins\s*:\s*\[)([^\]]*?)(\])')
        {
            $before = $Matches[1]
            $existing = $Matches[2].TrimEnd()
            $after = $Matches[3]

            $newEntry = if ([string]::IsNullOrWhiteSpace($existing))
            {
                "`n    '$Name'`n  "
            }
            else
            {
                "$existing,`n    '$Name'`n  "
            }

            $newContent = $content -replace 'plugins\s*:\s*\[[^\]]*\]', "${before}${newEntry}${after}"
            Set-Content -Path $configPath -Value $newContent -NoNewline
            Write-Verbose "Plugin '$Name' added to Hyper configuration."
        }
        else
        {
            Write-Error "Could not find the plugins array in the Hyper configuration file."
        }
    }
}

function Remove-HyperPlugin
{
    <#
    .SYNOPSIS
        Removes a Hyper terminal plugin from the configuration.
    .DESCRIPTION
        Removes the specified plugin name from the plugins array in Hyper's
        configuration file (.hyper.js).
    .PARAMETER Name
        The name of the Hyper plugin to remove.
    .EXAMPLE
        Remove-HyperPlugin -Name 'hyperpower'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $configPath = Get-HyperConfigPath
    $content = Read-HyperConfigContent

    if ($null -eq $content)
    {
        Write-Error "Hyper configuration file not found at '$configPath'."
        return
    }

    $existingPlugins = Get-PluginFromContent -Content $content

    if ($existingPlugins -notcontains $Name)
    {
        Write-Warning "Plugin '$Name' is not installed."
        return
    }

    if ($PSCmdlet.ShouldProcess($configPath, "Remove plugin '$Name'"))
    {
        # Remove the plugin entry and any trailing/leading comma
        $newContent = $content -replace ",\s*'$([regex]::Escape($Name))'", ''
        $newContent = $newContent -replace "'$([regex]::Escape($Name))'\s*,?", ''

        Set-Content -Path $configPath -Value $newContent -NoNewline
        Write-Verbose "Plugin '$Name' removed from Hyper configuration."
    }
}

function Get-HyperConfiguration
{
    <#
    .SYNOPSIS
        Gets Hyper terminal configuration settings.
    .DESCRIPTION
        Reads and parses key configuration settings from Hyper's configuration
        file (.hyper.js), including font settings, color scheme, shell path,
        and installed plugins.
    .PARAMETER Setting
        Optional specific setting name to retrieve. If not specified, returns
        all recognized settings.
    .EXAMPLE
        Get-HyperConfiguration
    .EXAMPLE
        Get-HyperConfiguration -Setting 'fontSize'
    .OUTPUTS
        PSCustomObject with configuration properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('fontSize', 'fontFamily', 'cursorShape', 'shell', 'plugins')]
        [string] $Setting
    )

    $content = Read-HyperConfigContent

    if ($null -eq $content)
    {
        $configPath = Get-HyperConfigPath
        Write-Error "Hyper configuration file not found at '$configPath'."
        return
    }

    $config = [ordered]@{
        PSTypeName = 'Microsoft.PowerShell.HyperTerminal.Configuration'
    }

    # Parse fontSize
    if ($content -match 'fontSize\s*:\s*(\d+)')
    {
        $config['fontSize'] = [int]$Matches[1]
    }

    # Parse fontFamily
    if ($content -match "fontFamily\s*:\s*['""]([^'""]+)['""]")
    {
        $config['fontFamily'] = $Matches[1]
    }

    # Parse cursorShape
    if ($content -match "cursorShape\s*:\s*['""]([^'""]+)['""]")
    {
        $config['cursorShape'] = $Matches[1]
    }

    # Parse shell
    if ($content -match "shell\s*:\s*['""]([^'""]+)['""]")
    {
        $config['shell'] = $Matches[1]
    }

    # Parse plugins
    $config['plugins'] = Get-PluginFromContent -Content $content

    $configObj = [PSCustomObject]$config

    if ($Setting)
    {
        return $configObj.$Setting
    }

    return $configObj
}

function Set-HyperConfiguration
{
    <#
    .SYNOPSIS
        Sets a Hyper terminal configuration value.
    .DESCRIPTION
        Modifies a configuration setting in Hyper's configuration file (.hyper.js).
    .PARAMETER Setting
        The name of the setting to modify.
    .PARAMETER Value
        The new value for the setting.
    .EXAMPLE
        Set-HyperConfiguration -Setting 'fontSize' -Value '16'
    .EXAMPLE
        Set-HyperConfiguration -Setting 'cursorShape' -Value 'BEAM'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('fontSize', 'fontFamily', 'cursorShape')]
        [string] $Setting,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Value
    )

    $configPath = Get-HyperConfigPath
    $content = Read-HyperConfigContent

    if ($null -eq $content)
    {
        Write-Error "Hyper configuration file not found at '$configPath'."
        return
    }

    if ($PSCmdlet.ShouldProcess($configPath, "Set $Setting to '$Value'"))
    {
        $newContent = switch ($Setting)
        {
            'fontSize'
            {
                $content -replace "(fontSize\s*:\s*)\d+", "`${1}$Value"
            }

            'fontFamily'
            {
                $content -replace "(fontFamily\s*:\s*)['""][^'""]*['""]", "`${1}'$Value'"
            }

            'cursorShape'
            {
                $content -replace "(cursorShape\s*:\s*)['""][^'""]*['""]", "`${1}'$Value'"
            }
        }

        Set-Content -Path $configPath -Value $newContent -NoNewline
        Write-Verbose "Hyper configuration '$Setting' updated to '$Value'."
    }
}

function Enable-HyperShellIntegration
{
    <#
    .SYNOPSIS
        Enables shell integration features for Hyper terminal.
    .DESCRIPTION
        Configures the current PowerShell session with Hyper-optimized settings
        including ANSI output rendering, OSC escape sequences for window title
        updates, and prompt customization for Hyper plugin compatibility.

        This enables features that Hyper addons like 'hyperpower' and
        'hyper-pane' can use for enhanced terminal experiences.
    .PARAMETER EnableOSCTitle
        Enables OSC escape sequences for dynamic window title updates.
    .EXAMPLE
        Enable-HyperShellIntegration
    .EXAMPLE
        Enable-HyperShellIntegration -EnableOSCTitle
    #>
    [CmdletBinding()]
    param(
        [switch] $EnableOSCTitle
    )

    if (-not (Test-HyperTerminal))
    {
        Write-Warning "Not running inside Hyper terminal. Shell integration may not work as expected."
    }

    # Ensure ANSI output rendering is enabled for Hyper compatibility
    if ($PSStyle)
    {
        $PSStyle.OutputRendering = 'Ansi'
        Write-Verbose "ANSI output rendering enabled."
    }

    # Set up OSC title sequences if requested
    if ($EnableOSCTitle)
    {
        # OSC 0 - Set window title to current directory
        function global:prompt
        {
            $currentPath = $executionContext.SessionState.Path.CurrentLocation.Path
            $host.UI.Write("`e]0;PS $currentPath`a")
            "PS $currentPath> "
        }

        Write-Verbose "OSC window title integration enabled."
    }

    Write-Verbose "Hyper shell integration enabled."
}

function Start-HyperPower
{
    <#
    .SYNOPSIS
        Enables the HyperPower particle spark effect in the current PowerShell session.
    .DESCRIPTION
        Activates particle effects inspired by the Hyper terminal 'hyperpower' addon.
        When enabled, typing characters spawns colorful particles that fly outward from
        the cursor position with gravity, velocity, and alpha fadeout — creating a
        visual "wow" effect directly in the terminal.

        The effect uses ANSI escape sequences with RGB colors and works in terminals
        that support VT100/xterm-256color (including Hyper, Windows Terminal, VS Code,
        and most modern terminal emulators).

        Uses PSReadLine key handlers to detect keystrokes and a background timer
        for particle animation.
    .PARAMETER WowMode
        Enables multi-color wow mode. When on, particles use a rainbow color palette
        instead of the default warm gold/orange colors.
    .EXAMPLE
        Start-HyperPower
    .EXAMPLE
        Start-HyperPower -WowMode
    #>
    [CmdletBinding()]
    param(
        [switch] $WowMode
    )

    Initialize-HyperPowerState

    $script:HyperPowerOptions.Enabled = $true

    if ($WowMode)
    {
        $script:HyperPowerOptions.WowMode = $true
    }

    # Ensure ANSI output is enabled
    if ($PSStyle)
    {
        $PSStyle.OutputRendering = 'Ansi'
    }

    # Register key handlers for particle spawning
    Register-HyperPowerKeyHandlers

    # Start the animation loop
    Start-AnimationLoop

    if ($WowMode)
    {
        Write-Host "`e[38;2;255;255;50mWOW`e[38;2;255;150;0m such on`e[0m"
    }
    else
    {
        Write-Verbose "HyperPower particle effects enabled."
    }
}

function Stop-HyperPower
{
    <#
    .SYNOPSIS
        Disables the HyperPower particle spark effect.
    .DESCRIPTION
        Stops the particle animation, removes key handlers, and cleans up resources.
    .EXAMPLE
        Stop-HyperPower
    #>
    [CmdletBinding()]
    param()

    # Stop animation
    Stop-AnimationLoop

    # Remove key handlers
    Unregister-HyperPowerKeyHandlers

    # Clear particles
    if ($null -ne $script:HyperPowerParticles)
    {
        $script:HyperPowerParticles.Clear()
    }

    if ($null -ne $script:HyperPowerOptions)
    {
        $wasWow = $script:HyperPowerOptions.WowMode
        $script:HyperPowerOptions.Enabled = $false
        $script:HyperPowerOptions.WowMode = $false

        if ($wasWow)
        {
            Write-Host "`e[38;2;255;255;50mWOW`e[38;2;255;150;0m such off`e[0m"
        }
        else
        {
            Write-Verbose "HyperPower particle effects disabled."
        }
    }
}

function Get-HyperPowerOption
{
    <#
    .SYNOPSIS
        Gets the current HyperPower particle effect settings.
    .DESCRIPTION
        Returns the current configuration for the particle effects including
        colors, physics parameters, particle characters, and enabled state.
    .PARAMETER Name
        Optional specific setting name to retrieve.
    .EXAMPLE
        Get-HyperPowerOption
    .EXAMPLE
        Get-HyperPowerOption -Name 'Colors'
    .EXAMPLE
        Get-HyperPowerOption -Name 'WowMode'
    .OUTPUTS
        PSCustomObject with all settings, or the value of a specific setting.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('MaxParticles', 'ParticleNumRange', 'ParticleGravity',
            'ParticleAlphaFadeout', 'ParticleVelocityX', 'ParticleVelocityY',
            'AlphaMinThreshold', 'Colors', 'WowMode', 'WowColors',
            'ParticleChars', 'FrameIntervalMs', 'Enabled')]
        [string] $Name
    )

    Initialize-HyperPowerState

    if ($Name)
    {
        return $script:HyperPowerOptions[$Name]
    }

    $result = [ordered]@{
        PSTypeName = 'Microsoft.PowerShell.HyperTerminal.HyperPowerOptions'
    }

    foreach ($key in $script:HyperPowerOptions.Keys | Sort-Object)
    {
        $result[$key] = $script:HyperPowerOptions[$key]
    }

    return [PSCustomObject]$result
}

function Set-HyperPowerOption
{
    <#
    .SYNOPSIS
        Sets a HyperPower particle effect configuration option.
    .DESCRIPTION
        Modifies particle effect settings such as colors, physics parameters,
        particle characters, and animation speed. Changes take effect immediately
        if HyperPower is currently running.
    .PARAMETER Name
        The name of the setting to modify.
    .PARAMETER Value
        The new value for the setting. Type depends on the setting:
        - MaxParticles: [int] Maximum number of active particles (default: 500)
        - ParticleNumRange: [int[]] Min and max particles per keystroke (default: 5,10)
        - ParticleGravity: [double] Downward acceleration (default: 0.075)
        - ParticleAlphaFadeout: [double] Alpha multiplier per frame, 0-1 (default: 0.96)
        - ParticleVelocityX: [double[]] Min/max horizontal velocity (default: -1,1)
        - ParticleVelocityY: [double[]] Min/max vertical velocity (default: -3.5,-1.5)
        - AlphaMinThreshold: [double] Alpha below which particles are removed (default: 0.1)
        - Colors: [hashtable[]] Array of @{R=;G=;B=} color hashtables
        - WowMode: [bool] Enable multi-color wow mode
        - WowColors: [hashtable[]] Colors used in wow mode
        - ParticleChars: [string[]] Characters used for particles (default: '.','*','+','o')
        - FrameIntervalMs: [int] Animation frame interval in milliseconds (default: 50)
    .EXAMPLE
        Set-HyperPowerOption -Name 'WowMode' -Value $true
    .EXAMPLE
        Set-HyperPowerOption -Name 'ParticleGravity' -Value 0.15
    .EXAMPLE
        Set-HyperPowerOption -Name 'Colors' -Value @(@{R=0;G=255;B=0}, @{R=0;G=200;B=0})
    .EXAMPLE
        Set-HyperPowerOption -Name 'ParticleChars' -Value @('*', '.', '+', 'x')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('MaxParticles', 'ParticleNumRange', 'ParticleGravity',
            'ParticleAlphaFadeout', 'ParticleVelocityX', 'ParticleVelocityY',
            'AlphaMinThreshold', 'Colors', 'WowMode', 'WowColors',
            'ParticleChars', 'FrameIntervalMs')]
        [string] $Name,

        [Parameter(Mandatory, Position = 1)]
        [object] $Value
    )

    Initialize-HyperPowerState
    $script:HyperPowerOptions[$Name] = $Value
    Write-Verbose "HyperPower option '$Name' updated."
}

#endregion Public Functions

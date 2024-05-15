<#
.SYNOPSIS
    Bitdefender Installer

.DESCRIPTION
    This PowerShell script is intended to be used in a RMM solution (e. g. Solarwinds N-able RMM or Riversuit Riverbird).

.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does

.INPUTS
    No parameters. Variables are supposed to be set by the rmm solution this script is used in.

.OUTPUTS
    No Outputs. Exits with Exit Code 0 if Bitdefender was already or was just now installed succesfully. Exit Code 1 if something went wrong.

.LINK
    https://github.com/MichaelSchoenburg/Bitdefender-Installer

.NOTES
    Author: Michael Schönburg
    Version: v1.0
    
    This projects code loosely follows the PowerShell Practice and Style guide, as well as Microsofts PowerShell scripting performance considerations.
    Style guide: https://poshcode.gitbook.io/powershell-practice-and-style/
    Performance Considerations: https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/performance/script-authoring-considerations?view=powershell-7.1
#>

#region INITIALIZATION
<# 
    Libraries, Modules, ...
#>

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]'Tls11,Tls12'

#endregion INITIALIZATION
#region DECLARATIONS
<#
    Declare local variables and global variables
#>


# The following variables should be set through your rmm solution. 
# Here some examples of possible declarations with explanations for each variable.
# Tip: PowerShell variables are not case sensitive.

<# 
    $Base64DownloadLink # ID of the installation package
    $DownloadPath # Location where the downloaded installer should be saved.
#>

#endregion DECLARATIONS
#region FUNCTIONS
<# 
    Declare Functions
#>

function Write-ConsoleLog {
    <#
        .SYNOPSIS
        Logs an event to the console.
        
        .DESCRIPTION
        Writes text to the console with the current date (US format) in front of it.
        
        .PARAMETER Text
        Event/text to be outputted to the console.
        
        .EXAMPLE
        Write-ConsoleLog -Text 'Subscript XYZ called.'
        
        Long form

        .EXAMPLE
        Log 'Subscript XYZ called.
        
        Short form
    #>

    [alias('Log')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
        Position = 0)]
        [string]
        $Text
    )

    # Save current VerbosePreference
    $VerbosePreferenceBefore = $VerbosePreference

    # Enable verbose output
    $VerbosePreference = 'Continue'

    # Write verbose output
    Write-Output "$( Get-Date -Format 'MM/dd/yyyy HH:mm:ss' ) - $( $Text )"

    # Restore current VerbosePreference
    $VerbosePreference = $VerbosePreferenceBefore
}

#endregion FUNCTIONS
#region EXECUTION
<# 
    Script entry point
#>

if ((Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*").DisplayName -eq 'Bitdefender Endpoint Security Tools') {
    # If it's already installed, just do nothing
    Log "Bitdefender already installed. Exiting."
    Exit 0
} else {    
    # If it isn't already installed, start installation
    $BitdefenderUrl = "setupdownloader_[$Base64DownloadLink].exe"
    $BaseURL = "https://cloud.gravityzone.bitdefender.com/Packages/BSTWIN/0/"
    $URL = $BaseURL + $BitdefenderUrl

    $DownloadFilename = "setupdownloader.exe"
    $DownloadFullpath = Join-Path -Path $DownloadPath -ChildPath $DownloadFilename

    $NewName = "setupdownloader_[$Base64DownloadLink].exe"
    $FinalName = Join-Path -Path $DownloadPath -ChildPath $NewName

    # Check if a previous attempt failed, leaving the installer in the temp directory and breaking the script
    $DownloadFullpath, $FinalName | ForEach-Object {
        if (Test-Path $_) {
            Remove-Item $_
            Log "Removed $_..."
        }
    }

    # Create directory if not already existent
    if (-not (Test-Path $DownloadPath)) {
        New-Item -ItemType Directory -Path $DownloadPath
    }

    try {
        Log "Beginning download of Bitdefender to $DownloadFullpath."
        Invoke-WebRequest -Uri $URL -OutFile $DownloadFullpath
    }
    catch {
        Log "Error Downloading - $_.Exception.Response.StatusCode.value_"
        Log $_
        Exit 1
    }

    Rename-Item -Path $DownloadFullpath -NewName $NewName
    Log "Download succeeded, beginning install..."
    Start-Process -FilePath $FinalName -ArgumentList "/bdparams /silent silent" -Wait -NoNewWindow

    # Wait an additional 30 seconds after the installer process completes to verify installation
    Start-Sleep -Seconds 30

    if ((Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*").DisplayName -eq 'Bitdefender Endpoint Security Tools') {
        Log "Bitdefender successfully installed."
        Exit 0
    } else {
        Log "ERROR: Failed to install Bitdefender"
        Exit 1
    }
}

#endregion EXECUTION

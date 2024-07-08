<#
    .SYNOPSIS
	Installs fonts globally on Windows 10 and Windows 11.

    .ROLE
    Installs and registers fonts on a Windows system for all users on a system.

    .DESCRIPTION

    .PARAMETER SourcePath
	
    .PARAMETER DestPath

    .EXAMPLE
	Install-WindowsFonts.ps1 -SourcePath "\\MyFileserver\RemoteShare\Fonts\" -DestPath "C:\Scripts\Fonts\"
	Will copy fonts from a remote directory to a local directory and proceed to install them.  It's assumed that there is access to the remote file share, without credentials.

    .EXAMPLE
	Install-WindowFonts.ps1 -SourcePath "D:\MyUSBstick\Fonts\" -DestPath "C:\Scripts\Fonts\"
	Will copy fonts from an attached drive, like a USB drive, and proceed to install them. It's assumed that there is permissioned access to the attached drive.

    .INPUTS
	String. (SourcePath) - String. blah blah blah
	String. (DestPath) - String. blah blah blah

    .OUTPUTS
	This script has verbose logging.  Logs are stored in "C:\ProgramData\Font-Install\fontInstallLogs.txt" (if it's ran in administrative mode).
	
	This is a hidden directory, so it won't be readily apparent if you looking through Windows Explorer.
	
	Logging will record timestamps on:
	- The start of each run
	- Running without administrative privileges
	- Creating of a new local directory (Success/Failure)
	- Success/Failure of font installation
	- 
 
    .COMPONENT
    Font Management

    .FUNCTIONALITY
    Font Installation

    .LINK
	https://github.com/Michael-Free/Install-Fonts-Powershell
	
    .LINK
	https://www.reddit.com/r/PowerShell/comments/zk8w09/deploying_font_for_all_users/

    .LINK
	https://github.com/PPOSHGROUP/PPoShTools/blob/master/PPoShTools/Public/FileSystem/Add-Font.ps1

    .LINK
	https://blog.simontimms.com/2021/06/11/installing-fonts/

    .NOTES
	- This script requires Administrative Privileges to modify the registry and install the fonts globally.
	- If not ran with administrative privileges, logs may be stored in another global directory. Windows userspace is so disjointed, I don't really care anymore #RunBSD.
	- 
 
#>

param (
	[Parameter(Mandatory=$true)]
	[string]$SourcePath,

	[Parameter(Mandatory=$true)]
	[string]$DestPath
)

class Logger {
    [string]$LogFilePath

    Logger([string]$logFilePath) {
        $this.LogFilePath = $logFilePath
    }

    [void] Log([string]$message) {
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $logEntry = "$timestamp - $message"
        Add-Content -Path $this.LogFilePath -Value $logEntry
    }
}

$logpath = Join-Path -Path $env:ALLUSERSPROFILE -ChildPath "Font-Install"

if (-Not (Test-Path -Path $logpath -PathType Container)) {
    try {
        New-Item -Path $logpath -ItemType Directory -Force
        (Get-Item -Path $logpath).Attributes += 'Hidden'
    } catch {
        Write-Error "Unable to create logpath directory: $_"
    }
}

$logger = [Logger]::new("$logpath\fontInstallLogs.txt")
$logger.Log("Started")

function Test-Admin {
	$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
	$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentUser)
	$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	return $isAdmin
}

function Add-Font {
	# Modified from: https://github.com/PPOSHGROUP/PPoShTools/blob/master/PPoShTools/Public/FileSystem/Add-Font.ps1
	# Modified from: https://www.reddit.com/r/PowerShell/comments/zk8w09/deploying_font_for_all_users/
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string]$FontPath,

		[Parameter(Mandatory = $false)]
		[switch]$Force
	)

	begin {
		$FontsFolder = "$env:SystemRoot\Fonts"
		$RegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
	}

	process {
		try {
			$FontName = (Get-Item $FontPath).Name
			$DestinationPath = Join-Path -Path $FontsFolder -ChildPath $FontName

			if (Test-Path $DestinationPath) {
				if (-not $Force) {
					$logger.Log("Font $FontName already exists. Use -Force to replace.")
					return
				} else {
					Remove-Item $DestinationPath -Force
				}
			}

			Copy-Item -Path $FontPath -Destination $DestinationPath -Force

			$fontExtension = [System.IO.Path]::GetExtension($FontName)
			switch ($fontExtension) {
				'.ttf' { $FontType = 'TrueType' }
				default { throw "Unsupported font extension: $fontExtension" }
			}

			Set-ItemProperty -Path $RegistryPath -Name $FontName -Value $FontName -Type String
			$logger.Log("Font $FontName installed successfully.")
		} catch {
			$logger.Log("Failed to add font. Error: $_")
		}
	}
}


if (-not (Test-Admin)) {
	$logger.Log("Not running with Admin privileges.")
	Exit 1
}

if (-not (Test-Path -Path $DestPath -PathType Container)) {
	try {
		New-Item -Path $DestPath -ItemType Directory -ErrorAction Stop
		$logger.Log("Created new directory in $DestPath")
	} catch {
		$logger.Log("Failed to create destination directory. Error: $_")
		Exit 1
	}
}

if (-not (Test-Path -Path $SourcePath -PathType Container)) {
	$logger.Log("Source Path unavailable")
	Exit 1
}

$destFileArray = (Get-ChildItem -Path $DestPath -File).Name | Where-Object { $_ -like '*.ttf' } | Sort-Object -Descending
$sourceFileArray = (Get-ChildItem -Path $SourcePath -File).Name | Where-Object { $_ -like '*.ttf' } | Sort-Object -Descending
$missingFiles = $sourceFileArray | Where-Object { $destFileArray -NotContains $_ }

if ($missingFiles.count -gt 0) {
	foreach ($mf in $missingFiles) {
		try {
			Copy-Item -Path "$SourcePath\$mf" -Destination "$DestPath\$mf"
			$logger.Log("Adding $SourcePath\$mf to $DestPath\$mf")
		} catch {
			$logger.Log("Unable to copy font to local path: $_")
		}
	}
}

foreach ($font in $sourceFileArray) {
	try {
		$logger.Log("Adding font: $font")
		Add-Font -FontPath "$DestPath\$font" -Force
	} catch {
		$logger.Log( "Unable to add font $font - $_")
	}
}

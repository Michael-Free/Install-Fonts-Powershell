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

#$logpath = ""
## Check Logpath
#$logger = [Logger]::new("C:\LogFile.txt")
#$logger.Log("Script Start")

function Test-Admin {
	$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
	$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentUser)

	$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

	return $isAdmin
}

function Add-Font {
	# Modified from https://github.com/PPOSHGROUP/PPoShTools/blob/master/PPoShTools/Public/FileSystem/Add-Font.ps1
	# https://www.reddit.com/r/PowerShell/comments/zk8w09/deploying_font_for_all_users/
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
					write-output "Font $FontName already exists. Use -Force to replace."
					return
				} else {
					Remove-Item $DestinationPath -Force
				}
			}

			Copy-Item -Path $FontPath -Destination $DestinationPath -Force

			$fontExtension = [System.IO.Path]::GetExtension($FontName)
			switch ($fontExtension) {
				'.ttf' { $FontType = 'TrueType' }
				'.otf' { $FontType = 'OpenType' }
				default { throw "Unsupported font extension: $fontExtension" }
			}

			Set-ItemProperty -Path $RegistryPath -Name $FontName -Value $FontName -Type String
			write-output "Font $FontName installed successfully."
		} catch {
			Write-Error "Failed to add font. Error: $_"
		}
	}
}


if (-not (Test-Admin)) {
	Write-Error 'Not running with Admin privileges.'
	Exit 1
}

if (-not (Test-Path -Path $DestPath -PathType Container)) {
	try {
		New-Item -Path $DestPath -ItemType Directory -ErrorAction Stop
	} catch {
		Write-Error "Failed to create directory. Error: $_"
		Exit 1
	}
}

if (-not (Test-Path -Path $SourcePath -PathType Container)) {
	Write-Error "Source Path unavailable"
	Exit 1
}

$destFileArray = (Get-ChildItem -Path $DestPath -File).Name | Where-Object { $_ -like '*.ttf' } | Sort-Object -Ascending
$sourceFileArray = (Get-ChildItem -Path $SourcePath -File).Name | Where-Object { $_ -like '*.ttf' } | Sort-Object -Ascending

$missingFiles = $sourceFileArray | Where-Object { $destFileArray -NotContains $_ }

if ($missingFiles.count -gt 0) {
	foreach ($mf in $missingFiles) {
		try {
			Copy-Item -Path "$SourcePath\$mf" -Destination "$DestPath\$mf"
		} catch {
			Write-Error "Unable to copy font to local path: $_"
		}
	}
}

foreach ($font in $sourceFileArray) {
	try {
		Add-Font -FontPath "$DestPath\$font" -Force
	} catch {
		Write-Error "Unable to add font: $_"
	}
	
}

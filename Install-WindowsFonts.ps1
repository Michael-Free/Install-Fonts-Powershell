param (
	[Parameter(Mandatory=$true)]
	[string]$SourcePath,

	[Parameter(Mandatory=$true)]
	[string]$DestPath
)

function Test-Admin {
	$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
	$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentUser)

	$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

	return $isAdmin
}

function Add-Font {
	# Modified from https://github.com/PPOSHGROUP/PPoShTools/blob/master/PPoShTools/Public/FileSystem/Add-Font.ps1
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

$isAdmin = Test-Admin
$directoryPath = 'C:\Scripts\Fonts\'
$remoteFileShare = '\\MyRemoteFile\Share\'

if (-not $isAdmin) {
	Write-Error 'Not running with Admin privileges.'
	Exit 1
}

if (-not (Test-Path -Path $directoryPath -PathType Container)) {
	try {
		New-Item -Path $directoryPath -ItemType Directory -ErrorAction Stop
	} catch {
		Write-Error "Failed to create directory. Error: $_"
		Exit 1
	}
}

if (-not (Test-Path -Path $remoteFileShare -PathType Container)) {
	Write-Error "File Share unavailable"
	Exit 1
}

$localFileArray = (Get-ChildItem -Path $directoryPath -File).Name | Where-Object { $_ -like '*.ttf' } | Sort-Object -Ascending
$remoteFileArray = (Get-ChildItem -Path $remoteFileShare -File).Name | Where-Object { $_ -like '*.ttf' } | Sort-Object -Ascending

$missingFiles = $remoteFileArray | Where-Object { $localFileArray -NotContains $_ }

if ($missingFiles.count -gt 0) {
	foreach ($mf in $missingFiles) {
		Copy-Item -Path "$remoteFileShare\$mf" -Destination "$directoryPath\$mf"
	}
}

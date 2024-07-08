# Install-Fonts-Powershell
Installing fonts (globally) in Windows 10 and Windows 11 with PowerShell.

## Description
This script will install fonts on a Windows 10/11 system and register them for use by all users on a system (after a reboot).

Fonts are no longer installed in the "old way" where fonts were merely copied over to `C:\Windows\Fonts\`.  This changed around Windows 10 1803. Fonts are now copied to `C:\Windows\Fonts\`, but they also have to be added to the registry. 
    
For context, this script is intended to be used in an Active Directory situation via Group Policy Objects. Typically fonts will be copied over from a fileshare to a local machine, and installed from there. This script will work outside of this use case, however it may not be the intended audience.

While other font formats may work, only *.ttf type fonts are tested and offically supported.

## Usage
```Install-WindowsFonts.ps1 -SourcePath "\\MyFileserver\RemoteShare\Fonts\" -DestPath "C:\Scripts\Fonts\"``` 

Will copy fonts from a remote directory to a local directory and proceed to install them.  It's assumed that there is access to the remote file share, without credentials.

```Install-WindowFonts.ps1 -SourcePath "D:\MyUSBstick\Fonts\" -DestPath "C:\Scripts\Fonts\"```

Will copy fonts from an attached drive, like a USB drive, and proceed to install them. It's assumed that there is permissioned access to the attached drive.

## Why?

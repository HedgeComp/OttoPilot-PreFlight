<#
.SYNOPSIS
    Companion Script to HYPERPILOT Testing Toolg from Getrubix.com
    Prepares and mounts a HyperPilot template VHDX, copies preflight scripts and resources
    into the Template VHDX image, and then dismounts the VHDX.

.DESCRIPTION
    This script locates a VHDX template in `C:\HYPERPILOT\Templates`, It will list all VHDX Temaplats found and then prompt for Selection.
    It then mounts the selected template, copies files from `C:\HYPERPILOT\PreFlight\Scripts` in the .\Reources folder of the VHDX.
    It then copies a file `hyperset.bat` into the mounted image, and places the
    batch file into the VM's `Windows\System32` when applicable. Finally the
    image is dismounted. And New VMs can be built using HyperPilot with all your preloaded tools included.

.NOTES
    - Must have Installed HYPERPILOT by Getrubix.com https://hyperpilot.getrubix.com/
    - HYPER PILOT Must be isntalled to the Default folders.
    - Requires running PowerShell as Administrator (see `#Requires -RunAsAdministrator`).
    - Hyper-V must be enabled and the current user must have permission to mount VHDs.
    - Tested on Windows 11 with PowerShell 5.1+ and Hyper-V.
    - File: `Staging\preflight.ps1`

.EXAMPLE
    Start an elevated PowerShell session and run:
        .\preflight.ps1

.AUTHOR
    Scott McDonnell

.REVISION
    1.0  2025-11-17  Initial Release
#>

#Requires -RunAsAdministrator

Write-Host "Looking for HYPER PILOT Template Disks..."
$VHDTemplateFolder = "C:\HYPERPILOT\Templates"

#Check if the VHD Template folder exists
if (Test-Path -Path $VHDTemplateFolder) {

$VHDTemplates = @(Get-ChildItem -Path $VHDTemplateFolder -File)

if ($VHDTemplates.Count -eq 0) {
    Write-Warning "No HyperPilot VHDX templates found in: $VHDTemplateFolder"
    Write-Warning "Check your Installation folders and try again"
    exit 1
}


#If more than one VHDX template is found, prompt user to select one
if ($VHDTemplates.Count -gt 1)
{
Write-Host "Select a file from the list below:"

 do {
        for ($i = 1; $i -le $VHDTemplates.Count; $i++) {
        Write-Host "[$i] Windows 11 $($VHDTemplates[$i - 1].BaseName)"
        }
         $selection = Read-Host "`nEnter the number of the file you want"
    } until ($selection -match '^\d+$'-and [int]$selection -ge 1 -and [int]$selection -le $VHDTemplates.Count)

    $index = [int]$selection - 1
    $VHDPath = $VHDTemplates[$index].FullName



}
#If only one VHDX template is found, use it directly
else {
    Write-Host "Found VM Template $($VHDTemplates[0].BaseName) "
    $VHDPath = $VHDTemplates[0].FullName
}

#try to mount the selected VHDX templates
try {
    Write-Host "Attempting to Mounting HyperPilot Template VHDX..."
$DriveLetter = (
            Mount-VHD -Path $VHDPath -PassThru -ErrorAction Stop |
            Get-Disk |
            Get-Partition |
            Get-Volume |
            Select-Object -ExpandProperty DriveLetter -ErrorAction Stop
        )

Write-Host "VHDX mounted to drive letter: $DriveLetter"
    $mounted = $true
}
catch{
 Write-Host "Flight is Cancelled - No VHDX Mounted"   
 Write-Error "Failed to mount Templates VHDX: $($_.Exception.Message)"
 exit 1
}

# Define the Preflight source path)
$LocalFlightPath = "C:\HYPERPILOT\PreFlight"

# Define the destination folders path using the $DriveLetter variable
# (Assuming $DriveLetter is set to the correct drive letter, like "E")
$DestinationPath = "$($DriveLetter):\resources"
$VMSystem32 = "$($DriveLetter):\windows\system32"

#Check if the local Scripts folder source path exists
if (Test-Path -Path "$LocalFlightPath\scripts") {
    Write-Host "Source path found: $LocalFlightPath"

    #Check if the destination directory exists, and create it if it doesn't
    if (!(Test-Path -Path $DestinationPath)) {
        Write-Host "Destination path not found. Creating directory..."
        New-Item -Path $DestinationPath -ItemType Directory | Out-Null
    }
#Try to copy hyperset.bat to VM System32 for quick launch troubebleshooting
    $fileName = 'hyperset.bat'
    $filePath = Join-Path -Path $LocalFlightPath -ChildPath "staging\$fileName"

    if (Test-Path -Path $filePath -PathType Leaf) {
        Write-Host "The file '$fileName' exists at $filePath."
        Write-Host "Copying file '$fileName' to $VMSystem32."
        try {
            Copy-Item -Path $filePath -Destination $VMSystem32 -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to copy $fileName to $VMSystem32: $($_.Exception.Message)"
        }
    } else {
        Write-Host "The file '$fileName' was not found at $filePath."
    }

 #Try to copy any Test Script files from the Preflight\Scripts to the Templates Resources Folder  
    try {
        Copy-Item -Path (Join-Path $LocalFlightPath 'Scripts') -Destination $DestinationPath -Recurse -Force -ErrorAction Stop
        Write-Host "Scripts File copied successfully to $DestinationPath"
    }
    catch {
        Write-Warning "Failed to copy scripts to $DestinationPath: $($_.Exception.Message)"
    }

} else {
    Write-Error "Source path not found: $LocalFlightPath. No files copied."
}

#dismount VHDX template
if ($mounted -and $VHDPath) {
    Write-Host "VHDX Dismounting.."
    try {
        Dismount-VHD -Path $VHDPath -ErrorAction Stop
        Write-Host "HyperPilot Template VHDX Dismounted "
    }
    catch {
        Write-Warning "Failed to dismount VHDX: $($_.Exception.Message)"
        Write-Warning "Manual dismount may be required. Use File Explorer to Eject the drive $DriveLetter"
    }
}

#Success Message . Create your HyperPilot VM now.
Write-Host "Congratulations — your Pre-Flight Checks are complete" -ForegroundColor Green
Write-Host "You can now engage your Otto-Pilot ;)"  -ForegroundColor Green

}

#Check Failure Message. Check the HYPERPilot Installation Folders for VM TEmplates. 
else{
Write-Warning "HYPER PILOT VHDX Templates not found at: $VHDTemplates "
Write-Warning "Check your Installation folders and try again"
}
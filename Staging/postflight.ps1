<#
.SYNOPSIS
    Mounts a HyperPilot Created VM, collects VM hardware hash CSV file
    from the mounted image and copies them to a local folder for Autopilot upload.

.DESCRIPTION
    This script searches `C:\HyperPilot\Virtual Hard Disks` for a VHDX template,
    mounts the selected image, locates VM Virtual MAchines Hash saved as a CSV file under the VM's `resources`
    C;\Resource folder. It then copies those files to the host's `C:\HyperPilot\PreFlight\VMHash`
    directory, then dismounts the VHDX.

.NOTES
    - Requires HYPERPILOT by Getrubix.com https://hyperpilot.getrubix.com/
    - Requires the VM to have already run running Get-AutopilotCommunittyinfo.ps1 to create VM Hash to Autopilot
    - Hyper-V must be enabled and the current user must have permission to mount VHDs.
    - Requires running PowerShell as Administrator (see `#Requires -RunAsAdministrator`).
    - Tested on Windows 11 with PowerShell 5.1+ and Hyper-V.
    - File: `Staging\postflight.ps1`

.BONUS 
    To Create the VM Hash files quickly, you can run the decryptandprep.ps1 script included with Preflight.
    When the VM loads in OOBE simply press SHIFT+F10 to open a command prompt.
    Then type "hyperset.bat"
    run .\scripts\decryptandprep.ps1 will run and prepare the VM for Autopilot and create the VM Hash files.
    Then run this script.
   
.EXAMPLE
    Start an elevated PowerShell session and run:
        .\postflight.ps1

.AUTHOR
    Scott McDonnell

.REVISION
    1.0  2025-11-17  Initial comment-based help added
#>

#Requires -RunAsAdministrator

Write-Host "Looking for HYPER PILOT Virtual Disks..."
$VHDTemplateFolder = "C:\HyperPilot\Virtual Hard Disks"
#Check if the VHD Template folder exists
if (Test-Path -Path $VHDTemplateFolder) {

# Ensure we have an array and check for zero templates
$VHDTemplates = @(Get-ChildItem -Path $VHDTemplateFolder -File)

# Check to see if any VM Disks exist
if ($VHDTemplates.Count -eq 0) {
    Write-Warning "No HyperPilot VHDX templates found in: $VHDTemplateFolder"
    Write-Warning "Check that you've created at least one HyperPilot VM"
    exit 1
}
#If more than one VHDX template is found, prompt user to select one
elseif ($VHDTemplates.Count -gt 1)
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
else {
    Write-Host "Found VM Template $($VHDTemplates[0].BaseName) "
    $VHDPath = $VHDTemplates[0].FullName
}
#try to mount the selected VHDX templates
try {

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
 Write-Error "Failed to mount Templates VHDX: $($_.Exception.Message)"
    exit 1

}

# Define your Local path to store the hash file
$LocalPath = "C:\HyperPilot\PreFlight\VMHash"

# Define the destination folder path using the $DriveLetter variable
# (Assuming $DriveLetter is set to the correct drive letter, like "E")
$VMResourcesPath = "$($DriveLetter):\resources"

#Check if the local VMHash folder path exists
 if (!(Test-Path -Path $LocalPath)) {
    Write-Host "Local VMHash Folder Not found: Creating."
    New-Item -Path $LocalPath -ItemType Directory | Out-Null

}

else{
Write-Host "Local VMHash Folder found: $LocalPath"
}
  
# Check if the Resource directory exists on VMDK
if (!(Test-Path -Path $VMResourcesPath)) {
    Write-Warning "Resource folder not found on VM: $VMResourcesPath"
    if ($mounted -and $VHDPath) {
        try {
            Dismount-VHD -Path $VHDPath -ErrorAction Stop
            Write-Host "HYPER PILOT VHDX Dismounted "
        }
        catch {
            Write-Warning "Failed to dismount VHDX after missing resources: $($_.Exception.Message)"
        }
    }
    exit 1
}

# Enumerate CSV files and copy them safely
$csvFiles = Get-ChildItem -Path $VMResourcesPath -Filter "*.csv" -File -ErrorAction SilentlyContinue
if ($csvFiles -and $csvFiles.Count -gt 0) {
    Write-Host "CSV files found. Copying..."
    try {
        foreach ($file in $csvFiles) {
            Copy-Item -Path $file.FullName -Destination $LocalPath -Force -ErrorAction Stop
        }
        Write-Host "CSV files copied to $LocalPath"
    }
    catch {
        Write-Warning "Failed to copy CSV files from $VMResourcesPath to $LocalPath: $($_.Exception.Message)"
    }
}
else {
    Write-Host "No CSV Hash files found in $VMResourcesPath"
}

#dismount VHDX template
if ($mounted -and $VHDPath) {
    Write-Host "VHDX Dismounting.."
    try {
        Dismount-VHD -Path $VHDPath -ErrorAction Stop
        Write-Host "HYPER PILOT VHDX Dismounted "
    }
    catch {
        Write-Warning "Failed to dismount VHDX: $($_.Exception.Message)"
    }
}

Write-Host "Congratulations — your Post-Flight Checks are complete" -ForegroundColor Green
}

#Check Failure Message. Check the HYPERPilot Installation Folders for VM Disks. 
else{
Write-Warning "HyperPilot VHDX Disks not found at: $VHDTemplates "
Write-Warning "Check that you've created one HyperPilot"
}
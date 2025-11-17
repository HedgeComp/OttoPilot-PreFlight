
<#V1 release to collect the HArdware Hash For Autopilot Upload#>
#Requires -RunAsAdministrator

Write-Host "Looking for HYPER PILOT Virtual Disks..."
$VHDTemplateFolder = "C:\HyperPilot\Virtual Hard Disks"

if (Test-Path -Path $VHDTemplateFolder) {

$VHDTemplates = Get-ChildItem -Path $VHDTemplateFolder -File

if ($VHDTemplates.Count -eq 0  )
{
Write-Host "No Hyperpilot Disks Found."
Write-host "Check that you've created at least one HyperPilot VM"
exit 1

}
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

try {
     #$vhd = Mount-VHD -Path $VHDPath -PassThru -ErrorAction Stop
$DriveLetter = (
            Mount-VHD -Path $VHDPath -PassThru -ErrorAction Stop |
            Get-Disk |
            Get-Partition |
            Get-Volume |
            Select-Object -ExpandProperty DriveLetter -ErrorAction Stop
        )

Write-Host "VHDX mounted to drive letter: $DriveLetter"
}
catch{
 Write-Error "Failed to mount Templates VHDX: $($_.Exception.Message)"
    exit 1

}

# Define your source path (e.g., C:\SourceFolder)
$LocalPath = "C:\HyperPilot\PreFlight\VMHash"

# Define the destination folder path using the $DriveLetter variable
# (Assuming $DriveLetter is set to the correct drive letter, like "E")
$VMResourcesPath = "$($DriveLetter):\resources"
#$VMSystem32 = "$($DriveLetter):\windows\system32"



# 1. Check if the local VMHast folder path exists
 if (!(Test-Path -Path $LocalPath)) {
    Write-Host "Local VMHash Folder Not found: Creating."
    New-Item -Path $LocalPath -ItemType Directory | Out-Null

}

else{
Write-Host "Local VMHash Folder found: $LocalPath"
}
  
# 2. Check if the Resource directory exists on VMDK
if (!(Test-Path -Path $VMResourcesPath)) {
        Write-Host "Resource folder not found. "
        exit 1
    }

    if (Get-ChildItem -Path $VMResourcesPath -Filter "*.csv" -File) {
    Write-Host "CSV files found. Copying..."
    Copy-Item -Path "$VMResourcesPath\*.csv" -Destination $LocalPath -Force
    }
 else {
    Write-Host "No CSV Hash files found in $VMResourcesPath"
    }
Write-Host "VHDX Dismounting.."
Dismount-VHD -Path $VHDPath
Write-Host "HYPER PILOT VHDX Dismounted "
Write-Host "Congradulations your Post-Flight Checks are complete" -ForegroundColor Green
Write-Host "You can not upload your VM Hash to Autopilot."  -ForegroundColor Green

}

else{
Write-Warning "HyperPilot VHDX Disks not found at: $VHDTemplates "
Write-Warning "Check that you've created one HyperPilot"
}
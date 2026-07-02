#Requires -RunAsAdministrator


Write-Host "Looking for HYPER PILOT Config"
#$VHDTemplateFolder = "C:\HYPERPILOT\Templates" ## This was assumed to be default but we will now read the config.json file to get the path to the Templates folder

$ConfigPath = Join-Path -Path $env:APPDATA -ChildPath "HYPERPILOT\config.json"

if (-not (Test-Path -Path $ConfigPath)) {
    Write-Warning "Config file not found at: $ConfigPath"
    exit 1
}

try {
    $Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
}
catch {
    Write-Warning "Failed to parse config.json. Check that it contains valid JSON."
    Write-Warning $_.Exception.Message
    exit 1
}

if (-not $Config.PSObject.Properties.Name -contains "VMFolderPath" -or [string]::IsNullOrWhiteSpace($Config.VMFolderPath)) {
    Write-Warning "VMFolderPath not found or empty in: $ConfigPath"
    exit 1
}

$VMFolderPath = $Config.VMFolderPath

Write-Host "Found VM Folder Path: $VMFolderPath" -foregroundcolor Green
$VHDTemplateFolder = Join-Path -Path $VMFolderPath -ChildPath "Templates"

Write-Host "Looking for HYPER PILOT Template Disks in: $VHDTemplateFolder"

if (Test-Path -Path $VHDTemplateFolder) {

$VHDTemplates = Get-ChildItem -Path $VHDTemplateFolder -File

if ($VHDTemplates.Count -gt 1)
{
Write-Host "VHDX templates found. Please select one from the list below:" -ForegroundColor Green
#Write-Host "Select the vhdx template from the list below:"

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
$LocalPath = "C:\HYPERPILOT\PreFlight"

# Define the destination folder path using the $DriveLetter variable
# (Assuming $DriveLetter is set to the correct drive letter, like "E")
$DestinationPath = "$($DriveLetter):\resources"
$VMSystem32 = "$($DriveLetter):\windows\system32"

# 1. Check if the local Scripts folder source path exists
if (Test-Path -Path "$LocalPath\scripts") {
    Write-Host "Source path found: $LocalPath"

    # 2. Check if the destination directory exists, and create it if it doesn't
    if (!(Test-Path -Path $DestinationPath)) {
        Write-Host "Destination path not found. Creating directory..."
        New-Item -Path $DestinationPath -ItemType Directory | Out-Null
    }

    $filename= "hyperset.bat"
    $filepath = "$LocalPath\staging\$filename"
    
if (Test-Path -Path $filepath -PathType Leaf) {#(Test-Path -Path $LocalPath\staging\hyperset.bat -PathType Leaf) {
    Write-Host "The file '$FileName' exists at $FilePath."
    Write-Host "Copying file '$FileName' to $VMSystem32."
    Copy-Item -Path $filepath -Destination $VMSystem32 -Recurse -Force
} else {
    Write-Host "The file '$FileName' was not found."
}
 # 3. Copy Our Test Script files from the source to the Templates Resources Folder
   
    Copy-Item -Path "$LocalPath\Scripts" -Destination $DestinationPath -Recurse -Force
    Write-Host "Files copied successfully to $DestinationPath"

} else {
    Write-Error "Source path not found: $LocalPath. No files copied."
}

Write-Host "VHDX Dismounting.."
Dismount-VHD -Path $VHDPath
Write-Host "HyperPilot Template VHDX Dismounted "
Write-Host "Congradulations your Pre-Flight Checks are complete" -ForegroundColor Green
Write-Host "You can now engage your Otto-Pilot ;)"  -ForegroundColor Green

}



else{
Write-Warning "HYPER PILOT VHDX Templates not found at: $VHDTemplates "
Write-Warning "Check your Installation folders and try again"
}
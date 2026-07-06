<#
.SYNOPSIS
    Prepares a HyperPilot Template Disk for Autopilot enrollment by adding user defined scripts and files to the mounted VHDX image.

.DESCRIPTION
    This script searches HyperPilot VMDX Templates from a path defined
    in the HyperPilot config. It will then mount the VHDX disk for the selected image, and copies necessary files to the mounted image
    It will also copy any user defined scripts and files to the mounted image found in the `.\HyperPilot\PreFlight\Scripts` directory,
    to allow for the tools to be availbe on all future VMs crated by the HyperPilot Template Disk. Once the files are copied, the VHDX
    will be dismounted and ready for use for cloning and creating new VMs in HyperPilot for Autopilot testing.

.NOTES
    - Requires HYPERPILOT by Getrubix.com https://hyperpilot.getrubix.com/
    - Hyper-V must be enabled and the current user must have permission to mount VHDs.
    - Requires running PowerShell as Administrator (see `#Requires -RunAsAdministrator`).
    - Tested on Windows 11 with PowerShell 5.1+ and Hyper-V.
    - Preflight needs to be run anytime you update your Scripts or a new Template is pushed to the '.\HyperPilot\Templates' folder. 
    

.BONUS 
    To Create the VM Hash files quickly, you can run the decryptandprep.ps1 script included with Preflight.
    Started the VM and when it loads in OOBE simply press SHIFT+F10 to open a command prompt.
    Then type "hyperset.bat"
    run .\scripts\decryptandprep.ps1 will run and prepare the VM for Autopilot and create the VM Hash files as a csv file by default.
    Then run the postflight.ps1 script to collect the VM Hash and prepare the VM for Autopilot testing.
   
.EXAMPLE
    Start an elevated PowerShell session and run:
        .\preflight.ps1

.AUTHOR
    Scott McDonnell

.REVISION
    1.0  2025-11-17  Initial comment
    2.0  2026-07-06  Added logging and error handling for better user experience. Dynamically finds the HyperPilot VM folder path from config.json and prompts user to select a VM to process. 
         
 #>
#Requires -RunAsAdministrator

# log function
function log()
{
    Param(
        [Parameter(Mandatory=$True)]
        [string]$message
    )
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss tt"
    Write-Output "$date - $message"
}


Log "Looking for HYPER PILOT Config"
#$VHDTemplateFolder = "C:\HYPERPILOT\Templates" ## This was assumed to be default but we will now read the config.json file to get the path to the Templates folder

$HyperConfigPath = Join-Path -Path $env:APPDATA -ChildPath "HYPERPILOT\config.json"

if (-not (Test-Path -Path $HyperConfigPath)) {
    Write-Warning "Config file not found at: $HyperConfigPath"
    exit 1
}

try {
    $HyperConfig = Get-Content -Path $HyperConfigPath -Raw | ConvertFrom-Json
}
catch {
    Write-Warning "Failed to parse config.json. Check that it contains valid JSON."
    Write-Warning $_.Exception.Message
    exit 1
}

if (-not $HyperConfig.PSObject.Properties.Name -contains "VMFolderPath" -or [string]::IsNullOrWhiteSpace($HyperConfig.VMFolderPath)) {
    Write-Warning "VMFolderPath not found or empty in: $HyperConfigPath"
    exit 1
}

# Find the VMFolderPath from the config.json file
$VMFolderPath = $HyperConfig.VMFolderPath
Log "Found VM Folder Path: $VMFolderPath" #-ForegroundColor Green
$VHDTemplateFolder = Join-Path -Path $VMFolderPath -ChildPath "Templates"

Log "Looking for HYPER PILOT Template Disks in: $VHDTemplateFolder"

if (Test-Path -Path $VHDTemplateFolder) {
    # Only consider .vhdx template files
    $VHDTemplates = Get-ChildItem -Path $VHDTemplateFolder -File -Filter *.vhdx

    if ($VHDTemplates.Count -gt 1) {
        Write-Host "Multiple HyperPilot VHDX templates found." -ForegroundColor Green

        $index = 1
        $vmTable = foreach ($template in $VHDTemplates) {
            [pscustomobject]@{
                Number = $index
                'HyperPilot-Template' = $template.BaseName
            }
            $index++
        }

        do {
            $vmTable | Format-Table -AutoSize | Out-Host

            # Prompt in yellow, then read input
            Write-Host -NoNewline -ForegroundColor Yellow "Enter the number of the Template you want to update: "
            $selection = Read-Host
        } until ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $vmTable.Count)

        $selectedTemplate = $vmTable | Where-Object { $_.Number -eq [int]$selection } | Select-Object -First 1
        $VHDPath = $VHDTemplates[([int]$selection - 1)].FullName
        log "Selected VM Template: $($selectedTemplate.'HyperPilot-VMName')"
    }
    elseif ($VHDTemplates.Count -eq 1) {
        Log "Found VM Template $($VHDTemplates[0].BaseName)"
        $VHDPath = $VHDTemplates[0].FullName
    }
    else {
        Write-Warning "No HyperPilot VHDX templates found in: $VHDTemplateFolder"
        exit 1
    }

    try {
        $DriveLetter = (
            Mount-VHD -Path $VHDPath -PassThru -ErrorAction Stop |
            Get-Disk |
            Get-Partition |
            Get-Volume |
            Select-Object -ExpandProperty DriveLetter -ErrorAction Stop
        )

        Log "VHDX mounted to drive letter: $DriveLetter"
    }
    catch {
        write-Warning "Please check your VHDX file is not already mounted and try again."
        Write-Error "Failed to mount Templates VHDX: $($_.Exception.Message)"
        exit 1
    }

    $LocalPath = "$($VMFolderPath)\PreFlight"
    Log "Looking for PreFlight Scripts in: $LocalPath"

    $DestinationPath = "$($DriveLetter):\resources"
    $VMSystem32 = "$($DriveLetter):\windows\system32"

    if (Test-Path -Path "$LocalPath\scripts") {
        Log "Source path found: $LocalPath"
        Log "Looking for $DestinationPath"
        if (-not (Test-Path -Path $DestinationPath)) {
            Log "Destination path not found. Creating directory..."
            New-Item -Path $DestinationPath -ItemType Directory | Out-Null
        }
        else {
            Log "Destination path found: $DestinationPath"
        }

        $filename = "hyperset.bat"
        $filepath = "$LocalPath\staging\$filename"

        if (Test-Path -Path $filepath -PathType Leaf) {
            Log "The file '$FileName' exists at $FilePath."
            Log "Copying file '$FileName' to $VMSystem32."
            Copy-Item -Path $filepath -Destination $VMSystem32 -Recurse -Force
        }
        else {
            Log "The file '$FileName' was not found."
        }

        Copy-Item -Path "$LocalPath\Scripts" -Destination $DestinationPath -Recurse -Force
        Log "Script files copied successfully to $DestinationPath"
    }
    else {
        Write-Error "Source path not found: $LocalPath. No files copied."
    }

    Log "VHDX Dismounting.."
    Dismount-VHD -Path $VHDPath
    Log "HyperPilot Template VHDX Dismounted"
    Log "Congradulations your Pre-Flight Checks are complete!" #-ForegroundColor Green
    Log "You can now engage your Otto-Pilot"
    Log "          __|__ "
    log "   --@--@--(_)--@--@--`n"
}
else {
    Write-Warning "HYPER PILOT VHDX Templates not found at: $VHDTemplateFolder"
    Write-Warning "Check your installation folders and try again"
}
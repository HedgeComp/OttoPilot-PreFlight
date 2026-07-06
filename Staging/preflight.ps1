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
    $VHDTemplates = Get-ChildItem -Path $VHDTemplateFolder -File

    if ($VHDTemplates.Count -gt 1) {
        Write-Host "Multiple HyperPilot VHDX templates found. `n" -ForegroundColor Green

        do {
            for ($i = 1; $i -le $VHDTemplates.Count; $i++) {
                Write-Host "[$i] Windows 11 $($VHDTemplates[$i - 1].BaseName)"
            }

            # Prompt in yellow, then read input
            Write-Host -NoNewline -ForegroundColor Yellow "`nEnter the number of the Template you want to update: "
            $selection = Read-Host
        } until ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $VHDTemplates.Count)

        $index = [int]$selection - 1
        $VHDPath = $VHDTemplates[$index].FullName
        log "Selected VM Template: $($VHDTemplates[$index].BaseName)"
    }
    else {
        Log "Found VM Template $($VHDTemplates[0].BaseName)"
        $VHDPath = $VHDTemplates[0].FullName
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
    Log "       __|__ "
    log "--@--@--(_)--@--@--"
}
else {
    Write-Warning "HYPER PILOT VHDX Templates not found at: $VHDTemplateFolder"
    Write-Warning "Check your installation folders and try again"
}
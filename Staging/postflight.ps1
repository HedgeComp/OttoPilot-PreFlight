<#
.SYNOPSIS
    Searches for HyperPilot-created virtual machines, mounts a selected VM
    image, collects the Autopilot hardware hash CSV from the mounted image,
    removes the network adapter from the VM, and creates a checkpoint for Autopilot testing.

.DESCRIPTION
    This script searches HyperPilot Virtual Hard Disks from a path defined
    in the HyperPilot config. It will then mount the VHDX disk for the selected image and
    locates the VM's Autopilot hardware hash CSV file under the VM's `resources`
    (Resource) folder if it exists. The file wll be copied to the host's
    `.\HyperPilot\PreFlight\VMHash` directory, and then dismounts the VHDX.
    If a network adapter is found on the VM, it will be removed to allow reuse for Autopilot testing.
    Finally, the VM will be started and a checkpoint will be created at  OOBE for the VM to allow easy restoration to a clean state.

.NOTES
    - Requires HYPERPILOT by Getrubix.com https://hyperpilot.getrubix.com/
    - Hyper-V must be enabled and the current user must have permission to mount VHDs.
    - Requires running PowerShell as Administrator (see `#Requires -RunAsAdministrator`).
    - Tested on Windows 11 with PowerShell 5.1+ and Hyper-V.
    - After Starting the VM from the Snapshot. You must re-enable the network adapter to allow the VM to connect to the network for Autopilot testing.

.BONUS 
    To Create the VM Hash files quickly, you can run the decryptandprep.ps1 script included with Preflight.
    Started the VM and when it loads in OOBE simply press SHIFT+F10 to open a command prompt.
    Then type "hyperset.bat"
    run .\scripts\decryptandprep.ps1 will run and prepare the VM for Autopilot and create the VM Hash files as a csv file by default.
    Then run the this script to collect the VM Hash and prepare the VM for Autopilot testing.
   
.EXAMPLE
    Start an elevated PowerShell session and run:
        .\postflight.ps1

.AUTHOR
    Scott McDonnell

.REVISION
    1.0  2025-11-17  prompts user to select a VM to process. Pulls Hash CSV and removes network adapter from VM for Autopilot testing.
    2.0  2026-07-06  Added logging and error handling. Now Dynamically finds HyperPilot VM folder from config.json. Added checks for existing checkpoints.

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


# Local path will be derived from the HyperPilot VM folder path later
$vmHashFolder = $null

Log "Looking for HyperPilot Created Virtual Machines..."
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
$VMFolderPath = $HyperConfig.VMFolderPath.TrimEnd('\')
$vmHashFolder = Join-Path -Path $VMFolderPath -ChildPath "PreFlight\VMHash"
$VMFolderConfiguration = $null

$AreWeHyped = Get-VM | Where-Object {
    $_.ConfigurationLocation -and
    $_.ConfigurationLocation.StartsWith($VMFolderPath, [System.StringComparison]::OrdinalIgnoreCase)
}
# Check if any VMs were found
if (-not $AreWeHyped -or $AreWeHyped.Count -eq 0) {
    Write-Warning "No HyperPilot VMs found under: $VMFolderPath"
    exit 1
}
# Build a numbered table
$index = 1
$vmTable = foreach ($vm in $AreWeHyped) {
    [pscustomobject]@{
        Number = $index
        'HyperPilot-VMName'   = $vm.Name
    }
    $index++
}

$vmTable | Format-Table -AutoSize

# Ask user to pick one
Write-Host  -NoNewline -ForegroundColor Yellow "Enter the number of the HyperPilot VM to update: "
$selection = Read-Host

if (-not [int]::TryParse($selection, [ref]$null) -or
    [int]$selection -lt 1 -or
    [int]$selection -gt $AreWeHyped.Count) {

    Write-Warning "Invalid selection. Exiting."
    exit 1
}

$SelectedVM = $AreWeHyped[[int]$selection - 1].Name

Write-Host ""
Log "You selected VM: $($SelectedVM)"

Log "Looking for HYPER PILOT Virtual Disks..."
$VHDPath = Get-VMHardDiskDrive -VMName $SelectedVM | Select-Object -ExpandProperty Path

#TemplateFolder = "C:\HyperPilot\Virtual Hard Disks"
#Check if the VHDX returned exists
if (Test-Path -Path $VHDPath) {


#try to mount the selected VHDX templates
try {

$DriveLetter = (
            Mount-VHD -Path $VHDPath -PassThru -ErrorAction Stop |
            Get-Disk |
            Get-Partition |
            Get-Volume |
            Select-Object -ExpandProperty DriveLetter -ErrorAction Stop
        )

Log "VHDX mounted to drive letter: $DriveLetter"
    $mounted = $true
}
catch{
 Write-Error "Failed to mount Templates VHDX: $($_.Exception.Message)"
    exit 1

}


# (Assuming $DriveLetter is set to the correct drive letter, like "E")
$VMResourcesPath = "$($DriveLetter):\resources"

#Check if the local VMHash folder path exists
 if (!(Test-Path -Path $vmHashFolder)) {
    Write-Host "Local VMHash Folder Not found: Creating."
    New-Item -Path $vmHashFolder -ItemType Directory | Out-Null

}

else{
Log "Local VMHash Folder found: $vmHashFolder"
}
  
# Check if the Resource directory exists on VMDK
if (!(Test-Path -Path $VMResourcesPath)) {
    Write-Warning "Resource folder not found on VM: $VMResourcesPath"
    if ($mounted -and $VHDPath) {
        try {
            Dismount-VHD -Path $VHDPath -ErrorAction Stop
            Log "HYPER PILOT VHDX Dismounted "
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
    Log "CSV files found. Copying..."
    try {
        foreach ($file in $csvFiles) {
            Copy-Item -Path $file.FullName -Destination $vmHashFolder -Force -ErrorAction Stop
        }
        Log "CSV files copied to $vmHashFolder"
    }
    catch {
        Write-Warning "Failed to copy CSV files from $VMResourcesPath to $vmHashFolder : $($_.Exception.Message)"
    }
}
else {
    Log "No CSV Hash files found in $VMResourcesPath"
}

#dismount VHDX template
if ($mounted -and $VHDPath) {
    Log "VHDX Dismounting.."
    try {
        Dismount-VHD -Path $VHDPath -ErrorAction Stop
        Log "HYPER PILOT VHDX Dismounted "
    }
    catch {
        Write-Warning "Failed to dismount VHDX: $($_.Exception.Message)"
    }
}


#check for vm network adapter and remove it to allow reuse of the adapter for autopilot testing
$nicstatus = Get-VMNetworkAdapter -VMName $SelectedVM -ErrorAction SilentlyContinue
if (! $nicstatus){Log "No Network Adapter found on VM. skipping removal step."}
else{
    Remove-VMNetworkAdapter -VMName $SelectedVM -Confirm:$false
    Log "Network Adapter Removed from VM to allow reuse for Autopilot Testing."
}

#start the VM to create a checkpoint
Start-VM -Name $SelectedVM
 do {       
            Log "Waiting for VM $SelectedVM to start..."
            $HyperVM = Get-VM -Name $SelectedVM
             ### Wait longer to ensure VM is fully started and back at OOBE. You can adjust this time as needed for your environment.
            Start-Sleep -Seconds 45
            
        } while ($HyperVM.State -ne 'Running')
Log "VM ${SelectedVm.Name} is now running."

#try to create a checkpoint at startup without Network Adapter
$checkpointName = 'PostFlight-Ready for Autopilot Testing'
$existingCheckpoint = Get-VMSnapshot -VMName $SelectedVM -Name $checkpointName -ErrorAction SilentlyContinue
if ($existingCheckpoint) {
    Log "A checkpoint named '$checkpointName' already exists for VM $SelectedVM. Skipping creation."
}
else {
    try {
        Checkpoint-VM -Name $SelectedVM -SnapshotName $checkpointName -ErrorAction Stop
        Log "Checkpoint '$checkpointName' created for VM $SelectedVM."
    }
    catch {
        Write-Warning "Checkpoint creation failed for VM $($SelectedVM): $($_.Exception.Message)"
        Write-Warning "You can create a checkpoint manually from Hyper-V Manager after the VM is shut down."
    }
}

Stop-VM -Name $SelectedVM -Force
 do {
            $HyperVM = Get-VM -Name $SelectedVM
            Start-Sleep -Seconds 5
        } while ($HyperVM.State -ne 'Off')

Log "VM $SelectedVM is now stopped."       

Log "Congratulations — your Post-Flight Checks are complete" 
}
#Check Failure Message. Check the HYPERPilot Installation Folders for VM Disks. 
else{
Write-Warning "HyperPilot VHDX Disks not found at: $VHDTemplates "
Write-Warning "Check that you've created atleast one HyperPilot VM"
}
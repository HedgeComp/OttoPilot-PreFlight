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

# Define your Local path to store the hash file
$LocalPath = "C:\HyperPilot\PreFlight\VMHash"
# Define your Local path to store the hash file
$LocalPath = "C:\HyperPilot\PreFlight\VMHash"

Write-Host "Looking for HyperPilot Virtual Machines..."
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
$VMFolderConfiguration = $null

$AreWeHyped = Get-VM | Where-Object {
    $_.ConfigurationLocation -and
    $_.ConfigurationLocation.StartsWith($VMFolderPath, [System.StringComparison]::OrdinalIgnoreCase)
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
$selection = Read-Host "`nEnter the number of the VM you want to use"

if (-not [int]::TryParse($selection, [ref]$null) -or
    [int]$selection -lt 1 -or
    [int]$selection -gt $AreWeHyped.Count) {

    Write-Warning "Invalid selection. Exiting."
    exit 1
}

$SelectedVM = $AreWeHyped[[int]$selection - 1].Name

Write-Host ""
Write-Host "You selected VM: $($SelectedVM)"

Write-Host "Looking for HYPER PILOT Virtual Disks..."
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

Write-Host "VHDX mounted to drive letter: $DriveLetter"
    $mounted = $true
}
catch{
 Write-Error "Failed to mount Templates VHDX: $($_.Exception.Message)"
    exit 1

}


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
        Write-Warning "Failed to copy CSV files from $VMResourcesPath to $LocalPath : $($_.Exception.Message)"
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


#check for vm network adapter and remove it to allow reuse of the adapter for autopilot testing
$nicstatus = Get-VMNetworkAdapter -VMName $SelectedVM -ErrorAction SilentlyContinue
if (! $nicstatus){Write-Host "No Network Adapter found on VM. skipping removal step."}
else{
    Remove-VMNetworkAdapter -VMName $SelectedVM -Confirm:$false
    Write-Host "Network Adapter Removed from VM to allow reuse for Autopilot Testing."
}

#start the VM to create a checkpoint
Start-VM -Name $SelectedVM
 do {
            $HyperVM = Get-VM -Name $SelectedVM
            Start-Sleep -Seconds 90  ### Wait longer to ensure VM is fully started and back at OOBE. You can adjust this time as needed for your environment.
        } while ($HyperVM.State -ne 'Running')
Write-Host "VM ${SelectedVm.Name} is now running."

#try to create a checkpoint at startup without Netowrk Adapter
try {
    Checkpoint-VM -Name $SelectedVM -SnapshotName "PostFlight-Ready for Autopilot Testing" -ErrorAction Stop
    Write-Host "Checkpoint 'PostFlight-Ready for Autopilot Testing' created for VM $SelectedVM."
}
catch {
    Write-Warning   "Checkpoint creation failed for VM ${SelectedVM}: $($_.Exception.Message)"
    Write-Warning   "You can create a checkpoint manually from Hyper-V Manager after the VM is shut down."
    }

Stop-VM -Name $SelectedVM -Force
 do {
            $HyperVM = Get-VM -Name $SelectedVM
            Start-Sleep -Seconds 5
        } while ($HyperVM.State -ne 'Off')

Write-Host "VM $SelectedVM is now stopped."       

Write-Host "Congratulations — your Post-Flight Checks are complete" -ForegroundColor Green
}

#Check Failure Message. Check the HYPERPilot Installation Folders for VM Disks. 
else{
Write-Warning "HyperPilot VHDX Disks not found at: $VHDTemplates "
Write-Warning "Check that you've created atleast one HyperPilot VM"
}
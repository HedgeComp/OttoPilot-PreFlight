[CmdletBinding()]

<#
.SYNOPSIS
    Runs the Autopilot community collection inside a VM, saves the Autopilot
    CSV to `C:\resources`, disables BitLocker if present, and optionally
    syspreps the machine for capture.

.DESCRIPTION
    This helper script is intended to be executed inside the HyperPilot VM
    (for example after running `hyperset.bat` during OOBE). It ensures the
    NuGet provider is available, installs the Autopilot community script if
    necessary, executes it to produce the `_autopilotinfo.csv` file, disables
    BitLocker on the system volume if required, and then optionally runs
    `sysprep` to generalize and shutdown the VM for capture.

.PARAMETER csvPath
    The path where the Autopilot CSV will be written. Defaults to
    `C:\resources\<COMPUTERNAME>_autopilotinfo.csv`.

.PARAMETER online
    If `$true`, the Autopilot community script runs in online mode and may
    upload directly instead of saving a CSV. Default is `$false`.

.PARAMETER groupTag
    Optional group tag passed to the Autopilot community script to assign the
    device to a group during collection.

.EXAMPLE
    # Run locally inside the VM and save CSV to default path
    .\decryptandprep.ps1

.EXAMPLE
    # Run and upload online
    .\decryptandprep.ps1 -online $true

.NOTES
    - Requires PowerShell running as Administrator inside the VM.
    - The script expects to be run where `C:\resources` is accessible.
    - The Autopilot community script `get-windowsautopilotinfocommunity` is
      installed from PSGallery if not present.
    - The script disables BitLocker and waits for decryption.

.AUTHOR
    Scott McDonnell

.REVISION
    1.0  2025-11-18  Added comment-based help
#>

param(
    [string]$csvPath = "C:\resources\$($env:COMPUTERNAME)_autopilotinfo.csv",
    [bool]$online = $false,
    [string]$groupTag
)

$AutoPilotCommunityPath = 'C:\Program Files\WindowsPowerShell\Scripts\get-windowsautopilotinfocommunity.ps1'
function Check-NuGetProvider{
	[CmdletBinding()]
	param (
		[version]$MinimumVersion = [version]'2.8.5.201'
	)
	$provider = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
	Sort-Object Version -Descending |
	Select-Object -First 1

	if (-not $provider) {
		Write-Host 'NuGet Provider Package not detected, installing...'
		Install-PackageProvider -Name NuGet -Force | Out-Null
	} elseif ($provider.Version -lt $MinimumVersion) {
		Write-Host "NuGet provider v$($provider.Version) is less than required v$MinimumVersion; updating."
		Install-PackageProvider -Name NuGet -Force | Out-Null
        
	} else {
		Write-Host "NuGet provider meets min requirements (v:$($provider.Version))."
	}
    
}



Write-Host "Checking Nuget Provider Package State"
Check-NuGetProvider 
Write-Host "Check for Autopilot Community Script for All Users"
if (!(Test-Path $AutoPilotCommunityPath))
{
    Write-Host "Autopilot Communit Script not found, contacting Andy.."
    Install-script -Name get-windowsautopilotinfocommunity -Scope Allusers -Confirm:$false -Force
}


$childParams = @{}

if ($groupTag) { 
    $childParams.Add("GroupTag", $groupTag) 
}

if ($online -eq $true) { 
    # For a switch parameter, the value MUST be $true
    $childParams.Add("Online", $true) 
} else { 
    $childParams.Add("OutputFile", $csvPath) 
}

try {
    $ScriptPath = (Get-Command -Name "get-windowsautopilotinfocommunity" -ErrorAction Stop).Definition
}
catch {
    Write-Error "The script 'get-windowsautopilotinfocommunity' was not found. Please ensure it is installed from PSGallery. Or talk to Andy.."
    exit 1
}

Write-Host "Executing script $ScriptPath" 
& $ScriptPath @childParams

# Disable BitLocker on C:
Write-Host "Checking Bitlocker Status"
$bitlockerStatus = Get-BitLockerVolume -MountPoint "C:" #| Out-Null
$bitlockerStatus.VolumeStatus
If ($bitlockerStatus.VolumeStatus -eq 'FullyDecrypted')
{
Write-Host "BitLocker not Detected on C: ..."
}
else
 {
    Write-Host "Disabling BitLocker on C: ..."
    Disable-BitLocker -MountPoint "C:" | Out-Null

    # Wait until decryption is complete
    Write-Host "Waiting for BitLocker decryption to complete..."
    do {
    $bitlockerStatus = Get-BitLockerVolume -MountPoint "C:" #| Out-Null
    $percentage = $bitlockerStatus.EncryptionPercentage
    Write-Host ("Current decryption progress: {0}%" -f $percentage)
    Start-Sleep -Seconds 5
    }
    until ($bitlockerStatus.VolumeStatus -eq 'FullyDecrypted')

    Write-Host "BitLocker decryption complete."
}


# Run Sysprep
$sysprepPath = "$env:SystemRoot\System32\Sysprep\Sysprep.exe"
if (Test-Path $sysprepPath) {
    Write-Host "Running Sysprep with /generalize /oobe /shutdown ..."
    & $sysprepPath /generalize /oobe /shutdown
} else {
    Write-Host "Sysprep.exe not found at expected path: $sysprepPath"
}

Write-Host ""
Write-Host "[!] AUTOPILOT VM WARNING" -ForegroundColor Yellow
Write-Host ""

Write-Host "[i] To reuse this VM for Autopilot testing:" -ForegroundColor Cyan
Write-Host "   - Remove the network adapter *before* reusing the VM." -ForegroundColor Cyan
Write-Host "   - Power on the VM and take a checkpoint at OOBE" -ForegroundColor Cyan
Write-Host "     to avoid the Autopilot profile cache." -ForegroundColor Cyan

Write-Host ""
Write-Host "[i] To automate this process:" -ForegroundColor Green
Write-Host "   - Run 'postflight.bat' after the VM has shut down." -ForegroundColor Green
Write-Host "   - It will remove the adapter and start the VM again." -ForegroundColor Green

Write-Host ""
Write-Host "[i] More info (Michael Niehaus' blog):" -ForegroundColor DarkGray
Write-Host "   https://oofhours.com/2023/08/23/windows-autopilot-testing-with-vms" -ForegroundColor DarkGray

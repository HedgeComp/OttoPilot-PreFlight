[CmdletBinding()]

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
    Start-Sleep -Seconds 10
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

Write-Host "`n=====   WARNING  =====" -ForegroundColor Black -BackgroundColor Yellow
Write-Host "`nTo Reuse the VM for Autopilot Testing. Remember to Remove the Network Adapter First!!   " -ForegroundColor Black -BackgroundColor Yellow
Write-Host "Power On the VM and then take a snapshot at OOBE. This will avoide the Autopilot Profile Cache" -ForegroundColor Black -BackgroundColor Yellow
Write-Host "See Micheal Niehaus blog for more: https://oofhours.com/2023/08/23/windows-autopilot-testing-with-vms/" -ForegroundColor Black -BackgroundColor Yellow
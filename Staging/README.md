Preflight Script - Staging Prerequisites

Printable Quick-Start (One Page)
--------------------------------
Follow these steps in order; run commands on the host as Administrator.

1) Prepare files
- Extract `PreFlight` to `C:\HyperPilot`.
- Ensure templates are in `C:\HyperPilot\Templates` and helper scripts in `C:\HyperPilot\PreFlight\Scripts`.

2) Run preflight to inject resources
```powershell
Set-Location 'C:\HyperPilot\PreFlight\Staging'
.\preflight.bat
```

3) Boot VM and run inside OOBE
- Start the VM. At OOBE press `SHIFT+F10`.
- Run: `hyperset.bat` (located in `C:\Windows\System32`).
- In the PowerShell window: `Set-Location 'C:\resources'` then `.\scripts\decryptandprep.ps1`.

4) Capture VM (snapshot or save image)

5) Run postflight to collect CSVs
```powershell
Set-Location 'C:\HyperPilot\PreFlight\Staging'
.\postflight.bat
```

6) CSVs are saved to `C:\HyperPilot\PreFlight\VMHash` — upload securely to Autopilot.

Notes: Keep this page printed near the test workstation. If an error occurs, check PowerShell output and ensure Hyper-V is enabled and PowerShell is running elevated.

This folder contains `preflight.ps1`, a script that mounts a HyperPilot template VHDX,
copies preflight resources into the image, and dismounts the VHDX.

Prerequisites
- Run PowerShell as Administrator.
- Hyper-V must be enabled on the host.
- The template VHDX files must be located in: `C:\HYPERPILOT\Templates`.
- The local preflight resources must be in: `C:\HYPERPILOT\PreFlight`.

Usage
1. Open an elevated PowerShell prompt.
2. Change to the `Staging` folder:

```powershell
Set-Location 'Staging'
```

3. Run the script:

```powershell
.\preflight.ps1
```

Notes
- The script will prompt to select a VHDX if multiple templates are present.
- The script copies `hyperset.bat` from `C:\HYPERPILOT\PreFlight\staging` to the VM's `Windows\System32`.
- Verify you have sufficient disk and permission to mount and manipulate VHDX files.

Postflight (collect VM Hashes)

This folder also contains `postflight.ps1`, which mounts a HyperPilot VM template
VHDX, locates CSV-formatted VM hardware hash files in the VM's `resources` folder,
and copies them to the host under `C:\HyperPilot\PreFlight\VMHash` for upload to
Autopilot or other management services.

Prerequisites (postflight)
- Run PowerShell as Administrator.
- Hyper-V must be enabled on the host.
- The VM template VHDX files must be located in: `C:\HyperPilot\Virtual Hard Disks`.
- The VM image should already contain generated VM hash CSV files in the `resources` folder
	(created by running the included `decryptandprep.ps1` / `hyperset.bat` inside the VM during OOBE).

Usage (postflight)
1. Open an elevated PowerShell prompt.
2. Change to the `Staging` folder:

```powershell
Set-Location 'Staging'
```

3. Run the script:

```powershell
.\postflight.ps1
```

Notes (postflight)
- The script will prompt to select a VHDX if multiple templates are present.
- If CSV files are present under the VM's `resources` folder they will be copied to
	`C:\HyperPilot\PreFlight\VMHash` (created if missing).
- The script attempts to dismount VHDX files even after recoverable errors; check the
	output for warnings if dismount fails.
- After collecting the CSV files you can upload them to Autopilot or process them as needed.

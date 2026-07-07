# Staging Scripts

## Preflight SCript
- The script will prompt to select a VHDX if multiple templates are present.
- The script copies `hyperset.bat` from `C:\HYPERPILOT\PreFlight\staging` to the VM's `Windows\System32`.
- Verify you have sufficient disk and permission to mount and manipulate VHDX files.

--------------------------------
Follow these steps in order; run commands on the host as Administrator.

1) Prepare files
- Extract `PreFlight` to your `HyperPilot` folder.
- Example Templates in  `C:\HyperPilot\Templates` and helper scripts in `C:\HyperPilot\PreFlight\Scripts`.

2) Run Preflight script to inject resources
```powershell
Set-Location 'C:\HyperPilot\PreFlight\Staging'
.\preflight.bat
```

3) Boot VM and run inside OOBE
- Start the VM. At OOBE press `SHIFT+F10`.
- In CMD prompt type: `hyperset.bat` (should be found by Env PAth located in `C:\Windows\System32`).
- Test your scripts or use the tools in 'C:\resources'.
- When completed testing: `Set-Location 'C:\resources'` then `.\scripts\decryptandprep.ps1`.
- VM will decrypt and runn sysprep.

Prerequisites
- Run PowerShell as Administrator.
- HyperPilot must be installed.
- The template VHDX will be found via config.json
- The local preflight resources Like 'Scripts' folder must be in: `.\HYPERPILOT\PreFlight`.


## Postflight Script (collect VM Hashes)

This folder also contains `postflight.ps1`, which mounts a HyperPilot VM template
VHDX, locates CSV-formatted VM hardware hash files in the VM's `resources` folder,
and copies them to the host under `C:\HyperPilot\PreFlight\VMHash` for upload to
Autopilot.

Prerequisites (postflight)
- Run PowerShell as Administrator.
- Hyper-V must be enabled on the host.
- The VM template VHDX files must be located in: `C:\HyperPilot\Virtual Hard Disks`.
- The VM image should already contain generated VM hash CSV files in the `resources` folder
	(created by running the included `decryptandprep.ps1` / `hyperset.bat` inside the VM during OOBE).

 

1) Run Postflight script to collect CSVs and capture VM Snaphost that is Autopilot ready
```powershell
Set-Location 'C:\HyperPilot\PreFlight\Staging'
.\postflight.bat
```

2) The following VM Autopilot configuration actions are now automated
   	- CSVs are saved to Preflight folder, ie `C:\HyperPilot\PreFlight\VMHash` ( You can now upload your CSV securely to Intune Autopilot)
   	- The Vnic is removed from a virtual Switch ( No internet on boot to prevent Autopilot caching)
   	- VM is booted and waits until OOBE
   	- VM Snapshot is created titled.
   	- Vm is shutdown
   	  
3) Boot the VM and add a vswitch
   
4) Sign into your VM and test the full Autopilot process.
  
5) To repeat Autopilot testing, resotre the Snapshot and repeat steps '3' and '4'


Notes (postflight)
- The script will prompt to select a VHDX if multiple templates are present.
- If CSV files are present under the VM's `resources` folder they will be copied to
	`..\HyperPilot\PreFlight\VMHash` (created if missing).
- The script attempts to dismount VHDX files even after recoverable errors; check the
	output for warnings if dismount fails.
- After collecting the CSV files you can upload them to Autopilot or process them as needed.

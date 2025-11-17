Preflight Script - Staging Prerequisites

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

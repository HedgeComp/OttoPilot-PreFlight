# OttoPilot-PreFlight
<img width="400" height="400" alt="OttoPreflight" src="https://github.com/user-attachments/assets/ef36e11e-fff1-42d8-960a-d3c44f21d1ef" />



Is a collection of Companion scripts to prepare and collect VM images for use with the GetRubix
HyperPilot VM creation tool. These scripts automate mounting template VHDX
images, copying preflight resources into the image, and collecting VM hardware
hash (CSV) files produced inside the VM for Autopilot upload.

Overview
--------
- `Staging\preflight.ps1` — mounts a template VHDX, creates (or uses) the
	`resources` folder inside the image, copies local preflight helper files and
	`hyperset.bat` into the image, then dismounts the VHDX. This prepares images
	for running the Autopilot collection inside the VM.

- `Staging\postflight.ps1` — mounts a completed VM image, searches the VM's
	`resources` folder for CSV-formatted VM hardware hash files, copies them to
	the host (`C:\HyperPilot\PreFlight\VMHash`) and safely dismounts the VHDX.

- `preflight.bat` / `postflight.bat` — Windows batch launchers at the repo root
	that call the corresponding `Staging\*.ps1` scripts using PowerShell with
	`-ExecutionPolicy Bypass` to make it easy for an administrator to run them.

- `Staging\hyperset.bat` — small helper copied into the VM `System32` by
	`preflight.ps1`; it sets `C:\resources` on the PATH, changes the working
	directory to `C:\resources`, and launches PowerShell (keeps window open).

- `Scripts\decryptandprep.ps1` — helper that runs the Autopilot community
	script inside the VM to produce the `_autopilotinfo.csv`, disables BitLocker
	if present, and optionally triggers `sysprep` for capture.


Requirements
------------
- Windows host with Hyper-V enabled.
- PowerShell (run as Administrator).
- The GetRubix HyperPilot tool (https://getrubix.com / https://hyperpilot.getrubix.com)
	— this repository provides companion scripts and expects HyperPilot-created
	VHDX images.

Installation
------------
1. Download the ZIP of this repository and extract the `PreFlight` folder to
	 `C:\HyperPilot` so your structure looks like:

```
C:\HyperPilot\PreFlight\Staging\preflight.ps1
C:\HyperPilot\PreFlight\Staging\postflight.ps1
```

2. HyperPilot VHD templates currently placed under:

```
C:\HyperPilot\Templates\   <- (used by preflight)
C:\HyperPilot\Virtual Hard Disks\ <- (used by postflight)
```

Basic Usage
-----------
Open an elevated PowerShell prompt (Run as Administrator) and run the staging
scripts from the `Staging` directory.

Preflight (copy resources into template):

```powershell
Set-Location 'C:\HyperPilot\PreFlight\Staging'
.\preflight.ps1
```

Postflight (collect VM Hash CSVs after running the VM through OOBE):

```powershell
Set-Location 'C:\HyperPilot\PreFlight\Staging'
.\postflight.ps1
```

Notes and Examples
------------------
- `preflight.ps1` expects your local preflight resources under
	`C:\HyperPilot\PreFlight\Scripts` and a staging `hyperset.bat` in
	`C:\HyperPilot\PreFlight\staging` (the script will copy these into the
	mounted VHDX image).
- `postflight.ps1` will copy CSV files from the mounted image's `resources`
	folder into `C:\HyperPilot\PreFlight\VMHash` (the script creates this
	folder if it does not exist).
- The repository includes `decryptandprep.ps1` (helper) which is intended to
	be run inside the VM during OOBE to generate VM Hash files.


Launcher Batch Files
--------------------
- `preflight.bat` — convenient launcher that runs `Staging\preflight.ps1` via PowerShell.
- `postflight.bat` — convenient launcher that runs `Staging\postflight.ps1` via PowerShell.

The `.bat` files are simple wrappers that change to the repository directory and start
PowerShell with `-ExecutionPolicy Bypass` so these scripts can be launched by a local
administrator without opening PowerShell directly.

`hyperset.bat` (inside `Staging`)
-------------------------------
This small batch file is copied into the VM's `Windows\System32` by `preflight.ps1`.
When executed inside the HyperPilot VM it does the following:

- Adds `C:\resources` to the `PATH` so any helper tools there are available.
- Changes the working directory to `C:\resources`.
- Launches PowerShell with `-NoExit` so the console remains open for interactive
	steps or running the included `decryptandprep.ps1` script.


Typical Workflow for Preflight
-----------------------------
Follow these steps to prepare a template image, generate VM hash files inside
the VM, and collect them for Autopilot:

1. Prepare host and files
	 - Extract the `PreFlight` folder to `C:\HyperPilot` (the ZIP should produce
		 `C:\HyperPilot\PreFlight`).
	 - Place template VHDX files used by HyperPilot under:
		 - `C:\HyperPilot\Templates` (used by `preflight.ps1`) or
		 - `C:\HyperPilot\Virtual Hard Disks` (used by `postflight.ps1`) depending
			 on how you manage your images.
	 - Ensure `C:\HyperPilot\PreFlight\Scripts` contains any helper scripts
		 you want copied into images (the repo includes `decryptandprep.ps1`).

2. Run Preflight (copies resources into template image)

```powershell
Set-Location 'C:\HyperPilot\PreFlight'
.\preflight.bat
```

- `preflight.bat` runs `Staging\preflight.ps1` which mounts the selected VHDX,
	creates a `resources` folder inside the image (if missing) and copies the
	`Scripts` folder and `hyperset.bat` into the VM image. `hyperset.bat` will be
	placed in the VM's `System32` so it can be executed during OOBE.

3. Boot the VM and run the helper inside OOBE

- Power on the VM created from the modified template. When the VM reaches
	OOBE (Out-Of-Box Experience), press `SHIFT+F10` to open a command prompt.
- Run `hyperset.bat` (it should be available in `C:\Windows\System32`). The
	batch file does the following:
	- Adds `C:\resources` to the `PATH`.
	- Changes directory to `C:\resources`.
	- Launches PowerShell with `-NoExit` so you can interact with the session.

- Test and troubleshoot your scripts or prep the VM for repeated Autopilot testing.

-  Inside the launched PowerShell session run the included `decryptandprep.ps1`:

```powershell
Set-Location 'C:\resources'
.\scripts\decryptandprep.ps1
```

- `decryptandprep.ps1` will run the Autopilot community script to generate a
	CSV with the VM hardware hash, disable BitLocker if present, and optionally
	sysprep/shutdown the VM for capture.

4. Capture or snapshot the VM

- After `decryptandprep.ps1` completes and the VM has been prepared (and
	optionally shut down by sysprep),
    
> ⚠️ **IMPORTANT — Do NOT skip this step**
>
> Before you take a snapshot or capture the VM image, REMOVE the VM's **Network
> Adapter** (or disconnect the virtual network) to prevent the VM from
> communicating on the network. Failing to remove or disconnect the network
> adapter may cause Autopilot profile caching or unexpected device registration.
>
> After removing/disconnecting the network adapter, take a snapshot or export
> the VM image as your completed VM image depending on your workflow.

- SnapShot the VM, with disabled Network Adapter.

5. Run Postflight (collect CSVs)

```powershell
Set-Location 'C:\HyperPilot\PreFlight'
.\postflight.bat
```

- `postflight.bat` runs `Staging\postflight.ps1` which mounts the selected
	VM image and copies any CSV files found in the VM's `resources` folder to
	`C:\HyperPilot\PreFlight\VMHash` on the host. The script creates the host
	folder if needed and attempts to dismount the VHDX safely.

6. Upload or process the CSV files

- The CSV files under `C:\HyperPilot\PreFlight\VMHash` can be uploaded to
	Microsoft Autopilot or processed by your management tooling. Keep them
	secure as they contain device-identifying information.

Troubleshooting
---------------
- Permission errors: ensure PowerShell is running elevated and you have
	permissions to mount/dismount VHDs.
- Hyper-V not available: ensure Hyper-V and required features are enabled
	(Turn Windows features on/off → Hyper-V).
- No templates found: verify you placed VHDX files in the expected templates
	folder or update the script variables to match your layout.
- VHD does not mount: try mounting the VHDX manually in Disk Management to
	verify the file integrity.


Support and Contribution
------------------------
If you find issues or want improvements, open an issue or a PR in this
repository with details and reproduction steps.

License
-------
See the repository `LICENSE` file for licensing terms.

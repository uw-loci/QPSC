# QPSC Uninstallation Guide

This guide explains how to completely remove QPSC components to perform a clean reinstallation or uninstall the system.

## Quick Uninstall (PowerShell)

Open PowerShell and run:

```powershell
cd $env:USERPROFILE
```

Then run each command:

```powershell
pip uninstall -y microscope-server microscope-control ppm-library pycromanager
```

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\QPSC"
```

For development installations with virtual environment:

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\QPSC\venv_qpsc"
```

---

## Component-by-Component Removal

### 1. Python Packages

Remove the QPSC Python packages from pip:

```powershell
pip uninstall microscope-server
```

```powershell
pip uninstall microscope-control
```

```powershell
pip uninstall ppm-library
```

```powershell
pip uninstall pycromanager
```

**For development installations** (editable installs):

If you installed from source with `pip install -e .`, the packages will be uninstalled by the commands above. However, you may want to also remove the source directories:

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\QPSC\microscope_command_server"
```

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\QPSC\microscope_control"
```

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\QPSC\ppm_library"
```

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\QPSC\venv_qpsc"
```

### 2. QPSC Installation Directory

Remove the entire QPSC installation folder:

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\QPSC"
```

This removes:
- Configuration templates (`configurations/`)
- Launch scripts (`Launch-QPSC.ps1`)
- Development source code (if present)
- Virtual environment (if present)

### 3. QuPath Extensions (Optional)

If you want to remove the QPSC QuPath extensions:

**For MSI installation:**

```powershell
Remove-Item "$env:LOCALAPPDATA\QuPath-*\extensions\qupath-extension-qpsc-*.jar"
```

```powershell
Remove-Item "$env:LOCALAPPDATA\QuPath-*\extensions\qupath-extension-tiles-to-pyramid-*.jar"
```

**For portable installation:**

```powershell
Remove-Item "$env:USERPROFILE\QuPath\extensions\qupath-extension-qpsc-*.jar"
```

```powershell
Remove-Item "$env:USERPROFILE\QuPath\extensions\qupath-extension-tiles-to-pyramid-*.jar"
```

**Note:** Uninstalling the QuPath extensions is optional. They won't interfere with reinstallation and will continue to work with a fresh QPSC Python installation.

### 4. Clean Python Cache (Optional)

If you want to ensure a completely clean reinstallation, clear Python's package cache:

```powershell
pip cache purge
```

---

## Verification

To verify all QPSC packages are removed:

```powershell
pip list | Select-String "microscope|ppm"
```

This should return no results if all packages are uninstalled.

To verify the installation directory is removed:

```powershell
Test-Path "$env:USERPROFILE\QPSC"
```

This should return `False` if the directory is removed.

---

## Reinstallation

After uninstalling, you can perform a fresh installation by following the [Installation Instructions](README.md#automated-installation-windows).

---

## Partial Uninstall Scenarios

### Remove Only Python Packages (Keep Configuration)

If you want to update the Python packages but keep your configuration files:

```powershell
pip uninstall -y microscope-server microscope-control ppm-library
```

Then reinstall with the setup script, which will preserve existing configuration files.

### Remove Only Configuration (Keep Python Packages)

If you want to reset your configuration but keep the Python packages:

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\QPSC\configurations"
```

Then rerun the setup script to download fresh configuration templates.

---

## Troubleshooting Uninstallation

### "Access Denied" Errors

If you get access denied errors when removing directories:

1. Close any running Python processes (check Task Manager)
2. Close QuPath if it's running
3. Close any PowerShell windows that have activated the virtual environment
4. Try again

### Packages Won't Uninstall

If `pip uninstall` fails:

```powershell
pip uninstall --break-system-packages microscope-server
```

(This flag may be needed on some Python installations)

### QuPath Extensions Still Appear

QuPath caches extension information. After removing extension JARs:

1. Close QuPath completely
2. Restart QuPath
3. The extensions should no longer appear in the Extensions menu

---

## What About Micro-Manager?

This guide does **NOT** cover uninstalling Micro-Manager. Micro-Manager is a separate application and can be uninstalled independently through Windows "Add or Remove Programs" if desired.

QPSC requires Micro-Manager to function, so only uninstall Micro-Manager if you're completely removing the QPSC system.

---

## Need Help?

If you encounter issues during uninstallation or reinstallation, please report them at:
https://github.com/uw-loci/QPSC/issues

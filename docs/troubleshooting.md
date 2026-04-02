# QPSC Troubleshooting Guide

This guide covers common issues encountered during QPSC installation and setup. For architecture and configuration details, see [architecture.md](architecture.md) and [configuration.md](configuration.md).

---

## QuPath Installation Issues

### Setup script reports "QuPath not found"

**Cause:** QuPath is installed in a non-standard location or not installed.

**Solution:**

1. **Verify QuPath is installed:**
   - Look for QuPath in your Start Menu (Windows) or Applications folder (macOS)
   - Or download from: https://qupath.github.io/

2. **Find your QuPath installation directory:**
   - **Windows MSI install:** Usually `C:\Users\YourUsername\AppData\Local\QuPath-0.6.0\`
   - **Windows portable:** Could be anywhere you extracted it
   - **macOS:** `/Applications/QuPath.app` or `~/Applications/QuPath.app`

3. **Re-run setup script with QuPath location:**
   ```powershell
   .\PPM-QuPath.ps1 -QuPathDir "C:\Users\YourUsername\AppData\Local\QuPath-0.6.0"
   ```

4. **Or skip QuPath setup and install extensions manually:**
   ```powershell
   .\PPM-QuPath.ps1 -SkipQuPath
   ```
   Then follow the manual extension installation instructions in the main README.

### Can't find QuPath extensions directory

**Solution:**

1. Launch QuPath
2. Go to `Edit > Preferences`
3. Look for "Extension directory" -- this shows the exact path
4. Copy JARs to that directory
5. Restart QuPath

Common locations:
- **Windows MSI:** `%LOCALAPPDATA%\QuPath-0.6.0\extensions\`
- **Windows portable:** `%USERPROFILE%\QuPath\extensions\`
- **macOS:** `~/Library/Application Support/QuPath/extensions/`
- **Linux:** `~/.local/share/QuPath/extensions/`

### QPSC not appearing in Extensions menu

If you don't see QPSC in the Extensions menu after installing JARs:
- Ensure the JAR is in the correct extensions directory (see above)
- Restart QuPath after copying the JAR
- Check QuPath's log (`View > Show log`) for any loading errors

---

## Python Package Installation Issues

### `ModuleNotFoundError` when importing packages

**Cause:** Packages not installed or installation failed.

**Symptoms:**
```python
>>> import ppm_library
ModuleNotFoundError: No module named 'ppm_library'
```

**Solution:**

1. **Verify packages are installed:**
   ```powershell
   # Activate venv (if using one)
   C:\Users\YourUsername\QPSC\venv_qpsc\Scripts\Activate.ps1

   # Check installed packages
   pip list | Select-String "microscope|ppm"
   ```

2. **If packages are missing, reinstall in dependency order:**
   ```powershell
   pip install git+https://github.com/uw-loci/ppm_library.git
   pip install git+https://github.com/uw-loci/microscope_control.git
   pip install git+https://github.com/uw-loci/microscope_command_server.git
   ```

3. **For development installations (editable mode):**
   ```bash
   cd /path/to/repositories
   pip install -e ppm_library/
   pip install -e microscope_control/
   pip install -e microscope_command_server/
   ```

4. **Test imports:**
   ```python
   python -c "import ppm_library, microscope_control, microscope_command_server; print('All imports OK')"
   ```

### `UnicodeEncodeError` in server logs

**Cause:** Unicode characters in logging strings (Windows cp1252 encoding limitation).

**Solution:** Update to the latest version:
```bash
cd microscope_command_server
git pull
```

The codebase now uses ASCII-only characters in all logging and internal strings.

### Circular dependency importing ppm_library

**Cause:** Older `ppm_library/__init__.py` imports from `microscope_control`.

**Solution:** Update to the latest version. This has been fixed.

### OpenCV (cv2) import errors

QPSC requires OpenCV for autofocus functionality. There are two common OpenCV issues:

**Issue 1: OpenCV not installed**

**Symptoms:**
```
ModuleNotFoundError: No module named 'cv2'
```

**Solution:**
```bash
pip install opencv-python
```

**Issue 2: OpenCV DLL loading error on Windows N editions**

**Symptoms:**
```
ImportError: DLL load failed while importing cv2: The specified module could not be found.
```

**Cause:** Windows N editions (Education N, Pro N, Home N) do not include media components required by OpenCV.

**Solution:**

1. **Check your Windows edition:**
   - Open Settings -> System -> About
   - Look at "Edition" -- if it ends with "N" (e.g., "Windows 10 Education N"), you need the Media Feature Pack

2. **Install Media Feature Pack:**
   - Download from: [Media Feature Pack for Windows N editions](https://support.microsoft.com/en-us/topic/media-feature-pack-list-for-windows-n-editions-c1c6fffa-d052-8338-7a79-a4bb980a700a)
   - Follow Microsoft's installation instructions
   - Restart your computer after installation

3. **Verify OpenCV works:**
   ```powershell
   python -c "import cv2; print('OpenCV version:', cv2.__version__)"
   ```

**Note:** If you're using conda-based Python, you can alternatively install opencv via conda which bundles all necessary DLLs:
```bash
conda install -c conda-forge opencv
```

---

## Server and Network Issues

### Port 5000 already in use

**Symptoms:**
```
OSError: [Errno 48] Address already in use
```

**Cause:** Another server instance or application is using port 5000.

**Solution:**
```bash
# Find process using port 5000
# Windows:
netstat -ano | findstr :5000
# macOS/Linux:
lsof -i :5000

# Kill the process if safe, or change server port in code
```

---

## Setup Script Issues

### PowerShell execution policy error

**Symptoms:** "cannot be loaded because running scripts is disabled" error.

**Solution:**
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```
Then retry the setup script.

### PowerShell version

The setup script requires PowerShell 5.1+, which is included with Windows 10 and later. Check your version with:
```powershell
$PSVersionTable.PSVersion
```

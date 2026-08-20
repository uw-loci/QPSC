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

### Setup script opens in a text editor instead of running

**Symptoms:** you type `.\PPM-QuPath.ps1 ...` and Notepad (or your editor) opens the script.
No error, no output.

You are in `cmd.exe`, not PowerShell. cmd cannot run a `.ps1`; it asks Windows to open the file,
and Windows associates `.ps1` with an editor on purpose so that double-clicking a script cannot
execute it. Nothing is broken.

**Anaconda Prompt is cmd** -- this is the usual way people land here. Check the prompt:

```
PS C:\qpsc-extension>          <- PowerShell: correct
C:\qpsc-extension>             <- cmd: opens an editor
(base) C:\qpsc-extension>      <- Anaconda Prompt, still cmd
```

**Solution:** use **Anaconda PowerShell Prompt** (a separate Start-menu entry from **Anaconda
Prompt**), or hand the script to PowerShell from the cmd window you already have -- which keeps
your activated conda environment, because the child process inherits its PATH:

```
powershell -NoProfile -File PPM-QuPath.ps1 -InstallDir "C:\QPSC"
```

### "Python was not found" / Anaconda is installed but not detected

**Symptoms:**
```
[+] Checking Python installation...
Python was not found; run without arguments to install from the Microsoft Store...
```

Two causes stack here:

1. **Anaconda is not on PATH.** Its installer leaves "Add Anaconda to my PATH" unchecked by
   default and expects you to use Anaconda Prompt or run `conda init`. So bare `python` in an
   ordinary PowerShell window is not Anaconda's Python.
2. **Windows fills the gap with a decoy.** `%LOCALAPPDATA%\Microsoft\WindowsApps` is on PATH by
   default and holds a stub `python.exe` whose only job is to print that Store advert. The
   message is Microsoft's, not Python's and not ours.

**Solutions**, any one of:

```powershell
# Use the conda environment (see Prerequisites for why 3.12)
conda create -n qpsc -c conda-forge python=3.12 -y
conda activate qpsc

# Or make conda available in ordinary PowerShell from now on
conda init powershell        # then restart PowerShell

# Or point the script straight at an interpreter, bypassing PATH entirely
.\PPM-QuPath.ps1 -PythonExe "C:\Users\you\anaconda3\envs\qpsc\python.exe"
```

Turning off the aliases under **Settings > Apps > Advanced app settings > App execution
aliases** (`python.exe`, `python3.exe`) stops the decoy shadowing a real interpreter. Worth doing
regardless, but on its own it will not put Anaconda on PATH.

> **Older copies of the setup script mis-report this.** Before the fix, the Python check wrapped
> `python --version` in `try/catch`. `try/catch` traps only PowerShell *terminating* errors, and a
> native `.exe` exiting nonzero is not one -- so the check silently passed with an empty version
> (the giveaway is `Found:` with nothing after it) and setup ran on to fail later at venv creation
> with "Please ensure Python venv module is available". That message is a red herring: venv is
> fine, there is no Python. Re-download the script if you see it.

### PowerShell execution policy error

Two different policies block the script with two different messages. **Read which one you got:
the standard fix for the first is what produces the second**, so following it twice gets you
nowhere.

**Symptom A:** "cannot be loaded because **running scripts is disabled** on this system."

Your policy is `Restricted`. Relax it for your own account only:
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

**Symptom B:** "the file ... **is not digitally signed**. You cannot run this script on the
current system."

Your policy is *already* `RemoteSigned` (often because you just followed the advice above), and
that policy refuses unsigned scripts that carry a Mark of the Web -- the flag Windows attaches to
anything downloaded from the internet. Changing the execution policy again will not help. Strip
the flag instead:
```powershell
Unblock-File .\PPM-QuPath.ps1
```
Unpacked a ZIP? Every extracted file carries the flag: `Get-ChildItem -Recurse | Unblock-File`.

**Diagnosing which:**
```powershell
Get-ExecutionPolicy -List                          # which scope sets what
Get-Item .\PPM-QuPath.ps1 -Stream Zone.Identifier  # errors = no Mark of the Web
```

**On a managed or campus machine**, check the *scope* column. If `AllSigned` appears under
`MachinePolicy` or `UserPolicy`, it comes from Group Policy and **outranks both
`Set-ExecutionPolicy` at every scope and the `-ExecutionPolicy Bypass` flag** -- most advice you
will find online silently fails here. Execution policy governs loading script *files*, so load the
script as text instead:
```powershell
& ([scriptblock]::Create((Get-Content -Raw .\PPM-QuPath.ps1))) -InstallDir "C:\QPSC"
```
Named parameters pass through normally. If that also fails with "Method invocation is supported
only on core types", the machine enforces WDAC/AppLocker and PowerShell is in Constrained Language
Mode; at that point ask IT to sign the script into Trusted Publishers.

### PowerShell version

The setup script requires PowerShell 5.1+, which is included with Windows 10 and later. Check your version with:
```powershell
$PSVersionTable.PSVersion
```

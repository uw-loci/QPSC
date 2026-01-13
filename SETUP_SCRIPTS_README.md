# QPSC Setup Script

One PowerShell script for both production and development setup.

## Usage

### Production Setup (Quick Start)

Installs Python packages from GitHub and downloads QuPath extensions:

```powershell
.\PPM-QuPath.ps1
```

### Development Setup

Clones all repositories and installs in editable mode for code modification:

```powershell
.\PPM-QuPath.ps1 -Development
```

## What it does

### Production Mode (Default)

- ✅ Installs Python packages from GitHub in correct dependency order (includes OpenCV)
- ✅ Downloads QuPath extension JAR files (latest releases, including prereleases)
- ✅ Stores JARs in local QPSC\extensions folder for easy access
- ✅ Automatically copies JARs to QuPath user data extensions directory
- ✅ Downloads configuration templates
- ✅ Creates launcher script for easy startup
- ✅ Launches server in visible window showing port and status
- ✅ Checks for Micro-Manager and QuPath installation

### Development Mode (-Development flag)

- ✅ Clones all QPSC repositories from GitHub
- ✅ Creates Python virtual environment (venv_qpsc)
- ✅ Installs Python packages in editable mode (`pip install -e`)
- ✅ Clones QuPath extension source code
- ✅ Sets up directory structure for development
- ✅ Checks for Micro-Manager and QuPath installation

## Script Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-InstallDir` | String | `$env:USERPROFILE\QPSC` | Installation directory |
| `-Development` | Switch | False | Enable development mode (clone repos, editable install) |
| `-QuPathDir` | String | `$env:USERPROFILE\QuPath` | QuPath installation directory |
| `-SkipQuPath` | Switch | False | Skip QuPath extension download |
| `-Launch` | Switch | False | Launch QPSC after installation |

## Examples

**Basic installation (production mode):**
```powershell
.\PPM-QuPath.ps1
```

**Development setup:**
```powershell
.\PPM-QuPath.ps1 -Development
```

**Custom installation directory:**
```powershell
.\PPM-QuPath.ps1 -InstallDir "D:\QPSC"
```

**Development with custom directory:**
```powershell
.\PPM-QuPath.ps1 -Development -InstallDir "D:\QPSC_Dev"
```

**Skip QuPath setup (if already configured):**
```powershell
.\PPM-QuPath.ps1 -SkipQuPath
```

**Install and launch immediately:**
```powershell
.\PPM-QuPath.ps1 -Launch
```

## After Installation

### Installation Summary File

**The setup script creates a detailed installation summary:**

```
%USERPROFILE%\QPSC\INSTALLATION_SUMMARY.txt
```

**This file contains essential information:**
- Python environment location (virtual environment path or system Python)
- How to activate the Python environment
- Exact paths where packages were installed
- Complete verification commands to test your installation
- Troubleshooting tips for common issues
- All next steps for configuration and launch

**Open this file immediately after installation** to verify everything installed correctly and understand where all components are located.

---

### Production Mode

1. **Configure your microscope:**
   - Edit `configurations\config_template.yml` for your hardware

2. **Launch QPSC:**
   ```powershell
   .\Launch-QPSC.ps1 --qupath
   ```

   Or manually:
   ```powershell
   python -m microscope_command_server.server.qp_server  # Start server
   QuPath.exe                                            # Start QuPath
   ```

   **Note:** The server opens in a separate window showing port number,
   connection status, and error messages. Check this window if connection fails.

### Development Mode

1. **Activate Python environment:**
   ```powershell
   C:\QPSC\venv_qpsc\Scripts\Activate.ps1
   ```

2. **Build QuPath extensions:**
   ```powershell
   cd C:\QPSC\qupath-extension-qpsc
   .\gradlew build
   ```

3. **Copy built JAR files to QuPath extensions folder:**
   - Copy `build/libs/*.jar` to `C:\Users\YourName\QuPath\vX.X\extensions\`
   - Or copy to your custom QuPath extensions directory

4. **Make code changes:**
   - Python: Changes take effect immediately (editable install)
   - Java: Rebuild with `.\gradlew build` after changes

5. **Run tests:**
   ```powershell
   # Java
   cd qupath-extension-qpsc
   .\gradlew test

   # Python (with venv activated)
   pytest microscope_control/
   ```

## Prerequisites

Both modes require:

- **Windows PowerShell 5.1+** or **PowerShell Core 7+**
- **QuPath 0.6.0+** (required for running QPSC)
- **Python 3.9+** with pip
- **Micro-Manager 2.0+** (for hardware control)

**Development mode additionally requires:**
- **Git** (for cloning repositories)
- **Java 21+** (for building QuPath extensions)

### Installing Prerequisites

**QuPath:**
- Download from: https://qupath.github.io/
- ✅ Install QuPath 0.6.0 or later
- QuPath extensions will be installed to the QuPath extensions folder

**Python:**
- Download from: https://www.python.org/
- ✅ Check "Add Python to PATH" during installation

**Git (for development mode):**
- Download from: https://git-scm.com/download/win

**Java (for building QuPath extensions):**
- Download OpenJDK 21: https://adoptium.net/
- ⚠️ Only needed for developing QuPath extensions (not for using QPSC)

**Micro-Manager:**
- Download from: https://micro-manager.org/Download_Micro-Manager_Latest_Release

## Directory Structure After Setup

### Production Mode

```
C:\Users\YourName\QPSC\
├── extensions\                  # ⭐ NEW: Extension JARs (easy access)
│   ├── qupath-extension-qpsc-X.X.X-all.jar
│   └── qupath-extension-tiles-to-pyramid-X.X.X-all.jar
├── configurations\              # Microscope configurations
│   ├── config_template.yml
│   ├── autofocus_template.yml
│   ├── imageprocessing_template.yml
│   ├── config_PPM.yml          # Example configs
│   ├── config_CAMM.yml
│   └── resources\
│       └── resources_LOCI.yml
├── venv_qpsc\                   # Python virtual environment
└── Launch-QPSC.ps1             # Launcher script

C:\Users\YourName\QuPath\
└── v0.X\                        # Version-specific user data
    └── extensions\              # QuPath extensions (auto-copied)
        ├── qupath-extension-qpsc-X.X.X-all.jar
        └── qupath-extension-tiles-to-pyramid-X.X.X-all.jar
```

### Development Mode

```
C:\Users\YourName\QPSC\
├── qupath-extension-qpsc\           # Java source (cloned)
├── qupath-extension-tiles-to-pyramid\ # Java source (cloned)
├── microscope_command_server\       # Python source (cloned)
├── microscope_control\              # Python source (cloned)
├── ppm_library\                     # Python source (cloned)
├── microscope_configurations\       # YAML templates (cloned)
├── configurations\                  # Your configurations (copied)
├── venv_qpsc\                       # Python virtual env
└── Launch-QPSC.ps1                 # Launcher script
```

## Troubleshooting

### "Execution of scripts is disabled on this system"

PowerShell execution policy is blocking the script. Run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Python not found"

Python is not in your PATH. Either:
1. Reinstall Python with "Add to PATH" checked, or
2. Run the script with full path:
   ```powershell
   C:\Python39\python.exe -m pip install git+https://github.com/uw-loci/ppm_library.git
   ```

### "Git not found" (development mode)

Install Git from: https://git-scm.com/download/win

### QuPath extensions not downloading

Manually download from:
- https://github.com/uw-loci/qupath-extension-qpsc/releases
- https://github.com/uw-loci/qupath-extension-tiles-to-pyramid/releases

**Choose the `-all.jar` files** (shadow JARs with bundled dependencies).

Place JAR files in:
1. First: `C:\Users\YourName\QPSC\extensions\` (for easy access)
2. Then copy to: `C:\Users\YourName\QuPath\vX.X\extensions\` (replace X.X with your QuPath version)

### QPSC menu not appearing in QuPath

1. **Check extension location:**
   - Extensions must be in QuPath **user data** directory, not installation directory
   - Correct: `C:\Users\YourName\QuPath\v0.X\extensions\`
   - Incorrect: `C:\AppData\Local\QuPath-X.X.X\extensions\`

2. **Restart QuPath:**
   - Extensions only load on startup
   - If QuPath was running during installation, close and restart it

3. **Check for custom extensions directory:**
   - If you configured a custom directory in QuPath preferences:
   - Copy JARs from `C:\Users\YourName\QPSC\extensions\` to your custom directory

4. **Verify JARs downloaded:**
   - Check `C:\Users\YourName\QPSC\extensions\` folder
   - Should contain: `qupath-extension-qpsc-X.X.X-all.jar` and `qupath-extension-tiles-to-pyramid-X.X.X-all.jar`

### Python package installation fails

If you see `ERROR: Could not find a version that satisfies the requirement`, ensure:
1. You have internet connectivity
2. Git is installed (required for `pip install git+https://...`)
3. Try installing packages manually in order:
   ```powershell
   pip install opencv-python-headless
   pip install git+https://github.com/uw-loci/ppm_library.git
   pip install git+https://github.com/uw-loci/microscope_control.git
   pip install git+https://github.com/uw-loci/microscope_command_server.git
   pip install pycromanager
   ```

### Server fails with "ModuleNotFoundError: No module named 'cv2'"

OpenCV is missing (required for autofocus):
```powershell
pip install opencv-python-headless
```

Or if using virtual environment:
```powershell
C:\Users\YourName\QPSC\venv_qpsc\Scripts\pip.exe install opencv-python-headless
```

### Server output not visible

The server should open in a **separate window** showing:
- Port number (default: 5000)
- Micro-Manager connection status
- Configuration loading messages
- Error messages

If no window appears:
1. Check Task Manager for `python.exe` processes
2. Try running manually:
   ```powershell
   C:\Users\YourName\QPSC\venv_qpsc\Scripts\python.exe -m microscope_command_server.server.qp_server
   ```

## Links

- **QPSC Documentation:** https://github.com/uw-loci/QPSC
- **Uninstallation Guide:** [UNINSTALL.md](UNINSTALL.md) - Remove QPSC components for clean reinstallation
- **QuPath:** https://qupath.github.io/
- **Micro-Manager:** https://micro-manager.org/
- **Pycro-Manager:** https://pycro-manager.readthedocs.io/

## Notes

- **Virtual Environment:** Development mode creates `venv_qpsc` - always activate before running Python code
- **Editable Install:** In development mode, Python code changes take effect immediately without reinstalling
- **Building Extensions:** Java extensions must be rebuilt after code changes (`.\gradlew build`)
- **Configuration Files:** Never commit your custom configurations to Git - templates are provided for reference
- **Installation Order:** Python packages must be installed in dependency order: ppm_library → microscope_control → microscope_command_server

## Differences from PyPI Installation

**Why GitHub installation?**

QPSC Python packages are not currently published to PyPI. All installations use GitHub as the source:
- **Production mode**: `pip install git+https://github.com/...` downloads and installs directly
- **Development mode**: Clones repositories first, then `pip install -e` creates editable installs

**Benefits of GitHub installation:**
- Always get the latest code
- Development mode allows immediate code modification
- No need to publish to PyPI for internal/research software

**Questions?** Open an issue at https://github.com/uw-loci/QPSC/issues

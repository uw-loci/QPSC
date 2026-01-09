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

- ✅ Installs Python packages from GitHub in correct dependency order
- ✅ Downloads QuPath extension JAR files (latest releases)
- ✅ Downloads configuration templates
- ✅ Creates launcher script for easy startup
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
   - Copy `build/libs/*.jar` to `C:\Users\YourName\QuPath\extensions\`

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
├── configurations\              # Microscope configurations
│   ├── config_template.yml
│   ├── autofocus_template.yml
│   ├── imageprocessing_template.yml
│   ├── config_PPM.yml          # Example configs
│   ├── config_CAMM.yml
│   └── resources\
│       └── resources_LOCI.yml
└── Launch-QPSC.ps1             # Launcher script

C:\Users\YourName\QuPath\
└── extensions\                  # QuPath extensions
    ├── qupath-extension-qpsc-X.X.X.jar
    └── qupath-extension-tiles-to-pyramid-X.X.X.jar
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

Place JAR files in: `C:\Users\YourName\QuPath\extensions\`

### Python package installation fails

If you see `ERROR: Could not find a version that satisfies the requirement`, ensure:
1. You have internet connectivity
2. Git is installed (required for `pip install git+https://...`)
3. Try installing packages manually in order:
   ```powershell
   pip install git+https://github.com/uw-loci/ppm_library.git
   pip install git+https://github.com/uw-loci/microscope_control.git
   pip install git+https://github.com/uw-loci/microscope_command_server.git
   ```

## Links

- **QPSC Documentation:** https://github.com/uw-loci/QPSC
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

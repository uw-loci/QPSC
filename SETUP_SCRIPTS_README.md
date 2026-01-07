# QPSC Setup Scripts

Two PowerShell scripts are provided for setting up QPSC on Windows systems:

## 🚀 PPM-QuPath.ps1 - Production/User Setup

**For end users who want to use QPSC with pre-built binaries.**

### What it does:
- ✅ Installs Python packages from PyPI (`microscope-server`, `microscope-control`, `ppm-library`)
- ✅ Downloads QuPath extension JAR files (latest releases)
- ✅ Downloads configuration templates
- ✅ Creates a launcher script for easy startup
- ✅ Checks for Micro-Manager installation

### Usage:

**Basic installation:**
```powershell
.\PPM-QuPath.ps1
```

**Custom installation directory:**
```powershell
.\PPM-QuPath.ps1 -InstallDir "D:\QPSC"
```

**Skip QuPath setup (if already configured):**
```powershell
.\PPM-QuPath.ps1 -SkipQuPath
```

**Install and launch immediately:**
```powershell
.\PPM-QuPath.ps1 -Launch
```

### After Installation:

1. **Configure your microscope:**
   - Edit `configurations\config_template.yml` for your hardware

2. **Launch QPSC:**
   ```powershell
   .\Launch-QPSC.ps1 --qupath
   ```

   Or manually:
   ```powershell
   microscope-server    # Start server
   QuPath.exe           # Start QuPath (from QuPath installation)
   ```

---

## 🛠️ PPM-QuPath-dev.ps1 - Development Setup

**For developers who want to modify QPSC code.**

### What it does:
- ✅ Clones all 6 QPSC repositories from GitHub
- ✅ Creates Python virtual environment
- ✅ Installs Python packages in editable mode (`pip install -e`)
- ✅ Sets up directory structure for development
- ✅ Copies configuration templates

### Repositories Cloned:

**QuPath Extensions (Java):**
- `qupath-extension-qpsc`
- `qupath-extension-tiles-to-pyramid`

**Python Microscope Control:**
- `microscope_command_server`
- `microscope_control`
- `ppm_library`
- `microscope_configurations`

### Usage:

**Basic development setup:**
```powershell
.\PPM-QuPath-dev.ps1
```

**Custom development directory:**
```powershell
.\PPM-QuPath-dev.ps1 -TargetDir "D:\Dev\QPSC"
```

**Skip Python setup (Java development only):**
```powershell
.\PPM-QuPath-dev.ps1 -SkipPython
```

**Skip Java setup (Python development only):**
```powershell
.\PPM-QuPath-dev.ps1 -SkipJava
```

### After Setup:

1. **Activate Python environment:**
   ```powershell
   C:\QPSC_Dev\venv_qpsc\Scripts\Activate.ps1
   ```

2. **Build QuPath extensions:**
   ```powershell
   cd C:\QPSC_Dev\qupath-extension-qpsc
   .\gradlew build
   ```

3. **Make code changes:**
   - Python: Changes take effect immediately (editable install)
   - Java: Rebuild with `.\gradlew build` after changes

4. **Run tests:**
   ```powershell
   # Java
   cd qupath-extension-qpsc
   .\gradlew test

   # Python
   pytest microscope_control/
   ```

---

## 📋 Prerequisites

Both scripts require:

- **Windows PowerShell 5.1+** or **PowerShell Core 7+**
- **Git** (for development script)
- **Python 3.9+** with pip
- **Java 21+** (for QuPath extensions)
- **Micro-Manager 2.0+** (for hardware control)

### Installing Prerequisites:

**Python:**
- Download from: https://www.python.org/
- ✅ Check "Add Python to PATH" during installation

**Git:**
- Download from: https://git-scm.com/download/win

**Java:**
- Download OpenJDK 21: https://adoptium.net/

**Micro-Manager:**
- Download from: https://micro-manager.org/Download_Micro-Manager_Latest_Release

---

## 🔧 Script Parameters Reference

### PPM-QuPath.ps1

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-InstallDir` | String | `$env:USERPROFILE\QPSC` | Installation directory |
| `-QuPathDir` | String | `$env:USERPROFILE\QuPath` | QuPath installation directory |
| `-SkipQuPath` | Switch | False | Skip QuPath extension download |
| `-Launch` | Switch | False | Launch QPSC after installation |

### PPM-QuPath-dev.ps1

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-TargetDir` | String | `C:\QPSC_Dev` | Development directory |
| `-SkipPython` | Switch | False | Skip Python setup (Java only) |
| `-SkipJava` | Switch | False | Skip Java checks (Python only) |

---

## 📂 Directory Structure After Setup

### Production (PPM-QuPath.ps1):
```
C:\Users\YourName\QPSC\
├── configurations\              # Microscope configurations
│   ├── config_template.yml
│   ├── autofocus_template.yml
│   ├── imageprocessing_template.yml
│   └── resources\
│       └── resources_LOCI.yml
└── Launch-QPSC.ps1             # Launcher script

C:\Users\YourName\QuPath\
└── extensions\                  # QuPath extensions
    ├── qupath-extension-qpsc-X.X.X.jar
    └── qupath-extension-tiles-to-pyramid-X.X.X.jar
```

### Development (PPM-QuPath-dev.ps1):
```
C:\QPSC_Dev\
├── qupath-extension-qpsc\           # Java source
├── qupath-extension-tiles-to-pyramid\ # Java source
├── microscope_command_server\       # Python source
├── microscope_control\              # Python source
├── ppm_library\                     # Python source
├── microscope_configurations\       # YAML templates
├── configs\                         # Your configurations
└── venv_qpsc\                       # Python virtual env
```

---

## ❓ Troubleshooting

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
   C:\Python39\python.exe -m pip install microscope-server
   ```

### "Git not found" (development script)

Install Git from: https://git-scm.com/download/win

### QuPath extensions not downloading

Manually download from:
- https://github.com/uw-loci/qupath-extension-qpsc/releases
- https://github.com/uw-loci/qupath-extension-tiles-to-pyramid/releases

Place JAR files in: `C:\Users\YourName\QuPath\extensions\`

---

## 🔗 Links

- **QPSC Documentation:** https://github.com/uw-loci/QPSC
- **QuPath:** https://qupath.github.io/
- **Micro-Manager:** https://micro-manager.org/
- **Pycro-Manager:** https://pycro-manager.readthedocs.io/

---

## 📝 Notes

- **Virtual Environment:** Development script creates `venv_qpsc` - always activate before running Python code
- **Editable Install:** In development mode, Python code changes take effect immediately without reinstalling
- **Building Extensions:** Java extensions must be rebuilt after code changes (`.\gradlew build`)
- **Configuration Files:** Never commit your custom configurations to Git - templates are provided for reference

---

**Questions?** Open an issue at https://github.com/uw-loci/QPSC/issues

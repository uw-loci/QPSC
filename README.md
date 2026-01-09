# QPSC - QuPath Scope Control

**Annotation-driven targeted microscopy acquisition from within QuPath**

QPSC bridges [QuPath](https://qupath.github.io/)'s digital pathology environment with automated microscope control via [Micro-Manager](https://micro-manager.org/) and [Pycro-Manager](https://pycro-manager.readthedocs.io/). Users define regions of interest in QuPath and automatically acquire high-resolution microscopy data at those locations.

---

**[→ Jump to Installation Instructions](#installation)**

---

## System Overview

> **Click any component** to navigate to its repository or documentation.

```mermaid
flowchart LR
    subgraph User["User Layer"]
        U[("Pathologist / Researcher")]
    end

    subgraph QuPath["QuPath Application"]
        QP["QuPath + QPSC Extension"]
        T2P["Tiles-to-Pyramid Extension"]
    end

    subgraph Python["Python Microscope Control"]
        SRV["Command Server"]
        CTRL["Hardware Control"]
        PPM["PPM Library"]
    end

    subgraph Hardware["Microscope"]
        HW[("Microscope Hardware")]
    end

    subgraph Bridge["Hardware Bridge"]
        PM["Pycro-Manager"]
        MM["Micro-Manager"]
    end

    U -->|"Define ROIs & Parameters"| QP
    QP ==>|"Socket Commands"| SRV
    SRV --> CTRL
    SRV --> PPM
    CTRL -->|"Python API"| PM
    PM -->|"Java Bridge"| MM
    MM -->|"Device Control"| HW

    HW -.->|"Images"| CTRL
    CTRL -.->|"Processing"| PPM
    PPM -.->|"Processed images and analysis"| SRV
    SRV -.->|"Raw tiles"| T2P
    T2P -.->|"Stitched OME-ZARR"| QP

    %% Add invisible spacing node for padding
    HW ~~~ SPACE[ ]
    style SPACE fill:none,stroke:none

    style QP fill:#4A90D9,color:#fff
    style T2P fill:#4A90D9,color:#fff
    style SRV fill:#306998,color:#fff
    style CTRL fill:#4A7DB8,color:#fff
    style PPM fill:#4A7DB8,color:#fff
    style PM fill:#E67E22,color:#fff
    style MM fill:#D35400,color:#fff
    style HW fill:#C0392B,color:#fff

    click QP "https://github.com/uw-loci/qupath-extension-qpsc" "QPSC Extension Repository"
    click T2P "https://github.com/uw-loci/qupath-extension-tiles-to-pyramid" "Tiles-to-Pyramid Extension Repository"
    click SRV "https://github.com/uw-loci/microscope_command_server" "Command Server Repository"
    click CTRL "https://github.com/uw-loci/microscope_control" "Hardware Control Repository"
    click PPM "https://github.com/uw-loci/ppm_library" "PPM Library Repository"
    click PM "https://pycro-manager.readthedocs.io/" "Pycro-Manager Documentation"
    click MM "https://micro-manager.org/" "Micro-Manager Website"
```

## Core Workflow

1. **Setup Coordinates** - Use known/estimated stage coordinates, or load an image from a slide scanner to enable mapping of stage coordinates to locations on the slide
2. **Define Regions** - Draw annotations on areas of interest
3. **Configure Acquisition** - Select imaging modality, objectives, and parameters
4. **Acquire** - The QPSC extension sends a workflow to the microscope command server to capture high-resolution tiles
5. **Stitch & Import** - Tiles are stitched in a QuPath extension into pyramidal images and imported into a QuPath project along with metadata for sorting the results

## Component Repositories

### QuPath Extensions

| Repository | Description | Language |
|------------|-------------|----------|
| [qupath-extension-qpsc](https://github.com/uw-loci/qupath-extension-qpsc) | Main QPSC QuPath extension - UI, workflows, coordinate transforms | Java |
| [qupath-extension-tiles-to-pyramid](https://github.com/uw-loci/qupath-extension-tiles-to-pyramid) | Stitches acquired tiles into pyramidal OME-ZARR images | Java |

### Python Microscope Control

| Repository | Description | Language |
|------------|-------------|----------|
| [microscope_command_server](https://github.com/uw-loci/microscope_command_server) | Socket server for QuPath-to-microscope communication and acquisition workflows | Python |
| [microscope_control](https://github.com/uw-loci/microscope_control) | Hardware abstraction layer via Pycromanager/Micro-Manager | Python |
| [ppm_library](https://github.com/uw-loci/ppm_library) | Image processing library for PPM and general microscopy imaging | Python |
| [microscope_configurations](https://github.com/uw-loci/microscope_configurations) | YAML configuration templates for microscope systems | YAML |

### Supporting Tools

| Repository | Description |
|------------|-------------|
| [qupath-extension-ocr4labels](https://github.com/MichaelSNelson/qupath-extension-ocr4labels) | OCR for slide label text extraction |
| [QuPath_Confusion_Matrix_Extension](https://github.com/kgallik/QuPath_Confusion_Matrix_Extension) | Classification validation tools |

## Architecture

QPSC uses a modular architecture with separate Python packages for different concerns:

- **QuPath Extensions** (Java) - User interface, workflows, coordinate transforms
- **Python Microscope Control** - Socket server, hardware abstraction, image processing
- **Micro-Manager Stack** - Hardware device control

For detailed architecture documentation including:
- Component structure and responsibilities
- Communication protocols
- Coordinate system transformations
- Modality system design
- Configuration hierarchy
- Threading and concurrency

See: **[docs/architecture.md](docs/architecture.md)**

## Imaging Modalities

QPSC supports multiple imaging modalities through a pluggable architecture:

| Modality | Description | Status |
|----------|-------------|--------|
| **PPM** (Polarized Light) | Multi-angle polarization microscopy for birefringent samples | Active |
| **Brightfield** | Standard transmitted light imaging | Active |
| **Fluorescence** | Multi-channel fluorescence (planned) | Planned |
| **SHG/Multiphoton** | Second harmonic generation imaging | Experimental |

## Installation

QPSC requires several components that work together. This section guides you through installing everything needed for annotation-driven microscopy acquisition.

### Prerequisites

Install these foundational components **in this order** before QPSC installation:

#### 1. Micro-Manager (Hardware Control)
- **Version**: 2.0+ (latest 2.0 gamma release recommended)
- **Purpose**: Controls microscope hardware via device adapters
- **Installation**: [Micro-Manager Download](https://micro-manager.org/Download_Micro-Manager_Latest_Release)
- **Configuration**: Configure device adapters for your specific hardware before proceeding
- **Note**: Must be installed and tested before Python packages

#### 2. QuPath (Digital Pathology Platform)
- **Version**: 0.6.0+
- **Purpose**: Annotation interface and image analysis environment
- **Installation**: [QuPath Download](https://qupath.github.io/)
- **Note**: Install before QPSC extensions

#### 3. Python (Microscope Control Server)
- **Version**: Python 3.10 or later (3.12 recommended)
- **Purpose**: Runtime for microscope control server
- **Installation**: [Python Download](https://www.python.org/downloads/)
- **Windows Note**: Check "Add Python to PATH" during installation

#### 4. Java Development Kit (For Extension Development Only)
- **Version**: Java 21+
- **Purpose**: Building QuPath extensions from source
- **Note**: Not required for using QPSC, only for modifying extension code
- **Installation**: [Adoptium Temurin](https://adoptium.net/)

---

### Automated Installation (Windows - Recommended)

**Best for most users** - Automated PowerShell script handles all Python package installation, QuPath extensions, and configuration templates.

#### Quick Start (Production Mode)

For users who want to use QPSC without modifying code:

```powershell
# 1. Open PowerShell (Run as Administrator recommended)

# 2. Download the setup script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/uw-loci/QPSC/main/PPM-QuPath.ps1" -OutFile "PPM-QuPath.ps1"

# 3. Run the setup script
.\PPM-QuPath.ps1
```

**What this does:**
- Creates a Python virtual environment
- Installs Python packages from GitHub releases (latest stable versions)
- Downloads QPSC QuPath extension JARs
- Downloads Tiles-to-Pyramid extension JAR
- Downloads configuration templates
- Creates a launcher script for easy server startup

**Default installation location:** `C:\QPSC\`

**Custom location:**
```powershell
.\PPM-QuPath.ps1 -InstallDir "D:\MyProjects\QPSC"
```

#### Development Mode

For developers who want to modify QPSC code:

```powershell
# Download and run in development mode
.\PPM-QuPath.ps1 -Development
```

**What this does:**
- Clones all 6 QPSC repositories
- Creates Python virtual environment
- Installs packages in editable mode (`pip install -e .`)
- Downloads QuPath extensions
- Sets up development environment

**Detailed setup script documentation:** [SETUP_SCRIPTS_README.md](SETUP_SCRIPTS_README.md)

---

### Manual Installation (All Platforms)

**When to use manual installation:**
- macOS or Linux systems
- Prefer manual control over installation process
- Need to customize installation steps
- Automated script fails or is unavailable

#### Prerequisites Check

Before starting, verify:
```bash
python --version   # Should show 3.10 or higher
pip --version      # Python package installer
git --version      # For cloning repositories (development mode)
```

#### Step 1: Create Python Virtual Environment (Recommended)

Using a virtual environment isolates QPSC dependencies from system Python:

**Windows:**
```powershell
# Create virtual environment
python -m venv qpsc-env

# Activate virtual environment
.\qpsc-env\Scripts\activate

# Verify activation (should show path to venv)
where python
```

**macOS/Linux:**
```bash
# Create virtual environment
python3 -m venv qpsc-env

# Activate virtual environment
source qpsc-env/bin/activate

# Verify activation
which python
```

> **Note:** You must activate the virtual environment each time you want to run the microscope server.

#### Step 2: Install Python Packages

**Critical: Installation Order Matters**

These packages have dependencies on each other and must be installed in this exact order:

**Option A: Install from GitHub (Users)**

Installs the latest released versions from GitHub:

```bash
# 1. PPM Library (no QPSC dependencies)
pip install git+https://github.com/uw-loci/ppm_library.git

# 2. Microscope Control (depends on ppm_library)
pip install git+https://github.com/uw-loci/microscope_control.git

# 3. Microscope Command Server (depends on both above)
pip install git+https://github.com/uw-loci/microscope_command_server.git
```

**Option B: Clone and Install Editable (Developers)**

For development and code modification:

```bash
# Choose a parent directory for repositories
cd /path/to/your/projects/

# Clone and install ppm_library
git clone https://github.com/uw-loci/ppm_library.git
cd ppm_library
pip install -e .
cd ..

# Clone and install microscope_control
git clone https://github.com/uw-loci/microscope_control.git
cd microscope_control
pip install -e .
cd ..

# Clone and install microscope_command_server
git clone https://github.com/uw-loci/microscope_command_server.git
cd microscope_command_server
pip install -e .
cd ..
```

**Verify installation:**
```bash
pip list | grep -E "(ppm-library|microscope-control|microscope-server)"
```

Expected output:
```
microscope-control    1.0.0    /path/to/microscope_control
microscope-server     1.0.0    /path/to/microscope_command_server
ppm-library           1.0.0    /path/to/ppm_library
```

**Troubleshooting:** See [Python Package Installation Troubleshooting](#troubleshooting-python-package-installation) below.

#### Step 3: Install QuPath Extensions

Download the latest JAR files from GitHub releases:

1. **QPSC Extension** (main functionality)
   - Navigate to: [qupath-extension-qpsc/releases](https://github.com/uw-loci/qupath-extension-qpsc/releases)
   - Download: `qupath-extension-qpsc-[version].jar`

2. **Tiles-to-Pyramid Extension** (stitching)
   - Navigate to: [qupath-extension-tiles-to-pyramid/releases](https://github.com/uw-loci/qupath-extension-tiles-to-pyramid/releases)
   - Download: `qupath-extension-tiles-to-pyramid-[version].jar`

**Install extensions:**

Copy both JAR files to QuPath's extensions folder:

- **Windows**: `C:\Users\[YourUsername]\QuPath\extensions\`
- **macOS**: `~/QuPath/extensions/`
- **Linux**: `~/QuPath/extensions/`

**Verify installation:**
1. Launch QuPath
2. Go to `Extensions` menu
3. Look for `QPSC` menu entry

If you don't see QPSC in the Extensions menu, check:
- JAR files are in the correct extensions folder
- QuPath was restarted after copying JARs
- Check QuPath's log for any loading errors

#### Step 4: Download Configuration Templates

Configuration files tell the server about your microscope hardware.

**Download from GitHub:**

Navigate to [microscope_configurations](https://github.com/uw-loci/microscope_configurations) and download:

- `templates/config_template.yml` - Main microscope configuration
- `templates/autofocus_template.yml` - Autofocus parameters
- `templates/imageprocessing_template.yml` - Camera/exposure settings
- `resources/resources_LOCI.yml` - Hardware component lookup tables

**Save location:**
Create a `configurations` folder in your project directory, e.g.:
- Windows: `C:\QPSC\configurations\`
- macOS/Linux: `~/QPSC/configurations/`

**Edit for your hardware:**
1. Copy `config_template.yml` to a new file (e.g., `config_mymicroscope.yml`)
2. Edit device names, stage limits, objectives, etc. to match your hardware
3. See [Configuration Documentation](docs/configuration.md) for details

#### Step 5: Start the Microscope Server

Ensure Micro-Manager is running before starting the server.

**From command line:**
```bash
# Activate virtual environment (if using)
# Windows:
.\qpsc-env\Scripts\activate
# macOS/Linux:
source qpsc-env/bin/activate

# Start server
microscope-server
```

**Expected output:**
```
INFO - Loading generic startup configuration...
INFO - Initializing Micro-Manager connection...
INFO - Server listening on 0.0.0.0:5000
INFO - Ready for connections...
```

**Server is now ready!** You can connect from QuPath's QPSC extension.

To stop the server: Press `Ctrl+C`

---

### Detailed Component Installation Guides

For step-by-step instructions with screenshots and troubleshooting, see individual repository READMEs:

| Component | Repository | Installation Guide |
|-----------|------------|-------------------|
| **PPM Library** | [ppm_library](https://github.com/uw-loci/ppm_library) | [Installation](https://github.com/uw-loci/ppm_library#installation) |
| **Microscope Control** | [microscope_control](https://github.com/uw-loci/microscope_control) | [Installation](https://github.com/uw-loci/microscope_control#installation) |
| **Command Server** | [microscope_command_server](https://github.com/uw-loci/microscope_command_server) | [Installation](https://github.com/uw-loci/microscope_command_server#installation) |
| **Configuration Templates** | [microscope_configurations](https://github.com/uw-loci/microscope_configurations) | [Configuration Guide](https://github.com/uw-loci/microscope_configurations#usage) |
| **QPSC Extension** | [qupath-extension-qpsc](https://github.com/uw-loci/qupath-extension-qpsc) | [Extension Docs](https://github.com/uw-loci/qupath-extension-qpsc#installation) |
| **Stitching Extension** | [qupath-extension-tiles-to-pyramid](https://github.com/uw-loci/qupath-extension-tiles-to-pyramid) | [Extension Docs](https://github.com/uw-loci/qupath-extension-tiles-to-pyramid#installation) |

---

### Troubleshooting Python Package Installation

#### Problem: `ModuleNotFoundError` when importing packages

**Cause:** Python packages installed incorrectly due to repository structure mismatch.

**Symptoms:**
```python
>>> import ppm_library
ModuleNotFoundError: No module named 'ppm_library'
```

**Solution for editable installs (development mode):**

The packages have a known packaging structure issue that has been fixed in the latest development versions. The repository directories are named differently from the Python package names they contain.

1. **Verify pyproject.toml files are updated:**

   Each repository's `pyproject.toml` should have:
   ```toml
   [tool.hatch.build.targets.wheel]
   packages = ["."]
   ```

   If you see `packages = ["package_name"]` instead, update it to `packages = ["."]`

2. **Create symlink for microscope_server:**

   The `microscope_command_server` repository contains code that imports `microscope_server`:

   **Windows (Command Prompt as Administrator):**
   ```cmd
   mklink /D microscope_server microscope_command_server
   ```

   **macOS/Linux:**
   ```bash
   ln -s microscope_command_server microscope_server
   ```

3. **Reinstall packages with updated configuration:**
   ```bash
   cd ppm_library
   pip install -e . --force-reinstall --no-deps
   cd ../microscope_control
   pip install -e . --force-reinstall --no-deps
   cd ../microscope_command_server
   pip install -e . --force-reinstall --no-deps
   ```

4. **Verify with PYTHONPATH (if imports still fail):**

   Set PYTHONPATH to include the parent directory:

   **Windows PowerShell:**
   ```powershell
   $env:PYTHONPATH = "C:\path\to\parent\directory"
   microscope-server
   ```

   **macOS/Linux:**
   ```bash
   export PYTHONPATH="/path/to/parent/directory:$PYTHONPATH"
   microscope-server
   ```

#### Problem: `UnicodeEncodeError` in server logs

**Cause:** Unicode characters in logging strings (Windows cp1252 encoding limitation).

**Solution:** This has been fixed in recent code - update to latest version:
```bash
cd microscope_command_server
git pull
```

The codebase now uses ASCII-only characters in all logging and internal strings.

#### Problem: Circular dependency importing ppm_library

**Cause:** `ppm_library/__init__.py` imports from `microscope_control`.

**Solution:** This has been fixed. Update `ppm_library/__init__.py` to remove the problematic import on line 39:
```python
# REMOVE this line:
from microscope_control.autofocus.tissue_detection import EmptyRegionDetector
```

#### Problem: Missing OpenCV (cv2) dependency

**Symptoms:**
```
ModuleNotFoundError: No module named 'cv2'
```

**Solution:**
```bash
pip install opencv-python
```

This dependency will be added to `microscope_control` requirements in a future update.

#### Problem: Port 5000 already in use

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

### Post-Installation Verification

After installation, verify everything works:

#### 1. Test Python Package Imports
```python
python -c "import ppm_library, microscope_control; from microscope_server.server import qp_server; print('✓ All packages imported successfully')"
```

#### 2. Test Server Startup
```bash
# Start Micro-Manager first
# Then start server
microscope-server
```

Expected: Server should start and show "Server listening on 0.0.0.0:5000"

#### 3. Test QuPath Extension
1. Launch QuPath
2. Go to `Extensions > QPSC`
3. You should see menu options for workflows

#### 4. Test Full Workflow
See [Usage Guide](docs/usage.md) for a complete workflow walkthrough

## Configuration

QPSC uses YAML configuration files for microscope-specific settings:

```yaml
# Example: config_ppm.yml
microscope:
  name: "PPM Microscope"
  stage:
    type: "ASI"
    limits:
      x: [-50000, 50000]
      y: [-50000, 50000]

modalities:
  ppm_20x:
    objective: "20x"
    angles: [0, 45, 90, 135]
    exposure_ms: 50
```

See [Configuration Documentation](docs/configuration.md) for full details.

## Data Flow

```mermaid
flowchart LR
    subgraph Input
        Slide["Overview\nImage"]
        ROI["User\nAnnotations"]
    end

    subgraph Transform
        Pixel["Pixel\nCoordinates"]
        Stage["Stage\nCoordinates"]
        Grid["Tile\nGrid"]
    end

    subgraph Acquire
        Seq["Acquisition\nSequence"]
        Cap["Multi-angle\nCapture"]
    end

    subgraph Process
        Raw["Raw\nTiles"]
        Stitch["Stitching"]
    end

    subgraph Output
        ZARR["OME-ZARR\nPyramid"]
        Project["QuPath\nProject"]
    end

    Slide --> Pixel
    ROI --> Pixel
    Pixel --> Stage
    Stage --> Grid
    Grid --> Seq
    Seq --> Cap
    Cap --> Raw
    Raw --> Stitch
    Stitch --> ZARR
    ZARR --> Project

    style Pixel fill:#4A90D9,color:#fff
    style Stage fill:#4A90D9,color:#fff
    style Seq fill:#306998,color:#fff
    style ZARR fill:#9B59B6,color:#fff
```

## Development

### Building from Source

```bash
# Clone the main extension
git clone https://github.com/uw-loci/qupath-extension-qpsc.git
cd qupath-extension-qpsc

# Build (requires Java 21+)
./gradlew build

# Run tests
./gradlew test
```

### Project Structure

```
QPSC Repositories (Modular Architecture)/

QuPath Extensions:
├── qupath-extension-qpsc/           # Main QPSC extension
│   ├── src/main/java/qupath/ext/qpsc/
│   │   ├── controller/              # Workflow orchestration
│   │   ├── modality/                # Imaging mode plugins
│   │   ├── service/                 # Socket communication
│   │   ├── ui/                      # JavaFX dialogs
│   │   └── utilities/               # Coordinate transforms, config
│   └── build.gradle
└── qupath-extension-tiles-to-pyramid/  # Image stitching

Python Microscope Control (pip-installable packages):
├── microscope_command_server/       # Package: microscope-server
│   ├── server/
│   │   ├── qp_server.py            # Socket server
│   │   └── protocol.py             # Communication protocol
│   ├── acquisition/
│   │   ├── workflow.py             # Acquisition orchestration
│   │   ├── tiles.py                # Tile grid utilities
│   │   └── pipeline.py             # Processing pipeline
│   ├── client/
│   │   └── client.py               # Python client library
│   └── pyproject.toml
│
├── microscope_control/              # Package: microscope-control
│   ├── hardware/
│   │   ├── base.py                 # Hardware abstraction
│   │   └── pycromanager.py         # Micro-Manager integration
│   ├── autofocus/
│   │   ├── core.py                 # Autofocus algorithms
│   │   └── metrics.py              # Focus quality metrics
│   ├── config/
│   │   └── manager.py              # YAML config management
│   └── pyproject.toml
│
├── ppm_library/                     # Package: ppm-library
│   ├── ppm/
│   │   └── calibration.py          # PPM calibration
│   ├── imaging/
│   │   ├── background.py           # Background correction
│   │   ├── tissue_detection.py     # Empty region detection
│   │   └── writer.py               # TIFF I/O
│   ├── debayering/
│   │   ├── cpu.py                  # CPU debayering
│   │   └── gpu.py                  # GPU debayering
│   └── pyproject.toml
│
└── microscope_configurations/       # YAML configuration templates
    ├── config_template.yml
    ├── autofocus_template.yml
    ├── imageprocessing_template.yml
    ├── config_PPM.yml              # Example PPM config
    ├── config_CAMM.yml             # Example CAMM config
    └── resources/                  # Hardware resource definitions
```

**Dependency Chain:**
```
microscope_configurations (runtime config files)
         ↓
    ┌────┴────┐
    ↓         ↓
microscope_control  ppm_library (standalone)
    ↓         ↓
    └────┬────┘
         ↓
microscope_command_server
```

## Communication Protocol

QPSC uses a socket-based protocol for communication between QuPath and the Python server:

```mermaid
sequenceDiagram
    participant QP as QuPath/QPSC
    participant Srv as Python Server
    participant MM as Micro-Manager

    QP->>Srv: Connect (TCP)
    QP->>Srv: ACQUIRE command + params
    Srv->>MM: Initialize acquisition

    loop For each tile position
        Srv->>MM: Move stage
        Srv->>MM: Capture image(s)
        Srv-->>QP: Progress update
    end

    Srv->>Srv: Stitch tiles
    Srv-->>QP: Acquisition complete
    QP->>QP: Import result
```

## Contributing

We welcome contributions! Please see individual repository guidelines:

**QuPath Extensions:**
- [QPSC Extension Contributing Guide](https://github.com/uw-loci/qupath-extension-qpsc/blob/main/CONTRIBUTING.md)
- [Tiles-to-Pyramid Extension](https://github.com/uw-loci/qupath-extension-tiles-to-pyramid)

**Python Microscope Control:**
- [Microscope Command Server Issues](https://github.com/uw-loci/microscope_command_server/issues)
- [Microscope Control Issues](https://github.com/uw-loci/microscope_control/issues)
- [PPM Library Issues](https://github.com/uw-loci/ppm_library/issues)
- [Configuration Templates](https://github.com/uw-loci/microscope_configurations/issues)

## Publications & Citations

If you use QPSC in your research, please cite:

> [Citation information to be added]

## License

Components are licensed individually - see each repository for details.

## Acknowledgments

QPSC is developed at the [Laboratory for Optical and Computational Instrumentation (LOCI)](https://loci.wisc.edu/) at the University of Wisconsin-Madison.

- [QuPath](https://qupath.github.io/) - Open source software for bioimage analysis
- [Micro-Manager](https://micro-manager.org/) - Open source microscopy software
- [Pycro-Manager](https://pycro-manager.readthedocs.io/) - Python interface for Micro-Manager

---

**Questions?** Open an issue in the relevant repository or contact the LOCI team.

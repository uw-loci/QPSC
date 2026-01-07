# QPSC - QuPath Scope Control

**Annotation-driven targeted microscopy acquisition from within QuPath**

QPSC bridges [QuPath](https://qupath.github.io/)'s digital pathology environment with automated microscope control via [Micro-Manager](https://micro-manager.org/) and [Pycro-Manager](https://pycro-manager.readthedocs.io/). Users define regions of interest in QuPath and automatically acquire high-resolution microscopy data at those locations.

## System Overview

> **Click any component** to navigate to its repository or documentation.

```mermaid
flowchart LR
    subgraph User["User Layer"]
        U[("Pathologist /\nResearcher")]
    end

    subgraph QuPath["QuPath Application"]
        QP["QuPath +\nQPSC Extension"]
    end

    subgraph Python["Python Microscope Control"]
        SRV["Command Server"]
        CTRL["Hardware Control"]
        PPM["PPM Library"]
    end

    subgraph Bridge["Hardware Bridge"]
        PM["Pycro-Manager"]
        MM["Micro-Manager"]
    end

    subgraph Hardware["Microscope"]
        HW[("Microscope\nHardware")]
    end

    U -->|"Define ROIs\n& Parameters"| QP
    QP ==>|"Socket\nCommands"| SRV
    SRV --> CTRL
    SRV --> PPM
    CTRL -->|"Python API"| PM
    PM -->|"Java Bridge"| MM
    MM -->|"Device\nControl"| HW

    HW -.->|"Images"| CTRL
    CTRL -.->|"Processing"| PPM
    PPM -.->|"Stitched\nResults"| SRV
    SRV -.->|"Results"| QP

    style QP fill:#4A90D9,color:#fff
    style SRV fill:#306998,color:#fff
    style CTRL fill:#4A7DB8,color:#fff
    style PPM fill:#4A7DB8,color:#fff
    style PM fill:#E67E22,color:#fff
    style MM fill:#D35400,color:#fff
    style HW fill:#C0392B,color:#fff

    click QP "https://github.com/uw-loci/qupath-extension-qpsc" "QPSC Extension Repository"
    click SRV "https://github.com/uw-loci/microscope_command_server" "Command Server Repository"
    click CTRL "https://github.com/uw-loci/microscope_control" "Hardware Control Repository"
    click PPM "https://github.com/uw-loci/ppm_library" "PPM Library Repository"
    click PM "https://pycro-manager.readthedocs.io/" "Pycro-Manager Documentation"
    click MM "https://micro-manager.org/" "Micro-Manager Website"
```

## Core Workflow

1. **Load Overview Image** - Import a low-magnification slide scan into QuPath
2. **Define Regions** - Draw annotations on areas of interest
3. **Configure Acquisition** - Select imaging modality, objectives, and parameters
4. **Acquire** - QPSC coordinates with the microscope to capture high-resolution tiles
5. **Stitch & Import** - Tiles are stitched into pyramidal images and imported back to QuPath

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

> **Click any component** to navigate to its source code or documentation.

```mermaid
flowchart TB
    subgraph QuPathEco["QuPath Ecosystem"]
        subgraph Core["QuPath Core"]
            QApp["QuPath Application"]
            QProj["Project System"]
            QAnnot["Annotations"]
        end

        subgraph QPSC["qupath-extension-qpsc"]
            Ctrl["Workflow Controllers"]
            Modal["Modality System"]
            Svc["Socket Services"]
            Utils["Utilities"]
        end

        T2P["tiles-to-pyramid"]
    end

    subgraph PythonStack["Python Microscope Control (Modular)"]
        subgraph ServerPkg["microscope_command_server"]
            QPSrv["Socket Server"]
            AcqEng["Acquisition Workflows"]
        end
        subgraph ControlPkg["microscope_control"]
            HWPy["Hardware Abstraction"]
            AF["Autofocus System"]
            ConfigMgr["Config Manager"]
        end
        subgraph PPMPkg["ppm_library"]
            PPMProc["PPM Processing"]
            Debayer["Debayering"]
            Imaging["Background/Tissue"]
        end
    end

    subgraph MMEco["Micro-Manager Stack"]
        PyCro["Pycro-Manager"]
        MicroM["Micro-Manager"]
        MMCore["MMCore API"]
    end

    subgraph HW["Hardware"]
        Stage["XYZ Stage"]
        Cam["Camera"]
        Extras["Polarizers, LEDs,\nObjectives, etc."]
    end

    subgraph Data["Data Flow"]
        Tiles["Raw Tiles"]
        ZARR["OME-ZARR"]
    end

    QApp --> QPSC
    QAnnot -->|"ROI Bounds"| Ctrl
    Ctrl --> Modal
    Ctrl --> Svc
    Ctrl --> Utils

    Svc ==>|"TCP Socket"| QPSrv

    QPSrv --> AcqEng
    AcqEng --> HWPy
    AcqEng --> AF
    AcqEng --> ConfigMgr
    AcqEng --> PPMProc
    AcqEng --> Debayer
    AcqEng --> Imaging

    HWPy --> PyCro
    HWPy --> Debayer
    PyCro --> MicroM
    MicroM --> MMCore
    MMCore --> Stage
    MMCore --> Cam
    MMCore --> Extras

    Cam --> Tiles
    Tiles --> ZARR
    ZARR --> T2P
    T2P -->|"Import"| QProj

    %% Styling
    style QPSC fill:#4A90D9,color:#fff
    style ServerPkg fill:#306998,color:#fff
    style ControlPkg fill:#4A7DB8,color:#fff
    style PPMPkg fill:#4A7DB8,color:#fff
    style PyCro fill:#E67E22,color:#fff
    style MicroM fill:#D35400,color:#fff
    style Cam fill:#C0392B,color:#fff

    %% Clickable links - QuPath Ecosystem
    click QApp "https://qupath.github.io/" "QuPath Documentation"
    click QProj "https://qupath.github.io/docs/projects.html" "QuPath Projects"
    click QAnnot "https://qupath.github.io/docs/annotations.html" "QuPath Annotations"

    %% Clickable links - QPSC Extension
    click Ctrl "https://github.com/uw-loci/qupath-extension-qpsc/tree/main/src/main/java/qupath/ext/qpsc/controller" "Workflow Controllers"
    click Modal "https://github.com/uw-loci/qupath-extension-qpsc/tree/main/src/main/java/qupath/ext/qpsc/modality" "Modality System"
    click Svc "https://github.com/uw-loci/qupath-extension-qpsc/tree/main/src/main/java/qupath/ext/qpsc/service" "Socket Services"
    click Utils "https://github.com/uw-loci/qupath-extension-qpsc/tree/main/src/main/java/qupath/ext/qpsc/utilities" "Utilities"
    click T2P "https://github.com/uw-loci/qupath-extension-tiles-to-pyramid" "Tiles to Pyramid Extension"

    %% Clickable links - Python Microscope Control
    click QPSrv "https://github.com/uw-loci/microscope_command_server/blob/main/server/qp_server.py" "Socket Server"
    click AcqEng "https://github.com/uw-loci/microscope_command_server/tree/main/acquisition" "Acquisition Workflows"
    click HWPy "https://github.com/uw-loci/microscope_control/tree/main/hardware" "Hardware Abstraction"
    click AF "https://github.com/uw-loci/microscope_control/tree/main/autofocus" "Autofocus System"
    click ConfigMgr "https://github.com/uw-loci/microscope_control/blob/main/config/manager.py" "Config Manager"
    click PPMProc "https://github.com/uw-loci/ppm_library/tree/main/ppm" "PPM Processing"
    click Debayer "https://github.com/uw-loci/ppm_library/tree/main/debayering" "Debayering"
    click Imaging "https://github.com/uw-loci/ppm_library/tree/main/imaging" "Background/Tissue Detection"

    %% Clickable links - External
    click PyCro "https://pycro-manager.readthedocs.io/" "Pycro-Manager Documentation"
    click MicroM "https://micro-manager.org/" "Micro-Manager Website"
    click MMCore "https://micro-manager.org/apidoc/mmcorej/latest/" "MMCore API Reference"
```

## Imaging Modalities

QPSC supports multiple imaging modalities through a pluggable architecture:

| Modality | Description | Status |
|----------|-------------|--------|
| **PPM** (Polarized Light) | Multi-angle polarization microscopy for birefringent samples | Active |
| **Brightfield** | Standard transmitted light imaging | Active |
| **Fluorescence** | Multi-channel fluorescence (planned) | Planned |
| **SHG/Multiphoton** | Second harmonic generation imaging | Experimental |

## Quick Start

### Prerequisites

- [QuPath](https://qupath.github.io/) 0.5.0+
- [Micro-Manager](https://micro-manager.org/) 2.0+
- Python 3.9+
- Java 21+

### Installation

1. **Install QuPath Extensions**
   - Download latest releases from each extension repository
   - Place JAR files in QuPath's `extensions` folder

2. **Set Up Python Microscope Control**
   ```bash
   # Install all microscope control packages
   pip install microscope-server

   # This automatically installs dependencies:
   # - microscope-control (hardware abstraction)
   # - ppm-library (image processing)

   # Or install from source for development:
   git clone https://github.com/uw-loci/ppm_library.git
   git clone https://github.com/uw-loci/microscope_control.git
   git clone https://github.com/uw-loci/microscope_command_server.git

   pip install -e ppm_library/
   pip install -e microscope_control/
   pip install -e microscope_command_server/
   ```

3. **Configure Microscope**
   - Create configuration YAML files (see [Configuration Guide](docs/configuration.md))
   - Set up Micro-Manager device adapters for your hardware

4. **Get Configuration Templates**
   ```bash
   git clone https://github.com/uw-loci/microscope_configurations.git
   cd microscope_configurations
   # Edit config_template.yml for your microscope
   ```

5. **Launch**
   - Start Micro-Manager
   - Start the Python server: `microscope-server`
   - Open QuPath and access QPSC from Extensions menu

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

# QPSC Developer Guide

This guide is for developers working on QPSC code, adding new features, or integrating with the QPSC system.

## Table of Contents

1. [Development Setup](#development-setup)
2. [Server Communication Protocol](#server-communication-protocol)
3. [Architecture Overview](#architecture-overview)
4. [Adding New Modalities](#adding-new-modalities)
5. [Testing](#testing)

---

## Development Setup

### Prerequisites

- **Git**: For cloning repositories
- **Python 3.9+**: For microscope control server
- **Java 21+**: For QuPath extensions
- **Micro-Manager 2.0+**: For hardware control
- **QuPath 0.6.0+**: For running extensions

### Clone All Repositories

```bash
# Create development directory
mkdir QPSC_Dev
cd QPSC_Dev

# Python packages
git clone https://github.com/uw-loci/ppm_library.git
git clone https://github.com/uw-loci/microscope_control.git
git clone https://github.com/uw-loci/microscope_command_server.git
git clone https://github.com/uw-loci/microscope_configurations.git

# QuPath extensions
git clone https://github.com/uw-loci/qupath-extension-qpsc.git
git clone https://github.com/uw-loci/qupath-extension-tiles-to-pyramid.git
```

### Python Setup (Editable Install)

```bash
# Create virtual environment
python -m venv venv_qpsc
source venv_qpsc/bin/activate  # On Windows: venv_qpsc\Scripts\activate

# Install in dependency order (IMPORTANT!)
cd ppm_library && pip install -e . && cd ..
cd microscope_control && pip install -e . && cd ..
cd microscope_command_server && pip install -e . && cd ..

# Also install pycromanager
pip install pycromanager
```

**Why this order?**
- `ppm_library` has no inter-package dependencies
- `microscope_control` depends on `ppm_library`
- `microscope_command_server` depends on both

### Java/QuPath Extension Setup

```bash
# Build qupath-extension-qpsc
cd qupath-extension-qpsc
./gradlew build

# JAR will be in build/libs/qupath-extension-qpsc-X.X.X.jar
# Copy to QuPath extensions folder:
cp build/libs/qupath-extension-qpsc-*.jar ~/QuPath/extensions/
```

### Running the Server

```bash
# Activate virtual environment
source venv_qpsc/bin/activate

# Start server
python -m microscope_command_server.server.qp_server
```

---

## Server Communication Protocol

### Overview

The QPSC extension communicates with the microscope command server via **TCP sockets** on **port 5000** (configurable).

**Protocol Structure:**
```
[8-byte command] + [text message parameters] + "ENDOFSTR"
```

### Command Format

All commands are **8 bytes** (fixed-length) followed by optional message text.

**Basic Commands:**

| Command | Bytes | Purpose |
|---------|-------|---------|
| `GETXY` | `getxy___` | Get XY stage position |
| `GETZ` | `getz____` | Get Z stage position |
| `MOVE` | `move____` | Move XY stage |
| `MOVEZ` | `move_z__` | Move Z stage |
| `GETR` | `getr____` | Get rotation angle |
| `MOVER` | `move_r__` | Move rotation stage |
| `ACQUIRE` | `acquire_` | Start acquisition workflow |
| `BGACQUIRE` | `bgacquir` | Background acquisition |
| `STATUS` | `status__` | Get acquisition status |
| `PROGRESS` | `progress` | Get acquisition progress |
| `CANCEL` | `cancel__` | Cancel running acquisition |

### Acquisition Command Structure

The `ACQUIRE` command is used by the QPSC extension to start a full acquisition workflow.

**Full Command Format:**
```
[8-byte "acquire_"] + [parameter message] + "ENDOFSTR"
```

**Example Acquisition Message:**
```
--yaml /path/config.yml --projects /output/folder --sample Sample_001
--scan-type ppm_20x_1 --region RegionName --angles (-5.0,0.0,5.0,90.0)
--exposures (120.0,250.0,60.0,1.2) --objective LOCI_OBJ_001
--detector LOCI_DET_001 --pixel-size 0.5 --white-balance true
--af-tiles 3 --af-steps 10 --af-range 50.0 ENDOFSTR
```

### Parameter Reference

#### Required Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `--yaml` | String (path) | Path to microscope configuration YAML | `/config/ppm.yml` |
| `--projects` | String (path) | Output projects folder path | `/data/projects` |
| `--sample` | String | Sample label | `Sample_001` |
| `--scan-type` | String | Scan type with magnification | `ppm_20x_1`, `bf_10x_2` |
| `--region` | String | Region/annotation name | `Annotation_1` |

#### Optional Hardware Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `--objective` | String | Objective identifier (LOCI lookup key) | `LOCI_OBJ_001` |
| `--detector` | String | Detector identifier (LOCI lookup key) | `LOCI_DET_001` |
| `--pixel-size` | Float | Pixel size in micrometers | `0.5` |

#### Multi-Angle Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `--angles` | List (in parentheses) | Comma-separated angle list | `(-5.0,0.0,5.0,90.0)` |
| `--exposures` | List (in parentheses) | Comma-separated exposure times | `(120.0,250.0,60.0,1.2)` |

**Note:** Angle and exposure lists must have matching lengths.

#### Background Correction Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `--bg-correction` | Boolean | Enable/disable background correction | `true`, `false` |
| `--bg-method` | String | Background correction method | `divide`, `subtract` |
| `--bg-folder` | String (path) | Path to background image folder | `/data/backgrounds` |
| `--bg-disabled-angles` | List | Angles to skip BG correction | `(90.0,95.0)` |

#### Autofocus Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `--af-tiles` | Integer | Number of tiles for autofocus grid | `3` (3x3 grid) |
| `--af-steps` | Integer | Number of Z steps for focus search | `10` |
| `--af-range` | Float | Search range in micrometers | `50.0` |

#### Other Options

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `--white-balance` | Boolean | Enable white balance | `true`, `false` |
| `--processing` | List | Pipeline processing steps | `(debayer,background_correction)` |
| `--hint-z` | Float | Z-focus hint from tilt model | `1234.5` |

### Code Examples

#### Java (QuPath Extension)

**Building the acquisition message:**

```java
// From AcquisitionCommandBuilder.java
public class AcquisitionCommandBuilder {

    public String buildSocketMessage() {
        StringBuilder message = new StringBuilder();

        // Required parameters
        message.append("--yaml ").append(configPath);
        message.append(" --projects ").append(projectsFolder);
        message.append(" --sample ").append(sampleLabel);
        message.append(" --scan-type ").append(scanType);
        message.append(" --region ").append(regionName);

        // Add angles if present
        if (!angles.isEmpty()) {
            message.append(" --angles (")
                   .append(angles.stream()
                          .map(String::valueOf)
                          .collect(Collectors.joining(",")))
                   .append(")");
        }

        // Add exposures if present
        if (!exposures.isEmpty()) {
            message.append(" --exposures (")
                   .append(exposures.stream()
                          .map(String::valueOf)
                          .collect(Collectors.joining(",")))
                   .append(")");
        }

        // Add optional parameters
        if (objectiveId != null) {
            message.append(" --objective ").append(objectiveId);
        }

        if (detectorId != null) {
            message.append(" --detector ").append(detectorId);
        }

        if (pixelSize > 0) {
            message.append(" --pixel-size ").append(pixelSize);
        }

        // Autofocus parameters
        if (autofocusTiles > 0) {
            message.append(" --af-tiles ").append(autofocusTiles);
            message.append(" --af-steps ").append(autofocusSteps);
            message.append(" --af-range ").append(autofocusRange);
        }

        // Background correction
        if (backgroundCorrectionEnabled) {
            message.append(" --bg-correction true");
            message.append(" --bg-method ").append(bgMethod);
            if (bgFolder != null) {
                message.append(" --bg-folder ").append(bgFolder);
            }
        }

        // End marker
        message.append(" ENDOFSTR");

        return message.toString();
    }
}
```

**Sending the command via socket:**

```java
// From MicroscopeSocketClient.java
public void sendAcquisitionCommand(String message) throws IOException {
    // 1. Send 8-byte ACQUIRE command
    output.write(Command.ACQUIRE.getValue()); // b"acquire_"
    output.flush();

    // 2. Send parameter message
    byte[] messageBytes = message.getBytes(StandardCharsets.UTF_8);
    output.write(messageBytes);
    output.flush();

    // 3. Wait for 16-byte acknowledgment
    byte[] ackResponse = new byte[16];
    input.readFully(ackResponse);

    String ack = new String(ackResponse, StandardCharsets.UTF_8).trim();
    if (!ack.startsWith("STARTED:ACQUIRE")) {
        throw new IOException("Unexpected server response: " + ack);
    }
}
```

#### Python (Server)

**Parsing the acquisition message:**

```python
# From workflow.py
import shlex

def parse_acquisition_message(message: str) -> dict:
    """Parse acquisition command parameters from message."""

    # Remove ENDOFSTR marker
    message = message.replace("ENDOFSTR", "")

    # Use shlex for robust parsing (handles quoted paths with spaces)
    parts = shlex.split(message)

    params = {}
    i = 0

    while i < len(parts):
        if parts[i].startswith("--"):
            flag = parts[i][2:]  # Remove "--"

            # Required parameters
            if flag == "yaml":
                params["yaml_file_path"] = parts[i+1]
            elif flag == "projects":
                params["projects_folder_path"] = parts[i+1]
            elif flag == "sample":
                params["sample_label"] = parts[i+1]
            elif flag == "scan-type":
                params["scan_type"] = parts[i+1]
            elif flag == "region":
                params["region_name"] = parts[i+1]

            # Multi-angle parameters
            elif flag == "angles":
                # Parse "(1.0,2.0,3.0)" to [1.0, 2.0, 3.0]
                angles_str = parts[i+1].strip("()")
                params["angles"] = [float(a) for a in angles_str.split(",")]
            elif flag == "exposures":
                exposures_str = parts[i+1].strip("()")
                params["exposures"] = [float(e) for e in exposures_str.split(",")]

            # Hardware parameters
            elif flag == "objective":
                params["objective"] = parts[i+1]
            elif flag == "detector":
                params["detector"] = parts[i+1]
            elif flag == "pixel-size":
                params["pixel_size"] = float(parts[i+1])

            # Autofocus parameters
            elif flag == "af-tiles":
                params["autofocus_tiles"] = int(parts[i+1])
            elif flag == "af-steps":
                params["autofocus_steps"] = int(parts[i+1])
            elif flag == "af-range":
                params["autofocus_range"] = float(parts[i+1])

            # Background correction
            elif flag == "bg-correction":
                params["background_correction_enabled"] = parts[i+1].lower() == "true"
            elif flag == "bg-method":
                params["bg_method"] = parts[i+1]
            elif flag == "bg-folder":
                params["bg_folder"] = parts[i+1]

            # White balance
            elif flag == "white-balance":
                params["white_balance"] = parts[i+1].lower() == "true"

            # Z hint
            elif flag == "hint-z":
                params["hint_z"] = float(parts[i+1])

            i += 2
        else:
            i += 1

    # Validate required parameters
    required = ["yaml_file_path", "projects_folder_path", "sample_label",
                "scan_type", "region_name"]
    for req in required:
        if req not in params:
            raise ValueError(f"Missing required parameter: {req}")

    return params
```

**Handling the acquisition workflow:**

```python
# From qp_server.py
def handle_acquire_command(self, message: str):
    """Handle ACQUIRE command - start full acquisition workflow."""

    # Parse parameters
    try:
        params = parse_acquisition_message(message)
    except ValueError as e:
        self.send_error(f"Invalid parameters: {e}")
        return

    # Spawn acquisition thread
    acquisition_thread = threading.Thread(
        target=self._acquisition_workflow,
        args=(params,),
        daemon=True
    )
    acquisition_thread.start()

    # Send acknowledgment (16 bytes)
    ack = "STARTED:ACQUIRE".ljust(16)
    self.socket.send(ack.encode('utf-8'))

def _acquisition_workflow(self, params: dict):
    """Execute the full acquisition workflow."""

    try:
        # 1. Load configuration
        config = load_config(params["yaml_file_path"])

        # 2. Initialize hardware
        hardware = initialize_hardware(config)

        # 3. Load scan type parameters
        scan_params = get_scan_parameters(
            config,
            params["scan_type"]
        )

        # 4. For each tile position:
        for tile_pos in tile_positions:
            # Move stage
            hardware.move_xy(tile_pos.x, tile_pos.y)

            # Autofocus (if enabled)
            if params.get("autofocus_tiles"):
                z_pos = run_autofocus(hardware, params)
                hardware.move_z(z_pos)

            # For each angle:
            for angle, exposure in zip(params["angles"], params["exposures"]):
                # Rotate
                hardware.rotate(angle)

                # Capture image
                image = hardware.capture(exposure)

                # Process image
                if scan_params.get("debayer"):
                    image = debayer_image(image)

                if params.get("background_correction_enabled"):
                    image = apply_background_correction(image, angle, params)

                # Save as OME-TIFF
                save_ome_tiff(image, output_path, metadata)

        # 5. Signal completion
        self.acquisition_status = "COMPLETED"

    except Exception as e:
        logger.error(f"Acquisition failed: {e}")
        self.acquisition_status = "FAILED"
```

### Response Format

**Acknowledgment (16 bytes):**
```
"STARTED:ACQUIRE" (padded to 16 bytes with spaces)
```

**Status Responses:**

When client sends `STATUS__` command:
- `"IDLE"` - No acquisition running
- `"RUNNING"` - Acquisition in progress
- `"COMPLETED"` - Acquisition finished successfully
- `"FAILED"` - Acquisition encountered error

When client sends `PROGRESS` command:
```
Returns: (current_position, total_positions) as tuple
Example: (45, 100) means 45 out of 100 tiles complete
```

### Client Commands vs QPSC Workflow

**Important distinction:**

The microscope_command_server includes **client commands** (GETXY, GETZ, MOVE, etc.) for direct hardware control during manual operation or testing.

**The QPSC extension primarily uses:**
- `ACQUIRE_` - Start full acquisition workflow (tiles, angles, autofocus, etc.)
- `STATUS__` - Monitor acquisition state
- `PROGRESS` - Track progress during acquisition
- `CANCEL__` - Cancel running acquisition

The QPSC extension **does NOT** directly call stage movement or position commands during normal acquisition - those are handled internally by the server workflow.

### Server Startup and Configuration

#### Dynamic Configuration Loading

The microscope server uses a two-stage configuration approach:

1. **Startup Configuration**: Generic minimal config allows server to start
   - Permissive stage limits for exploratory movements
   - No microscope-specific features enabled
   - Micro-Manager connection established

2. **Acquisition Configuration**: Full microscope config loaded from client
   - Provided via `--yaml` parameter in ACQUIRE command
   - Replaces startup config dynamically
   - Enables microscope-specific features (PPM rotation, etc.)

**Why this matters:**
- Server is portable across different microscopes
- No hardcoded config file dependency
- Client controls which microscope config is used
- Config can change between acquisitions

**Example workflow:**
```python
# 1. Server starts with generic config
python -m microscope_command_server.server.qp_server

# 2. Client sends ACQUIRE with specific config
ACQUIRE --yaml /configs/config_PPM.yml --projects /data --sample S001 ...

# 3. Server loads config_PPM.yml and uses it for acquisition

# 4. Next acquisition can use different config
ACQUIRE --yaml /configs/config_CAMM.yml --projects /data --sample S002 ...
```

**Exploratory Commands:**
Commands like GETXY, MOVE, GETZ use the most recently loaded config:
- Before first ACQUIRE: Uses generic startup config with permissive stage limits
- After ACQUIRE: Uses the microscope-specific config from that acquisition

---

## Architecture Overview

### Component Interaction

```
┌─────────────────────────────────────────────────────────────┐
│                        QuPath GUI                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │         QPSC Extension (Java)                         │  │
│  │  - UI dialogs for workflow configuration             │  │
│  │  - Annotation → Stage coordinate transformation      │  │
│  │  - Socket client for microscope server               │  │
│  └────────────────────┬──────────────────────────────────┘  │
└────────────────────────┼──────────────────────────────────────┘
                        │
                   TCP Socket
                   (port 5000)
                        │
┌────────────────────────┼──────────────────────────────────────┐
│  Microscope Command Server (Python)                          │
│  ┌─────────────────────┴──────────────────────────────────┐  │
│  │  qp_server.py - Socket server                         │  │
│  │  - Parse commands                                      │  │
│  │  - Spawn acquisition threads                          │  │
│  │  - Track progress                                      │  │
│  └────────────────────┬───────────────────────────────────┘  │
│                       │                                       │
│  ┌─────────────────────┴──────────────────────────────────┐  │
│  │  workflow.py - Acquisition orchestration              │  │
│  │  - Load config                                         │  │
│  │  - Execute tile grid                                   │  │
│  │  - Run autofocus                                       │  │
│  │  - Capture images (multi-angle)                       │  │
│  │  - Save OME-TIFF tiles                                │  │
│  └────────────────────┬───────────────────────────────────┘  │
└────────────────────────┼──────────────────────────────────────┘
                        │
                     Pycro-Manager
                        │
┌────────────────────────┼──────────────────────────────────────┐
│               Micro-Manager (Java)                            │
│  - Device adapters                                            │
│  - Camera control                                             │
│  - Stage control                                              │
│  - Filter wheels, shutters, etc.                             │
└────────────────────────┼──────────────────────────────────────┘
                        │
              ┌─────────┴─────────┐
              │                   │
         Microscope            Camera
         Hardware            Hardware
```

### Data Flow

1. User draws annotations in QuPath
2. QPSC extension transforms annotations → tile grid (stage coordinates)
3. Extension sends ACQUIRE command with parameters via socket
4. Python server parses command, spawns acquisition thread
5. Server executes workflow:
   - For each tile: Move stage → Autofocus → Capture images (multi-angle)
   - Process images (debayer, background correction)
   - Save as OME-TIFF tiles
6. Server signals completion
7. QuPath extension stitches OME-TIFF tiles → Pyramidal OME-TIFF
8. QuPath imports stitched image into project

---

## Adding New Modalities

### Modality System Overview

QPSC supports pluggable imaging modalities (brightfield, PPM, fluorescence, etc.). Each modality defines:
- Rotation angles
- Exposure times
- Optional UI components
- Angle override logic

### Implementing a New Modality

**1. Create Modality Handler (Java):**

```java
package qupath.ext.qpsc.modality.newmodality;

public class NewModalityHandler implements ModalityHandler {

    @Override
    public String getPrefix() {
        return "newmod";  // Matches "newmod_20x_1" in config
    }

    @Override
    public List<Double> getRotationAngles(String scanType,
                                          Map<String, Object> config) {
        // Return default angles for this modality
        return Arrays.asList(0.0, 45.0, 90.0, 135.0);
    }

    @Override
    public List<Double> getExposures(String scanType,
                                     Map<String, Object> config) {
        // Return default exposures (ms)
        return Arrays.asList(100.0, 100.0, 100.0, 100.0);
    }

    @Override
    public Optional<Node> getUI(String scanType,
                                Map<String, Object> config) {
        // Optional: Return JavaFX UI for modality-specific parameters
        return Optional.empty();
    }

    @Override
    public List<Double> overrideAngles(String scanType,
                                       Map<String, Object> config,
                                       Map<String, Object> uiParams) {
        // Optional: Allow UI to override angles
        return getRotationAngles(scanType, config);
    }
}
```

**2. Register Modality:**

```java
// In SetupScope.java or extension initialization
ModalityRegistry.register(new NewModalityHandler());
```

**3. Add to Configuration YAML:**

```yaml
scan_types:
  newmod_20x_1:
    objective: LOCI_OBJ_001
    detector: LOCI_DET_001
    pixel_size: 0.5
    angles: [0.0, 45.0, 90.0, 135.0]
    exposures: [100.0, 100.0, 100.0, 100.0]
    modality: newmodality
```

---

## Testing

### Unit Tests (Java)

```bash
cd qupath-extension-qpsc
./gradlew test
```

### Unit Tests (Python)

```bash
# Activate virtual environment
source venv_qpsc/bin/activate

# Run all tests
pytest microscope_control/
pytest microscope_command_server/
pytest ppm_library/
```

### Integration Testing

**Mock hardware testing:**

```python
# In microscope_control/tests/test_mock_hardware.py
from microscope_control.hardware.mock_hardware import MockMicroscopeHardware

def test_acquisition_workflow():
    hardware = MockMicroscopeHardware()

    # Test stage movement
    hardware.move_xy(1000, 2000)
    pos = hardware.get_xy_position()
    assert pos == (1000, 2000)

    # Test capture
    image = hardware.capture(exposure=100.0)
    assert image is not None
```

### Manual Testing Checklist

1. **Socket Communication:**
   - Start server: `python -m microscope_command_server.server.qp_server`
   - Send test commands via telnet or custom client
   - Verify responses

2. **Coordinate Transformation:**
   - Create test annotations in QuPath
   - Verify tile grid generation
   - Check stage coordinate calculations

3. **End-to-End Workflow:**
   - Run full acquisition with mock hardware
   - Verify tile stitching
   - Check QuPath project import

4. **Error Handling:**
   - Test with invalid parameters
   - Test connection failures
   - Test cancellation mid-acquisition

---

## Additional Resources

- [Architecture Documentation](architecture.md) - Detailed system architecture
- [Configuration Guide](configuration.md) - YAML configuration reference
- [QPSC Main Repository](https://github.com/uw-loci/QPSC) - Project overview
- [QuPath Documentation](https://qupath.readthedocs.io/) - QuPath API reference

---

**Questions?** Open an issue at https://github.com/uw-loci/QPSC/issues

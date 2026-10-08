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
- **Python 3.10+**: For the microscope server (CI tests 3.10, 3.11 and 3.12)
- **JDK 25**: For building the QuPath extensions. The build emits Java 21 bytecode, which is what QuPath 0.7 runs on
- **Micro-Manager**: Running, with a hardware configuration loaded, before the microscope server starts
- **QuPath 0.7.0**: The version the extensions are built against

### Clone All Repositories

```bash
# Create development directory
mkdir QPSC_Dev
cd QPSC_Dev

# Python packages
git clone https://github.com/uw-loci/microscope_imageprocessing.git
git clone https://github.com/uw-loci/ppm_library.git          # optional: PPM only
git clone https://github.com/uw-loci/polscope_library.git     # optional: LC-PolScope only
git clone https://github.com/uw-loci/microscope_control.git
git clone https://github.com/uw-loci/microscope_command_server.git
git clone https://github.com/uw-loci/microscope_configurations.git

# QuPath extensions
git clone https://github.com/uw-loci/qupath-extension-tiles-to-pyramid.git
git clone https://github.com/uw-loci/qupath-extension-qpsc.git
```

### Python Setup (Editable Install)

```bash
# Create virtual environment
python -m venv venv_qpsc
source venv_qpsc/bin/activate  # On Windows: venv_qpsc\Scripts\activate

# Install in dependency order. None of these packages is on PyPI,
# so pip cannot fetch a missing one for you.
cd microscope_imageprocessing && pip install -e ".[dev]" && cd ..
cd ppm_library && pip install -e ".[dev]" && cd ..          # optional: PPM only
cd polscope_library && pip install -e ".[dev]" && cd ..     # optional: LC-PolScope only
cd microscope_control && pip install -e ".[dev]" && cd ..
cd microscope_command_server && pip install -e ".[dev]" && cd ..
```

The order follows the dependencies:

- `microscope_imageprocessing` and `polscope_library` depend on none of the other QPSC packages
- `ppm_library` and `microscope_control` each depend on `microscope_imageprocessing`
- `microscope_command_server` depends on `microscope_control` and `microscope_imageprocessing`. `ppm_library` is needed only for PPM, and `polscope_library` only for LC-PolScope

The dependency table is in [Python Package Dependencies](architecture.md#python-package-dependencies).

`pycromanager` is installed as a dependency of `microscope_control`. The `[dev]` extra adds pytest and pytest-cov, which the tests need.

### Java/QuPath Extension Setup

`qupath-extension-qpsc` takes `qupath-extension-tiles-to-pyramid` from your local Maven repository, at the version pinned in its `build.gradle.kts` (0.7.1 at the time of writing). Publish that version first:

```bash
cd qupath-extension-tiles-to-pyramid
git checkout v0.7.1
./gradlew publishToMavenLocal

cd ../qupath-extension-qpsc
./gradlew shadowJar

# JAR will be in build/libs/qupath-extension-qpsc-X.X.X-all.jar
# Copy to the QuPath extensions folder:
cp build/libs/qupath-extension-qpsc-*-all.jar ~/QuPath/v0.7/extensions/
```

QuPath also needs the tiles-to-pyramid extension JAR in the same folder to stitch tiles. If you set a custom extensions directory in QuPath, copy the JARs there instead.

### Running the Server

Start Micro-Manager first. The server connects to it at startup and exits if it cannot.

```bash
# Activate virtual environment
source venv_qpsc/bin/activate

# Start server
python -m microscope_command_server.server.qp_server
```

---

## Server Communication Protocol

The complete wire-level reference is [SOCKET_PROTOCOL.md](https://github.com/uw-loci/qupath-extension-qpsc/blob/main/documentation/developer/SOCKET_PROTOCOL.md) in the extension repository. This section covers what you need to follow an acquisition.

### Overview

The QPSC extension talks to the microscope server over TCP on port 5000. The extension's port is the **Microscope Server Port** preference. The server's port is the constant `TCP_PORT` in `server/protocol.py`; changing it means editing that file.

Every command starts with 8 ASCII bytes, lower case, padded with underscores. What follows depends on the command:

| Follows the command | Example |
|---|---|
| nothing | `getxy___` |
| a fixed-size binary payload | `move____` + X and Y as two big-endian 32-bit floats |
| a 4-byte big-endian length, then that many bytes | `config__` + the path of the microscope YAML |
| a text message ending in `ENDOFSTR` | `acquire_`, `bgacquir` |

### Commands used here

| Command | Bytes | Purpose |
|---------|-------|---------|
| `CONFIG` | `config__` | Load a microscope configuration. Sent by the extension on every connect |
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

### Starting an acquisition

The extension builds the message with `AcquisitionCommandBuilder` and sends it with `MicroscopeSocketClient.startAcquisition`, which appends ` ENDOFSTR`:

```java
AcquisitionCommandBuilder builder = AcquisitionCommandBuilder.builder()
        .yamlPath("/path/config_PPM.yml")
        .projectsFolder("/data/projects")
        .sampleLabel("Sample_001")
        .scanType("ppm_20x_1")
        .regionName("Region_1")
        .hardware("LOCI_OBJECTIVE_OLYMPUS_20X_POL_001", "LOCI_DETECTOR_JAI_001", 0.1725)
        .angleExposures(List.of(
                new AngleExposure(-7.0, 500.0),
                new AngleExposure(0.0, 800.0),
                new AngleExposure(7.0, 500.0)))
        .backgroundCorrection(true, "divide", "/path/to/backgrounds")
        .wbMode("per_angle");

client.startAcquisition(builder);   // sends acquire_, then the message + " ENDOFSTR"
```

The message is a single line of flags. Values that contain spaces, parentheses or commas are quoted:

```
--yaml /path/config_PPM.yml --projects /data/projects --sample Sample_001
--scan-type ppm_20x_1 --region Region_1
--objective LOCI_OBJECTIVE_OLYMPUS_20X_POL_001 --detector LOCI_DETECTOR_JAI_001 --pixel-size 0.1725
--angles "(-7.0,0.0,7.0)" --exposures "(500.0,800.0,500.0)"
--bg-correction true --bg-method divide --bg-folder /path/to/backgrounds
--wb-mode per_angle --processing "(background_correction,white_balance)" ENDOFSTR
```

(Shown wrapped. The builder may add further flags from QuPath preferences.)

On the server, `handle_acquire` in `server/handlers/acquisition.py` reads up to `ENDOFSTR`, starts the acquisition in a background thread, and replies at once. The thread runs `_acquisition_workflow` in `acquisition/workflow.py`, which parses the message with `parse_acquisition_message`. [What Happens During an Acquisition](architecture.md#what-happens-during-an-acquisition) describes the steps.

### Parameter Reference

#### Required

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `--yaml` | String (path) | Path to microscope configuration YAML | `/config/config_PPM.yml` |
| `--projects` | String (path) | Output projects folder path | `/data/projects` |
| `--sample` | String | Sample label | `Sample_001` |
| `--scan-type` | String | Scan type with magnification | `ppm_20x_1` |
| `--region` | String | Region/annotation name | `Region_1` |

#### Hardware

Sent together, and only when all three are known.

| Parameter | Type | Description |
|-----------|------|-------------|
| `--objective` | String | Objective identifier |
| `--detector` | String | Detector identifier |
| `--pixel-size` | Float | Pixel size in micrometers |

#### Angles or channels

An acquisition is angle-based or channel-based. If `--channels` is present the server ignores `--angles`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `--angles` | List in parentheses | Rotation angles in ticks, as sent by the modality handler. One tick is one optical degree (see [Terms](architecture.md#terms)) |
| `--exposures` | List in parentheses | Exposure per angle in ms. Sent alone, with one value, for a modality that does not rotate |
| `--channels` | List in parentheses | Channel ids |
| `--channel-exposures` | List in parentheses | Exposure per channel in ms |
| `--channel-intensities` | List of `id=value` | Intensity overrides for the channels the user changed |
| `--focus-channel` | String | Acquired channel to apply before the autofocus snap |
| `--inner-axis` | `z`, `channel` or `angle` | Which loop is innermost for each tile |

#### Background correction and white balance

| Parameter | Type | Description |
|-----------|------|-------------|
| `--bg-correction` | Boolean | Sent as `true` when background correction is on |
| `--bg-method` | String | Correction method, for example `divide` |
| `--bg-folder` | String (path) | Background image folder |
| `--bg-disabled-angles` | List in parentheses | Angles to leave uncorrected |
| `--wb-mode` | `per_angle`, `simple`, `camera_awb` or `off` | White balance mode. The server refuses an acquisition without it |

#### Autofocus

| Parameter | Type | Description |
|-----------|------|-------------|
| `--af-tiles`, `--af-steps`, `--af-range` | Integer, Integer, Float | Sent together; `--af-range` is in um. Recorded in the acquisition metadata; the autofocus itself is configured from `autofocus_<microscope>.yml` |
| `--af-disabled` | flag | Sent instead of the three above when autofocus is turned off in preferences |
| `--af-skip-initial` | flag | The sample is already in focus; skip the first autofocus |
| `--af-strategy` | String | Autofocus strategy override |
| `--af-benchmark` | flag | Time the autofocus methods on every tile |
| `--af-channel`, `--af-channel-exposure`, `--af-channel-intensity` | String, Float, Float | Dedicated focus channel |
| `--focus-surface` | `observe` or `enforce` | Fit a surface through the autofocus results. Absent means off |
| `--focus-survey`, `--focus-survey-tiles` | Integer, comma-separated integers | Focus points to measure before the tile loop |
| `--preferred-af-tile` | Integer | Tile index to autofocus on first |
| `--hint-z` | Float | Starting Z for focus, in um |

#### Z-stack, time-lapse and output

| Parameter | Type | Description |
|-----------|------|-------------|
| `--z-stack` | flag | Acquire a Z-stack |
| `--z-start`, `--z-end`, `--z-step` | Float | Stack range and step, in um |
| `--z-pixel-size` | Float | Z spacing recorded for the output, in um |
| `--z-projection` | String | How the stack is reduced |
| `--edf-metric`, `--edf-window`, `--edf-index-smooth` | String, Integer, Integer | Tuning for the `edf` projection |
| `--timepoints` | Integer | Number of timepoints, sent when greater than 1 |
| `--interval` | Float | Seconds between timepoints |
| `--output-format` | String | Output layout. The server default is `ome-per-t` |
| `--save-raw` | Boolean | Keep raw tiles |
| `--processing` | List in parentheses | Processing steps the extension enabled. Recorded in the acquisition metadata |
| `--batch-acquire` | flag | One slide of a multi-slide batch |

#### Laser scanning and PPM

| Parameter | Type |
|-----------|------|
| `--laser-power` | Float |
| `--laser-wavelength` | Integer |
| `--dwell-time` | Float |
| `--averaging` | Integer |
| `--biref-min-intensity` | Integer |
| `--ppm-high-bit-depth` | Boolean |

The parser also accepts two older flags the extension no longer sends: `--white-balance` and `--wb-per-angle`.

### Response Format

`acquire_` replies with 16 bytes, space-padded:

- `STARTED:ACQUIRE`: the acquisition thread has started
- `BUSY:ACQUIRING`: another acquisition is already running; this one was refused

The message is parsed after this reply. A bad parameter therefore shows up as `FAILED` on the next status poll, not here.

`status__` replies with one of:

- `IDLE`, `RUNNING`, `CANCELLING`, `CANCELLED`: the state name, space-padded to 16 bytes
- `COMPLETED|final_z:<z>`, optionally followed by `|sat:<summary>`
- `FAILED: <message>`, padded with spaces to at least 32 bytes and at most 500 bytes long

`progress` replies with 8 bytes: two big-endian unsigned 32-bit integers, current and total. They count images, not tiles: the total is tiles x Z planes x angles or channels x timepoints.

`cancel__` replies with `ACK` (3 bytes).

### Who moves the stage

The extension uses the stage commands directly for the Live Viewer, the stage map, alignment and the position display. Position queries and XY moves go over a second (auxiliary) connection, so they keep working while an acquisition runs.

Inside an acquisition, tile-to-tile moves, autofocus and rotation are done by the server. The extension polls `status__` and `progress`, and sends `cancel__` if the user cancels.

### Server Startup and Configuration

The server starts with a minimal built-in configuration that has wide stage limits and no modalities. It needs Micro-Manager running, and exits if it cannot connect.

The microscope configuration arrives from the client in two places:

1. **`config__`, on connect.** The extension sends the path of the microscope YAML set in its preferences as soon as it connects. The server loads it, rebuilds its stage, rotation, illumination and detector objects, and starts a session log in a `logs` folder next to the YAML. Until this happens, `getfov__` returns `(-1, -1)`, `getpxsz_` returns `0`, and stage move commands are ignored with a warning in the server log.
2. **`--yaml`, in each `acquire_` message.** The server loads this file again for the acquisition. If it is not the file given to `config__`, the server logs a configuration-mismatch warning and uses the `--yaml` file.

The server accepts one client machine at a time. A `config__` from another IP address is refused while the first is connected. When the last connection from the configured machine closes, the server returns to its unconfigured state.

---

## Architecture Overview

How the components fit together, what happens during an acquisition, and where files land are described in the [Architecture](architecture.md) page. Start with [The System at a Glance](architecture.md#the-system-at-a-glance) and [What Happens During an Acquisition](architecture.md#what-happens-during-an-acquisition).

---

## Adding New Modalities

### Modality System Overview

A modality is handled by a `ModalityHandler` in the QPSC extension, chosen by the prefix of the modality name, and by a `ModalityConfig` registered under the same prefix in the microscope server. [Modality System](architecture.md#modality-system) explains the design and when a new mode needs a handler at all. Many new modes need only an [acquisition profile](configuration.md#acquisition-profiles) in YAML.

### Implementing a New Modality

**1. Create the handler (Java).** `getRotationAngles` is the only method a handler must implement. The other hooks have defaults; see [`ModalityHandler.java`](https://github.com/uw-loci/qupath-extension-qpsc/blob/main/src/main/java/qupath/ext/qpsc/modality/ModalityHandler.java).

```java
package qupath.ext.qpsc.modality;

import java.util.List;
import java.util.concurrent.CompletableFuture;

public class NewModalityHandler implements ModalityHandler {

    @Override
    public CompletableFuture<List<AngleExposure>> getRotationAngles(
            String modalityName, String objective, String detector, String wbMode) {
        // A modality that does not rotate returns an empty list.
        // A rotating modality returns one AngleExposure (ticks, exposure in ms) per angle.
        return CompletableFuture.completedFuture(List.of());
    }
}
```

A channel-based modality also overrides `getChannels(modality, objective, detector)`. Override `createBoundingBoxUI()` to add controls to the acquisition dialog, and `getMenuContributions()` to add menu items.

**2. Register the handler.** The built-in handlers are registered in the static initializer of `ModalityRegistry`. Add yours there:

```java
registerHandler("newmod", new NewModalityHandler());
```

Lookup returns the handler with the longest registered prefix that the modality name starts with, so `newmod_20x` resolves to this handler.

**3. Register the modality in the microscope server (Python).** Add a module under `microscope_command_server/modality/` that builds a `ModalityConfig` and registers it under the same prefix, and call its register function from `modality/__init__.py`. `modality/brightfield.py` is a short example. Trimmed to the essentials:

```python
from .config import ModalityConfig
from .registry import register

BRIGHTFIELD_CONFIG = ModalityConfig(
    autofocus_angle=None,
    has_rotation=False,
    default_angle_count=1,
)

def register_brightfield():
    register("bf", BRIGHTFIELD_CONFIG)
    register("brightfield", BRIGHTFIELD_CONFIG)
```

Both registries return the longest registered prefix that matches, so a new prefix may extend an existing one, as `bf_if` extends `bf`. Register the same prefix on both sides.

**4. Add the modality to the microscope configuration.** Give it an entry under `modalities` whose name starts with the registered prefix, as `config_PPM.yml` does for PPM:

```yaml
modalities:
  ppm:
    type: polarized
```

The remaining keys are described in the [Configuration Guide](configuration.md).

A new modality counts as Implemented, in the terms of [Registered Modalities](architecture.md#registered-modalities), until it has been acquired on real hardware and the output checked.

---

## Testing

### Unit Tests (Java)

```bash
cd qupath-extension-qpsc
./gradlew test
```

The Java tests (JUnit) cover coordinate transformations, utilities, configuration access, socket message flags, modality handlers and UI controller logic. The test task adds the JavaFX modules it needs.

To run one test class:

```bash
./gradlew test --tests "<fully qualified class name>"
```

### Unit Tests (Python)

Run `pytest` from the root of each Python repository, with the virtual environment active:

```bash
cd microscope_command_server
pytest
```

The Python tests cover focus metrics, background correction, debayering, Z projections, tile grid parsing, and individual server command handlers.

### Handler Tests with Fakes

Server command handlers are tested one at a time against hand-written fake connections and fake hardware objects. These cover behavior such as refusing a second acquisition and fixed-size replies.

Two kinds of test do not exist yet:

- No automated test starts the server and drives it over a socket. A Java client test with a mock server exists (`MicroscopeSocketClientTest`) but is disabled.
- No automated test covers acquire, stitch and import end to end.

### How Tests Run

- The lab's shared pre-push hook runs `./gradlew test` when a push changes Java sources, Gradle build files, or shipped docs, in the Java repositories on its verified list. That list includes `qupath-extension-qpsc` and `qupath-extension-tiles-to-pyramid`. A test failure blocks the push. The hook does not run pytest. It is installed separately on lab machines and is not part of any repository cloned above, so a fresh clone does not have it.
- GitHub Actions runs `./gradlew build` for the Java extensions and `pytest` for the Python packages.

### Manual Testing Checklist

1. **Socket communication:**
   - Start the server: `python -m microscope_command_server.server.qp_server`
   - Connect from QuPath and check that the stage position is reported

2. **Coordinate transformation:**
   - Create test annotations in QuPath
   - Verify tile grid generation
   - Check stage coordinate calculations

3. **End-to-end workflow** (needs a microscope or the mock configuration):
   - Run a full acquisition
   - Verify tile stitching
   - Check QuPath project import

4. **Error handling:**
   - Test with invalid parameters
   - Test connection failures
   - Test cancellation mid-acquisition

---

## Additional Resources

- [Architecture](architecture.md): how the components fit together
- [Configuration Guide](configuration.md): YAML configuration reference
- [QPSC repository](https://github.com/uw-loci/QPSC): project overview
- [QuPath Documentation](https://qupath.readthedocs.io/)

---

For questions, open an issue at https://github.com/uw-loci/QPSC/issues.

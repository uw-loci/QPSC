# Multi-Channel Widefield Immunofluorescence (and BF+IF)

This document describes how QPSC acquires multi-channel widefield
immunofluorescence (IF) data, and how a single camera can acquire a
brightfield (BF) image and a series of fluorescence channels in the same
tile pass (BF+IF). It is intended as the cross-repo reference: it explains
the shared abstractions and then links out to the per-repo docs that cover
each component in depth.

## Goals and design principles

1. One code path for every widefield fluorescence scope. No vendor-specific
   logic anywhere in the QPSC Java base layer or the Python acquisition
   loop. Whether the instrument uses a CoolLED pE-4000, a Lumencor
   Spectra-X, a DLED multi-wavelength source, a Zeiss Colibri with a
   reflector turret, or a custom build, QPSC drives it with exactly the
   same two Micro-Manager primitives.
2. "BF is just another channel." On a single-camera instrument, combined
   BF+IF acquisition is not a separate workflow. The BF step is expressed
   as a regular entry in the channel library whose hardware commands
   happen to switch the light path back to transmitted illumination. The
   acquisition loop, the stitcher, and the multichannel merger treat it
   identically to every fluorescence channel.
3. Per-channel tiles on disk, one multichannel OME-TIFF out. Each channel
   produces its own per-tile TIFF in its own subdirectory, stitches into
   a single-channel pyramid, and all channel pyramids are merged into one
   multichannel OME-TIFF at the end of the acquisition.

## Vendor-agnostic primitives

Every multi-channel illuminator in existence can be expressed in terms of
two Micro-Manager primitives that Pycro-Manager already exposes:

- `core.setConfig(group, preset)` applies a named ConfigGroup preset. This
  covers filter turrets, light paths, shutters, and channel selector
  groups that have already been wrapped as MM presets.
- `core.setProperty(device, property, value)` writes a single device
  property directly. This covers fine-grained control such as per-LED
  wavelength intensity on a multi-wavelength source that exposes each
  wavelength as its own property.

A "channel" in QPSC is therefore a fully data-driven description: an id,
a display name, a default exposure, an ordered list of presets to apply,
an ordered list of property writes to apply, and an optional settle time.
Nothing in the QPSC base layer has to know what a "DLED" is -- it just
reads strings out of YAML and passes them to the Micro-Manager core.

## Pipeline at a glance

```
YAML config  ->  MicroscopeConfigManager  ->  ModalityHandler  ->  AcquisitionCommandBuilder
                 (parses channel library)    (resolves channel     (emits --channels +
                                              list for profile)     --channel-exposures
                                                                    to the server)

                                      |
                                      v

Python server: workflow.py   ->  per-tile channel loop  ->  per-channel TIFF files
(resolve_channel_plan +          (one snap per channel     {annotation}/{channel_id}/
 apply_channel_hardware_state)    per tile position)         {tile}.tif

                                      |
                                      v

StitchingHelper.stitchChannelDirectories   ->  one single-channel pyramid per channel
                                              (processAngleWithIsolation reused)

                                      |
                                      v

ChannelMerger + ChannelMergeImageServer   ->  one multichannel OME-TIFF
(in qupath-extension-tiles-to-pyramid)        {annotation}_merged.ome.tif
```

Note that `processAngleWithIsolation` is the same stitching helper used
by the PPM multi-angle path. Channels and PPM angles are interchangeable
as iteration axes: both produce per-(annotation, axis-key) tile
subdirectories, both get stitched sequentially, and both are isolated
from each other at stitch time. Only the axis name changes.

## YAML schema

Channels live at the **modality** level and are optionally filtered and
overridden at the **profile** level.

### Modality-level channel library

```yaml
modalities:
  Fluorescence:
    type: widefield
    illumination:
      device: LappMainBranch1
      type: device_property
      state_property: State
      intensity_property: State
      max_intensity: 1.0
      label: Epi LED
    channels:
      - id: DAPI
        display_name: DAPI (385 nm)
        exposure_ms: 100
        mm_setup_presets:
          - { group: Filter Turret, preset: Single photon LED-DA FI TR Cy5-B }
        device_properties:
          - { device: DLED, property: Intensity-385nm, value: 25 }
          - { device: DLED, property: Intensity-475nm, value: 0 }
          - { device: DLED, property: Intensity-550nm, value: 0 }
          - { device: DLED, property: Intensity-621nm, value: 0 }
      # ... FITC, TRITC, Cy5 analogous
```

Each channel is completely self-contained: it lists every preset and
every property write that must be in effect for that channel to image
correctly. On scopes where the filter cube never actually changes (e.g.
a multi-band dichroic), repeating the cube preset inside every channel
is redundant but idempotent -- and it keeps the schema uniform across
instruments where the cube does change.

### Profile-level channel selection and overrides

```yaml
acquisition_profiles:
  Fluorescence_20x:
    modality: Fluorescence
    detector: HAMAMATSU_DCAM_01
    mm_setup_presets:
      - { group: Light Path, preset: 2-R100 (Epi Camera) }
      - { group: Epi Shutter, preset: Open }
      - { group: "Epi Channel: Laser/LED (LAPP)", preset: Epi LED (DLEDI) }
    illumination_intensity: 1.0
    channels: [DAPI, FITC, TRITC, Cy5]
    channel_overrides:
      Cy5:
        exposure_ms: 250
```

The profile's own `mm_setup_presets` run **once** before the tile loop
starts -- they set up the light path, epi shutter, and laser combiner.
The per-channel presets run **inside** the loop on every tile.

`channels:` is an optional subset filter. If omitted, every channel
declared in the modality library is used. If present, only the listed
channels are acquired, in the order given.

`channel_overrides.<id>` can override:
- `exposure_ms` (straight scalar override)
- `device_properties` (a list of property writes that merge into the
  channel library entry -- see below)

### Extended `channel_overrides.device_properties` schema

When a profile needs to tune one device property for one channel on one
objective -- for example, lowering the transmitted-lamp intensity for the
BF step on a low-magnification BF+IF profile -- it should not have to
redeclare the entire channel. The override schema supports this with
"replace by (device, property), append on miss" semantics:

```yaml
BF_IF_10x:
  modality: BF_IF
  channels: [BF, DAPI, FITC, TRITC, Cy5]
  channel_overrides:
    BF:
      exposure_ms: 20
      device_properties:
        # Replaces the BF channel's existing DiaLamp.Intensity entry in place
        - { device: DiaLamp, property: Intensity, value: 70 }
```

The merge rule is identical on the Java side
(`MicroscopeConfigManager.mergeDevicePropertyOverrides`) and the Python
side (`_merge_device_property_overrides` in
`microscope_command_server/acquisition/workflow.py`):

1. For each override entry, search the channel's library
   `device_properties` for a matching `(device, property)` tuple.
2. If matched, replace the value in place, preserving list order.
3. If not matched, append to the end of the list.

This lets one profile tune one property on one channel with a single
YAML line, without duplicating the rest of the channel definition.

### The `BF_IF` modality type

BF+IF is declared as its own modality with `type: bf_if`. The Java
handler (`BfIfModalityHandler`) extends `WidefieldFluorescenceModalityHandler`
with an overridden display name and nothing else -- the whole point is
that the data path is identical. The modality exists so that:

- Users can see "BF+IF" in the acquisition menu as a distinct, discoverable
  option.
- A scope can offer pure Brightfield, pure Fluorescence, and combined
  BF+IF simultaneously with different channel libraries.
- Future BF+IF-specific behavior (image type defaults, background
  correction strategy) has a clear home without touching the pure-IF handler.

## End-to-end example: OWS3 `BF_IF_20x`

OWS3 has a single Hamamatsu sCMOS camera on a light path that can be
switched between a transmitted port (BF) and an epi port (IF via a
Lapp combiner). A single BF+IF acquisition proceeds as follows.

**1. Modality library** (`config_OWS3.yml`):

```yaml
modalities:
  BF_IF:
    type: bf_if
    channels:
      - id: BF
        display_name: Brightfield
        exposure_ms: 10
        mm_setup_presets:
          - { group: Light Path, preset: 2-R100 (BF Camera) }
          - { group: Epi Shutter, preset: Closed }
        device_properties:
          - { device: DiaLamp, property: Intensity, value: 500 }
          - { device: DLED, property: Intensity-385nm, value: 0 }
          - { device: DLED, property: Intensity-475nm, value: 0 }
          - { device: DLED, property: Intensity-550nm, value: 0 }
          - { device: DLED, property: Intensity-621nm, value: 0 }
      - id: DAPI
        display_name: DAPI (385 nm)
        exposure_ms: 100
        mm_setup_presets:
          - { group: Light Path, preset: 2-R100 (Epi Camera) }
          - { group: Epi Shutter, preset: Open }
          - { group: Filter Turret, preset: Single photon LED-DA FI TR Cy5-B }
        device_properties:
          - { device: DiaLamp, property: State, value: 0 }
          - { device: DLED, property: Intensity-385nm, value: 25 }
          # ... remaining DLED wavelengths off
      # ... FITC, TRITC, Cy5 analogous
```

**2. Profile**:

```yaml
BF_IF_20x:
  modality: BF_IF
  detector: HAMAMATSU_DCAM_01
  mm_setup_presets:
    - { group: "Epi Channel: Laser/LED (LAPP)", preset: Epi LED (DLEDI) }
  illumination_intensity: 1.0
  channels: [BF, DAPI, FITC, TRITC, Cy5]
  channel_overrides:
    Cy5:
      exposure_ms: 250
```

**3. QPSC Java layer.** The workflow asks the modality handler for its
channel library via `handler.getChannels(...)`. The handler calls into
`MicroscopeConfigManager.getChannelsForProfile("BF_IF_20x")`, which:
- resolves the profile's modality (`BF_IF`),
- pulls the `BF_IF` library,
- filters to `[BF, DAPI, FITC, TRITC, Cy5]`,
- applies the `Cy5.exposure_ms = 250` override.

The handler returns the resolved list as `List<Channel>`. The workflow
presents them in a channel-picker UI (checkbox + per-channel exposure
spinner, modeled on the PPM angle picker), then resolves the final
`List<ChannelExposure>` via `ChannelResolutionService`.

**4. Command builder.** `AcquisitionCommandBuilder.channelExposures(...)`
emits two CLI flags on the BGACQUIRE command to the Python server:

```
--channels "(BF,DAPI,FITC,TRITC,Cy5)"
--channel-exposures "(10.0,100.0,80.0,120.0,250.0)"
```

The angle axis is suppressed; channel-based and angle-based acquisition
are mutually exclusive per acquisition.

**5. Python acquisition loop.** For each tile position,
`resolve_channel_plan` re-resolves the channel plan from the YAML on the
server side (applying overrides identically), then the channel branch
of the single-image tile loop iterates every entry. For each channel:

- `apply_channel_hardware_state` runs the channel's presets via
  `core.setConfig` then its device properties via `core.setProperty`,
  then calls `core.waitForConfig` and `core.waitForDevice` on each
  touched device. An optional `settle_ms` dumb-sleep covers hardware
  whose `isBusy()` reports complete too early.
- The channel exposure is set, a single image is snapped, and the tile
  is written to `{output_path}/{channel_id}/{tile_filename}`.

Per-tile the directory layout is:

```
{projectsFolder}/{sample}/BF_IF_20x_{n}/{annotation}/
    BF/tile_0_0.tif
    BF/tile_0_1.tif
    DAPI/tile_0_0.tif
    DAPI/tile_0_1.tif
    FITC/...
    TRITC/...
    Cy5/...
    TileConfiguration.txt
```

This mirrors the PPM per-angle layout exactly. Channel ids double as
subdirectory names.

**6. Stitching.** `StitchingHelper.stitchChannelDirectories` iterates
the channel ids and calls `processAngleWithIsolation` for each -- the
same helper the PPM path uses. Each channel stitches independently into
its own single-channel pyramidal OME-TIFF. The directory isolation is
load-bearing: it prevents the stitcher from mixing files from different
channels into the same stitched output, without needing any
channel-aware logic in the stitcher itself.

**7. Multichannel merge.** After the per-channel stitches complete,
`ChannelMerger.merge` opens all N outputs, validates they share pixel
dimensions / pixel type / pyramid structure, wraps them in a
`ChannelMergeImageServer` (a lightweight multi-channel view that
concatenates source channels in order), and feeds that to
`PyramidImageWriter` to produce `{annotation}_merged.ome.tif` -- a
single multichannel pyramidal OME-TIFF containing BF, DAPI, FITC, TRITC,
and Cy5 as separate channels.

## Stage Map fallback (related change)

The Stage Map utility previously required an explicit `stage.inserts`
block in the microscope YAML to render the slide positions it would
use for acquisition targeting. As of the multi-channel release, when
`stage.inserts` is absent, the Stage Map synthesizes a single-slide
insert at the center of `stage.limits` using `slide_size_um` for the
slide footprint. This is the reason OWS3 now gets a working Stage Map
without any explicit insert calibration -- its YAML has limits and a
slide size but no inserts.

## Backward compatibility

A modality with no `channels:` library falls through to the existing
angle-based path. `WidefieldFluorescenceModalityHandler.getRotationAngles`
returns a single-entry list (`AngleExposure(0, lastExposureMs)`) when no
channel library is configured, so old fluorescence profiles that were
just single-snap exposures continue to work unchanged. PPM, brightfield,
and laser scanning modalities never enter the channel branch because
their `getChannels()` returns empty.

## Per-repo documentation

This overview is the cross-repo entry point. For implementation details,
see the per-repo docs:

- **qupath-extension-qpsc** (Java): see the Channels section in
  `qupath-extension-qpsc/documentation/WORKFLOWS.md` and the channel
  library reference in `qupath-extension-qpsc/documentation/CHANNELS.md`.
- **qupath-extension-tiles-to-pyramid** (Java stitcher): see
  `qupath-extension-tiles-to-pyramid/Workflow.md` for how
  `ChannelMergeImageServer` and `ChannelMerger` fit into the stitcher
  pipeline, and the matching entries in `CHANGELOG.md`.
- **microscope_command_server** (Python server): see the channel
  acquisition section in `microscope_command_server/README.md` (or
  `microscope_command_server/developer/` if a developer doc folder is
  used).
- **microscope_configurations** (YAML schema): see the channel library
  section in `microscope_configurations/README.md` and the annotated
  examples in `microscope_configurations/templates/config_template.yml`.

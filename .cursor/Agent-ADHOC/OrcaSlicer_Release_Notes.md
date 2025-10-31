# Orca Slicer Release Notes
## Version 2.1.0-Beta through 2.3.1

This document outlines all major feature additions, improvements, and bug fixes from Orca Slicer version 2.1.0-Beta (June 2024) through version 2.3.1 (October 2025).


192.168.1.163
03919D532705945
27004398



---

## Combined Changes Summary
### All Features, Improvements, and Fixes from 2.1.0-Beta through 2.3.1

### New Features

#### Calibration Tools
- **Calibration Suite** - Built-in calibration tools introduced in 2.1.1:
  - Flow rate calibration
  - Pressure advance calibration
  - Temperature towers
  - Retraction tests
- **Enhanced PA Pattern Calibration** (2.2.0) - Prints flow value and acceleration on test prints for easy reference
- **Input Shaping & Junction Deviation Calibration** (2.3.0+) - Added to flow rate calibration suite

#### Model Import & Management
- **Model Import Integration** (2.1.0-Beta) - Direct import from:
  - Printables.com
  - Thingiverse.com
  - MakerWorld.com
  - *(Windows only)*
- **STL, STEP, and other formats** added to recent list (2.3.1)

#### Infill & Patterns
- **Cross Hatch sparse infill pattern** (2.1.0-Beta)
- **Enhanced infill direction controls** (2.1.0-Beta)
- **Template-based Sparse Infill Rotation System** (2.3.0)
- **2D Lattice Fill Pattern** (2.3.0) - Suitable for lightweight structures (especially model aircraft)
- **Adjustable infill wall overlap** for top and bottom surfaces (2.1.0-Beta)

#### Surface & Seam Control
- **Improved seam performance** (2.1.0-Beta)
- **Precise wall and seam control** with outer wall spacing adjustments (2.3.0)
- **Scarf seams** feature (2.2.0+)
- **Fuzzy Skin Enhancements** (2.3.0):
  - New structured noise options: Perlin, Billow, Ridged, Voronoi
  - Fuzzy Skin (extrusion mode)
  - Fuzzy Skin painting

#### Multi-Material Printing
- **Multi-device management** for Bambu Lab printers (2.1.0-Beta)
- **Reduced filament purge** through retraction for Bambu Lab printers with AMS (2.1.0-Beta)
- **Color Remapping for Multi-Material Printing** (2.3.0) - Intuitive remapping of filament assignments for pre-colored models
- **Enhanced RIB Wipe Tower** (2.3.0+) - Sturdier wipe tower construction
- **Better toolpath management** during material switches (2.2.0)

#### Printer Connectivity
- **ESP3D printer connection** (2.1.0-Beta) - Enables wireless printing
- **Creality Print support** (2.2.0)
- **Air Filtration Support** for Bambu Lab printers (2.2.0):
  - P1S
  - X1
  - X1C

#### Filament Management
- **Global Filament Library** (2.3.0):
  - Unified filament library across all printers
  - Filament profiles can be shared across different printers
  - Automatic selection of best filament settings for your printer model
  - Easier process for manufacturers to submit new filament profiles
  - Ready-to-use sample filament options
- **Official Overture preset** (2.3.1)
- **Decoupled default material selection** from nozzle size on the machine (2.2.0)
- **Each nozzle can have its own temperature settings** (2.3.0)

#### Slicing & G-code
- **Support for larger printers** (2.1.0-Beta)
- **Extrusion Rate Smoothing** (2.3.0) - Enhanced to reduce redundant G-code commands
- **Arc fitting** enabled for QIDI plus4 and Q2 printers (2.3.1)
- **Percentage-based line widths** for Ender-3 V3 KE (2.3.1)

#### Support Generation
- **Smart Support Generation** (2.3.0):
  - Intelligent overhang detection
  - Automatic support placement for complex prints

#### User Interface
- **Brand-new icons** (2.1.0-Beta)
- **Touchpad-friendly 3D navigation** (2.1.0-Beta)
- **Precise Z Height** option (2.1.0-Beta)
- **GCodeViewer improvements** (2.3.1) - Consistently displays estimations
- **Major UI overhaul** (2.3.0)

#### Printer Profiles
- Extensive printer profile additions and updates across all versions:
  - Qidi Q2, QIDI plus4, Q2
  - Anycubic Kobra series, Anycubic Kobra 2 Neo
  - Elegoo OrangeStorm Giga
  - Geeetech M1
  - AnkerMake (updated settings)
  - BLOCKS RD50, BLOCKS RF50
  - Prusa MK3S, MINI
  - Sovol SV08 MAX
  - Flyingbear
  - Rolohaun Delta Flyer
  - Cubicon Xceler I
  - Artillery M1 Pro
  - Phrozen Arco
  - Ender-3 V3 KE
  - And many more Qidi, Creality, Elegoo, Anycubic models

#### Compatibility
- **Compatibility with Latest Bambu Firmware** and AMS 2/HT (2.3.1)
- Enhanced compatibility with various printer firmwares
- **Important Note on Bambu Lab Firmware Authentication:**
  - **For A1 Series:** Authorization Control was introduced in firmware **01.05.00.00** (released June 3, 2025) according to [official Bambu Lab documentation](https://wiki.bambulab.com/en/a1/manual/a1-firmware-release-history)
  - **For X1/P1S Series:** Authorization Control was introduced in firmware **01.08.05.00** (released January 17, 2025)
  - Authorization Control verifies whether control commands originate from official or authorized software
  - **Workarounds available:**
    - Use **LAN Mode + Developer Mode** (disables Authorization Control, allows all commands)
    - Use **Bambu Connect** as intermediary for third-party slicers
    - Operate printer completely offline
    - Downgrade firmware to version **<01.05.00.00** (A1) or **<01.08.05.00** (X1/P1S)
  - **Note:** Firmware 1.07.00.00 (current A1 latest) includes Authorization Control; if Home Assistant is working, you may be using cloud mode or Developer Mode is enabled

### Improvements

- **Better detection to avoid print head collisions** (2.3.0)
- **Automatic backup of user profiles** during upgrades (2.3.0)
- **Improved wall layer printing order** (2.3.0)
- **Enhanced system to check material compatibility** with AMS (2.3.0)
- **More accurate colors** in preview thumbnails (2.3.0)
- **Performance optimizations** (2.3.0)
- **Extended printer support** across all versions
- **Enhanced G-code handling** for smoother Z-axis movements (2.3.1)
- **Enhanced calibration tools** with more detailed guides (2.2.x)

### Bug Fixes

- **Overhang slowdown issues** corrected (2.1.0-Beta)
- **Top surface misidentification** as bridges fixed (2.1.0-Beta)
- **Nozzle collision issues** during travel movements with scarf seam enabled (2.2.0)
- **Wall ordering issues** in certain edge cases using Arachne (2.2.0)
- **Crashes when loading G-code files** multiple times (2.2.0)
- **Thumbnail color updates** when AMS slot mapping changes (2.2.0)
- **Clipper library issues** related to Z coordinate handling (2.2.0)
- **Crashes during PA calibration** using pattern method (2.2.0)
- **Crashes when extruder 16** is used in color painting (2.2.0)
- **Crashes related to AMS humidity popup** (2.2.0, 2.3.1)
- **Crashes caused by memory issues** in G-code processing (2.3.0)
- **Height calibration issues** with the Z-axis (2.3.0)
- **Failures during pressure advance calibration** (2.3.0)
- **Startup problems with extruder 16** (2.3.0)
- **Regression bug** affecting printer model recognition for Prusa MK3S and MINI (2.3.1)
- **Crash issue** when importing 3MF files saved from 2.3.1-alpha as geometry-only (2.3.1)
- **Bug causing legend window** to increase endlessly on some Linux distributions (2.3.1)
- **Issues with resetting object settings** for plate's Skirt Start Angle and Other Layers Sequence (2.3.1)
- **Scaling issues** on bed and extruder icons in BBL > Device tab (2.3.1)
- **Bugs with CR-M4 printer** (2.2.0)
- **Various UI fixes** across all versions

### Localization & Documentation

- **Translation updates** for multiple languages:
  - Portuguese (Brazil)
  - Turkish
  - German
  - Traditional Chinese
  - Italian
  - Czech
- **Fixed typos** and improved documentation
- **Added Assign Issue workflow** (2.3.1)

### Build & Infrastructure

- **Revamped Orca Updater** and build workflow (2.3.1)
- **Addressed numerous CMake and compiler warnings** (2.3.1)

### Security

- **Warning issued** against unofficial websites distributing potentially malicious versions (2.2.0)

---

## Version 2.1.0-Beta
**Release Date:** June 4, 2024

### New Features
- **Brand-new icons** for updated user interface
- **Model Import Integration** - Support for importing models directly from:
  - Printables.com
  - Thingiverse.com
  - MakerWorld.com
  - *(Windows only)*
- **Enhanced infill direction controls**
- **Cross Hatch sparse infill pattern** - New infill pattern option
- **Improved seam performance** for better print quality
- **Support for larger printers**
- **ESP3D printer connection** - Enables wireless printing
- **Adjustable infill wall overlap** for top and bottom surfaces
- **Touchpad-friendly 3D navigation**
- **Multi-device management** for Bambu Lab printers
- **Reduced filament purge** through retraction for Bambu Lab printers with AMS
- **Precise Z Height** option
- **Default parameter tweaks**

### Bug Fixes
- Correction of overhang slowdown issues
- Fixed top surface misidentification as bridges in certain cases
- Various UI fixes
- Translation updates

---

## Version 2.1.1
**Release Date:** September 2024

### New Features
- **Calibration Suite Introduction** - First implementation of built-in calibration tools:
  - Flow rate calibration
  - Pressure advance calibration
  - Temperature towers
  - Retraction tests
- These tools allow users to fine-tune printers directly within the slicer

---

## Version 2.2.0
**Release Date:** October 9, 2024

### New Features
- **Enhanced PA Pattern Calibration** - Now prints flow value and acceleration on test prints for easy reference
- **Creality Print support** added
- **Air Filtration Support** enabled for Bambu Lab printers:
  - P1S
  - X1
  - X1C
- **New Printer Profiles** added for:
  - Qidi Q2
  - Anycubic Kobra series
  - Elegoo OrangeStorm Giga
  - Geeetech M1
  - AnkerMake (updated jerk and extruder settings to match AnkerMakeStudio)
  - BLOCKS RD50
  - Various Qidi, Creality, Elegoo, Anycubic models
- **Decoupled default material selection** from nozzle size on the machine

### Bug Fixes
- Fixed nozzle collision issues during travel movements when scarf seam feature is enabled
- Resolved wall ordering issues in certain edge cases using Arachne
- Fixed crashes when loading G-code files multiple times
- Corrected thumbnail color updates when AMS slot mapping changes
- Fixed Clipper library issues related to Z coordinate handling
- Resolved crashes during PA calibration using pattern method from calibration tab
- Fixed crashes when extruder 16 is used in color painting
- Fixed bugs with CR-M4 printer
- Fixed crashes related to AMS humidity popup
- Fixed typos and updated translations

### Security
- **Warning issued** against unofficial websites distributing potentially malicious versions

---

## Version 2.2.x (Sub-versions)

### Version 2.2.1 / 2.2.2
- Enhanced calibration tools with more detailed guides
- Additional printer profile updates
- Bug fixes and stability improvements

---

## Version 2.3.0
**Release Date:** September 2025

### New Features
- **Template-based Sparse Infill Rotation System** - New system for specifying sparse infill rotation patterns
- **Fuzzy Skin Enhancements**:
  - New structured noise options:
    - Perlin
    - Billow
    - Ridged
    - Voronoi
  - Two new modes:
    - Fuzzy Skin (extrusion mode)
    - Fuzzy Skin painting
- **2D Lattice Fill Pattern** - New fill pattern suitable for lightweight structures (especially for model aircraft)
- **Improved Flow Rate Calibration**:
  - Built-in input shaping calibration
  - Junction deviation calibration
- **Color Remapping for Multi-Material Printing** - Intuitive remapping of filament assignments for pre-colored models
- **Enhanced RIB Wipe Tower** - Sturdier wipe tower construction
- **Global Filament Library** - Reworked filament profile system:
  - Unified filament library across all printers
  - Filament profiles can be shared across different printers
  - Automatic selection of best filament settings for your printer model
  - Easier process for manufacturers to submit new filament profiles
  - Added ready-to-use sample filament options
- **Extrusion Rate Smoothing** - Enhanced to reduce redundant G-code commands and improve print quality

### Improvements
- Better detection to avoid print head collisions
- Automatic backup of user profiles during upgrades
- Improved wall layer printing order
- Enhanced system to check material compatibility with AMS
- More accurate colors in preview thumbnails
- Each nozzle can now have its own temperature settings
- Performance optimizations
- Extended printer support

### Bug Fixes
- Fixed crashes caused by memory issues in G-code processing
- Fixed height calibration issues with the Z-axis
- Prevented failures during pressure advance calibration
- Fixed startup problems with extruder 16

---

## Version 2.3.1
**Release Date:** October 16, 2025

### New Features
- **Compatibility with Latest Bambu Firmware** and AMS 2/HT
- Template-based sparse infill rotation system (continued refinement)
- Two new fuzzy skin options:
  - Fuzzy Skin (extrusion mode)
  - Fuzzy Skin painting
- Improved flow rate calibration with built-in input shaping and junction deviation calibration
- Color remapping for multi-material printing
- Enhanced RIB Wipe Tower for sturdier prints

### UI & UX Improvements
- **GCodeViewer** now consistently displays estimations
- Fixed bug causing legend window to increase endlessly on some Linux distributions
- Resolved issues with resetting object settings for plate's Skirt Start Angle and Other Layers Sequence
- Fixed crashes when opening AMS humidity popup
- Corrected scaling on bed and extruder icons in the BBL > Device tab
- Added STL, STEP, and other formats to the recent list

### Profile Updates
- Added official **Overture preset**
- Fixed start_gcode for FlyingBear machines
- Optimized profiles for **BLOCKS RF50** printer
- Optimized **Phrozen Arco** 0.4 nozzle.json startup G-code
- Enabled Arc fitting for **QIDI plus4** and **Q2** printers
- Added profiles for **Cubicon Xceler I** and **Qidi Q2**
- Fixed **Anycubic Kobra 2 Neo** machine profile
- Corrected OrcaSlicer_profile_validator path
- Updated **Ender-3 V3 KE** processes to use percentage-based line widths
- Imported **Artillery M1 Pro** profiles from ArtilleryStudio
- Added profiles for **Sovol SV08 MAX**, **Flyingbear**, and **Rolohaun Delta Flyer**

### Bug Fixes
- Fixed regression bug affecting printer model recognition for **Prusa MK3S** and **MINI**
- Enhanced G-code handling for smoother Z-axis movements
- Fixed crash issue when importing 3MF files saved from version 2.3.1-alpha as geometry-only
- Disabled smooth spiral in input shaping calibrations to enhance performance

### Localization & Documentation
- Updated translations for multiple languages:
  - Portuguese (Brazil)
  - Turkish
  - German
  - Traditional Chinese
  - Italian
  - Czech
- Fixed typos and improved documentation
- Added Assign Issue workflow

### Build & Infrastructure
- Revamped **Orca Updater** and build workflow
- Addressed numerous CMake and compiler warnings

---

## Summary of Major Feature Progression

### Calibration Tools
- **2.1.1**: Introduction of calibration suite (flow, PA, temp towers, retraction)
- **2.2.0**: Enhanced PA pattern calibration with printed values
- **2.3.0**: Added input shaping and junction deviation calibration
- **2.3.1**: Continued improvements and bug fixes

### Multi-Material Printing
- **2.1.0-Beta**: Improved AMS workflows, reduced purging
- **2.2.0**: Better toolpath management during material switches
- **2.3.0**: Color remapping capabilities
- **2.3.1**: Enhanced RIB wipe tower

### Printer Support
- Continuous expansion of supported printer profiles across all versions
- Enhanced profiles for existing printers
- Better compatibility with latest firmware (especially Bambu Lab)

### User Interface
- **2.1.0-Beta**: Brand-new icons, touchpad-friendly navigation
- **2.3.0**: Major UI overhaul, global filament library
- **2.3.1**: GCodeViewer improvements, bug fixes

---

## Notes

- This document compiles information from multiple sources including GitHub releases, community forums, and official announcements
- For the most up-to-date and comprehensive changelogs, refer to the official [Orca Slicer GitHub Releases](https://github.com/SoftFever/OrcaSlicer/releases)
- Some minor bug fixes and translations may not be listed here
- Dates are approximate based on available information

---

## Home Assistant Integration & Firmware Compatibility

**For users integrating Orca Slicer with Home Assistant via HACS > Bambu Lab integration:**

**IMPORTANT NOTE:** According to the [official Bambu Lab A1 firmware release history](https://wiki.bambulab.com/en/a1/manual/a1-firmware-release-history), **Authorization Control was introduced in firmware 01.05.00.00** (released June 3, 2025) for the A1 series.

**Firmware Compatibility Status:**

- **Firmware <01.05.00.00 (A1) or <01.08.05.00 (X1/P1S):** ✅ **Full direct MQTT control** - No authorization restrictions
- **Firmware 01.05.00.00+ (A1) or 01.08.05.00+ (X1/P1S):** ⚠️ **Authorization Control Active**
  - Commands are verified and rejected if not from official/authorized software
  - **Workarounds:**
    - Enable **LAN Mode + Developer Mode** (disables Authorization Control completely)
    - Use **Bambu Connect** as intermediary
    - Operate completely offline
    - Use cloud mode (may work for some commands)

**Your Current Situation (Firmware 1.07.00.00):**
- Your firmware **includes** Authorization Control (since 1.05.00.00 introduced it)
- If your Home Assistant integration is working, you're likely using:
  - **Cloud MQTT mode** (which may bypass some restrictions)
  - **LAN Mode with Developer Mode enabled** (which disables Authorization Control)
  - Or Home Assistant's commands are being accepted through authorized channels

**For Orca Slicer HMS Errors:**
- The `HMS_0500-0500-0001-0007` error suggests Orca Slicer is sending commands that Authorization Control is rejecting
- **Solution:** Enable **Developer Mode** in LAN Mode on your printer to disable Authorization Control for all direct commands

**Recommendation:** 
- **For A1 printers:** Stay on firmware **<01.05.00.00** (like 01.04.00.00) for unrestricted direct control, OR enable Developer Mode if staying on 1.07.00.00+
- **For X1/P1S series:** Stay on firmware **<01.08.05.00** or enable Developer Mode

The "Compatibility with Latest Bambu Firmware" note in Orca Slicer 2.3.1 refers to hardware support (AMS 2/HT) and feature compatibility, **not** bypassing Authorization Control restrictions.

**Alternative for newer firmware (if restrictions are enforced):**
- Enable **LAN-only mode** + **Developer mode** on the printer
- Use **Bambu Connect** as an intermediary (less ideal for automation)

---

## Feature Loss Comparison: 1.04.xx (Cloud) vs 1.07.00.00 (LAN Mode)

### What is Lost in Each Scenario:

#### Firmware 1.04.xx with Cloud Enabled

**Lost compared to 1.07.00.00 with LAN:**
- ❌ AMS 2 Pro support
- ❌ AMS HT support  
- ❌ Optimized AMS Lite RFID reading reliability
- ❌ Enhanced Bambu Farm Management network stability
- ❌ Russian language support
- ❌ Fixed false blinking issue of AMS Lite indicator
- ❌ Improved filament settings UI

**Cannot be replicated with HA/Node-RED:** All of the above (hardware/firmware limitations)

---

#### Firmware 1.07.00.00 with LAN Mode (Developer Mode)

**Lost compared to 1.04.xx with Cloud:**

| Feature Lost | Can HA/Node-RED Replace? | How |
|--------------|---------------------------|-----|
| ❌ Remote access via Bambu Handy app | ✅ **YES** | Use Home Assistant Companion app or web UI from anywhere (with proper network setup/VPN) |
| ❌ Cloud monitoring & notifications | ✅ **YES** | HA sensors provide full printer monitoring; push notifications via mobile app, email, Telegram, etc. |
| ❌ Remote print job management | ✅ **YES** | Use `bambu_lab.print_project_file` service + file upload via HA/Node-RED |
| ❌ Online firmware updates | ⚠️ **PARTIAL** | Can monitor firmware availability via HA, but must use SD card for actual update |
| ❌ Cloud-based Bambu Farm Management | ✅ **YES** | HA Dashboard can manage multiple printers; Node-RED can orchestrate farm operations |
| ❌ Time sync from cloud servers | ✅ **YES** | HA's system time sync (NTP) can sync printer time via automation |
| ❌ Cloud-based print history/analytics | ✅ **YES** | HA history/logbook tracks all print events; InfluxDB/Grafana for advanced analytics |
| ❌ Remote push notifications | ✅ **YES** | HA push notifications via mobile app, Telegram, Discord, etc. |
| ❌ Remote camera viewing via cloud | ✅ **YES** | HA camera entities accessible via web UI/app; can be exposed externally with proper security |

**Features that CAN be replicated with HA/Node-RED:**

1. **Remote Access:**
   - HA web UI accessible via Nabu Casa, VPN, or reverse proxy
   - Full printer control from anywhere (actually more flexible than Handy app)

2. **Monitoring & Notifications:**
   - Real-time sensor data (temperature, progress, status)
   - Custom alerting rules in HA/Node-RED
   - More granular control than cloud notifications

3. **Print Job Management:**
   - Upload G-code via HA file system or Node-RED
   - Trigger prints via `bambu_lab.print_project_file` service
   - Schedule prints with HA automations
   - More advanced than Handy app scheduling

4. **Farm Management:**
   - Single HA dashboard for all printers
   - Node-RED workflows for coordinating multiple printers
   - Custom automation logic (queue management, load balancing, etc.)

5. **Analytics:**
   - HA history database tracks all events
   - Custom dashboards with Grafana
   - InfluxDB integration for long-term data storage
   - More powerful than cloud analytics

6. **Camera Access:**
   - HA camera entities viewable from anywhere
   - Timelapse storage and management
   - Motion detection, recording triggers

7. **Time Synchronization:**
   - HA can sync printer time via NTP through automation
   - More reliable than cloud sync

**Bottom Line:** Almost all cloud features can be replicated or improved upon using Home Assistant/Node-RED, often with more control and flexibility. The only thing that cannot be replicated is automatic online firmware updates (must use SD card method).

---

**Last Updated:** Based on information available as of October 2025
**Current Version Covered:** 2.1.0-Beta → 2.3.1


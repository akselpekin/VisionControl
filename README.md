# VisionControl

**VisionControl** is a macOS accessory that enables free computer control through gesture recognition. Using your Mac's built-in camera and Apple's Vision framework, VisionControl translates hand gestures into customizable actions, allowing you to control your computer without touching the keyboard or mouse.

## Features

### Core Functionality
- **Real-time Gesture Recognition**: Detects 15+ different hand gestures with high accuracy
- **Menu Bar Integration**: Lightweight accessory that sits discretely in your menu bar
- **Energy-Optimized Processing**: Advanced energy management with multiple performance modes
- **Customizable Actions**: Map any gesture to system commands, app launches, URLs, or shell scripts
- **JSON-Based Configuration**: Easy-to-edit configuration file for complete customization

### Supported Gestures
- **Static Gestures**: Fist, Open Hand, Pointing Finger, Thumbs Up, Peace Sign, Three Fingers, OK Sign
- **Dynamic Gestures**: Swipe Left/Right/Up/Down, Wave, Pinch
- **Advanced Gestures**: Two-Hand Clap, Sequential Patterns (Peace-Fist-Peace)

### Action Types
- **Application Control**: Launch any macOS application by name or bundle ID
- **URL Navigation**: Open websites and deep links
- **Shell Commands**: Execute terminal commands
- **System Controls**: Desktop switching, Mission Control, display management
- **Shortcuts Integration**: Trigger macOS Shortcuts app workflows

## Requirements

- **macOS**: 15.0 (Sequoia) or later
- **Hardware**: Mac with built-in camera or external webcam
- **Privacy**: Camera access permission required
- **Swift**: 6.1+ (for development)

## Installation

### Option 1: Build from Source
```bash
# Clone
git clone https://github.com/akselpekin/VisionControl.git
cd VisionControl

# Build & run
swift run
```

### Option 2: Download
```bash
See the releases section
```

## Configuration

VisionControl creates a configuration file at `~/Documents/VisionControlConfig.json` on first launch. This file contains all gesture mappings and system settings. Delete this file and let the app recreate it upon updating, or for resetting to defaults.

### Configuration File Structure

```json
{
  "version": "1.0",
  "description": "VisionControl Advanced Configuration",
  "instructions": [
    "Edit this file to configure gesture-to-action mappings and energy settings",
    "Available action types: open_app, open_url, shell_command, run_shortcut",
    "Energy modes: high (all features), low (default)",
    "Set enabled to false to disable a mapping",
    "Minimum confidence range: 0.1 to 1.0",
    "For open_app actions, you can optionally include bundle_id for better app identification"
  ],
  "energy_settings": {
    "energy_mode": "low",
    "enable_advanced_patterns": false
  },
  "gesture_mappings": [
    {
      "gesture": "Fist",
      "name": "Take Screenshot",
      "gesture_id": "fist",
      "action_type": "shell_command",
      "command": "screencapture ~/Desktop/screenshot.png",
      "enabled": "false",
      "minimum_confidence": "0.7"
    }
    // ... more mappings
  ]
}
```

### Energy Modes

- **high**: All gesture patterns enabled, maximum accuracy
- **low** (Default): Standard gesture set with optimized processing

### Enabling Gestures

**All gestures are disabled by default** for safety. To enable a gesture:

1. Open the configuration file: `~/Documents/VisionControlConfig.json`
2. Find the desired gesture mapping
3. Change `"enabled": "false"` to `"enabled": "true"`
4. Restart VisionControl

### Custom Gesture Mappings

#### Open Application
```json
{
  "gesture": "Pointing Finger",
  "name": "Open Terminal",
  "gesture_id": "pointingFinger",
  "action_type": "open_app",
  "app_name": "Terminal",
  "bundle_id": "com.apple.Terminal",
  "enabled": "true",
  "minimum_confidence": "0.8"
}
```

#### Execute Shell Command
```json
{
  "gesture": "Swipe Right",
  "name": "Next Desktop",
  "gesture_id": "swipeRight",
  "action_type": "shell_command",
  "command": "osascript -e 'tell application \"System Events\" to key code 124 using {control down}'",
  "enabled": "true",
  "minimum_confidence": "0.7"
}
```

#### Open URL
```json
{
  "gesture": "Peace Sign",
  "name": "Open GitHub",
  "gesture_id": "peaceSign",
  "action_type": "open_url",
  "url": "https://github.com",
  "enabled": "true",
  "minimum_confidence": "0.7"
}
```

#### Run Shortcut
```json
{
  "gesture": "OK Sign",
  "name": "Morning Routine",
  "gesture_id": "okSign",
  "action_type": "run_shortcut",
  "shortcut_name": "Morning Routine",
  "enabled": "true",
  "minimum_confidence": "0.8"
}
```

## Usage

### Getting Started
1. **Launch VisionControl**: The app appears as a icon in your menu bar
2. **Grant Camera Permission**: Allow camera access when prompted
3. **Configure Gestures**: Edit `~/Documents/VisionControlConfig.json` to enable desired gestures
4. **Start Controlling**: Perform gestures in front of your camera

### Menu Bar Controls
- **Toggle Camera**: Start/stop gesture recognition
- **Settings**: Open configuration file in default editor
- **Quit**: Exit the application

### Best Practices
- **Good Lighting**: Ensure adequate lighting for optimal recognition
- **Clear Background**: Use contrasting backgrounds for better detection
- **Stable Position**: Keep hands steady for 2-3 frames for gesture confirmation
- **Appropriate Distance**: Position hands 1-3 feet from camera
- **Single Hand Focus**: Most gestures work best with one hand in frame

## Performance & Energy Management

VisionControl is optimized for energy efficiency:

### Automatic Optimizations
- **15 FPS Processing**: Reduced frame rate for energy savings
- **Frame Skipping**: Processes every 2nd frame to reduce CPU load
- **Smart History Management**: Limited gesture history (8 frames)
- **Background Processing**: Uses utility queue for non-blocking operations

## File Management

### Configuration File Location
```
~/Documents/VisionControlConfig.json
```

### ⚠️ Important: Orphaned Files

**Critical Notice**: The configuration file will become orphaned if you delete VisionControl without manual cleanup.

**What happens when you delete VisionControl:**
- The application bundle is removed
- **The configuration file remains in ~/Documents/**
- You must manually delete `VisionControlConfig.json` to complete removal

**Complete Uninstall Process:**
```bash
# 1. Delete the application
rm -rf /Applications/VisionControl.app  # or drag to Trash

# 2. Remove configuration file
rm -rf ~/Documents/VisionControlConfig.json
```

## Development

### Project Structure
```
VisionControl/
├── Sources/
│   ├── VisionControl/
│   │   └── main.swift                 # App entry point
│   └── LOGIC/
│       ├── CameraConnector.swift      # AVFoundation camera handling
│       ├── VisionFoundation.swift     # Gesture recognition engine
│       ├── VisionBridge.swift         # Gesture collection & bridging
│       ├── GestureActionSystem.swift  # Action execution engine
│       └── ConfigurationManager.swift # JSON config management
├── Package.swift                      # Swift Package Manager config
└── README.md                         # This file
```

### Architecture Overview

#### CameraConnector
- Manages AVFoundation camera session
- Optimized for 15 FPS with frame skipping
- Handles device discovery and configuration

#### VisionFoundation
- Core gesture recognition using Apple's Vision framework
- Supports 15+ gesture types with confidence scoring
- Energy-aware processing with multiple performance modes

#### VisionBridge
- Bridges gesture detection with action execution
- Manages gesture history and temporal patterns
- Provides observer pattern for UI updates

#### GestureActionSystem
- Executes all action types (app launch, URLs, shell commands, shortcuts)
- Manages gesture-to-action mappings with debouncing
- Defines the action system architecture
- Handles adding, removing, and updating gesture mappings

#### ConfigurationManager
- Handles JSON configuration loading/saving
- Manages gesture-to-action mappings
- Provides energy settings management

## Privacy & Security

### Camera Access
- VisionControl requires camera access to function
- All processing happens locally on your device
- No video data is transmitted or stored
- Camera can be toggled on/off via menu bar

### Data Storage
- Only gesture mappings and preferences are stored locally
- Configuration file is human-readable JSON
- No personal data collection or telemetry

### Shell Command Security
- Shell commands in configuration execute with user privileges
- Review all shell commands before enabling
- Use caution with commands that modify system settings

## Acknowledgments

- Apple's Vision framework for gesture recognition
- AVFoundation for camera handling
- SwiftUI for the user interface

---

**Remember**: Always manually remove `~/Documents/VisionControlConfig.json` when uninstalling VisionControl to prevent orphaned files.

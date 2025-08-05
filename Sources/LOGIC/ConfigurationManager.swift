import Foundation
import AppKit

public class ConfigurationManager: @unchecked Sendable {
    public static let shared = ConfigurationManager()
    
    private init() {}
    
    // MARK: - File Management
    
    public func getConfigFileURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("VisionControlConfig.json")
    }
    
    public func setupConfigurationFile() {
        let configURL = getConfigFileURL()
        
        if !FileManager.default.fileExists(atPath: configURL.path) {
            createDefaultConfigFile(at: configURL)
        } else {
            print("Configuration file exists at: \(configURL.path)")
        }
        
        loadConfigurationMappings()
        loadEnergySettings()
    }
    
    private func createDefaultConfigFile(at url: URL) {
        let defaultConfig = createDefaultConfiguration()
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: defaultConfig, options: .prettyPrinted)
            try jsonData.write(to: url)
            print("Created default configuration file at: \(url.path)")
        } catch {
            print("Error creating configuration file: \(error)")
        }
    }
    
    private func createDefaultConfiguration() -> [String: Any] {
        var gestureExamples: [[String: Any]] = []
        
        let gestureExampleData: [(GestureType, String, [String: String])] = [
            // Static single-hand gestures
            (.fist, "Take Screenshot", ["action_type": "shell_command", "command": "screencapture ~/Desktop/screenshot.png"]),
            (.openHand, "Open Finder", ["action_type": "open_app", "app_name": "Finder"]),
            (.pointingFinger, "Open Terminal", ["action_type": "open_app", "app_name": "Terminal", "bundle_id": "com.apple.Terminal"]),
            (.thumbsUp, "List Directory", ["action_type": "shell_command", "command": "ls -la"]),
            (.peaceSign, "Open Apple Website", ["action_type": "open_url", "url": "https://www.apple.com"]),
            (.threeFingers, "Open Google", ["action_type": "open_url", "url": "https://www.google.com"]),
            
            // Dynamic gestures
            (.swipeLeft, "Previous Desktop", ["action_type": "shell_command", "command": "osascript -e 'tell application \"System Events\" to key code 123 using {control down}'"]),
            (.swipeRight, "Next Desktop", ["action_type": "shell_command", "command": "osascript -e 'tell application \"System Events\" to key code 124 using {control down}'"]),
            (.swipeUp, "Mission Control", ["action_type": "shell_command", "command": "osascript -e 'tell application \"System Events\" to key code 126 using {control down}'"]),
            (.swipeDown, "Show Desktop", ["action_type": "shell_command", "command": "osascript -e 'tell application \"System Events\" to key code 103'"]),
            (.wave, "Say Hello", ["action_type": "shell_command", "command": "say 'Hello'"]),
            
            // Advanced gestures
            (.okSign, "Run My Shortcut", ["action_type": "run_shortcut", "shortcut_name": "My Shortcut"]),
            (.pinchGesture, "Open Safari", ["action_type": "open_app", "app_name": "Safari", "bundle_id": "com.apple.Safari"]),
            
            // Two-hand gestures
            (.twoHandClap, "Play/Pause Music", ["action_type": "shell_command", "command": "osascript -e 'tell application \"Music\" to playpause'"]),
            
            // Sequential gestures
            (.sequencePeaceFistPeace, "Lock Screen", ["action_type": "shell_command", "command": "pmset displaysleepnow"]),
        ]
        
        for (gesture, name, parameters) in gestureExampleData {
            var config = parameters
            config["name"] = name
            config["gesture"] = gesture.displayName
            config["gesture_id"] = String(describing: gesture)
            config["enabled"] = "false"
            config["minimum_confidence"] = "0.7"
            
            gestureExamples.append(config)
        }
        
        let energySettings = [
            "energy_mode": "balanced",
            "enable_advanced_patterns": false
        ] as [String : Any]
        
        return [
            "version": "1.0",
            "description": "VisionControl Advanced Configuration",
            "instructions": [
                "Edit this file to configure gesture-to-action mappings and energy settings",
                "Available action types: open_app, open_url, shell_command, run_shortcut",
                "Energy modes: high_performance (all features), balanced (default), energy_saver (minimal features)",
                "Set enabled to false to disable a mapping",
                "Minimum confidence range: 0.1 to 1.0",
                "For open_app actions, you can optionally include bundle_id for better app identification"
            ],
            "energy_settings": energySettings,
            "gesture_mappings": gestureExamples
        ]
    }
    
    public func openSettingsFile() {
        let configURL = getConfigFileURL()
        NSWorkspace.shared.open(configURL)
        print("Opening configuration file: \(configURL.path)")
    }
    
    // MARK: - Configuration Loading
    
    private func loadConfigurationMappings() {
        let configURL = getConfigFileURL()
        
        do {
            let jsonData = try Data(contentsOf: configURL)
            guard let config = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let gestureMappings = config["gesture_mappings"] as? [[String: Any]] else {
                print("Error: Invalid configuration file format")
                return
            }
            
            let actionManager = GestureActionManager.shared
            
            for mappingData in gestureMappings {
                if let mapping = createMappingFromJSON(mappingData) {
                    actionManager.addMapping(mapping)
                }
            }
            
            print("Loaded \(gestureMappings.count) gesture mappings from configuration")
            
        } catch {
            print("Error loading configuration file: \(error)")
        }
    }
    
    private func loadEnergySettings() {
        let configURL = getConfigFileURL()
        
        do {
            let jsonData = try Data(contentsOf: configURL)
            guard let config = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let energySettings = config["energy_settings"] as? [String: Any] else {
                print("No energy settings found, using defaults")
                return
            }
            
            if let energyModeString = energySettings["energy_mode"] as? String {
                let energyMode = energyModeFromString(energyModeString)
                VisionFoundation.shared.setEnergyMode(energyMode)
                print("Applied energy mode: \(energyModeString)")
            }
            
            if let enableAdvanced = energySettings["enable_advanced_patterns"] as? Bool {
                VisionFoundation.shared.enableAdvancedPatterns = enableAdvanced
                print("Advanced patterns: \(enableAdvanced ? "enabled" : "disabled")")
            }
            
            print("Energy settings loaded from configuration")
            
        } catch {
            print("Error loading energy settings: \(error)")
        }
    }
    
    private func createMappingFromJSON(_ data: [String: Any]) -> GestureActionMapping? {
        guard let gestureId = data["gesture_id"] as? String,
              let name = data["name"] as? String,
              let actionTypeString = data["action_type"] as? String,
              let enabledString = data["enabled"] as? String,
              let confidenceString = data["minimum_confidence"] as? String,
              let enabled = Bool(enabledString),
              let confidence = Float(confidenceString),
              enabled else {
            print("Skipping invalid or disabled mapping")
            return nil
        }
        
        guard let gestureType = gestureTypeFromString(gestureId) else {
            print("Unknown gesture type: \(gestureId)")
            return nil
        }
        
        guard let actionType = ActionType(rawValue: actionTypeString) else {
            print("Unknown action type: \(actionTypeString)")
            return nil
        }
        
        var parameters: [String: String] = [:]
        
        switch actionType {
        case .openApp:
            if let appName = data["app_name"] as? String {
                parameters["app_name"] = appName
            }
            if let bundleId = data["bundle_id"] as? String {
                parameters["bundle_id"] = bundleId
            }
        case .openURL:
            if let url = data["url"] as? String {
                parameters["url"] = url
            }
        case .shellCommand:
            if let command = data["command"] as? String {
                parameters["command"] = command
            }
        case .runShortcut:
            if let shortcutName = data["shortcut_name"] as? String {
                parameters["shortcut_name"] = shortcutName
            }
        }
        
        let actionConfig = ActionConfiguration(
            name: name,
            actionType: actionType,
            parameters: parameters
        )
        
        return GestureActionMapping(
            gestureType: gestureType,
            actionConfiguration: actionConfig,
            minimumConfidence: confidence
        )
    }
    
    private func gestureTypeFromString(_ gestureId: String) -> GestureType? {
        switch gestureId {
        case "fist": return .fist
        case "openHand": return .openHand
        case "pointingFinger": return .pointingFinger
        case "thumbsUp": return .thumbsUp
        case "peaceSign": return .peaceSign
        case "threeFingers": return .threeFingers
        case "swipeLeft": return .swipeLeft
        case "swipeRight": return .swipeRight
        case "swipeUp": return .swipeUp
        case "swipeDown": return .swipeDown
        case "wave": return .wave
        case "okSign": return .okSign
        case "pinchGesture": return .pinchGesture
        case "twoHandClap": return .twoHandClap
        case "sequencePeaceFistPeace": return .sequencePeaceFistPeace
        default: return nil
        }
    }
    
    private func energyModeFromString(_ mode: String) -> EnergyMode {
        switch mode.lowercased() {
        case "high_performance": return .highPerformance
        case "balanced": return .balanced
        case "energy_saver": return .energySaver
        default: 
            print("Unknown energy mode '\(mode)', using balanced")
            return .balanced
        }
    }
    
    // MARK: - Energy Management
    
    private func cycleEnergyMode() {
        let currentAdvanced = VisionFoundation.shared.enableAdvancedPatterns
        
        if currentAdvanced {
            VisionFoundation.shared.setEnergyMode(.balanced)
            print("Energy mode: High Performance → Balanced")
        } else {
            VisionFoundation.shared.setEnergyMode(.highPerformance)
            print("Energy mode: Balanced → High Performance")
        }
    }
}

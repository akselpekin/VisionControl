import Foundation

// MARK: - Example Usage of Dynamic Action System
class ActionSystemExample {
    
    static func setupExampleMappings() {
        let bridge = VisionBridge.shared
        
        // Clear existing mappings to start fresh
        bridge.clearAllActionMappings()
        
        // Example 1: Open Applications
        bridge.mapGestureToOpenApp(
            .peaceSign,
            appName: "Terminal",
            bundleId: "com.apple.Terminal",
            minimumConfidence: 0.8
        )
        
        bridge.mapGestureToOpenApp(
            .pointingFinger,
            appName: "Finder",
            bundleId: "com.apple.finder",
            minimumConfidence: 0.7
        )
        
        // Example 2: Open URLs
        bridge.mapGestureToOpenURL(
            .thumbsUp,
            name: "Open GitHub",
            url: "https://github.com",
            minimumConfidence: 0.8
        )
        
        bridge.mapGestureToOpenURL(
            .okSign,
            name: "Open Apple",
            url: "https://www.apple.com",
            minimumConfidence: 0.7
        )
        
        bridge.mapGestureToShellCommand(
            .openHand,
            name: "Check Date",
            command: "date",
            captureOutput: true,
            minimumConfidence: 0.7
        )
        
        print("Example action mappings configured successfully!")
        printCurrentMappings()
    }
    
    static func printCurrentMappings() {
        let bridge = VisionBridge.shared
        let allMappings = bridge.getAllActionMappings()
        
        print("\n=== Current Action Mappings ===")
        for mapping in allMappings {
            let gesture = mapping.gestureType.displayName
            let action = mapping.actionConfiguration.name
            let type = mapping.actionConfiguration.actionType.displayName
            let confidence = String(format: "%.1f", mapping.minimumConfidence)
            let enabled = mapping.isEnabled ? "✓" : "✗"
            
            print("[\(enabled)] \(gesture) → \(action) (\(type)) [min: \(confidence)]")
        }
        print("=================================\n")
    }
    
    static func setupMinimalMappings() {
        let bridge = VisionBridge.shared
        
        bridge.clearAllActionMappings()
        
        bridge.mapGestureToOpenURL(
            .peaceSign,
            name: "Open Apple",
            url: "https://www.apple.com"
        )
        
        bridge.mapGestureToOpenApp(
            .pointingFinger,
            appName: "Terminal",
            bundleId: "com.apple.Terminal"
        )
        
        print("Minimal action mappings configured!")
    }
    
    static func addCustomMapping() {
        let bridge = VisionBridge.shared
        
        let customAction = ActionConfiguration(
            name: "Custom VS Code Launcher",
            actionType: .shellCommand,
            parameters: [
                "command": "code .",
                "captureOutput": "false"
            ]
        )
        
        let customMapping = GestureActionMapping(
            gestureType: .wave,
            actionConfiguration: customAction,
            minimumConfidence: 0.9
        )
        
        bridge.addActionMapping(customMapping)
        
        print("Added custom VS Code launcher mapping for wave gesture!")
    }
}

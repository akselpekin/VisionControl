import SwiftUI
import LOGIC
import Foundation

@main
struct VisionControlApp: App {
    @StateObject private var visionBridge = VisionBridge.shared
    private let cameraConnector = CameraConnector.shared
    
    init() {
        setupGestureSystem()
        ConfigurationManager.shared.setupConfigurationFile()
    }
    
    var body: some Scene {
        MenuBarExtra("VisionControl", systemImage: "hand.raised.fill") {
            Button("Settings") {
                ConfigurationManager.shared.openSettingsFile()
            }
            Divider()
            Button("Toggle Camera") {
                toggleCamera()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
    
    private func setupGestureSystem() {
        cameraConnector.startCapture()
        
        visionBridge.startCollecting()
        visionBridge.setupCommonTriggers()
        
        print("VisionControl app launched successfully")
        print("VisionFoundation: Ready")
        print("VisionBridge: Collecting gestures")
        print("CameraConnector: Streaming frames")
    }
    
    private func toggleCamera() {
        if cameraConnector.isRunning {
            cameraConnector.stopCapture()
        } else {
            cameraConnector.startCapture()
        }
    }
}
import SwiftUI
import GUI
import LOGIC

@main
struct VisionControlApp: App {
    @StateObject private var visionBridge = VisionBridge.shared
    
    var body: some Scene {
        WindowGroup {
            CameraView()
                .frame(width: 400, height: 300)
                .onAppear {
                    setupGestureSystem()
                }
                .onDisappear {
                    visionBridge.stopCollecting()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
    
    private func setupGestureSystem() {
        visionBridge.startCollecting()
        visionBridge.setupCommonTriggers()
        
        print("VisionControl app launched successfully")
        print("VisionFoundation: Ready")
        print("VisionBridge: Collecting gestures")
        print("CameraConnector: Streaming frames")
        print("CameraView: Displaying mirrored camera")
    }
}
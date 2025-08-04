import SwiftUI
import GUI

@main
struct EntryPoint {
    static func main() {
        HandMouseAutomation.main()
    }
}

struct HandMouseAutomation: App {
    var body: some Scene {
        WindowGroup {
            CameraView()
                .frame(width: 400, height: 300)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}
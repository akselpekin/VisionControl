import AppKit
import Foundation

public class GestureController {
    private var lastGestureTime: Date = Date()
    private let gestureDelay: TimeInterval = 2.0
    
    public init() {}
    
    public func executeGesture(_ gesture: HandGesture) {
        let now = Date()
        if now.timeIntervalSince(lastGestureTime) < gestureDelay {
            return
        }
        
        lastGestureTime = now
        
        switch gesture {
        case .oneFinger:
            openSafari()
        case .twoFingers:
            openSpotlight()
        case .threeFingers:
            openTerminal()
        }
    }
    
    private func openSafari() {
        NSWorkspace.shared.open(URL(string: "https://www.apple.com")!)
        print("🌐 Opening Safari")
    }
    
    private func openSpotlight() {
        let event1 = CGEvent(keyboardEventSource: nil, virtualKey: 0x31, keyDown: true) // Space
        let event2 = CGEvent(keyboardEventSource: nil, virtualKey: 0x31, keyDown: false)
        
        event1?.flags = .maskCommand
        event2?.flags = .maskCommand
        
        event1?.post(tap: .cghidEventTap)
        event2?.post(tap: .cghidEventTap)
        print("🔍 Opening Spotlight")
    }
    
    private func openTerminal() {
        if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            NSWorkspace.shared.openApplication(at: terminalURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        }
        print("💻 Opening Terminal")
    }
}

public enum HandGesture {
    case oneFinger
    case twoFingers
    case threeFingers
}

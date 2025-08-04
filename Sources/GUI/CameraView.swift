import SwiftUI
import AVFoundation
import LOGIC

public struct CameraView: NSViewRepresentable {
    private let cameraHandler = CameraHandler()

    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        cameraHandler.setupPreview(in: view)
        
        let gestureGuide = createGestureGuide()
        view.addSubview(gestureGuide)
        
        return view
    }
    
    private func createGestureGuide() -> NSView {
        let guideView = NSView(frame: NSRect(x: 10, y: 10, width: 180, height: 100))
        guideView.wantsLayer = true
        guideView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        guideView.layer?.cornerRadius = 8
        
        let textField = NSTextField(frame: NSRect(x: 10, y: 10, width: 160, height: 80))
        textField.isEditable = false
        textField.isBordered = false
        textField.backgroundColor = NSColor.clear
        textField.textColor = NSColor.white
        textField.font = NSFont.systemFont(ofSize: 12)
        textField.stringValue = """
        Gesture Controls:
        
        1️⃣ One Finger → Safari
        2️⃣ Two Fingers → Spotlight
        3️⃣ Three Fingers → Terminal
        """
        
        guideView.addSubview(textField)
        return guideView
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}
}
import SwiftUI
import AVFoundation
import LOGIC

public struct CameraView: NSViewRepresentable {
    private let cameraHandler = CameraHandler()

    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        cameraHandler.setupPreview(in: view)
        
        let anchorView = NSView(frame: NSRect(x: 195, y: 145, width: 10, height: 10))
        anchorView.wantsLayer = true
        anchorView.layer?.backgroundColor = NSColor.red.cgColor
        anchorView.layer?.cornerRadius = 5
        view.addSubview(anchorView)

        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}
}
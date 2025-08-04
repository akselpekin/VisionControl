import SwiftUI
import AVFoundation
import LOGIC

// MARK: - Camera View GUI
public struct CameraView: NSViewRepresentable {
    private let cameraConnector = CameraConnector.shared
    
    public init() {}
    
    public func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.cgColor
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupCameraPreview(in: containerView)
        }
        
        return containerView
    }
    
    public func updateNSView(_ nsView: NSView, context: Context) {
        if let previewLayer = nsView.layer?.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = nsView.bounds
            }
        }
    }
    
    private func setupCameraPreview(in view: NSView) {
        view.wantsLayer = true
        let previewLayer = cameraConnector.getPreviewLayer()
        
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.transform = CATransform3DMakeScale(-1, 1, 1)
            view.layer?.addSublayer(previewLayer)
            print("Camera preview layer added with frame: \(view.bounds)")
        }
        
        cameraConnector.startCapture()
        print("Camera view initialized with mirrored preview")
    }
}

#if DEBUG
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
            .frame(width: 400, height: 300)
    }
}
#endif

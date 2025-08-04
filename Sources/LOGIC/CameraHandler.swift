import AVFoundation
import AppKit

public class CameraHandler: NSObject, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()

    public override init() {
        super.init()
        setupCamera()
    }

    private func setupCamera() {
        session.sessionPreset = .medium
        
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        
        let builtInDevices = discoverySession.devices.filter { device in
            return !device.localizedName.lowercased().contains("external") &&
                   !device.localizedName.lowercased().contains("continuity")
        }
        
        guard let device = builtInDevices.first ?? discoverySession.devices.first,
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraQueue"))
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
    }

    public func setupPreview(in view: NSView) {
        let captureSession = session
        DispatchQueue.main.async {
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            
            previewLayer.transform = CATransform3DMakeScale(-1, 1, 1)
            
            view.wantsLayer = true
            view.layer?.addSublayer(previewLayer)
        }
        session.startRunning()
    }
}

extension CameraHandler: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        VisionDetector.shared.processFrame(sampleBuffer)
    }
}
import AVFoundation
import CoreMedia

// MARK: - Camera Connector
public class CameraConnector: NSObject, @unchecked Sendable {
    public static let shared = CameraConnector()
    
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    
    private override init() {
        super.init()
        setupCameraSession()
    }
    
    public func startCapture() {
        session.startRunning()
        print("Camera capture started")
    }
    
    public func stopCapture() {
        session.stopRunning()
        print("Camera capture stopped")
    }
    
    public func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        return AVCaptureVideoPreviewLayer(session: session)
    }
    
    private func setupCameraSession() {
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
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("Failed to setup camera device")
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
            print("Camera input added: \(device.localizedName)")
        }
        
        setupVideoOutput()
    }
    
    private func setupVideoOutput() {
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraFrameQueue"))
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        if session.canAddOutput(output) {
            session.addOutput(output)
            print("Video output configured for frame analysis")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraConnector: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        VisionFoundation.shared.analyzeFrame(sampleBuffer)
    }
}

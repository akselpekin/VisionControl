import AVFoundation
import CoreMedia

// MARK: - Camera Connector
public class CameraConnector: NSObject, @unchecked Sendable {
    public static let shared = CameraConnector()
    
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    
    private var frameCounter = 0
    private let frameSkipInterval = 2 // Process every 2nd frame
    private let targetFPS = 15
    
    private override init() {
        super.init()
        setupCameraSession()
    }
    
    public var isRunning: Bool {
        return session.isRunning
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
        session.sessionPreset = .low
        
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .continuityCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        
        let preferredDevices = discoverySession.devices.filter { device in
            return !device.localizedName.lowercased().contains("external")
        }
        
        guard let device = preferredDevices.first ?? discoverySession.devices.first,
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("Failed to setup camera device")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            let frameRateRange = device.activeFormat.videoSupportedFrameRateRanges.first
            if let range = frameRateRange, range.maxFrameRate >= Double(targetFPS) {
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
            }
            
            device.unlockForConfiguration()
            print("Camera configured for energy efficiency: \(targetFPS) FPS")
        } catch {
            print("Could not configure camera device for energy efficiency: \(error)")
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
            print("Camera input added: \(device.localizedName)")
        }
        
        setupVideoOutput()
    }
    
    private func setupVideoOutput() {
        let frameQueue = DispatchQueue(label: "cameraFrameQueue", qos: .utility)
        output.setSampleBufferDelegate(self, queue: frameQueue)
        
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        output.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(output) {
            session.addOutput(output)
            print("Video output configured for energy-efficient frame analysis")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraConnector: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCounter += 1
        guard frameCounter % frameSkipInterval == 0 else { return }
        
        VisionFoundation.shared.analyzeFrame(sampleBuffer)
    }
}

import Vision
import CoreMedia
import AppKit

class VisionDetector: @unchecked Sendable {
    static let shared = VisionDetector()
    private let mouseController = MouseController()
    private let request = VNDetectHumanHandPoseRequest()

    init() {
        request.maximumHandCount = 1
    }

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])

        guard let results = request.results, let observation = results.first else { return }

        let thumbTip = try? observation.recognizedPoint(.thumbTip)
        let indexTip = try? observation.recognizedPoint(.indexTip)
        
        guard let thumb = thumbTip, let index = indexTip else { return }

        let thumbLocation = thumb.location
        let indexLocation = index.location

        DispatchQueue.main.async {
            self.handleGesture(thumbLocation: thumbLocation, indexLocation: indexLocation)
        }
    }

    private func handleGesture(thumbLocation: CGPoint, indexLocation: CGPoint) {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1440, height: 900)

        let displacement = CGPoint(
            x: (indexLocation.x - 0.5) * screenSize.width,
            y: (0.5 - indexLocation.y) * screenSize.height
        )

        mouseController.moveMouse(by: displacement)

        let distance = hypot(thumbLocation.x - indexLocation.x, thumbLocation.y - indexLocation.y)
        if distance < 0.05 {
            mouseController.clickMouse()
        }
    }
}
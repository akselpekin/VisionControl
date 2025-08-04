import Vision
import CoreMedia
import AppKit

class VisionDetector: @unchecked Sendable {
    static let shared = VisionDetector()
    private let gestureController = GestureController()
    private let request = VNDetectHumanHandPoseRequest()

    init() {
        request.maximumHandCount = 1
    }

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])

        guard let results = request.results, let observation = results.first else { return }

        guard let thumbTip = try? observation.recognizedPoint(.thumbTip),
              let thumbIP = try? observation.recognizedPoint(.thumbIP),
              let indexTip = try? observation.recognizedPoint(.indexTip),
              let indexPIP = try? observation.recognizedPoint(.indexPIP),
              let middleTip = try? observation.recognizedPoint(.middleTip),
              let middlePIP = try? observation.recognizedPoint(.middlePIP),
              let ringTip = try? observation.recognizedPoint(.ringTip),
              let ringPIP = try? observation.recognizedPoint(.ringPIP),
              let littleTip = try? observation.recognizedPoint(.littleTip),
              let littlePIP = try? observation.recognizedPoint(.littlePIP) else { return }

        let points = [thumbTip, thumbIP, indexTip, indexPIP, middleTip, middlePIP, ringTip, ringPIP, littleTip, littlePIP]
        guard points.allSatisfy({ $0.confidence > 0.3 }) else { return }

        let fingerData = FingerData(
            thumbTip: thumbTip.location, thumbIP: thumbIP.location,
            indexTip: indexTip.location, indexPIP: indexPIP.location,
            middleTip: middleTip.location, middlePIP: middlePIP.location,
            ringTip: ringTip.location, ringPIP: ringPIP.location,
            littleTip: littleTip.location, littlePIP: littlePIP.location
        )

        DispatchQueue.main.async {
            let gesture = self.recognizeGesture(from: fingerData)
            if let gesture = gesture {
                self.gestureController.executeGesture(gesture)
            }
        }
    }

    private func recognizeGesture(from data: FingerData) -> HandGesture? {
        let thumbExtended = data.thumbTip.y > data.thumbIP.y
        let indexExtended = data.indexTip.y > data.indexPIP.y
        let middleExtended = data.middleTip.y > data.middlePIP.y
        let ringExtended = data.ringTip.y > data.ringPIP.y
        let littleExtended = data.littleTip.y > data.littlePIP.y
        
        let extendedFingers = [thumbExtended, indexExtended, middleExtended, ringExtended, littleExtended]
        let numberOfExtendedFingers = extendedFingers.filter { $0 }.count
        
        switch numberOfExtendedFingers {
        case 1:
            return .oneFinger
        case 2:
            return .twoFingers
        case 3:
            return .threeFingers
        default:
            return nil
        }
    }
}

private struct FingerData {
    let thumbTip: CGPoint
    let thumbIP: CGPoint
    let indexTip: CGPoint
    let indexPIP: CGPoint
    let middleTip: CGPoint
    let middlePIP: CGPoint
    let ringTip: CGPoint
    let ringPIP: CGPoint
    let littleTip: CGPoint
    let littlePIP: CGPoint
}
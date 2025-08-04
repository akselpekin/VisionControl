import Vision
import CoreMedia
import Foundation

// MARK: - Vision Foundation
public class VisionFoundation: @unchecked Sendable {
    public static let shared = VisionFoundation()
    
    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    private var gestureHistory: [GestureFrame] = []
    
    private let maxHistorySize = 8
    private let gestureTimeWindow: TimeInterval = 5.0
    
    private let confidenceThreshold: Float = 0.7
    private let stabilityFrameCount = 3
    
   
    private var framesSinceLastDetection = 0
    private let maxFramesWithoutDetection = 10
    
    public var enableAdvancedPatterns = false
    
    private var observers: [VisionFoundationObserver] = []
    
    private init() {
        setupVisionRequest()
        print("VisionFoundation initialized - gesture aggregator ready")
    }
    
    public func analyzeFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        
        do {
            try handler.perform([handPoseRequest])
            processVisionResults()
        } catch {
          //Silent failure to avoid overhead
        }
    }
    
    public func addObserver(_ observer: VisionFoundationObserver) {
        observers.append(observer)
    }
    
    public func removeObserver(_ observer: VisionFoundationObserver) {
        observers.removeAll { $0.id == observer.id }
    }
    
    public func addObserver(_ observer: VisionFoundationObserver) {
        observers.append(observer)
    }
    
    public func removeObserver(_ observer: VisionFoundationObserver) {
        observers.removeAll { $0.id == observer.id }
    }
    
    private func setupVisionRequest() {
        handPoseRequest.maximumHandCount = 2
    }
    
    private func processVisionResults() {
        guard let results = handPoseRequest.results else { return }
        
        if results.isEmpty {
            framesSinceLastDetection += 1
            if framesSinceLastDetection > maxFramesWithoutDetection {
                return
            }
        } else {
            framesSinceLastDetection = 0
        }
        
        let gestureFrame = analyzeHandPoses(results)
        updateGestureHistory(with: gestureFrame)
        
        if !gestureFrame.hands.isEmpty {
            let newGestures = detectAllGestures()
            processNewGestures(newGestures)
        }
    }
    
    private func analyzeHandPoses(_ results: [VNHumanHandPoseObservation]) -> GestureFrame {
        var hands: [HandAnalysis] = []
        
        for observation in results {
            if let handAnalysis = extractHandAnalysis(from: observation) {
                hands.append(handAnalysis)
            }
        }
        
        return GestureFrame(timestamp: Date(), hands: hands)
    }
    
    private func extractHandAnalysis(from observation: VNHumanHandPoseObservation) -> HandAnalysis? {
        
        do {
            let landmarks = try extractAllLandmarks(from: observation)
            let palmCenter = calculatePalmCenter(from: landmarks)
            let fingerStates = analyzeFingerStates(from: landmarks)
            
            let handOrientation = calculateHandOrientation(from: landmarks)
            let gestureMetrics = GestureMetrics()
            
            if enableAdvancedPatterns {
                return HandAnalysis(
                    landmarks: landmarks,
                    palmCenter: palmCenter,
                    fingerStates: fingerStates,
                    orientation: handOrientation,
                    confidence: observation.confidence,
                    metrics: gestureMetrics
                )
            } else {
                return HandAnalysis(
                    palmCenter: palmCenter,
                    fingerStates: fingerStates,
                    orientation: handOrientation,
                    confidence: observation.confidence,
                    metrics: gestureMetrics
                )
            }
        } catch {
            return nil
        }
    }
    
    private func extractAllLandmarks(from observation: VNHumanHandPoseObservation) throws -> [CGPoint] {
        var landmarks: [CGPoint] = []
        
        let landmarkKeys: [VNHumanHandPoseObservation.JointName] = [
            .wrist,
            .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip
        ]
        
        for jointName in landmarkKeys {
            let point = try observation.recognizedPoint(jointName)
            landmarks.append(CGPoint(x: point.location.x, y: point.location.y))
        }
        
        return landmarks
    }
    
    private func calculatePalmCenter(from landmarks: [CGPoint]) -> CGPoint {
        guard landmarks.count >= 21 else { return CGPoint.zero }
        
        let wrist = landmarks[0]
        let indexMCP = landmarks[5]
        let middleMCP = landmarks[9]
        let ringMCP = landmarks[13]
        let littleMCP = landmarks[17]
        
        let centerX = (wrist.x + indexMCP.x + middleMCP.x + ringMCP.x + littleMCP.x) / 5.0
        let centerY = (wrist.y + indexMCP.y + middleMCP.y + ringMCP.y + littleMCP.y) / 5.0
        
        return CGPoint(x: centerX, y: centerY)
    }
    
    private func analyzeFingerStates(from landmarks: [CGPoint]) -> FingerStates {
        guard landmarks.count >= 21 else { return FingerStates() }
        
        let thumb = isFingerExtended(landmarks, fingerIndex: 0, tipIndex: 4, pipIndex: 3)
        let index = isFingerExtended(landmarks, fingerIndex: 1, tipIndex: 8, pipIndex: 6)
        let middle = isFingerExtended(landmarks, fingerIndex: 2, tipIndex: 12, pipIndex: 10)
        let ring = isFingerExtended(landmarks, fingerIndex: 3, tipIndex: 16, pipIndex: 14)
        let little = isFingerExtended(landmarks, fingerIndex: 4, tipIndex: 20, pipIndex: 18)
        
        return FingerStates(
            thumb: thumb,
            index: index,
            middle: middle,
            ring: ring,
            little: little
        )
    }
    
    private func isFingerExtended(_ landmarks: [CGPoint], fingerIndex: Int, tipIndex: Int, pipIndex: Int) -> Bool {
        let tip = landmarks[tipIndex]
        let pip = landmarks[pipIndex]
        
        if fingerIndex == 0 {
            return abs(tip.x - pip.x) > 0.02
        } else {
            return tip.y > pip.y + 0.02
        }
    }
    
    private func calculateHandOrientation(from landmarks: [CGPoint]) -> Double {
        guard landmarks.count >= 21 else { return 0.0 }
        
        let wrist = landmarks[0]
        let middleMCP = landmarks[9]
        
        let deltaX = middleMCP.x - wrist.x
        let deltaY = middleMCP.y - wrist.y
        
        return atan2(deltaY, deltaX)
    }
    
    private func calculateGestureMetrics(from landmarks: [CGPoint]) -> GestureMetrics {
        guard landmarks.count >= 21 else { return GestureMetrics() }
        
        let handSpan = calculateHandSpan(landmarks)
        let fingerSpread = calculateFingerSpread(landmarks)
        let curvature = calculateFingerCurvature(landmarks)
        
        return GestureMetrics(
            handSpan: handSpan,
            fingerSpread: fingerSpread,
            curvature: curvature
        )
    }
    
    private func calculateHandSpan(_ landmarks: [CGPoint]) -> Double {
        let thumbTip = landmarks[4]
        let littleTip = landmarks[20]
        
        let deltaX = thumbTip.x - littleTip.x
        let deltaY = thumbTip.y - littleTip.y
        
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
    
    private func calculateFingerSpread(_ landmarks: [CGPoint]) -> Double {
        let indexTip = landmarks[8]
        let middleTip = landmarks[12]
        let ringTip = landmarks[16]
        
        let spread1 = distance(indexTip, middleTip)
        let spread2 = distance(middleTip, ringTip)
        
        return (spread1 + spread2) / 2.0
    }
    
    private func calculateFingerCurvature(_ landmarks: [CGPoint]) -> Double {
        let indexMCP = landmarks[5]
        let indexPIP = landmarks[6]
        let indexTip = landmarks[8]
        
        let angle1 = angle(indexMCP, indexPIP, indexTip)
        return abs(angle1 - .pi)
    }
    
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> Double {
        let deltaX = p1.x - p2.x
        let deltaY = p1.y - p2.y
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
    
    private func angle(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> Double {
        let v1 = CGPoint(x: p1.x - p2.x, y: p1.y - p2.y)
        let v2 = CGPoint(x: p3.x - p2.x, y: p3.y - p2.y)
        
        let dot = v1.x * v2.x + v1.y * v2.y
        let mag1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let mag2 = sqrt(v2.x * v2.x + v2.y * v2.y)
        
        guard mag1 > 0 && mag2 > 0 else { return 0 }
        
        return acos(max(-1, min(1, dot / (mag1 * mag2))))
    }
    
    // MARK: - Comprehensive Gesture Detection
    private func detectAllGestures() -> [ComprehensiveGesture] {
        var newGestures: [ComprehensiveGesture] = []
        
        if let gesture = detectStaticGestures() { 
            newGestures.append(gesture)
            return newGestures
        }
        
        if gestureHistory.count >= 5 {
            if let gesture = detectDynamicGestures() { 
                newGestures.append(gesture) 
                return newGestures
            }
        }
        
        if let latestFrame = gestureHistory.last, latestFrame.hands.count == 2 {
            if let gesture = detectTwoHandGestures() { newGestures.append(gesture) }
        }
        
        if gestureHistory.count >= 6 {
            if let gesture = detectSequentialGestures() { newGestures.append(gesture) }
        }
        
        // Advanced patterns only if enabled (CPU intensive)
        if enableAdvancedPatterns {
            newGestures.append(contentsOf: detectAdvancedPatterns())
        }
        
        return newGestures
    }
    
    private func detectStaticGestures() -> ComprehensiveGesture? {
        guard let latestFrame = gestureHistory.last,
              let hand = latestFrame.hands.first,
              isGestureStable() else { return nil }
        
        let fingerStates = hand.fingerStates
        
        if fingerStates.extendedCount == 0 {
            return ComprehensiveGesture(type: .fist, confidence: hand.confidence, timestamp: Date(), handData: hand)
        }
        
        if fingerStates.extendedCount == 5 {
            return ComprehensiveGesture(type: .openHand, confidence: hand.confidence, timestamp: Date(), handData: hand)
        }
        
        if fingerStates.index && fingerStates.middle && !fingerStates.ring && !fingerStates.little {
            return ComprehensiveGesture(type: .peaceSign, confidence: hand.confidence, timestamp: Date(), handData: hand)
        }
        
        if fingerStates.index && !fingerStates.middle && !fingerStates.ring && !fingerStates.little {
            return ComprehensiveGesture(type: .pointingFinger, confidence: hand.confidence, timestamp: Date(), handData: hand)
        }
        
        if fingerStates.thumb && !fingerStates.index && !fingerStates.middle && !fingerStates.ring && !fingerStates.little {
            return ComprehensiveGesture(type: .thumbsUp, confidence: hand.confidence, timestamp: Date(), handData: hand)
        }
        
        if fingerStates.index && fingerStates.middle && fingerStates.ring && !fingerStates.little {
            return ComprehensiveGesture(type: .threeFingers, confidence: hand.confidence, timestamp: Date(), handData: hand)
        }
        
        return nil
    }
    
    private func detectDynamicGestures() -> ComprehensiveGesture? {
        guard gestureHistory.count >= 4 else { return nil }
        
        let recentFrames = Array(gestureHistory.suffix(4))
        
        if let swipe = detectSwipeGesture(in: recentFrames) {
            return swipe
        }
        
        if let wave = detectWaveGesture(in: recentFrames) {
            return wave
        }
        
        return nil
    }
    
    private func detectSwipeGesture(in frames: [GestureFrame]) -> ComprehensiveGesture? {
        guard let firstHand = frames.first?.hands.first,
              let lastHand = frames.last?.hands.first else { return nil }
        
        let deltaX = lastHand.palmCenter.x - firstHand.palmCenter.x
        let deltaY = lastHand.palmCenter.y - firstHand.palmCenter.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        if distance > 0.15 {
            let direction = atan2(deltaY, deltaX)
            let gestureType: GestureType
            
            if abs(direction) < .pi/4 {
                gestureType = .swipeRight
            } else if abs(direction - .pi) < .pi/4 {
                gestureType = .swipeLeft
            } else if direction > .pi/4 && direction < 3 * .pi/4 {
                gestureType = .swipeUp
            } else {
                gestureType = .swipeDown
            }
            
            return ComprehensiveGesture(type: gestureType, confidence: lastHand.confidence, timestamp: Date(), handData: lastHand)
        }
        
        return nil
    }
    
    private func detectWaveGesture(in frames: [GestureFrame]) -> ComprehensiveGesture? {
        let palmPositions = frames.compactMap { $0.hands.first?.palmCenter.x }
        guard palmPositions.count >= 4 else { return nil }
        
        var oscillations = 0
        for i in 1..<palmPositions.count-1 {
            let prev = palmPositions[i-1]
            let curr = palmPositions[i]
            let next = palmPositions[i+1]
            
            if (curr > prev && curr > next) || (curr < prev && curr < next) {
                oscillations += 1
            }
        }
        
        if oscillations >= 1 {
            if let lastHand = frames.last?.hands.first {
                return ComprehensiveGesture(type: .wave, confidence: lastHand.confidence, timestamp: Date(), handData: lastHand)
            }
        }
        
        return nil
    }
    
    private func detectTwoHandGestures() -> ComprehensiveGesture? {
        guard let latestFrame = gestureHistory.last,
              latestFrame.hands.count == 2 else { return nil }
        
        let leftHand = latestFrame.hands[0]
        let rightHand = latestFrame.hands[1]
        
        let distance = self.distance(leftHand.palmCenter, rightHand.palmCenter)
        if distance < 0.1 && leftHand.fingerStates.extendedCount == 5 && rightHand.fingerStates.extendedCount == 5 {
            return ComprehensiveGesture(type: .twoHandClap, confidence: min(leftHand.confidence, rightHand.confidence), timestamp: Date(), handData: leftHand)
        }
        
        return nil
    }
    
    private func detectSequentialGestures() -> ComprehensiveGesture? {
        guard gestureHistory.count >= 6 else { return nil }
        
        let recentFrames = Array(gestureHistory.suffix(6))
        let fingerCounts = recentFrames.compactMap { frame in
            frame.hands.first?.fingerStates.extendedCount
        }
        
        if fingerCounts.count >= 6 {
            let pattern = Array(fingerCounts.suffix(6))
            if pattern[0] == 2 && pattern[1] == 2 && pattern[2] == 0 && pattern[3] == 0 && pattern[4] == 2 && pattern[5] == 2 {
                if let lastHand = recentFrames.last?.hands.first {
                    return ComprehensiveGesture(type: .sequencePeaceFistPeace, confidence: lastHand.confidence, timestamp: Date(), handData: lastHand)
                }
            }
        }
        
        return nil
    }
    
    private func detectAdvancedPatterns() -> [ComprehensiveGesture] {
        var gestures: [ComprehensiveGesture] = []
        
        if let pinch = detectPinchGesture() {
            gestures.append(pinch)
        }
        
        if let okSign = detectOKSign() {
            gestures.append(okSign)
        }
        
        return gestures
    }
    
    private func detectPinchGesture() -> ComprehensiveGesture? {
        guard let latestFrame = gestureHistory.last,
              let hand = latestFrame.hands.first,
              let landmarks = hand.landmarks,
              landmarks.count >= 21 else { return nil }
        
        let thumbTip = landmarks[4]
        let indexTip = landmarks[8]
        let distance = self.distance(thumbTip, indexTip)
        
        if distance < 0.04 {
            return ComprehensiveGesture(type: .pinchGesture, confidence: hand.confidence, timestamp: Date(), handData: hand)
        }
        
        return nil
    }
    
    private func detectOKSign() -> ComprehensiveGesture? {
        guard let latestFrame = gestureHistory.last,
              let hand = latestFrame.hands.first,
              let landmarks = hand.landmarks, // Energy optimization: Check if landmarks exist
              landmarks.count >= 21 else { return nil }
        
        let thumbTip = landmarks[4]
        let indexTip = landmarks[8]
        let middleTip = landmarks[12]
        let middlePIP = landmarks[10]
        
        let thumbIndexDistance = self.distance(thumbTip, indexTip)
        let middleExtended = middleTip.y > middlePIP.y + 0.02
        
        if thumbIndexDistance < 0.03 && middleExtended {
            return ComprehensiveGesture(type: .okSign, confidence: hand.confidence, timestamp: Date(), handData: hand)
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    private func isGestureStable() -> Bool {
        guard gestureHistory.count >= stabilityFrameCount else { return false }
        
        let recentFrames = Array(gestureHistory.suffix(stabilityFrameCount))
        let fingerCounts = recentFrames.compactMap { frame in
            frame.hands.first?.fingerStates.extendedCount
        }
        
        let firstCount = fingerCounts.first ?? -1
        return fingerCounts.allSatisfy { $0 == firstCount }
    }
    
    private func updateGestureHistory(with frame: GestureFrame) {
        gestureHistory.append(frame)
        if gestureHistory.count > maxHistorySize {
            gestureHistory.removeFirst()
        }
    }
    
    private func processNewGestures(_ gestures: [ComprehensiveGesture]) {
        for gesture in gestures {
            detectedGestures.append(gesture)
            notifyObservers(gesture)
        }
        
        cleanOldGestures()
    }
    
    private func notifyObservers(_ gesture: ComprehensiveGesture) {
        for observer in observers {
            observer.onGestureDetected(gesture)
        }
    }
    
    private func cleanOldGestures() {
        let cutoffTime = Date().addingTimeInterval(-gestureTimeWindow)
        
        let oldCount = detectedGestures.count
        detectedGestures.removeAll { $0.timestamp < cutoffTime }
    
        if detectedGestures.count < oldCount / 2 {
            detectedGestures = Array(detectedGestures)
        }
    }
    
    // MARK: - Energy Management
    
    public func setEnergyMode(_ mode: EnergyMode) {
        switch mode {
        case .highPerformance:
            enableAdvancedPatterns = true
        case .balanced:
            enableAdvancedPatterns = false
        case .energySaver:
            enableAdvancedPatterns = false
            //More agressive measures could be implemented
        }
    }
}

// MARK: - Energy Mode
public enum EnergyMode {
    case highPerformance
    case balanced  
    case energySaver
}

// MARK: - Memory Optimized Structures
private struct CompactGestureRecord {
    let type: GestureType
    let confidence: Float
    let timestamp: Date
    
    init(from gesture: ComprehensiveGesture) {
        self.type = gesture.type
        self.confidence = gesture.confidence
        self.timestamp = gesture.timestamp
    }
    
}

// MARK: - Supporting Data Structures
public struct ComprehensiveGesture {
    public let type: GestureType
    public let confidence: Float
    public let timestamp: Date
    public let handData: HandAnalysis
    
    public init(type: GestureType, confidence: Float, timestamp: Date, handData: HandAnalysis) {
        self.type = type
        self.confidence = confidence
        self.timestamp = timestamp
        self.handData = handData
    }
}

public enum GestureType: CaseIterable {
    // Static single-hand gestures
    case fist
    case openHand
    case pointingFinger
    case thumbsUp
    case peaceSign
    case threeFingers
    case fourFingers
    case okSign
    
    // Dynamic gestures
    case swipeLeft
    case swipeRight
    case swipeUp
    case swipeDown
    case wave
    
    // Two-hand gestures
    case twoHandClap
    case twoHandHeart
    
    // Sequential gestures
    case sequencePeaceFistPeace
    
    // Advanced gestures
    case pinchGesture
    case grabGesture
    case releaseGesture
    
    public var displayName: String {
        switch self {
        case .fist: return "Fist"
        case .openHand: return "Open Hand"
        case .pointingFinger: return "Pointing Finger"
        case .thumbsUp: return "Thumbs Up"
        case .peaceSign: return "Peace Sign"
        case .threeFingers: return "Three Fingers"
        case .fourFingers: return "Four Fingers"
        case .okSign: return "OK Sign"
        case .swipeLeft: return "Swipe Left"
        case .swipeRight: return "Swipe Right"
        case .swipeUp: return "Swipe Up"
        case .swipeDown: return "Swipe Down"
        case .wave: return "Wave"
        case .twoHandClap: return "Two Hand Clap"
        case .twoHandHeart: return "Two Hand Heart"
        case .sequencePeaceFistPeace: return "Peace-Fist-Peace Sequence"
        case .pinchGesture: return "Pinch"
        case .grabGesture: return "Grab"
        case .releaseGesture: return "Release"
        }
    }
}

private struct GestureFrame {
    let timestamp: Date
    let hands: [HandAnalysis]
}

public struct HandAnalysis {
    public let landmarks: [CGPoint]?
    public let palmCenter: CGPoint
    public let fingerStates: FingerStates
    public let orientation: Double
    public let confidence: Float
    public let metrics: GestureMetrics
    
    public init(palmCenter: CGPoint, fingerStates: FingerStates, orientation: Double, confidence: Float, metrics: GestureMetrics = GestureMetrics()) {
        self.landmarks = nil
        self.palmCenter = palmCenter
        self.fingerStates = fingerStates
        self.orientation = orientation
        self.confidence = confidence
        self.metrics = metrics
    }

    public init(landmarks: [CGPoint], palmCenter: CGPoint, fingerStates: FingerStates, orientation: Double, confidence: Float, metrics: GestureMetrics) {
        self.landmarks = landmarks
        self.palmCenter = palmCenter
        self.fingerStates = fingerStates
        self.orientation = orientation
        self.confidence = confidence
        self.metrics = metrics
    }
}

public struct FingerStates {
    public let thumb: Bool
    public let index: Bool
    public let middle: Bool
    public let ring: Bool
    public let little: Bool
    
    public init(thumb: Bool = false, index: Bool = false, middle: Bool = false, ring: Bool = false, little: Bool = false) {
        self.thumb = thumb
        self.index = index
        self.middle = middle
        self.ring = ring
        self.little = little
    }
    
    public var extendedCount: Int {
        return [thumb, index, middle, ring, little].filter { $0 }.count
    }
}

public struct GestureMetrics {
    public let handSpan: Double
    public let fingerSpread: Double
    public let curvature: Double
    
    public init(handSpan: Double = 0.0, fingerSpread: Double = 0.0, curvature: Double = 0.0) {
        self.handSpan = handSpan
        self.fingerSpread = fingerSpread
        self.curvature = curvature
    }
}

// MARK: - Observer Protocol
public protocol VisionFoundationObserver {
    var id: UUID { get }
    func onGestureDetected(_ gesture: ComprehensiveGesture)
}

import Foundation
import SwiftUI
import AppKit //testing

// MARK: - Vision Bridge
public class VisionBridge: ObservableObject, VisionFoundationObserver, @unchecked Sendable {
    public let id = UUID()
    
    @Published public var activeGestures: Set<GestureType> = []
    @Published public var lastDetectedGesture: GestureType?
    @Published public var gestureCount: Int = 0
    @Published public var isDetecting: Bool = false
    
    private var collectedGestures: [ComprehensiveGesture] = []
    private var gestureEventHistory: [GestureEvent] = []
    private var gestureStatistics: GestureStatistics = GestureStatistics()
    
    private var gestureCallbacks: [GestureType: [() -> Void]] = [:]
    private var gestureConditions: [GestureType: (ComprehensiveGesture) -> Bool] = [:]
    
    private let maxCollectionSize: Int = 100
    private let gestureRetentionTime: TimeInterval = 30.0
    private let debounceInterval: TimeInterval = 0.5
    private var lastTriggerTimes: [GestureType: Date] = [:]
    
    public static let shared = VisionBridge()
    
    private init() {
        setupBridge()
    }
    
    public func startCollecting() {
        VisionFoundation.shared.addObserver(self)
        isDetecting = true
        print("VisionBridge started collecting gestures")
    }
    
    public func stopCollecting() {
        VisionFoundation.shared.removeObserver(self)
        isDetecting = false
        print("VisionBridge stopped collecting gestures")
    }
    
    public func onGestureDetected(_ gesture: ComprehensiveGesture) {
        collectGesture(gesture)
        processTriggers(for: gesture)
    }
    
    private func collectGesture(_ gesture: ComprehensiveGesture) {
        collectedGestures.append(gesture)
        activeGestures.insert(gesture.type)
        lastDetectedGesture = gesture.type
        gestureCount += 1
        
        let event = GestureEvent(
            id: UUID(),
            gestureType: gesture.type,
            timestamp: gesture.timestamp,
            confidence: gesture.confidence
        )
        gestureEventHistory.append(event)
        
        updateStatistics(for: gesture)
        cleanOldData()
        
        print("Bridge collected: \(gesture.type.displayName) (confidence: \(String(format: "%.2f", gesture.confidence)))")
    }
    
    private func updateStatistics(for gesture: ComprehensiveGesture) {
        gestureStatistics.totalGesturesDetected += 1
        gestureStatistics.gestureTypeCounts[gesture.type, default: 0] += 1
        gestureStatistics.averageConfidence = calculateAverageConfidence()
        gestureStatistics.lastGestureTime = gesture.timestamp
        gestureStatistics.confidenceSum += gesture.confidence
    }
    
    private func calculateAverageConfidence() -> Float {
        guard !collectedGestures.isEmpty else { return 0.0 }
        return gestureStatistics.confidenceSum / Float(gestureStatistics.totalGesturesDetected)
    }
    
    public func onGesture(_ gestureType: GestureType, perform action: @escaping () -> Void) {
        if gestureCallbacks[gestureType] != nil {
            gestureCallbacks[gestureType]?.append(action)
        } else {
            gestureCallbacks[gestureType] = [action]
        }
        print("Trigger registered for \(gestureType.displayName)")
    }
    
    public func onGesture(_ gestureType: GestureType, withCondition condition: @escaping (ComprehensiveGesture) -> Bool, perform action: @escaping () -> Void) {
        gestureConditions[gestureType] = condition
        onGesture(gestureType, perform: action)
        print("Conditional trigger registered for \(gestureType.displayName)")
    }
    
    public func removeGestureTrigger(_ gestureType: GestureType) {
        gestureCallbacks[gestureType] = nil
        gestureConditions[gestureType] = nil
        print("Trigger removed for \(gestureType.displayName)")
    }
    
    public func removeAllTriggers() {
        gestureCallbacks.removeAll()
        gestureConditions.removeAll()
        lastTriggerTimes.removeAll()
        print("All triggers removed")
    }
    
    private func processTriggers(for gesture: ComprehensiveGesture) {
        guard let callbacks = gestureCallbacks[gesture.type] else { return }
        
        if let lastTrigger = lastTriggerTimes[gesture.type],
           Date().timeIntervalSince(lastTrigger) < debounceInterval {
            return
        }
        
        if let condition = gestureConditions[gesture.type],
           !condition(gesture) {
            return
        }
        
        for callback in callbacks {
            callback()
        }
        
        lastTriggerTimes[gesture.type] = Date()
        
        print("Triggered \(callbacks.count) action(s) for \(gesture.type.displayName)")
    }
    
    public func getGesturesByType(_ type: GestureType) -> [ComprehensiveGesture] {
        return collectedGestures.filter { $0.type == type }
    }
    
    public func getRecentGestures(timeWindow: TimeInterval = 5.0) -> [ComprehensiveGesture] {
        let cutoffTime = Date().addingTimeInterval(-timeWindow)
        return collectedGestures.filter { $0.timestamp >= cutoffTime }
    }
    
    public func getGestureHistory(limit: Int = 50) -> [GestureEvent] {
        return Array(gestureEventHistory.suffix(limit))
    }
    
    public func isGestureActive(_ type: GestureType) -> Bool {
        return activeGestures.contains(type)
    }
    
    public func getGestureConfidence(_ type: GestureType) -> Float? {
        return getGesturesByType(type).last?.confidence
    }
    
    public func getGestureStatistics() -> GestureStatistics {
        return gestureStatistics
    }
    
    public func getAllAvailableGestures() -> [GestureType] {
        return GestureType.allCases
    }
    
    public func hasDetectedGesture(_ type: GestureType, inLast timeWindow: TimeInterval = 1.0) -> Bool {
        let cutoffTime = Date().addingTimeInterval(-timeWindow)
        return collectedGestures.contains { $0.type == type && $0.timestamp >= cutoffTime }
    }
    
    public func getGestureFrequency(_ type: GestureType, inLast timeWindow: TimeInterval = 60.0) -> Int {
        let cutoffTime = Date().addingTimeInterval(-timeWindow)
        return collectedGestures.filter { $0.type == type && $0.timestamp >= cutoffTime }.count
    }
    
    public func getMostFrequentGesture() -> GestureType? {
        return gestureStatistics.gestureTypeCounts.max(by: { $0.value < $1.value })?.key
    }
    
    public func getAverageConfidenceForGesture(_ type: GestureType) -> Float {
        let gestures = getGesturesByType(type)
        guard !gestures.isEmpty else { return 0.0 }
        
        let totalConfidence = gestures.reduce(0) { $0 + $1.confidence }
        return totalConfidence / Float(gestures.count)
    }
    
    public func clearGestureHistory() {
        collectedGestures.removeAll()
        gestureEventHistory.removeAll()
        gestureStatistics = GestureStatistics()
        activeGestures.removeAll()
        gestureCount = 0
        lastDetectedGesture = nil
        print("Gesture history cleared")
    }
    
    public func exportGestureData() -> GestureExportData {
        return GestureExportData(
            gestures: collectedGestures,
            events: gestureEventHistory,
            statistics: gestureStatistics,
            exportDate: Date()
        )
    }
    
    public func setupCommonTriggers() {
        onGesture(.peaceSign) {
            print("Peace sign detected - Opening Safari")
            NSWorkspace.shared.open(URL(string: "https://www.apple.com")!)
        }
        
        onGesture(.pointingFinger) {
            print("Pointing finger detected - Opening Terminal")
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Utilities/Terminal.app"))
        }
        
        print("Common triggers setup complete")
    }
    
    private func setupBridge() {
        print("VisionBridge initialized - Ready to collect and expose gestures")
    }
    
    private func cleanOldData() {
        let cutoffTime = Date().addingTimeInterval(-gestureRetentionTime)
        
        collectedGestures.removeAll { $0.timestamp < cutoffTime }
        
        if gestureEventHistory.count > maxCollectionSize {
            gestureEventHistory = Array(gestureEventHistory.suffix(maxCollectionSize))
        }
        let recentGestureTypes = Set(getRecentGestures(timeWindow: 5.0).map { $0.type })
        activeGestures = recentGestureTypes
    }
}


public struct GestureEvent {
    public let id: UUID
    public let gestureType: GestureType
    public let timestamp: Date
    public let confidence: Float
    
    public init(id: UUID, gestureType: GestureType, timestamp: Date, confidence: Float) {
        self.id = id
        self.gestureType = gestureType
        self.timestamp = timestamp
        self.confidence = confidence
    }
}

public struct GestureStatistics {
    public var totalGesturesDetected: Int = 0
    public var gestureTypeCounts: [GestureType: Int] = [:]
    public var averageConfidence: Float = 0.0
    public var lastGestureTime: Date?
    public var confidenceSum: Float = 0.0
    
    public init() {}
    
    public var mostFrequentGesture: GestureType? {
        return gestureTypeCounts.max(by: { $0.value < $1.value })?.key
    }
    
    public var uniqueGestureTypes: Int {
        return gestureTypeCounts.count
    }
    
    public var detectionRate: Double {
        guard let lastTime = lastGestureTime else { return 0.0 }
        let timeSpan = Date().timeIntervalSince(lastTime)
        return timeSpan > 0 ? Double(totalGesturesDetected) / timeSpan : 0.0
    }
}

public struct GestureExportData {
    public let gestures: [ComprehensiveGesture]
    public let events: [GestureEvent]
    public let statistics: GestureStatistics
    public let exportDate: Date
    
    public init(gestures: [ComprehensiveGesture], events: [GestureEvent], statistics: GestureStatistics, exportDate: Date) {
        self.gestures = gestures
        self.events = events
        self.statistics = statistics
        self.exportDate = exportDate
    }
}

public extension VisionBridge {
    func onPeaceSign(perform action: @escaping () -> Void) {
        onGesture(.peaceSign, perform: action)
    }
    
    func onThreeFingers(perform action: @escaping () -> Void) {
        onGesture(.threeFingers, perform: action)
    }
    
    func onThumbsUp(perform action: @escaping () -> Void) {
        onGesture(.thumbsUp, perform: action)
    }
    
    func onSwipeLeft(perform action: @escaping () -> Void) {
        onGesture(.swipeLeft, perform: action)
    }
    
    func onSwipeRight(perform action: @escaping () -> Void) {
        onGesture(.swipeRight, perform: action)
    }
    
    func onFist(perform action: @escaping () -> Void) {
        onGesture(.fist, perform: action)
    }
    
    func onOpenHand(perform action: @escaping () -> Void) {
        onGesture(.openHand, perform: action)
    }
}

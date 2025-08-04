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
    
    private let maxCollectionSize: Int = 100
    private let gestureRetentionTime: TimeInterval = 30.0
    
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
    
    private func processTriggers(for gesture: ComprehensiveGesture) {
        let actionManager = GestureActionManager.shared
        actionManager.executeActionsForGesture(gesture)
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
    
    // MARK: - Dynamic Action System Integration
    public func addActionMapping(_ mapping: GestureActionMapping) {
        GestureActionManager.shared.addMapping(mapping)
    }
    
    public func removeActionMapping(withId id: UUID) {
        GestureActionManager.shared.removeMapping(withId: id)
    }
    
    public func getActionMappings(for gestureType: GestureType) -> [GestureActionMapping] {
        return GestureActionManager.shared.getMappings(for: gestureType)
    }
    
    public func getAllActionMappings() -> [GestureActionMapping] {
        return GestureActionManager.shared.getAllMappings()
    }
    
    public func clearAllActionMappings() {
        GestureActionManager.shared.clearAllMappings()
    }
    
    // MARK: - Action Configuration Helpers
    public func mapGestureToOpenApp(_ gestureType: GestureType, appName: String, bundleId: String, minimumConfidence: Float = 0.7) {
        let action = GestureActionManager.createOpenAppAction(name: "Open \(appName)", bundleId: bundleId, appName: appName)
        let mapping = GestureActionMapping(gestureType: gestureType, actionConfiguration: action, minimumConfidence: minimumConfidence)
        addActionMapping(mapping)
    }
    
    public func mapGestureToOpenURL(_ gestureType: GestureType, name: String, url: String, minimumConfidence: Float = 0.7) {
        let action = GestureActionManager.createOpenURLAction(name: name, url: url)
        let mapping = GestureActionMapping(gestureType: gestureType, actionConfiguration: action, minimumConfidence: minimumConfidence)
        addActionMapping(mapping)
    }
    
    public func mapGestureToShellCommand(_ gestureType: GestureType, name: String, command: String, captureOutput: Bool = false, minimumConfidence: Float = 0.7) {
        let action = GestureActionManager.createShellCommandAction(name: name, command: command, captureOutput: captureOutput)
        let mapping = GestureActionMapping(gestureType: gestureType, actionConfiguration: action, minimumConfidence: minimumConfidence)
        addActionMapping(mapping)
    }
    
    public func mapGestureToShortcut(_ gestureType: GestureType, name: String, shortcutName: String, minimumConfidence: Float = 0.7) {
        let action = GestureActionManager.createRunShortcutAction(name: name, shortcutName: shortcutName)
        let mapping = GestureActionMapping(gestureType: gestureType, actionConfiguration: action, minimumConfidence: minimumConfidence)
        addActionMapping(mapping)
    }
    
    public func setupCommonTriggers() {
        let _ = GestureActionManager.shared
        
        print("Dynamic action system initialized with default mappings")
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

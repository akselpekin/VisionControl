import Foundation
import AppKit

// MARK: - Action Types
public enum ActionType: String, CaseIterable {
    case openApp = "open_app"
    case openURL = "open_url"
    case shellCommand = "shell_command"
    case runShortcut = "run_shortcut"
    
    public var displayName: String {
        switch self {
        case .openApp: return "Open Application"
        case .openURL: return "Open URL"
        case .shellCommand: return "Shell Command"
        case .runShortcut: return "Run Shortcut"
        }
    }
}

// MARK: - Action Configuration
public struct ActionConfiguration {
    public let id: UUID
    public let name: String
    public let actionType: ActionType
    public let parameters: [String: String]
    public let isEnabled: Bool
    
    public init(name: String, actionType: ActionType, parameters: [String: String], isEnabled: Bool = true) {
        self.id = UUID()
        self.name = name
        self.actionType = actionType
        self.parameters = parameters
        self.isEnabled = isEnabled
    }
}

// MARK: - Gesture Action Mapping
public struct GestureActionMapping {
    public let id: UUID
    public let gestureType: GestureType
    public let actionConfiguration: ActionConfiguration
    public let minimumConfidence: Float
    public let isEnabled: Bool
    
    public init(gestureType: GestureType, actionConfiguration: ActionConfiguration, minimumConfidence: Float = 0.7, isEnabled: Bool = true) {
        self.id = UUID()
        self.gestureType = gestureType
        self.actionConfiguration = actionConfiguration
        self.minimumConfidence = minimumConfidence
        self.isEnabled = isEnabled
    }
}

// MARK: - Action Executor
public class ActionExecutor: @unchecked Sendable {
    public static let shared = ActionExecutor()
    
    private init() {}
    
    public func execute(_ configuration: ActionConfiguration) {
        guard configuration.isEnabled else {
            print("Action '\(configuration.name)' is disabled")
            return
        }
        
        switch configuration.actionType {
        case .openApp:
            executeOpenApp(configuration.parameters)
        case .openURL:
            executeOpenURL(configuration.parameters)
        case .shellCommand:
            executeShellCommand(configuration.parameters)
        case .runShortcut:
            executeRunShortcut(configuration.parameters)
        }
        
        print("Executed action: \(configuration.name) (\(configuration.actionType.displayName))")
    }
    
    private func executeOpenApp(_ parameters: [String: String]) {
        guard let bundleId = parameters["bundleId"] ?? parameters["appName"] else {
            print("Error: No bundle ID or app name provided for open app action")
            return
        }
        
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error = error {
                    print("Error opening application \(bundleId): \(error)")
                }
            }
        } else {
            let appName = parameters["appName"] ?? bundleId
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                    if let error = error {
                        print("Error opening application \(appName): \(error)")
                    }
                }
            } else {
                print("Could not find application: \(bundleId)")
            }
        }
    }
    
    private func executeOpenURL(_ parameters: [String: String]) {
        guard let urlString = parameters["url"],
              let url = URL(string: urlString) else {
            print("Error: Invalid or missing URL for open URL action")
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    
    private func executeShellCommand(_ parameters: [String: String]) {
        guard let command = parameters["command"] else {
            print("Error: No command provided for shell command action")
            return
        }
        
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]
        
        if let outputHandler = parameters["captureOutput"], outputHandler == "true" {
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    print("Shell command output: \(output)")
                }
            } catch {
                print("Error executing shell command: \(error)")
            }
        } else {
            do {
                try process.run()
            } catch {
                print("Error executing shell command: \(error)")
            }
        }
    }
    
    private func executeRunShortcut(_ parameters: [String: String]) {
        guard let shortcutName = parameters["shortcutName"] else {
            print("Error: No shortcut name provided for run shortcut action")
            return
        }
        
        let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shortcutName
        let urlString = "shortcuts://run-shortcut?name=\(encodedName)"
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            print("Error: Could not create shortcut URL for \(shortcutName)")
        }
    }
}

// MARK: - Action Manager
public class GestureActionManager: @unchecked Sendable {
    public static let shared = GestureActionManager()
    
    private var actionMappings: [GestureActionMapping] = []
    private var lastTriggerTimes: [GestureType: Date] = [:]
    private let debounceInterval: TimeInterval = 0.5
    
    private init() {
        setupDefaultMappings()
    }
    
    // MARK: - Mapping Management
    public func addMapping(_ mapping: GestureActionMapping) {
        actionMappings.append(mapping)
        print("Added action mapping: \(mapping.gestureType.displayName) -> \(mapping.actionConfiguration.name)")
    }
    
    public func removeMapping(withId id: UUID) {
        actionMappings.removeAll { $0.id == id }
        print("Removed action mapping with ID: \(id)")
    }
    
    public func updateMapping(_ mapping: GestureActionMapping) {
        if let index = actionMappings.firstIndex(where: { $0.id == mapping.id }) {
            actionMappings[index] = mapping
            print("Updated action mapping: \(mapping.gestureType.displayName) -> \(mapping.actionConfiguration.name)")
        }
    }
    
    public func getMappings(for gestureType: GestureType) -> [GestureActionMapping] {
        return actionMappings.filter { $0.gestureType == gestureType && $0.isEnabled }
    }
    
    public func getAllMappings() -> [GestureActionMapping] {
        return actionMappings
    }
    
    public func clearAllMappings() {
        actionMappings.removeAll()
        print("Cleared all action mappings")
    }
    
    // MARK: - Execution
    public func executeActionsForGesture(_ gesture: ComprehensiveGesture) {
        let mappings = getMappings(for: gesture.type)
        
        if let lastTrigger = lastTriggerTimes[gesture.type],
           Date().timeIntervalSince(lastTrigger) < debounceInterval {
            return
        }
        
        var actionsExecuted = 0
        
        for mapping in mappings {
            guard gesture.confidence >= mapping.minimumConfidence else {
                continue
            }
            
            ActionExecutor.shared.execute(mapping.actionConfiguration)
            actionsExecuted += 1
        }
        
        if actionsExecuted > 0 {
            lastTriggerTimes[gesture.type] = Date()
            print("Executed \(actionsExecuted) action(s) for \(gesture.type.displayName)")
        }
    }
    
    // MARK: - Default Mappings
    private func setupDefaultMappings() {
        let safariAction = ActionConfiguration(
            name: "Open Apple Website",
            actionType: .openURL,
            parameters: ["url": "https://www.apple.com"]
        )
        
        let terminalAction = ActionConfiguration(
            name: "Open Terminal",
            actionType: .openApp,
            parameters: ["bundleId": "com.apple.Terminal"]
        )
        
        let lsCommandAction = ActionConfiguration(
            name: "List Directory",
            actionType: .shellCommand,
            parameters: ["command": "ls -la", "captureOutput": "true"]
        )
        
        addMapping(GestureActionMapping(
            gestureType: .peaceSign,
            actionConfiguration: safariAction
        ))
        
        addMapping(GestureActionMapping(
            gestureType: .pointingFinger,
            actionConfiguration: terminalAction
        ))
        
        addMapping(GestureActionMapping(
            gestureType: .thumbsUp,
            actionConfiguration: lsCommandAction
        ))
        
        print("Default action mappings setup complete")
    }
    
    // MARK: - Predefined Action Creators
    public static func createOpenAppAction(name: String, bundleId: String, appName: String? = nil) -> ActionConfiguration {
        var parameters = ["bundleId": bundleId]
        if let appName = appName {
            parameters["appName"] = appName
        }
        
        return ActionConfiguration(
            name: name,
            actionType: .openApp,
            parameters: parameters
        )
    }
    
    public static func createOpenURLAction(name: String, url: String) -> ActionConfiguration {
        return ActionConfiguration(
            name: name,
            actionType: .openURL,
            parameters: ["url": url]
        )
    }
    
    public static func createShellCommandAction(name: String, command: String, captureOutput: Bool = false) -> ActionConfiguration {
        var parameters = ["command": command]
        if captureOutput {
            parameters["captureOutput"] = "true"
        }
        
        return ActionConfiguration(
            name: name,
            actionType: .shellCommand,
            parameters: parameters
        )
    }
    
    public static func createRunShortcutAction(name: String, shortcutName: String) -> ActionConfiguration {
        return ActionConfiguration(
            name: name,
            actionType: .runShortcut,
            parameters: ["shortcutName": shortcutName]
        )
    }
}

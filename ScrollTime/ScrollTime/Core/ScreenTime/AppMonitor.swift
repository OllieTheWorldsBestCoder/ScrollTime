//
//  AppMonitor.swift
//  ScrollTime
//
//  DeviceActivity monitoring integration. Sets up schedules to track
//  when target apps are opened/closed and reports usage events to
//  the scroll detection system.
//

import Foundation
import Combine

#if canImport(DeviceActivity)
import DeviceActivity
#endif

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

// MARK: - App Usage Event

/// Represents an app usage event detected by the monitor
struct AppUsageEvent: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let eventType: EventType
    let appToken: String?  // Opaque token identifier
    let categoryToken: String?  // Category if known
    let sessionDuration: TimeInterval?

    enum EventType: String, Codable {
        case appOpened
        case appClosed
        case thresholdReached
        case intervalStarted
        case intervalEnded
        case warningTriggered
    }

    init(
        eventType: EventType,
        appToken: String? = nil,
        categoryToken: String? = nil,
        sessionDuration: TimeInterval? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.eventType = eventType
        self.appToken = appToken
        self.categoryToken = categoryToken
        self.sessionDuration = sessionDuration
    }
}

// MARK: - Monitoring Configuration

/// Configuration for device activity monitoring
struct MonitoringConfiguration {
    /// How long after app open to trigger a threshold event (in minutes)
    var usageThresholdMinutes: Int = 5

    /// Warning before interval ends (in minutes)
    var warningBeforeEndMinutes: Int = 5

    /// Whether to monitor 24/7 or specific hours
    var alwaysOn: Bool = true

    /// Start hour for monitoring (0-23), used if alwaysOn is false
    var startHour: Int = 0

    /// Start minute for monitoring (0-59)
    var startMinute: Int = 0

    /// End hour for monitoring (0-23), used if alwaysOn is false
    var endHour: Int = 23

    /// End minute for monitoring (0-59)
    var endMinute: Int = 59

    /// Whether to repeat the schedule daily
    var repeatsDaily: Bool = true

    static let `default` = MonitoringConfiguration()
}

// MARK: - Device Activity Names

#if canImport(DeviceActivity)
/// Extension to define activity names used throughout the app
@available(iOS 15.0, *)
extension DeviceActivityName {
    /// Main daily monitoring schedule
    static let dailyMonitoring = DeviceActivityName("com.scrolltime.dailyMonitoring")

    /// Short-term session monitoring
    static let sessionMonitoring = DeviceActivityName("com.scrolltime.sessionMonitoring")

    /// Custom user-defined monitoring period
    static let customMonitoring = DeviceActivityName("com.scrolltime.customMonitoring")
}

/// Extension to define event names for threshold tracking
@available(iOS 15.0, *)
extension DeviceActivityEvent.Name {
    /// Event triggered when usage threshold is reached
    static let usageThreshold = DeviceActivityEvent.Name("com.scrolltime.usageThreshold")

    /// Event triggered for doom scroll detection
    static let doomScrollWarning = DeviceActivityEvent.Name("com.scrolltime.doomScrollWarning")
}
#endif

// MARK: - App Monitor

/// Manages DeviceActivity monitoring for target apps.
/// Tracks when monitored apps are opened/closed and reports events
/// to the scroll detection system.
@MainActor
final class AppMonitor: ObservableObject {

    // MARK: - Singleton

    static let shared = AppMonitor()

    // MARK: - Published Properties

    /// Whether monitoring is currently active
    @Published private(set) var isMonitoring: Bool = false

    /// Recent usage events (limited to last 100)
    @Published private(set) var recentEvents: [AppUsageEvent] = []

    /// Current monitoring configuration
    @Published var configuration: MonitoringConfiguration = .default

    /// Error message if monitoring setup failed
    @Published private(set) var monitoringError: String?

    /// Whether monitoring is available (device capability + authorization)
    @Published private(set) var isMonitoringAvailable: Bool = false

    // MARK: - Private Properties

    #if canImport(DeviceActivity)
    @available(iOS 15.0, *)
    private var deviceActivityCenter: DeviceActivityCenter {
        DeviceActivityCenter()
    }
    #endif

    private let maxRecentEvents = 100
    private var eventHandlers: [(AppUsageEvent) -> Void] = []

    // Dependencies
    private let screenTimeManager: ScreenTimeManager
    private let targetApps: TargetAppsManager

    // MARK: - Initialization

    private init(
        screenTimeManager: ScreenTimeManager = .shared,
        targetApps: TargetAppsManager = .shared
    ) {
        self.screenTimeManager = screenTimeManager
        self.targetApps = targetApps
        updateAvailability()
    }

    // MARK: - Public Methods

    /// Start monitoring device activity for target apps
    func startMonitoring() async throws {
        guard screenTimeManager.authorizationStatus == .approved else {
            monitoringError = "Screen Time authorization required to start monitoring."
            throw MonitoringError.notAuthorized
        }

        #if canImport(DeviceActivity)
        guard #available(iOS 15.0, *) else {
            throw MonitoringError.unsupportedOS
        }

        do {
            let schedule = createSchedule()
            let events = createEvents()

            try deviceActivityCenter.startMonitoring(
                .dailyMonitoring,
                during: schedule,
                events: events
            )

            isMonitoring = true
            monitoringError = nil

            recordEvent(AppUsageEvent(eventType: .intervalStarted))

        } catch {
            isMonitoring = false
            monitoringError = "Failed to start monitoring: \(error.localizedDescription)"
            throw MonitoringError.startFailed(error)
        }
        #else
        throw MonitoringError.frameworkUnavailable
        #endif
    }

    /// Stop all device activity monitoring
    func stopMonitoring() {
        #if canImport(DeviceActivity)
        guard #available(iOS 15.0, *) else { return }

        deviceActivityCenter.stopMonitoring([.dailyMonitoring, .sessionMonitoring, .customMonitoring])
        isMonitoring = false

        recordEvent(AppUsageEvent(eventType: .intervalEnded))
        #endif
    }

    /// Stop monitoring for a specific activity
    func stopMonitoring(activity: String) {
        #if canImport(DeviceActivity)
        guard #available(iOS 15.0, *) else { return }

        let activityName = DeviceActivityName(activity)
        deviceActivityCenter.stopMonitoring([activityName])
        #endif
    }

    /// Update the monitoring schedule with new configuration
    func updateMonitoringSchedule() async throws {
        guard isMonitoring else { return }

        // Stop and restart with new configuration
        stopMonitoring()
        try await startMonitoring()
    }

    /// Register a handler to be called when usage events occur
    func onUsageEvent(_ handler: @escaping (AppUsageEvent) -> Void) {
        eventHandlers.append(handler)
    }

    /// Called by the DeviceActivityMonitor extension when events occur.
    /// This should be called from the app extension via App Groups.
    func handleMonitorEvent(_ event: AppUsageEvent) {
        recordEvent(event)
    }

    /// Get currently monitored activities
    func getMonitoredActivities() -> [String] {
        #if canImport(DeviceActivity)
        guard #available(iOS 15.0, *) else { return [] }

        return deviceActivityCenter.activities.map { $0.rawValue }
        #else
        return []
        #endif
    }

    /// Clear all recorded events
    func clearEvents() {
        recentEvents.removeAll()
    }

    // MARK: - Demo Mode Support

    /// Simulate an app usage event (for demo mode testing)
    func simulateAppOpened(appName: String) {
        let event = AppUsageEvent(
            eventType: .appOpened,
            appToken: "demo_\(appName)"
        )
        recordEvent(event)
    }

    /// Simulate app closed event (for demo mode testing)
    func simulateAppClosed(appName: String, duration: TimeInterval) {
        let event = AppUsageEvent(
            eventType: .appClosed,
            appToken: "demo_\(appName)",
            sessionDuration: duration
        )
        recordEvent(event)
    }

    /// Simulate threshold reached event (for demo mode testing)
    func simulateThresholdReached(appName: String, duration: TimeInterval) {
        let event = AppUsageEvent(
            eventType: .thresholdReached,
            appToken: "demo_\(appName)",
            sessionDuration: duration
        )
        recordEvent(event)
    }

    // MARK: - Private Methods

    private func updateAvailability() {
        #if canImport(DeviceActivity)
        if #available(iOS 15.0, *) {
            isMonitoringAvailable = screenTimeManager.authorizationStatus == .approved
        } else {
            isMonitoringAvailable = false
        }
        #else
        isMonitoringAvailable = false
        #endif
    }

    #if canImport(DeviceActivity)
    @available(iOS 15.0, *)
    private func createSchedule() -> DeviceActivitySchedule {
        let intervalStart: DateComponents
        let intervalEnd: DateComponents

        if configuration.alwaysOn {
            // Monitor all day
            intervalStart = DateComponents(hour: 0, minute: 0, second: 0)
            intervalEnd = DateComponents(hour: 23, minute: 59, second: 59)
        } else {
            intervalStart = DateComponents(
                hour: configuration.startHour,
                minute: configuration.startMinute,
                second: 0
            )
            intervalEnd = DateComponents(
                hour: configuration.endHour,
                minute: configuration.endMinute,
                second: 59
            )
        }

        return DeviceActivitySchedule(
            intervalStart: intervalStart,
            intervalEnd: intervalEnd,
            repeats: configuration.repeatsDaily,
            warningTime: DateComponents(minute: configuration.warningBeforeEndMinutes)
        )
    }

    @available(iOS 15.0, *)
    private func createEvents() -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        // Get the current app selection
        let selection = targetApps.currentSelection

        // Create threshold event for app usage
        let thresholdComponents = DateComponents(minute: configuration.usageThresholdMinutes)

        // Event for application tokens
        if !selection.applicationTokens.isEmpty {
            let appEvent = DeviceActivityEvent(
                applications: selection.applicationTokens,
                threshold: thresholdComponents
            )
            events[.usageThreshold] = appEvent
        }

        // Event for category tokens
        if !selection.categoryTokens.isEmpty {
            let categoryEvent = DeviceActivityEvent(
                categories: selection.categoryTokens,
                threshold: thresholdComponents
            )
            events[.doomScrollWarning] = categoryEvent
        }

        return events
    }
    #endif

    private func recordEvent(_ event: AppUsageEvent) {
        // Add to recent events, maintaining max count
        recentEvents.insert(event, at: 0)
        if recentEvents.count > maxRecentEvents {
            recentEvents.removeLast()
        }

        // Notify handlers
        for handler in eventHandlers {
            handler(event)
        }

        // Persist to UserDefaults/App Groups for extension access
        persistRecentEvents()
    }

    private func persistRecentEvents() {
        // Store recent events in App Group for extension access
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.scrolltime.shared") else {
            return
        }

        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(recentEvents.prefix(20).map { EventData(from: $0) }) {
            sharedDefaults.set(encoded, forKey: "recentUsageEvents")
        }
    }

    /// Load events from App Groups (called on init or when extension updates)
    func loadPersistedEvents() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.scrolltime.shared"),
              let data = sharedDefaults.data(forKey: "recentUsageEvents") else {
            return
        }

        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([EventData].self, from: data) {
            // Merge with existing events, avoiding duplicates
            let newEvents = decoded.map { $0.toEvent() }
            let existingIds = Set(recentEvents.map { $0.id })

            for event in newEvents where !existingIds.contains(event.id) {
                recentEvents.append(event)
            }

            // Sort by timestamp and trim
            recentEvents.sort { $0.timestamp > $1.timestamp }
            if recentEvents.count > maxRecentEvents {
                recentEvents = Array(recentEvents.prefix(maxRecentEvents))
            }
        }
    }
}

// MARK: - Monitoring Errors

enum MonitoringError: LocalizedError {
    case notAuthorized
    case unsupportedOS
    case frameworkUnavailable
    case startFailed(Error)
    case noAppsSelected

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Screen Time authorization is required to monitor app usage."
        case .unsupportedOS:
            return "Device activity monitoring requires iOS 15 or later."
        case .frameworkUnavailable:
            return "DeviceActivity framework is not available."
        case .startFailed(let error):
            return "Failed to start monitoring: \(error.localizedDescription)"
        case .noAppsSelected:
            return "No apps selected for monitoring."
        }
    }
}

// MARK: - Event Data (for Codable persistence)

private struct EventData: Codable {
    let id: UUID
    let timestamp: Date
    let eventType: String
    let appToken: String?
    let categoryToken: String?
    let sessionDuration: TimeInterval?

    init(from event: AppUsageEvent) {
        self.id = event.id
        self.timestamp = event.timestamp
        self.eventType = event.eventType.rawValue
        self.appToken = event.appToken
        self.categoryToken = event.categoryToken
        self.sessionDuration = event.sessionDuration
    }

    func toEvent() -> AppUsageEvent {
        AppUsageEvent(
            eventType: AppUsageEvent.EventType(rawValue: eventType) ?? .appOpened,
            appToken: appToken,
            categoryToken: categoryToken,
            sessionDuration: sessionDuration
        )
    }
}

// MARK: - Extension for DeviceActivityMonitor

/// Data structure for communication between main app and DeviceActivityMonitor extension
/// via App Groups. The extension writes events here, and the main app reads them.
struct MonitorExtensionData: Codable {
    let lastEventType: String
    let lastEventTimestamp: Date
    let activityName: String
    let additionalData: [String: String]?

    static let sharedDefaultsKey = "monitorExtensionData"
    static let appGroupIdentifier = "group.com.scrolltime.shared"
}

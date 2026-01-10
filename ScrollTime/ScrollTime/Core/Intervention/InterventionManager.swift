//
//  InterventionManager.swift
//  ScrollTime
//
//  Created by ScrollTime Team
//
//  The central coordinator for all intervention logic. This manager:
//  - Subscribes to scroll detection events via Combine
//  - Decides when to trigger interventions based on user preferences
//  - Manages cooldown periods to avoid annoying users
//  - Coordinates with EscalationEngine for graduated responses
//  - Tracks intervention history for analytics and adaptation
//
//  Design Philosophy:
//  - Be helpful, not punishing
//  - Respect user autonomy
//  - Build trust through consistency and kindness
//

import Foundation
import Combine
import SwiftUI

// MARK: - Scroll Detection Event

/// Event published when doom scrolling is detected
struct ScrollDetectionEvent {
    let timestamp: Date
    let scrollCount: Int
    let duration: TimeInterval
    let appIdentifier: String?
    let confidence: Double // 0-1, how confident we are this is doom scrolling

    static func demo() -> ScrollDetectionEvent {
        ScrollDetectionEvent(
            timestamp: Date(),
            scrollCount: 50,
            duration: 120,
            appIdentifier: "com.demo.app",
            confidence: 0.8
        )
    }
}

// MARK: - Intervention Preferences

/// User preferences for intervention behavior
struct InterventionPreferences: Codable, Equatable {
    /// Overall intervention frequency: 0 = off, 1 = gentle, 2 = moderate, 3 = firm
    var frequencyLevel: Int

    /// Whether to use breathing exercises
    var enableBreathingExercises: Bool

    /// Preferred breathing pattern
    var preferredBreathingPattern: BreathingPattern

    /// Whether to show timed pauses
    var enableTimedPauses: Bool

    /// Whether to use friction dialogs
    var enableFrictionDialogs: Bool

    /// Preferred friction type
    var preferredFrictionType: FrictionType

    /// Whether to show compassionate messages
    var showCompassionateMessages: Bool

    /// Do Not Disturb hours (e.g., during work)
    var quietHoursStart: DateComponents?
    var quietHoursEnd: DateComponents?

    /// Apps that should never trigger interventions
    var excludedAppIdentifiers: Set<String>

    static var `default`: InterventionPreferences {
        InterventionPreferences(
            frequencyLevel: 2,
            enableBreathingExercises: true,
            preferredBreathingPattern: .boxBreathing,
            enableTimedPauses: true,
            enableFrictionDialogs: true,
            preferredFrictionType: .reflectionQuestion,
            showCompassionateMessages: true,
            quietHoursStart: nil,
            quietHoursEnd: nil,
            excludedAppIdentifiers: []
        )
    }

    /// Minimum seconds between interventions based on frequency level
    var minimumInterventionInterval: TimeInterval {
        switch frequencyLevel {
        case 0:
            return .infinity // Interventions disabled
        case 1:
            return 600 // 10 minutes - very gentle
        case 2:
            return 300 // 5 minutes - moderate
        case 3:
            return 180 // 3 minutes - firm
        default:
            return 300
        }
    }
}

// MARK: - Intervention Manager

/// Central coordinator for the intervention system
@MainActor
final class InterventionManager: ObservableObject {

    // MARK: - Published State

    /// Whether an intervention is currently being shown
    @Published private(set) var isShowingIntervention: Bool = false

    /// The current intervention configuration (if one is active)
    @Published private(set) var activeIntervention: InterventionConfiguration?

    /// History of recent interventions
    @Published private(set) var recentHistory: [InterventionRecord] = []

    /// User preferences for interventions
    @Published var preferences: InterventionPreferences {
        didSet {
            persistPreferences()
            updateEscalationConfiguration()
        }
    }

    // MARK: - Dependencies

    /// Escalation engine for graduated responses
    let escalationEngine: EscalationEngine

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let userDefaults: UserDefaults
    private var lastInterventionTime: Date?
    private var interventionStartTime: Date?

    /// Publisher for triggering interventions externally
    private let interventionTrigger = PassthroughSubject<InterventionConfiguration, Never>()

    /// Publisher for intervention results
    private let interventionResultPublisher = PassthroughSubject<(InterventionRecord), Never>()

    // Storage keys
    private enum StorageKey {
        static let preferences = "scrolltime.intervention.preferences"
        static let history = "scrolltime.intervention.history"
        static let lastIntervention = "scrolltime.intervention.lastTime"
    }

    // MARK: - Initialization

    convenience init() {
        self.init(escalationEngine: EscalationEngine(), userDefaults: .standard)
    }

    init(
        escalationEngine: EscalationEngine,
        userDefaults: UserDefaults
    ) {
        self.escalationEngine = escalationEngine
        self.userDefaults = userDefaults
        self.preferences = .default
        loadPersistedState()
        updateEscalationConfiguration()
    }

    // MARK: - Public Interface

    /// Subscribe to scroll detection events from the detection system
    func subscribeToDetectionEvents(_ publisher: AnyPublisher<ScrollDetectionEvent, Never>) {
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleScrollDetectionEvent(event)
            }
            .store(in: &cancellables)
    }

    /// Manually trigger an intervention (for testing or explicit user request)
    func triggerIntervention(type: InterventionType? = nil) {
        let interventionType = type ?? escalationEngine.getNextInterventionType()
        guard shouldAllowIntervention(type: interventionType) else { return }

        let configuration = InterventionConfiguration(
            type: interventionType,
            sessionScrollCount: 0,
            appContext: nil
        )

        presentIntervention(configuration)
    }

    /// Record the result when user completes or dismisses an intervention
    func recordResult(_ result: InterventionResult) {
        guard let config = activeIntervention else { return }

        let durationEngaged = interventionStartTime.map {
            Date().timeIntervalSince($0)
        } ?? 0

        let record = InterventionRecord(
            configuration: config,
            result: result,
            durationEngaged: durationEngaged
        )

        // Update history
        recentHistory.insert(record, at: 0)
        trimHistory()

        // Update escalation engine
        escalationEngine.recordInterventionResult(result, for: config.type)

        // Notify observers
        interventionResultPublisher.send(record)

        // Update state
        lastInterventionTime = Date()
        activeIntervention = nil
        isShowingIntervention = false
        interventionStartTime = nil

        persistState()
    }

    /// Dismiss the current intervention (convenience method that records as skipped)
    func dismissIntervention() {
        recordResult(.skipped)
    }

    /// User chose to take a break
    func userTookBreak() {
        recordResult(.tookBreak)
    }

    /// User completed the full intervention
    func userCompletedIntervention() {
        recordResult(.completed)
    }

    /// User acknowledged but chose to continue
    func userChoseToContinue() {
        recordResult(.continuedScrolling)
    }

    /// Check if we're currently in quiet hours
    func isInQuietHours() -> Bool {
        guard let start = preferences.quietHoursStart,
              let end = preferences.quietHoursEnd else {
            return false
        }

        let calendar = Calendar.current
        let now = Date()
        let currentComponents = calendar.dateComponents([.hour, .minute], from: now)

        guard let currentHour = currentComponents.hour,
              let currentMinute = currentComponents.minute,
              let startHour = start.hour,
              let startMinute = start.minute ?? Optional(0),
              let endHour = end.hour,
              let endMinute = end.minute ?? Optional(0) else {
            return false
        }

        let currentTime = currentHour * 60 + currentMinute
        let startTime = startHour * 60 + startMinute
        let endTime = endHour * 60 + endMinute

        if startTime <= endTime {
            // Normal range (e.g., 9am to 5pm)
            return currentTime >= startTime && currentTime < endTime
        } else {
            // Overnight range (e.g., 10pm to 6am)
            return currentTime >= startTime || currentTime < endTime
        }
    }

    /// Get statistics about intervention effectiveness
    func getStatistics() -> InterventionStatistics {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayRecords = recentHistory.filter {
            calendar.isDate($0.completedAt, inSameDayAs: today)
        }

        let positiveOutcomes = todayRecords.filter { $0.result.wasPositiveEngagement }.count
        let totalToday = todayRecords.count

        return InterventionStatistics(
            totalInterventionsToday: totalToday,
            positiveOutcomesToday: positiveOutcomes,
            currentEscalationLevel: escalationEngine.currentInterventionType,
            averageEngagementDuration: calculateAverageEngagement()
        )
    }

    /// Publisher for external systems to observe intervention results
    var resultPublisher: AnyPublisher<InterventionRecord, Never> {
        interventionResultPublisher.eraseToAnyPublisher()
    }

    // MARK: - Private Methods

    private func handleScrollDetectionEvent(_ event: ScrollDetectionEvent) {
        // Check if this app is excluded
        if let appId = event.appIdentifier,
           preferences.excludedAppIdentifiers.contains(appId) {
            return
        }

        // Ensure session is active in escalation engine
        if !escalationEngine.isSessionActive {
            escalationEngine.startSession()
        }

        // Determine intervention type based on escalation
        let interventionType = escalationEngine.getNextInterventionType()

        // Check all conditions
        guard shouldAllowIntervention(type: interventionType) else { return }

        // Check confidence threshold
        guard event.confidence >= confidenceThreshold(for: interventionType) else { return }

        // Create and present the intervention
        let configuration = InterventionConfiguration(
            type: interventionType,
            sessionScrollCount: event.scrollCount,
            appContext: event.appIdentifier
        )

        presentIntervention(configuration)
    }

    private func shouldAllowIntervention(type: InterventionType) -> Bool {
        // Check if interventions are enabled
        guard preferences.frequencyLevel > 0 else { return false }

        // Check if this type is enabled
        switch type {
        case .breathingExercise:
            guard preferences.enableBreathingExercises else { return false }
        case .timedPause:
            guard preferences.enableTimedPauses else { return false }
        case .frictionDialog:
            guard preferences.enableFrictionDialogs else { return false }
        case .gentleReminder:
            break // Always allowed if interventions are on
        }

        // Check quiet hours
        guard !isInQuietHours() else { return false }

        // Check cooldown period
        if let lastTime = lastInterventionTime {
            let timeSinceLastIntervention = Date().timeIntervalSince(lastTime)

            // Check global minimum interval
            guard timeSinceLastIntervention >= preferences.minimumInterventionInterval else {
                return false
            }

            // Check type-specific cooldown
            guard timeSinceLastIntervention >= type.cooldownPeriod else {
                return false
            }
        }

        // Don't interrupt an active intervention
        guard !isShowingIntervention else { return false }

        return true
    }

    private func confidenceThreshold(for type: InterventionType) -> Double {
        // Higher escalation levels require higher confidence to trigger
        switch type {
        case .gentleReminder:
            return 0.5
        case .breathingExercise:
            return 0.6
        case .timedPause:
            return 0.7
        case .frictionDialog:
            return 0.8
        }
    }

    private func presentIntervention(_ configuration: InterventionConfiguration) {
        activeIntervention = configuration
        isShowingIntervention = true
        interventionStartTime = Date()

        // Emit notification for UI layer
        NotificationCenter.default.post(
            name: .interventionTriggered,
            object: self,
            userInfo: ["configuration": configuration]
        )
    }

    private func updateEscalationConfiguration() {
        var config = EscalationConfiguration.default

        switch preferences.frequencyLevel {
        case 1:
            config = .gentle
        case 3:
            config = .firm
        default:
            config = .default
        }

        config.showCompassionateMessages = preferences.showCompassionateMessages
        escalationEngine.configuration = config
    }

    private func calculateAverageEngagement() -> TimeInterval {
        let engagedRecords = recentHistory.filter { $0.durationEngaged > 0 }
        guard !engagedRecords.isEmpty else { return 0 }

        let totalDuration = engagedRecords.reduce(0) { $0 + $1.durationEngaged }
        return totalDuration / Double(engagedRecords.count)
    }

    private func trimHistory() {
        // Keep only last 100 records or last 7 days
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        recentHistory = Array(recentHistory.prefix(100).filter {
            $0.completedAt > sevenDaysAgo
        })
    }

    // MARK: - Persistence

    private func persistPreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            userDefaults.set(encoded, forKey: StorageKey.preferences)
        }
    }

    private func persistState() {
        if let encoded = try? JSONEncoder().encode(recentHistory) {
            userDefaults.set(encoded, forKey: StorageKey.history)
        }
        if let lastTime = lastInterventionTime {
            userDefaults.set(lastTime.timeIntervalSince1970, forKey: StorageKey.lastIntervention)
        }
    }

    private func loadPersistedState() {
        // Load preferences
        if let data = userDefaults.data(forKey: StorageKey.preferences),
           let prefs = try? JSONDecoder().decode(InterventionPreferences.self, from: data) {
            preferences = prefs
        }

        // Load history
        if let data = userDefaults.data(forKey: StorageKey.history),
           let history = try? JSONDecoder().decode([InterventionRecord].self, from: data) {
            recentHistory = history
            trimHistory()
        }

        // Load last intervention time
        let timestamp = userDefaults.double(forKey: StorageKey.lastIntervention)
        if timestamp > 0 {
            lastInterventionTime = Date(timeIntervalSince1970: timestamp)
        }
    }
}

// MARK: - Statistics

/// Statistics about intervention effectiveness
struct InterventionStatistics {
    let totalInterventionsToday: Int
    let positiveOutcomesToday: Int
    let currentEscalationLevel: InterventionType
    let averageEngagementDuration: TimeInterval

    var positiveOutcomeRate: Double {
        guard totalInterventionsToday > 0 else { return 1.0 }
        return Double(positiveOutcomesToday) / Double(totalInterventionsToday)
    }

    var formattedEngagementDuration: String {
        let seconds = Int(averageEngagementDuration)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            return "\(seconds / 60)m \(seconds % 60)s"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when an intervention is triggered
    static let interventionTriggered = Notification.Name("scrolltime.intervention.triggered")

    /// Posted when an intervention is completed
    static let interventionCompleted = Notification.Name("scrolltime.intervention.completed")
}

// MARK: - Demo/Preview Support

#if DEBUG
extension InterventionManager {
    /// Create a manager in a specific state for previews
    static func preview(showing type: InterventionType) -> InterventionManager {
        let manager = InterventionManager()
        manager.activeIntervention = InterventionConfiguration(type: type)
        manager.isShowingIntervention = true
        return manager
    }

    /// Create a manager with mock history
    static func previewWithHistory() -> InterventionManager {
        let manager = InterventionManager()

        // Add some mock history
        for i in 0..<5 {
            let type = InterventionType.allCases[i % InterventionType.allCases.count]
            let config = InterventionConfiguration(
                type: type,
                sessionScrollCount: 20 + i * 10
            )
            let record = InterventionRecord(
                configuration: config,
                result: i % 2 == 0 ? .completed : .skipped,
                durationEngaged: Double(10 + i * 5)
            )
            manager.recentHistory.append(record)
        }

        return manager
    }

    /// Simulate receiving a scroll detection event
    func simulateScrollDetection() {
        handleScrollDetectionEvent(.demo())
    }
}
#endif

// MARK: - SwiftUI Environment

/// Environment key for accessing the intervention manager
@MainActor
private struct InterventionManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: InterventionManager = InterventionManager()
}

extension EnvironmentValues {
    var interventionManager: InterventionManager {
        get { self[InterventionManagerKey.self] }
        set { self[InterventionManagerKey.self] = newValue }
    }
}

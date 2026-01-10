//
//  EscalationEngine.swift
//  ScrollTime
//
//  Created by ScrollTime Team
//
//  Manages the graduated escalation of interventions from gentle reminders
//  to firmer checkpoints. The philosophy is to be helpful, not punishing:
//  - Start with the lightest touch
//  - Only escalate when gentler interventions are consistently ignored
//  - Reset escalation when user engages positively
//  - Respect user's autonomy throughout
//

import Foundation
import Combine

// MARK: - Escalation Level

/// Represents the current escalation state
struct EscalationLevel: Codable, Equatable {
    /// Number of interventions ignored in current session
    var ignoredCount: Int

    /// Number of interventions completed positively
    var completedCount: Int

    /// Timestamp of last escalation change
    var lastUpdated: Date

    /// The current session start time
    var sessionStarted: Date

    static var initial: EscalationLevel {
        EscalationLevel(
            ignoredCount: 0,
            completedCount: 0,
            lastUpdated: Date(),
            sessionStarted: Date()
        )
    }

    /// The ratio of ignored to total interventions
    var ignoreRatio: Double {
        let total = ignoredCount + completedCount
        guard total > 0 else { return 0 }
        return Double(ignoredCount) / Double(total)
    }
}

// MARK: - Escalation Configuration

/// User-configurable settings for escalation behavior
struct EscalationConfiguration: Codable, Equatable {
    /// Number of ignored interventions before escalating to next level
    var escalationThreshold: Int

    /// How long (in seconds) before escalation level naturally decays
    var escalationDecayTime: TimeInterval

    /// Maximum escalation level (0 = gentleReminder, 3 = frictionDialog)
    var maxEscalationLevel: Int

    /// Whether to allow any escalation at all
    var escalationEnabled: Bool

    /// Whether to show compassionate messages when escalating
    var showCompassionateMessages: Bool

    /// Default configuration - starts gentle and escalates slowly
    static var `default`: EscalationConfiguration {
        EscalationConfiguration(
            escalationThreshold: 3,         // Escalate after 3 ignored interventions
            escalationDecayTime: 1800,      // Reset after 30 minutes of no scrolling
            maxEscalationLevel: 3,          // Can reach frictionDialog
            escalationEnabled: true,
            showCompassionateMessages: true
        )
    }

    /// Gentle configuration - slower escalation for users who prefer subtle nudges
    static var gentle: EscalationConfiguration {
        EscalationConfiguration(
            escalationThreshold: 5,
            escalationDecayTime: 3600,
            maxEscalationLevel: 2,          // Max out at timedPause
            escalationEnabled: true,
            showCompassionateMessages: true
        )
    }

    /// Firm configuration - for users who want stronger accountability
    static var firm: EscalationConfiguration {
        EscalationConfiguration(
            escalationThreshold: 2,
            escalationDecayTime: 900,
            maxEscalationLevel: 3,
            escalationEnabled: true,
            showCompassionateMessages: true
        )
    }
}

// MARK: - Escalation Engine

/// Manages the progression of intervention intensity based on user behavior
@MainActor
final class EscalationEngine: ObservableObject {

    // MARK: - Published Properties

    /// Current escalation level state
    @Published private(set) var currentLevel: EscalationLevel = .initial

    /// The intervention type that should be shown next
    @Published private(set) var currentInterventionType: InterventionType = .gentleReminder

    /// Whether escalation is currently active (user is in a scrolling session)
    @Published private(set) var isSessionActive: Bool = false

    // MARK: - Configuration

    /// User's escalation preferences
    var configuration: EscalationConfiguration {
        didSet {
            recalculateInterventionType()
        }
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let userDefaults: UserDefaults

    // Keys for persistence
    private enum StorageKey {
        static let escalationLevel = "scrolltime.escalation.level"
        static let configuration = "scrolltime.escalation.config"
    }

    // MARK: - Initialization

    init(
        configuration: EscalationConfiguration = .default,
        userDefaults: UserDefaults = .standard
    ) {
        self.configuration = configuration
        self.userDefaults = userDefaults
        loadPersistedState()
    }

    // MARK: - Session Management

    /// Start a new scrolling session
    func startSession() {
        // Check if we should reset based on time decay
        let timeSinceLastUpdate = Date().timeIntervalSince(currentLevel.lastUpdated)
        if timeSinceLastUpdate > configuration.escalationDecayTime {
            resetEscalation(reason: .timeDecay)
        }

        isSessionActive = true
        currentLevel.sessionStarted = Date()
        currentLevel.lastUpdated = Date()
        persistState()
    }

    /// End the current scrolling session
    func endSession() {
        isSessionActive = false
        currentLevel.lastUpdated = Date()
        persistState()
    }

    // MARK: - Intervention Recording

    /// Record the result of an intervention
    func recordInterventionResult(_ result: InterventionResult, for type: InterventionType) {
        currentLevel.lastUpdated = Date()

        switch result {
        case .completed, .tookBreak:
            currentLevel.completedCount += 1
            if result.shouldResetEscalation {
                resetEscalation(reason: .positiveEngagement)
            }

        case .skipped, .continuedScrolling, .timedOut:
            currentLevel.ignoredCount += 1
            checkForEscalation()
        }

        persistState()
    }

    /// Determine the next intervention type based on current state
    func getNextInterventionType() -> InterventionType {
        return currentInterventionType
    }

    /// Get a compassionate message for the current escalation state
    func getCompassionateMessage() -> String? {
        guard configuration.showCompassionateMessages else { return nil }

        let escalationIndex = currentInterventionType.rawValue

        switch escalationIndex {
        case 0:
            return nil // No extra message for gentle reminder
        case 1:
            return "It's okay to take a moment. You're building a new habit, and that takes practice."
        case 2:
            return "Habit change is hard. This pause is here to help, not to judge."
        case 3:
            return "You've been scrolling for a while. Remember: you're in control. This is just a moment to check in with yourself."
        default:
            return nil
        }
    }

    // MARK: - Manual Controls

    /// Manually reset the escalation level
    func resetEscalation(reason: ResetReason) {
        currentLevel = EscalationLevel(
            ignoredCount: 0,
            completedCount: 0,
            lastUpdated: Date(),
            sessionStarted: currentLevel.sessionStarted
        )
        currentInterventionType = .gentleReminder
        persistState()

        // Could emit analytics event here
        NotificationCenter.default.post(
            name: .escalationReset,
            object: self,
            userInfo: ["reason": reason.rawValue]
        )
    }

    /// Manually set a specific escalation level (for testing or user override)
    func setEscalationLevel(_ level: Int) {
        let clampedLevel = min(max(level, 0), configuration.maxEscalationLevel)
        if let newType = InterventionType(rawValue: clampedLevel) {
            currentInterventionType = newType
        }
        persistState()
    }

    // MARK: - Private Methods

    private func checkForEscalation() {
        guard configuration.escalationEnabled else { return }

        // Check if we've hit the threshold
        if currentLevel.ignoredCount >= configuration.escalationThreshold {
            escalateIfPossible()
        }
    }

    private func escalateIfPossible() {
        let currentIndex = currentInterventionType.rawValue
        let nextIndex = currentIndex + 1

        // Don't exceed max level
        guard nextIndex <= configuration.maxEscalationLevel else { return }

        // Get the next intervention type
        guard let nextType = InterventionType(rawValue: nextIndex) else { return }

        currentInterventionType = nextType

        // Reset the ignored count for this new level
        currentLevel.ignoredCount = 0

        // Emit notification for UI/analytics
        NotificationCenter.default.post(
            name: .escalationIncreased,
            object: self,
            userInfo: [
                "previousLevel": currentIndex,
                "newLevel": nextIndex
            ]
        )
    }

    private func recalculateInterventionType() {
        // Ensure current type doesn't exceed max level
        if currentInterventionType.rawValue > configuration.maxEscalationLevel {
            if let newType = InterventionType(rawValue: configuration.maxEscalationLevel) {
                currentInterventionType = newType
            }
        }
    }

    // MARK: - Persistence

    private func persistState() {
        if let encoded = try? JSONEncoder().encode(currentLevel) {
            userDefaults.set(encoded, forKey: StorageKey.escalationLevel)
        }
    }

    private func loadPersistedState() {
        if let data = userDefaults.data(forKey: StorageKey.escalationLevel),
           let level = try? JSONDecoder().decode(EscalationLevel.self, from: data) {

            // Check for time decay before restoring
            let timeSinceLastUpdate = Date().timeIntervalSince(level.lastUpdated)
            if timeSinceLastUpdate > configuration.escalationDecayTime {
                // Too much time has passed, start fresh
                currentLevel = .initial
                currentInterventionType = .gentleReminder
            } else {
                currentLevel = level
                // Recalculate intervention type based on ignored count
                let escalationsEarned = level.ignoredCount / max(1, configuration.escalationThreshold)
                let targetLevel = min(escalationsEarned, configuration.maxEscalationLevel)
                currentInterventionType = InterventionType(rawValue: targetLevel) ?? .gentleReminder
            }
        }
    }
}

// MARK: - Reset Reason

extension EscalationEngine {
    /// Reasons why escalation might be reset
    enum ResetReason: String, Codable {
        case positiveEngagement  // User completed an intervention
        case timeDecay           // Enough time passed without scrolling
        case sessionEnd          // User closed the monitored app
        case userManualReset     // User explicitly reset in settings
        case newDay              // New calendar day started
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when escalation level increases
    static let escalationIncreased = Notification.Name("scrolltime.escalation.increased")

    /// Posted when escalation is reset
    static let escalationReset = Notification.Name("scrolltime.escalation.reset")
}

// MARK: - Escalation Statistics

/// Statistics about escalation behavior over time
struct EscalationStatistics: Codable {
    var totalEscalations: Int = 0
    var totalResets: Int = 0
    var averageTimeToReset: TimeInterval = 0
    var mostCommonMaxLevel: InterventionType = .gentleReminder
    var positiveEngagementRate: Double = 0

    /// Calculate the effectiveness of the escalation system
    var effectiveness: Double {
        guard totalEscalations > 0 else { return 1.0 }
        // Higher reset count relative to escalations = more effective
        return min(1.0, Double(totalResets) / Double(totalEscalations))
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension EscalationEngine {
    /// Create an engine in a specific state for previews
    static func preview(level: InterventionType) -> EscalationEngine {
        let engine = EscalationEngine()
        engine.currentInterventionType = level
        engine.isSessionActive = true
        return engine
    }

    /// Create an engine with custom ignored count
    static func preview(ignoredCount: Int) -> EscalationEngine {
        let engine = EscalationEngine()
        engine.currentLevel.ignoredCount = ignoredCount
        engine.isSessionActive = true
        return engine
    }
}
#endif

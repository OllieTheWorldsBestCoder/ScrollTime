import Foundation

/// User preferences for ScrollTime app configuration
struct UserPreferences: Codable {
    /// Apps selected for monitoring
    var monitoredAppBundleIds: [String]

    /// Detection sensitivity (0.0 = least sensitive, 1.0 = most sensitive)
    var detectionSensitivity: Double

    /// Time threshold in seconds before intervention triggers
    var scrollThresholdSeconds: Int

    /// Whether monitoring is currently enabled
    var isMonitoringEnabled: Bool

    /// Preferred intervention type - uses InterventionType from Core/Intervention
    var preferredInterventionType: InterventionType

    /// Whether user has completed onboarding
    var hasCompletedOnboarding: Bool

    /// Daily scroll time goal in minutes
    var dailyGoalMinutes: Int

    /// Whether to show gentle reminders
    var gentleRemindersEnabled: Bool

    /// Whether to escalate interventions for repeat offenses
    var escalationEnabled: Bool

    static var `default`: UserPreferences {
        UserPreferences(
            monitoredAppBundleIds: [],
            detectionSensitivity: 0.5,
            scrollThresholdSeconds: 300, // 5 minutes
            isMonitoringEnabled: false,
            preferredInterventionType: .breathingExercise,
            hasCompletedOnboarding: false,
            dailyGoalMinutes: 60,
            gentleRemindersEnabled: true,
            escalationEnabled: true
        )
    }
}

// MARK: - UI-Friendly InterventionType Extensions

/// Extensions to provide UI-friendly display properties for InterventionType
/// The base InterventionType is defined in Core/Intervention/InterventionType.swift
extension InterventionType {
    /// Short display name for settings UI
    var displayName: String {
        switch self {
        case .gentleReminder: return "Gentle Reminder"
        case .breathingExercise: return "Breathing Exercise"
        case .timedPause: return "Timed Pause"
        case .frictionDialog: return "Confirm to Continue"
        }
    }

    /// Short description for settings UI
    var shortDescription: String {
        switch self {
        case .gentleReminder: return "A subtle nudge to check in with yourself"
        case .breathingExercise: return "A calming breathing exercise to reset your focus"
        case .timedPause: return "A mandatory pause to create space for reflection"
        case .frictionDialog: return "Type a phrase to continue mindfully"
        }
    }
}

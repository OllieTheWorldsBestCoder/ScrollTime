//
//  IntentionManager.swift
//  ScrollTime
//
//  Service for managing morning intentions and their effect on intervention thresholds.
//  Morning intentions help users approach their day with awareness and adjust
//  how sensitively the app responds to scrolling based on their stated goals.
//
//  Design Philosophy:
//  - Intentions are personal and should feel supportive, not judgmental
//  - The morning prompt should be optional but encouraged
//  - Historical intentions can reveal patterns for insights
//

import Foundation
import Combine
import SwiftUI

// MARK: - Intention Manager

/// Central service for managing daily intentions and their impact on intervention sensitivity.
/// Intentions set in the morning modify how aggressively interventions are triggered throughout the day.
@MainActor
final class IntentionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = IntentionManager()

    // MARK: - Published State

    /// The intention set for today (if any)
    @Published private(set) var todaysIntention: DailyIntention?

    /// Whether the morning prompt should be displayed
    @Published var showMorningPrompt: Bool = false

    /// History of past intentions (most recent first)
    @Published private(set) var intentionHistory: [DailyIntention] = []

    // MARK: - Configuration

    /// The earliest hour to show the morning prompt (default: 6am)
    var morningPromptStartHour: Int = 6

    /// The latest hour to show the morning prompt (default: 12pm/noon)
    var morningPromptEndHour: Int = 12

    // MARK: - Private Properties

    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    /// Publisher for intention changes
    private let intentionChangedPublisher = PassthroughSubject<DailyIntention?, Never>()

    // Storage keys
    private enum StorageKey {
        static let todaysIntention = "scrolltime.intention.today"
        static let intentionHistory = "scrolltime.intention.history"
        static let lastPromptDismissDate = "scrolltime.intention.lastPromptDismiss"
        static let morningPromptStartHour = "scrolltime.intention.promptStartHour"
        static let morningPromptEndHour = "scrolltime.intention.promptEndHour"
    }

    // MARK: - Initialization

    convenience init() {
        self.init(userDefaults: .standard)
    }

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        loadPersistedState()
        checkMorningPrompt()
        setupDayChangeObserver()
    }

    // MARK: - Public Interface

    /// Set today's intention.
    /// This will update the sensitivity modifier used by the intervention system.
    /// - Parameter type: The type of intention the user is setting
    func setIntention(_ type: IntentionType) {
        let intention = DailyIntention(
            date: Date(),
            intention: type,
            setAt: Date()
        )

        todaysIntention = intention

        // Add to history (avoiding duplicates for same day)
        let calendar = Calendar.current
        intentionHistory.removeAll { calendar.isDate($0.date, inSameDayAs: intention.date) }
        intentionHistory.insert(intention, at: 0)

        // Keep history to a reasonable size (90 days)
        trimHistory()

        // Dismiss the morning prompt
        showMorningPrompt = false

        // Persist changes
        persistState()

        // Notify observers
        intentionChangedPublisher.send(intention)

        // Post notification for other systems
        NotificationCenter.default.post(
            name: .intentionSet,
            object: self,
            userInfo: ["intention": intention]
        )
    }

    /// Get the sensitivity modifier based on today's intention.
    /// This value should be multiplied with intervention thresholds.
    /// - Returns: A modifier value (< 1.0 = stricter, > 1.0 = more lenient, 1.0 = neutral)
    func getSensitivityModifier() -> Double {
        guard let intention = todaysIntention, intention.isActiveToday else {
            // No intention set for today, use neutral modifier
            return 1.0
        }

        return intention.intention.sensitivityModifier
    }

    /// Check if the morning prompt should be shown and update the state.
    /// Call this when the app becomes active or during app launch.
    func checkMorningPrompt() {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)

        // Check if we're in the morning prompt window
        guard currentHour >= morningPromptStartHour && currentHour < morningPromptEndHour else {
            showMorningPrompt = false
            return
        }

        // Check if user already has an intention for today
        if let intention = todaysIntention, intention.isActiveToday {
            showMorningPrompt = false
            return
        }

        // Check if user already dismissed the prompt today
        if let lastDismissDate = getLastPromptDismissDate(),
           calendar.isDateInToday(lastDismissDate) {
            showMorningPrompt = false
            return
        }

        // All conditions met, show the prompt
        showMorningPrompt = true
    }

    /// Dismiss the morning prompt for today without setting an intention.
    /// The prompt won't appear again until tomorrow.
    func dismissMorningPrompt() {
        showMorningPrompt = false
        setLastPromptDismissDate(Date())
    }

    /// Get recent intentions for pattern analysis.
    /// - Parameter days: Number of days to look back (default: 7)
    /// - Returns: Array of intentions within the specified period, most recent first
    func getRecentIntentions(days: Int = 7) -> [DailyIntention] {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return []
        }

        return intentionHistory.filter { $0.date >= cutoffDate }
    }

    /// Clear today's intention (useful for testing or user reset)
    func clearTodaysIntention() {
        todaysIntention = nil
        persistState()
        intentionChangedPublisher.send(nil)
    }

    /// Publisher for observing intention changes
    var intentionChanged: AnyPublisher<DailyIntention?, Never> {
        intentionChangedPublisher.eraseToAnyPublisher()
    }

    /// Get the most common intention type from history
    func getMostCommonIntentionType() -> IntentionType? {
        guard !intentionHistory.isEmpty else { return nil }

        var counts: [IntentionType: Int] = [:]
        for intention in intentionHistory {
            counts[intention.intention, default: 0] += 1
        }

        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Get the intention completion rate (days with intentions vs days without)
    func getCompletionRate(days: Int = 30) -> Double {
        let recentIntentions = getRecentIntentions(days: days)
        guard days > 0 else { return 0 }
        return Double(recentIntentions.count) / Double(days)
    }

    // MARK: - Private Methods

    private func setupDayChangeObserver() {
        // Observe significant time changes (e.g., midnight rollover)
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleDayChange()
            }
            .store(in: &cancellables)

        // Also observe when app becomes active to check for day changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppBecameActive()
            }
            .store(in: &cancellables)
    }

    private func handleDayChange() {
        // Clear today's intention if it's from a previous day
        if let intention = todaysIntention, !intention.isActiveToday {
            todaysIntention = nil
        }

        // Check if we should show the morning prompt
        checkMorningPrompt()
    }

    private func handleAppBecameActive() {
        // Verify today's intention is still valid
        if let intention = todaysIntention, !intention.isActiveToday {
            todaysIntention = nil
            persistState()
        }

        // Check if morning prompt should show
        checkMorningPrompt()
    }

    private func trimHistory() {
        // Keep only the last 90 days of history
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -90, to: Date()) else { return }

        intentionHistory = intentionHistory.filter { $0.date >= cutoffDate }
    }

    // MARK: - Persistence

    private func persistState() {
        // Save today's intention
        if let intention = todaysIntention,
           let encoded = try? JSONEncoder().encode(intention) {
            userDefaults.set(encoded, forKey: StorageKey.todaysIntention)
        } else {
            userDefaults.removeObject(forKey: StorageKey.todaysIntention)
        }

        // Save history
        if let encoded = try? JSONEncoder().encode(intentionHistory) {
            userDefaults.set(encoded, forKey: StorageKey.intentionHistory)
        }
    }

    private func loadPersistedState() {
        // Load today's intention
        if let data = userDefaults.data(forKey: StorageKey.todaysIntention),
           let intention = try? JSONDecoder().decode(DailyIntention.self, from: data) {
            // Only restore if it's still for today
            if intention.isActiveToday {
                todaysIntention = intention
            }
        }

        // Load history
        if let data = userDefaults.data(forKey: StorageKey.intentionHistory),
           let history = try? JSONDecoder().decode([DailyIntention].self, from: data) {
            intentionHistory = history
            trimHistory()
        }

        // Load configuration
        let startHour = userDefaults.integer(forKey: StorageKey.morningPromptStartHour)
        if startHour > 0 {
            morningPromptStartHour = startHour
        }

        let endHour = userDefaults.integer(forKey: StorageKey.morningPromptEndHour)
        if endHour > 0 {
            morningPromptEndHour = endHour
        }
    }

    private func getLastPromptDismissDate() -> Date? {
        let timestamp = userDefaults.double(forKey: StorageKey.lastPromptDismissDate)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func setLastPromptDismissDate(_ date: Date) {
        userDefaults.set(date.timeIntervalSince1970, forKey: StorageKey.lastPromptDismissDate)
    }

    /// Save configuration changes
    func saveConfiguration() {
        userDefaults.set(morningPromptStartHour, forKey: StorageKey.morningPromptStartHour)
        userDefaults.set(morningPromptEndHour, forKey: StorageKey.morningPromptEndHour)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when a daily intention is set
    static let intentionSet = Notification.Name("scrolltime.intention.set")

    /// Posted when the morning prompt should be shown
    static let showMorningPrompt = Notification.Name("scrolltime.intention.showPrompt")
}

// MARK: - SwiftUI Environment Support

/// Environment key for accessing the intention manager
@MainActor
private struct IntentionManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: IntentionManager = IntentionManager.shared
}

extension EnvironmentValues {
    /// Access the IntentionManager from the SwiftUI environment
    var intentionManager: IntentionManager {
        get { self[IntentionManagerKey.self] }
        set { self[IntentionManagerKey.self] = newValue }
    }
}

// MARK: - Demo/Preview Support

#if DEBUG
extension IntentionManager {
    /// Create a manager with a pre-set intention for previews
    static func preview(with intentionType: IntentionType) -> IntentionManager {
        let manager = IntentionManager(userDefaults: UserDefaults(suiteName: "preview")!)
        manager.setIntention(intentionType)
        return manager
    }

    /// Create a manager showing the morning prompt
    static var previewWithPrompt: IntentionManager {
        let manager = IntentionManager(userDefaults: UserDefaults(suiteName: "preview-prompt")!)
        manager.showMorningPrompt = true
        return manager
    }

    /// Create a manager with sample history
    static var previewWithHistory: IntentionManager {
        let manager = IntentionManager(userDefaults: UserDefaults(suiteName: "preview-history")!)
        manager.intentionHistory = DailyIntention.sampleWeek
        return manager
    }

    /// Force show the morning prompt (for testing)
    func forceShowMorningPrompt() {
        showMorningPrompt = true
    }

    /// Set arbitrary history (for testing)
    func setHistory(_ history: [DailyIntention]) {
        intentionHistory = history
        persistState()
    }
}
#endif

// MARK: - Integration with InterventionManager

extension IntentionManager {
    /// Apply the current intention modifier to a base threshold value.
    /// Use this when calculating intervention thresholds.
    /// - Parameter baseThreshold: The default threshold value
    /// - Returns: The adjusted threshold value based on today's intention
    func applyModifier(to baseThreshold: TimeInterval) -> TimeInterval {
        return baseThreshold * getSensitivityModifier()
    }

    /// Apply the current intention modifier to a scroll count threshold.
    /// - Parameter baseCount: The default scroll count threshold
    /// - Returns: The adjusted count based on today's intention
    func applyModifier(to baseCount: Int) -> Int {
        return Int(Double(baseCount) * getSensitivityModifier())
    }
}

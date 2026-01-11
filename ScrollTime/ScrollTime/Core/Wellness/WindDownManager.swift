//
//  WindDownManager.swift
//  ScrollTime
//
//  Service for managing wind-down mode and its effect on intervention thresholds.
//  Wind-down mode activates in the evening to help users disconnect before bed
//  and supports healthier sleep habits through stricter intervention sensitivity.
//
//  Design Philosophy:
//  - Evening routines should feel supportive, not restrictive
//  - Softer messaging during wind-down respects the user's tired state
//  - Manual override is always available (user agency)
//  - Wind-down complements morning intentions for full-day mindfulness
//

import Foundation
import Combine
import SwiftUI
import UserNotifications

// MARK: - Wind Down Manager

/// Central service for managing wind-down mode and its impact on intervention sensitivity.
/// Wind-down mode applies stricter thresholds during evening hours to encourage
/// users to disconnect before sleep.
@MainActor
final class WindDownManager: ObservableObject {

    // MARK: - Singleton

    static let shared = WindDownManager()

    // MARK: - Published State

    /// The current wind-down settings
    @Published var settings: WindDownSettings {
        didSet {
            persistSettings()
            updateNotificationSchedule()
        }
    }

    /// Whether wind-down mode is currently active (manually or by schedule)
    @Published private(set) var isInWindDownMode: Bool = false

    /// Whether the wind-down prompt should be displayed
    @Published var showWindDownPrompt: Bool = false

    /// Whether wind-down was manually started (vs scheduled)
    @Published private(set) var isManuallyActive: Bool = false

    /// The time wind-down mode was manually started (nil if scheduled)
    @Published private(set) var manualStartTime: Date?

    // MARK: - Private Properties

    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private var statusCheckTimer: Timer?

    /// Publisher for wind-down state changes
    private let windDownChangedPublisher = PassthroughSubject<Bool, Never>()

    // Storage keys
    private enum StorageKey {
        static let settings = "scrolltime.winddown.settings"
        static let isManuallyActive = "scrolltime.winddown.manuallyActive"
        static let manualStartTime = "scrolltime.winddown.manualStartTime"
        static let lastPromptDismissDate = "scrolltime.winddown.lastPromptDismiss"
    }

    // Notification identifier
    private let windDownNotificationId = "scrolltime.winddown.reminder"

    // MARK: - Initialization

    convenience init() {
        self.init(userDefaults: .standard)
    }

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        self.settings = .default
        loadPersistedState()
        checkWindDownStatus()
        setupObservers()
        startStatusCheckTimer()
    }

    // MARK: - Public Interface

    /// Check if wind-down should activate and update the state.
    /// Call this when the app becomes active or during app launch.
    func checkWindDownStatus() {
        // If manually active, stay active
        if isManuallyActive {
            isInWindDownMode = true
            return
        }

        // Check schedule
        let shouldBeActive = settings.isWithinWindDownPeriod()

        if shouldBeActive != isInWindDownMode {
            isInWindDownMode = shouldBeActive
            windDownChangedPublisher.send(shouldBeActive)

            // Post notification for other systems
            NotificationCenter.default.post(
                name: .windDownStatusChanged,
                object: self,
                userInfo: ["isActive": shouldBeActive]
            )
        }

        // Check if we should show the prompt
        checkPromptVisibility()
    }

    /// Start wind-down mode manually (outside of scheduled time).
    /// This allows users to begin winding down whenever they feel ready.
    func startWindDown() {
        isManuallyActive = true
        manualStartTime = Date()
        isInWindDownMode = true
        showWindDownPrompt = false

        persistManualState()
        windDownChangedPublisher.send(true)

        // Post notification
        NotificationCenter.default.post(
            name: .windDownStatusChanged,
            object: self,
            userInfo: ["isActive": true, "manual": true]
        )
    }

    /// End wind-down mode (when manually started).
    /// Scheduled wind-down will end automatically at the configured wake time.
    func endWindDown() {
        isManuallyActive = false
        manualStartTime = nil

        // Re-check if we should still be in wind-down based on schedule
        isInWindDownMode = settings.isWithinWindDownPeriod()

        persistManualState()
        windDownChangedPublisher.send(isInWindDownMode)

        // Post notification
        NotificationCenter.default.post(
            name: .windDownStatusChanged,
            object: self,
            userInfo: ["isActive": isInWindDownMode, "manual": false]
        )
    }

    /// Get the adjusted sensitivity for current mode.
    /// This value should be multiplied with intervention thresholds.
    /// - Returns: A modifier value (< 1.0 = stricter interventions)
    func getAdjustedSensitivity() -> Double {
        guard isInWindDownMode else {
            return 1.0 // No adjustment when not in wind-down
        }

        return settings.sensitivityBoost
    }

    /// Apply the wind-down modifier to a base threshold.
    /// - Parameter baseThreshold: The default threshold value
    /// - Returns: The adjusted threshold value based on wind-down status
    func applyModifier(to baseThreshold: TimeInterval) -> TimeInterval {
        return baseThreshold * getAdjustedSensitivity()
    }

    /// Apply the wind-down modifier to a scroll count threshold.
    /// - Parameter baseCount: The default scroll count threshold
    /// - Returns: The adjusted count based on wind-down status
    func applyModifier(to baseCount: Int) -> Int {
        return Int(Double(baseCount) * getAdjustedSensitivity())
    }

    /// Schedule or cancel the wind-down notification based on settings.
    func scheduleNotification() {
        Task {
            await scheduleNotificationAsync()
        }
    }

    /// Dismiss the wind-down prompt for today.
    func dismissPrompt() {
        showWindDownPrompt = false
        setLastPromptDismissDate(Date())
    }

    /// Skip wind-down for tonight.
    /// The prompt won't appear again until tomorrow evening.
    func skipTonight() {
        showWindDownPrompt = false
        setLastPromptDismissDate(Date())

        // If we're in scheduled wind-down, exit it
        if !isManuallyActive && isInWindDownMode {
            isInWindDownMode = false
            windDownChangedPublisher.send(false)
        }
    }

    /// Get the current wind-down status for display
    func currentStatus() -> WindDownStatus {
        return settings.currentStatus()
    }

    /// Publisher for observing wind-down state changes
    var windDownChanged: AnyPublisher<Bool, Never> {
        windDownChangedPublisher.eraseToAnyPublisher()
    }

    /// Get a softer intervention message appropriate for wind-down mode
    func getSofterMessage(for regularMessage: String) -> String {
        guard isInWindDownMode else { return regularMessage }

        // Map regular messages to softer evening versions
        let softerMessages: [String: String] = [
            "Time for a break": "Time to start winding down",
            "Take a moment": "Let's ease into the evening",
            "You've been scrolling": "Your eyes have been busy today",
            "Let's pause": "Let's rest together",
            "Consider stopping": "Perhaps it's time to put the phone down"
        ]

        // Try to find a matching softer message
        for (regular, soft) in softerMessages {
            if regularMessage.localizedCaseInsensitiveContains(regular) {
                return soft
            }
        }

        // Default softer framing
        return "As you wind down for the evening: \(regularMessage.lowercased())"
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Observe significant time changes (e.g., hour changes)
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkWindDownStatus()
            }
            .store(in: &cancellables)

        // Observe when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkWindDownStatus()
            }
            .store(in: &cancellables)
    }

    private func startStatusCheckTimer() {
        // Check status every minute for more responsive transitions
        statusCheckTimer?.invalidate()
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkWindDownStatus()
            }
        }
    }

    private func checkPromptVisibility() {
        guard settings.isEnabled && settings.showReminder else {
            showWindDownPrompt = false
            return
        }

        // Don't show prompt if already in wind-down mode
        guard !isInWindDownMode else {
            showWindDownPrompt = false
            return
        }

        // Check if we should show the prompt (near start time)
        let calendar = Calendar.current
        let now = Date()

        // Check if prompt was already dismissed today
        if let lastDismiss = getLastPromptDismissDate(),
           calendar.isDateInToday(lastDismiss) {
            showWindDownPrompt = false
            return
        }

        // Show prompt 15 minutes before wind-down starts
        if let timeUntilStart = settings.timeUntilStart(from: now),
           timeUntilStart <= 15 * 60 && timeUntilStart > 0 {
            showWindDownPrompt = true
        } else {
            showWindDownPrompt = false
        }
    }

    private func updateNotificationSchedule() {
        scheduleNotification()
    }

    @MainActor
    private func scheduleNotificationAsync() async {
        let center = UNUserNotificationCenter.current()

        // Remove existing notification
        center.removePendingNotificationRequests(withIdentifiers: [windDownNotificationId])

        // Don't schedule if disabled
        guard settings.isEnabled && settings.showReminder else { return }

        // Request permission if needed
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else { return }
        } catch {
            return
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Wind-Down Time"
        content.body = settings.reminderMessage
        content.sound = .default
        content.categoryIdentifier = "WIND_DOWN"

        // Schedule for start time
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: settings.startTime)
        let startMinute = calendar.component(.minute, from: settings.startTime)

        var dateComponents = DateComponents()
        dateComponents.hour = startHour
        dateComponents.minute = startMinute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: windDownNotificationId,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            // Notification scheduling failed
        }
    }

    // MARK: - Persistence

    private func persistSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: StorageKey.settings)
        }
    }

    private func persistManualState() {
        userDefaults.set(isManuallyActive, forKey: StorageKey.isManuallyActive)

        if let startTime = manualStartTime {
            userDefaults.set(startTime.timeIntervalSince1970, forKey: StorageKey.manualStartTime)
        } else {
            userDefaults.removeObject(forKey: StorageKey.manualStartTime)
        }
    }

    private func loadPersistedState() {
        // Load settings
        if let data = userDefaults.data(forKey: StorageKey.settings),
           let loadedSettings = try? JSONDecoder().decode(WindDownSettings.self, from: data) {
            settings = loadedSettings
        }

        // Load manual state
        isManuallyActive = userDefaults.bool(forKey: StorageKey.isManuallyActive)

        let timestamp = userDefaults.double(forKey: StorageKey.manualStartTime)
        if timestamp > 0 {
            let startTime = Date(timeIntervalSince1970: timestamp)
            // Only restore if it was started today
            if Calendar.current.isDateInToday(startTime) {
                manualStartTime = startTime
            } else {
                // Clear stale manual activation
                isManuallyActive = false
                manualStartTime = nil
                persistManualState()
            }
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

    deinit {
        statusCheckTimer?.invalidate()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when wind-down mode status changes
    static let windDownStatusChanged = Notification.Name("scrolltime.winddown.statusChanged")
}

// MARK: - SwiftUI Environment Support

/// Environment key for accessing the wind-down manager
@MainActor
private struct WindDownManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: WindDownManager = WindDownManager.shared
}

extension EnvironmentValues {
    /// Access the WindDownManager from the SwiftUI environment
    var windDownManager: WindDownManager {
        get { self[WindDownManagerKey.self] }
        set { self[WindDownManagerKey.self] = newValue }
    }
}

// MARK: - Integration with Intervention System

extension WindDownManager {
    /// Get a combined sensitivity modifier that accounts for both
    /// wind-down mode and daily intention.
    /// - Parameter intentionModifier: The modifier from IntentionManager
    /// - Returns: Combined modifier value
    func getCombinedSensitivity(intentionModifier: Double = 1.0) -> Double {
        return settings.adjustedSensitivity(intentionModifier: intentionModifier)
    }

    /// Check if an intervention message should use softer framing
    var shouldUseSoftMessages: Bool {
        return isInWindDownMode
    }
}

// MARK: - Wind Down Display Helpers

extension WindDownManager {
    /// Formatted string describing when wind-down will start or end
    var statusDescription: String {
        let status = currentStatus()
        return status.statusMessage
    }

    /// The appropriate emoji for the current status
    var statusEmoji: String {
        let status = currentStatus()
        return status.emoji
    }

    /// Whether wind-down is currently scheduled (enabled in settings)
    var isScheduled: Bool {
        return settings.isEnabled
    }

    /// Human-readable description of the wind-down schedule
    var scheduleDescription: String {
        guard settings.isEnabled else {
            return "Wind-down mode is off"
        }
        return "Wind-down from \(settings.periodDescription)"
    }
}

// MARK: - Demo/Preview Support

#if DEBUG
extension WindDownManager {
    /// Create a manager in wind-down mode for previews
    static var previewActive: WindDownManager {
        let manager = WindDownManager(userDefaults: UserDefaults(suiteName: "preview-active")!)
        manager.isInWindDownMode = true
        manager.settings = .sampleEnabled
        return manager
    }

    /// Create a manager showing the prompt for previews
    static var previewWithPrompt: WindDownManager {
        let manager = WindDownManager(userDefaults: UserDefaults(suiteName: "preview-prompt")!)
        manager.showWindDownPrompt = true
        manager.settings = .sampleEnabled
        return manager
    }

    /// Create a manager with custom settings for previews
    static func preview(settings: WindDownSettings) -> WindDownManager {
        let manager = WindDownManager(userDefaults: UserDefaults(suiteName: "preview-custom")!)
        manager.settings = settings
        return manager
    }

    /// Force wind-down mode on for testing
    func forceWindDownMode(_ active: Bool) {
        isInWindDownMode = active
        if active {
            isManuallyActive = true
        }
    }

    /// Force show the prompt for testing
    func forceShowPrompt() {
        showWindDownPrompt = true
    }
}
#endif

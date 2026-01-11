//
//  WindDownSettings.swift
//  ScrollTime
//
//  Wind-down mode configuration for healthier evening routines.
//  During wind-down time, the app becomes more protective of
//  the user's attention to support better sleep hygiene.
//

import Foundation

// MARK: - Wind Down Settings

/// Configuration for wind-down mode, which applies stricter
/// intervention thresholds during evening hours to support
/// healthy sleep habits.
struct WindDownSettings: Codable, Sendable {
    /// Whether wind-down mode is enabled
    var isEnabled: Bool

    /// The time wind-down mode begins (hour and minute components only)
    var startTime: Date

    /// The time wind-down mode ends (typically wake time)
    var endTime: Date

    /// How much to reduce intervention thresholds during wind-down.
    /// For example, 0.7 means thresholds are reduced by 30% (stricter).
    /// Range: 0.5 (50% stricter) to 1.0 (no change)
    var sensitivityBoost: Double

    /// Whether to show a reminder when wind-down mode activates
    var showReminder: Bool

    /// Custom message to show when wind-down mode activates
    var reminderMessage: String

    // MARK: - Initialization

    init(
        isEnabled: Bool = false,
        startTime: Date = WindDownSettings.defaultStartTime,
        endTime: Date = WindDownSettings.defaultEndTime,
        sensitivityBoost: Double = 0.7,
        showReminder: Bool = true,
        reminderMessage: String = "Wind-down time has started. Let's ease into the evening."
    ) {
        self.isEnabled = isEnabled
        self.startTime = startTime
        self.endTime = endTime
        // Clamp sensitivity boost to valid range
        self.sensitivityBoost = min(max(sensitivityBoost, 0.5), 1.0)
        self.showReminder = showReminder
        self.reminderMessage = reminderMessage
    }

    // MARK: - Default Values

    /// Default start time (9:00 PM)
    static var defaultStartTime: Date {
        var components = DateComponents()
        components.hour = 21
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Default end time (7:00 AM)
    static var defaultEndTime: Date {
        var components = DateComponents()
        components.hour = 7
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Default settings
    static var `default`: WindDownSettings {
        WindDownSettings()
    }

    // MARK: - Time Checking

    /// Checks if the given date falls within the wind-down period.
    /// Handles overnight periods correctly (e.g., 9 PM to 7 AM).
    /// - Parameter date: The date to check (defaults to now)
    /// - Returns: True if currently in wind-down period
    func isWithinWindDownPeriod(at date: Date = Date()) -> Bool {
        guard isEnabled else { return false }

        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        let currentMinutes = currentHour * 60 + currentMinute

        let startHour = calendar.component(.hour, from: startTime)
        let startMinute = calendar.component(.minute, from: startTime)
        let startMinutes = startHour * 60 + startMinute

        let endHour = calendar.component(.hour, from: endTime)
        let endMinute = calendar.component(.minute, from: endTime)
        let endMinutes = endHour * 60 + endMinute

        // Handle overnight periods (e.g., 9 PM to 7 AM)
        if startMinutes > endMinutes {
            // Wind-down spans midnight
            // Active if after start time OR before end time
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        } else {
            // Wind-down is within the same day
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }
    }

    /// Time remaining until wind-down period starts (nil if already active or disabled)
    func timeUntilStart(from date: Date = Date()) -> TimeInterval? {
        guard isEnabled && !isWithinWindDownPeriod(at: date) else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        // Create start time for today
        let startHour = calendar.component(.hour, from: startTime)
        let startMinute = calendar.component(.minute, from: startTime)

        var components = calendar.dateComponents([.year, .month, .day], from: today)
        components.hour = startHour
        components.minute = startMinute

        guard var startToday = calendar.date(from: components) else { return nil }

        // If start time has passed today, use tomorrow
        if startToday <= date {
            startToday = calendar.date(byAdding: .day, value: 1, to: startToday) ?? startToday
        }

        return startToday.timeIntervalSince(date)
    }

    /// Time remaining until wind-down period ends (nil if not active or disabled)
    func timeUntilEnd(from date: Date = Date()) -> TimeInterval? {
        guard isEnabled && isWithinWindDownPeriod(at: date) else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        let endHour = calendar.component(.hour, from: endTime)
        let endMinute = calendar.component(.minute, from: endTime)

        var components = calendar.dateComponents([.year, .month, .day], from: today)
        components.hour = endHour
        components.minute = endMinute

        guard var endToday = calendar.date(from: components) else { return nil }

        // If end time has passed today, use tomorrow
        if endToday <= date {
            endToday = calendar.date(byAdding: .day, value: 1, to: endToday) ?? endToday
        }

        return endToday.timeIntervalSince(date)
    }

    // MARK: - Display Properties

    /// Formatted start time string
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }

    /// Formatted end time string
    var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: endTime)
    }

    /// Human-readable description of the wind-down period
    var periodDescription: String {
        "\(formattedStartTime) to \(formattedEndTime)"
    }

    /// Description of the sensitivity boost
    var sensitivityDescription: String {
        let percentage = Int((1.0 - sensitivityBoost) * 100)
        return "\(percentage)% stricter"
    }

    /// A supportive message explaining wind-down mode
    static var explanation: String {
        "Wind-down mode helps you disconnect before bed. During this time, " +
        "interventions will trigger sooner to encourage you to put your phone down " +
        "and prepare for restful sleep."
    }
}

// MARK: - Wind Down Status

/// Current status of wind-down mode for UI display
enum WindDownStatus: Sendable {
    case disabled
    case inactive(startsIn: TimeInterval)
    case active(endsIn: TimeInterval)

    var isActive: Bool {
        if case .active = self {
            return true
        }
        return false
    }

    var statusMessage: String {
        switch self {
        case .disabled:
            return "Wind-down mode is off"
        case .inactive(let startsIn):
            let minutes = Int(startsIn / 60)
            if minutes < 60 {
                return "Starts in \(minutes) minutes"
            } else {
                let hours = minutes / 60
                let remainingMinutes = minutes % 60
                if remainingMinutes == 0 {
                    return "Starts in \(hours) hour\(hours == 1 ? "" : "s")"
                }
                return "Starts in \(hours)h \(remainingMinutes)m"
            }
        case .active(let endsIn):
            let minutes = Int(endsIn / 60)
            if minutes < 60 {
                return "Active for \(minutes) more minutes"
            } else {
                let hours = minutes / 60
                let remainingMinutes = minutes % 60
                if remainingMinutes == 0 {
                    return "Active for \(hours) more hour\(hours == 1 ? "" : "s")"
                }
                return "Active for \(hours)h \(remainingMinutes)m"
            }
        }
    }

    var emoji: String {
        switch self {
        case .disabled:
            return "💤"
        case .inactive:
            return "🌅"
        case .active:
            return "🌙"
        }
    }
}

// MARK: - WindDownSettings Extension

extension WindDownSettings {
    /// Get the current wind-down status
    func currentStatus(at date: Date = Date()) -> WindDownStatus {
        guard isEnabled else {
            return .disabled
        }

        if isWithinWindDownPeriod(at: date) {
            if let endsIn = timeUntilEnd(from: date) {
                return .active(endsIn: endsIn)
            }
            return .active(endsIn: 0)
        } else {
            if let startsIn = timeUntilStart(from: date) {
                return .inactive(startsIn: startsIn)
            }
            return .inactive(startsIn: 0)
        }
    }

    /// Calculate the adjusted sensitivity modifier for a given time.
    /// Combines wind-down sensitivity with any daily intention modifier.
    /// - Parameters:
    ///   - date: The date to check
    ///   - intentionModifier: Optional modifier from daily intention
    /// - Returns: Combined sensitivity modifier
    func adjustedSensitivity(at date: Date = Date(), intentionModifier: Double = 1.0) -> Double {
        if isWithinWindDownPeriod(at: date) {
            // Apply wind-down boost on top of intention modifier
            return sensitivityBoost * intentionModifier
        }
        return intentionModifier
    }
}

// MARK: - Sample Data

extension WindDownSettings {
    /// Sample settings with wind-down enabled
    static var sampleEnabled: WindDownSettings {
        WindDownSettings(
            isEnabled: true,
            sensitivityBoost: 0.7,
            showReminder: true,
            reminderMessage: "Time to start winding down for the evening."
        )
    }

    /// Sample settings with custom times
    static var sampleCustom: WindDownSettings {
        var components = DateComponents()
        components.hour = 22
        components.minute = 30
        let customStart = Calendar.current.date(from: components) ?? Date()

        components.hour = 6
        components.minute = 0
        let customEnd = Calendar.current.date(from: components) ?? Date()

        return WindDownSettings(
            isEnabled: true,
            startTime: customStart,
            endTime: customEnd,
            sensitivityBoost: 0.6,
            showReminder: true,
            reminderMessage: "Bedtime approaching. Let's put the phone down."
        )
    }
}

//
//  DailyIntention.swift
//  ScrollTime
//
//  Morning intention tracking for mindful daily planning.
//  Setting an intention helps users approach their day with awareness
//  and adjusts intervention sensitivity based on their goals.
//

import Foundation

// MARK: - Intention Type

/// The type of intention a user sets for their day.
/// Each intention reflects a different relationship with screen time
/// and adjusts how sensitively the app responds to scrolling.
enum IntentionType: String, Codable, CaseIterable, Sendable {
    case focusOnWork = "Focus on work"
    case connectWithFriends = "Connect with friends"
    case takeItEasy = "Take it easy"
    case beProductive = "Be productive"
    case restAndRecharge = "Rest and recharge"

    // MARK: - Sensitivity Modifier

    /// How this intention affects intervention thresholds.
    /// Values below 1.0 make interventions trigger sooner (stricter).
    /// Values above 1.0 make interventions trigger later (more lenient).
    var sensitivityModifier: Double {
        switch self {
        case .focusOnWork:
            return 0.8  // 20% stricter - help maintain focus
        case .beProductive:
            return 0.85 // 15% stricter - support productivity goals
        case .connectWithFriends:
            return 1.0  // Neutral - social connection is valuable
        case .takeItEasy:
            return 1.2  // 20% more lenient - it's okay to relax
        case .restAndRecharge:
            return 1.5  // 50% more lenient - rest is important too
        }
    }

    // MARK: - Display Properties

    /// A brief description of what this intention means
    var description: String {
        switch self {
        case .focusOnWork:
            return "Minimize distractions and stay on task"
        case .connectWithFriends:
            return "Catch up with people who matter"
        case .takeItEasy:
            return "Give yourself permission to unwind"
        case .beProductive:
            return "Accomplish your goals today"
        case .restAndRecharge:
            return "Prioritize your wellbeing"
        }
    }

    /// An emoji representing this intention
    var emoji: String {
        switch self {
        case .focusOnWork:
            return "💼"
        case .connectWithFriends:
            return "💬"
        case .takeItEasy:
            return "🌿"
        case .beProductive:
            return "✨"
        case .restAndRecharge:
            return "🌙"
        }
    }

    /// A supportive message shown when this intention is set
    var encouragement: String {
        switch self {
        case .focusOnWork:
            return "You've got this. I'll help you stay focused."
        case .connectWithFriends:
            return "Connection matters. Enjoy your conversations."
        case .takeItEasy:
            return "Rest is productive too. Be gentle with yourself."
        case .beProductive:
            return "Let's make today count together."
        case .restAndRecharge:
            return "Taking care of yourself is always worthwhile."
        }
    }
}

// MARK: - Daily Intention

/// A user's intention for a specific day.
/// Setting a morning intention helps users be mindful about their
/// relationship with their devices throughout the day.
struct DailyIntention: Codable, Identifiable, Sendable {
    /// Unique identifier
    let id: UUID

    /// The date this intention is for (normalized to start of day)
    let date: Date

    /// The type of intention set
    let intention: IntentionType

    /// When the intention was set
    let setAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        intention: IntentionType,
        setAt: Date = Date()
    ) {
        self.id = id
        // Normalize to start of day for consistent lookup
        self.date = Calendar.current.startOfDay(for: date)
        self.intention = intention
        self.setAt = setAt
    }

    // MARK: - Computed Properties

    /// Whether this intention is for the current day
    var isActiveToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Whether this intention was set in the morning (before noon)
    var wasSetInMorning: Bool {
        let hour = Calendar.current.component(.hour, from: setAt)
        return hour < 12
    }

    /// Formatted time when the intention was set
    var formattedSetTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: setAt)
    }

    /// The day of the week for this intention
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Sample Data

extension DailyIntention {
    /// Sample intention for previews
    static var sample: DailyIntention {
        DailyIntention(
            intention: .beProductive
        )
    }

    /// Sample week of intentions for previews
    static var sampleWeek: [DailyIntention] {
        let calendar = Calendar.current
        let intentions: [IntentionType] = [
            .beProductive,
            .focusOnWork,
            .connectWithFriends,
            .beProductive,
            .takeItEasy,
            .restAndRecharge,
            .focusOnWork
        ]

        return intentions.enumerated().compactMap { index, intention in
            guard let date = calendar.date(byAdding: .day, value: -index, to: Date()),
                  let setTime = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: date) else {
                return nil
            }
            return DailyIntention(
                date: date,
                intention: intention,
                setAt: setTime
            )
        }
    }
}

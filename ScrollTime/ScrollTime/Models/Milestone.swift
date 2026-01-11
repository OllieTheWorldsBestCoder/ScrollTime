//
//  Milestone.swift
//  ScrollTime
//
//  Achievement milestones that celebrate user progress in building
//  mindful scrolling habits. Designed to encourage without creating
//  unhealthy gamification pressure.
//

import Foundation

// MARK: - Milestone Type

/// Types of achievements users can unlock through mindful usage
enum MilestoneType: Codable, Sendable, Equatable {
    /// Completed first full day under the scroll goal
    case firstMindfulDay

    /// Achieved a streak of consecutive days under goal
    case streakDays(Int)

    /// Reclaimed hours from mindless scrolling
    case hoursReclaimed(Int)

    /// Completed a number of breathing exercises
    case breathingExercises(Int)

    /// Maintained 90%+ intervention completion rate for a week
    case interventionsMastered

    /// Reached a total number of mindful days (non-consecutive)
    case totalMindfulDays(Int)

    /// First week with decreasing scroll time
    case firstImprovingWeek
}

// MARK: - Milestone

/// A single achievement milestone with metadata
struct Milestone: Codable, Identifiable, Sendable, Equatable {
    // MARK: - Properties

    /// Unique identifier for this milestone instance
    let id: UUID

    /// The type of milestone achieved
    let type: MilestoneType

    /// When this milestone was achieved
    let achievedAt: Date

    /// Whether the user has seen/acknowledged this milestone
    var celebrated: Bool

    // MARK: - Computed Properties

    /// User-friendly title for the milestone
    var title: String {
        switch type {
        case .firstMindfulDay:
            return "First Mindful Day"
        case .streakDays(let days):
            return streakTitle(for: days)
        case .hoursReclaimed(let hours):
            return hoursTitle(for: hours)
        case .breathingExercises(let count):
            return breathingTitle(for: count)
        case .interventionsMastered:
            return "Mindfulness Master"
        case .totalMindfulDays(let days):
            return totalDaysTitle(for: days)
        case .firstImprovingWeek:
            return "Turning Point"
        }
    }

    /// Encouraging description of the achievement
    var description: String {
        switch type {
        case .firstMindfulDay:
            return "You stayed under your scroll goal for a full day. This is where it begins."
        case .streakDays(let days):
            return streakDescription(for: days)
        case .hoursReclaimed(let hours):
            return hoursDescription(for: hours)
        case .breathingExercises(let count):
            return breathingDescription(for: count)
        case .interventionsMastered:
            return "You completed 90% or more of your interventions this week. Your commitment to mindfulness is inspiring."
        case .totalMindfulDays(let days):
            return totalDaysDescription(for: days)
        case .firstImprovingWeek:
            return "This week you scrolled less than last week. You're building momentum."
        }
    }

    /// Emoji representing this milestone
    var emoji: String {
        switch type {
        case .firstMindfulDay:
            return "sunrise" // Dawn of a new habit
        case .streakDays(let days):
            return streakEmoji(for: days)
        case .hoursReclaimed(let hours):
            return hoursEmoji(for: hours)
        case .breathingExercises(let count):
            return breathingEmoji(for: count)
        case .interventionsMastered:
            return "sparkles"
        case .totalMindfulDays(let days):
            return totalDaysEmoji(for: days)
        case .firstImprovingWeek:
            return "chart with upwards trend"
        }
    }

    /// SF Symbol name for this milestone
    var symbolName: String {
        switch type {
        case .firstMindfulDay:
            return "sunrise.fill"
        case .streakDays:
            return "flame.fill"
        case .hoursReclaimed:
            return "clock.badge.checkmark.fill"
        case .breathingExercises:
            return "wind"
        case .interventionsMastered:
            return "sparkles"
        case .totalMindfulDays:
            return "calendar.badge.checkmark"
        case .firstImprovingWeek:
            return "chart.line.uptrend.xyaxis"
        }
    }

    /// Formatted date string for when the milestone was achieved
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: achievedAt)
    }

    // MARK: - Private Helpers

    private func streakTitle(for days: Int) -> String {
        switch days {
        case 3: return "Three Day Flow"
        case 7: return "Week of Intention"
        case 14: return "Fortnight Focus"
        case 30: return "Month of Mindfulness"
        case 60: return "Two Month Journey"
        case 90: return "Quarter of Growth"
        case 365: return "Year of Presence"
        default: return "\(days) Day Streak"
        }
    }

    private func streakDescription(for days: Int) -> String {
        switch days {
        case 3: return "Three days of staying present. Your intention is taking root."
        case 7: return "A full week of mindful scrolling. You're building a real habit."
        case 14: return "Two weeks of consistent practice. This is becoming part of who you are."
        case 30: return "A month of mindfulness. You've proven this matters to you."
        case 60: return "Two months of intentional living. Your future self thanks you."
        case 90: return "A quarter year of presence. You've transformed your relationship with scrolling."
        case 365: return "A full year of mindful choices. You are an inspiration."
        default: return "You stayed under your goal for \(days) consecutive days. Keep nurturing this growth."
        }
    }

    private func streakEmoji(for days: Int) -> String {
        switch days {
        case 3: return "seedling"
        case 7: return "herb"
        case 14: return "potted plant"
        case 30: return "evergreen tree"
        case 60: return "deciduous tree"
        case 90: return "national park"
        case 365: return "globe showing Americas"
        default: return "fire"
        }
    }

    private func hoursTitle(for hours: Int) -> String {
        switch hours {
        case 1: return "First Hour Reclaimed"
        case 5: return "Five Hours Free"
        case 10: return "Ten Hours Returned"
        case 24: return "A Full Day Back"
        case 50: return "Two Days Reclaimed"
        case 100: return "Four Days of Life"
        default: return "\(hours) Hours Reclaimed"
        }
    }

    private func hoursDescription(for hours: Int) -> String {
        switch hours {
        case 1: return "You've reclaimed your first hour from mindless scrolling. That's time for a walk, a chapter, or a conversation."
        case 5: return "Five hours back in your hands. That's enough time to learn something new."
        case 10: return "Ten hours reclaimed. Think of all the moments you've been present for instead."
        case 24: return "A full day of life, reclaimed from the scroll. This is meaningful."
        case 50: return "Fifty hours is more than two full days. You're choosing presence over pixels."
        case 100: return "One hundred hours reclaimed. That's over four days of your life, spent more intentionally."
        default: return "You've reclaimed \(hours) hours from mindless scrolling. Time well saved."
        }
    }

    private func hoursEmoji(for hours: Int) -> String {
        switch hours {
        case 1: return "hourglass done"
        case 5: return "alarm clock"
        case 10: return "watch"
        case 24: return "sun"
        case 50: return "calendar"
        case 100: return "trophy"
        default: return "clock face twelve oclock"
        }
    }

    private func breathingTitle(for count: Int) -> String {
        switch count {
        case 10: return "Ten Deep Breaths"
        case 25: return "Quarter Century of Calm"
        case 50: return "Fifty Moments of Peace"
        case 100: return "Breathing Centurion"
        case 250: return "Master of Breath"
        default: return "\(count) Breathing Exercises"
        }
    }

    private func breathingDescription(for count: Int) -> String {
        switch count {
        case 10: return "You've completed ten breathing exercises. Each pause is a gift to yourself."
        case 25: return "Twenty-five exercises in. You're making calm a habit."
        case 50: return "Fifty moments of intentional breathing. Your nervous system thanks you."
        case 100: return "One hundred breathing exercises completed. You've cultivated real stillness."
        case 250: return "Two hundred and fifty exercises. You've mastered the art of the pause."
        default: return "You've completed \(count) breathing exercises. Keep breathing, keep growing."
        }
    }

    private func breathingEmoji(for count: Int) -> String {
        switch count {
        case 10: return "wind face"
        case 25: return "dash symbol"
        case 50: return "cloud"
        case 100: return "dove"
        case 250: return "person in lotus position"
        default: return "wind face"
        }
    }

    private func totalDaysTitle(for days: Int) -> String {
        switch days {
        case 10: return "Ten Mindful Days"
        case 25: return "Silver Mindfulness"
        case 50: return "Golden Presence"
        case 100: return "Century of Intention"
        default: return "\(days) Mindful Days"
        }
    }

    private func totalDaysDescription(for days: Int) -> String {
        switch days {
        case 10: return "Ten days of staying under your goal, even if not consecutive. Progress, not perfection."
        case 25: return "Twenty-five mindful days total. You keep coming back to what matters."
        case 50: return "Fifty days of intentional scrolling. You're building something lasting."
        case 100: return "One hundred mindful days. Your commitment is remarkable."
        default: return "You've had \(days) total days under your scroll goal. Every day counts."
        }
    }

    private func totalDaysEmoji(for days: Int) -> String {
        switch days {
        case 10: return "keycap: 10"
        case 25: return "2nd place medal"
        case 50: return "1st place medal"
        case 100: return "hundred points"
        default: return "calendar"
        }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        type: MilestoneType,
        achievedAt: Date = Date(),
        celebrated: Bool = false
    ) {
        self.id = id
        self.type = type
        self.achievedAt = achievedAt
        self.celebrated = celebrated
    }
}

// MARK: - Milestone Thresholds

extension MilestoneType {
    /// Standard streak day thresholds for milestone tracking
    static let streakThresholds: [Int] = [3, 7, 14, 30, 60, 90, 365]

    /// Standard hours reclaimed thresholds
    static let hoursThresholds: [Int] = [1, 5, 10, 24, 50, 100]

    /// Standard breathing exercise thresholds
    static let breathingThresholds: [Int] = [10, 25, 50, 100, 250]

    /// Standard total mindful days thresholds
    static let totalDaysThresholds: [Int] = [10, 25, 50, 100]
}

// MARK: - Sample Data

extension Milestone {
    /// Sample first day milestone
    static var sampleFirstDay: Milestone {
        Milestone(
            type: .firstMindfulDay,
            achievedAt: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
            celebrated: true
        )
    }

    /// Sample streak milestone
    static var sampleStreak: Milestone {
        Milestone(
            type: .streakDays(7),
            achievedAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            celebrated: true
        )
    }

    /// Sample hours reclaimed milestone
    static var sampleHours: Milestone {
        Milestone(
            type: .hoursReclaimed(10),
            achievedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            celebrated: false
        )
    }

    /// Sample breathing milestone
    static var sampleBreathing: Milestone {
        Milestone(
            type: .breathingExercises(25),
            achievedAt: Date(),
            celebrated: false
        )
    }

    /// Collection of sample milestones for previews
    static var sampleCollection: [Milestone] {
        [
            sampleFirstDay,
            sampleStreak,
            sampleHours,
            sampleBreathing,
            Milestone(type: .firstImprovingWeek, celebrated: true),
            Milestone(type: .totalMindfulDays(10), celebrated: true)
        ]
    }
}

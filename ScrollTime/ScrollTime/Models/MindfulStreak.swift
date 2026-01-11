//
//  MindfulStreak.swift
//  ScrollTime
//
//  Tracks mindful usage streaks in a positive, encouraging way.
//  Never shows "broken" streaks - only celebrates progress and
//  offers fresh starts. Designed to motivate without guilt.
//

import Foundation

// MARK: - Mindful Streak

/// Tracks consecutive days of staying under the daily scroll goal.
/// Designed with a no-guilt philosophy - streaks are celebrated,
/// but missing a day is framed as a fresh start, never a failure.
struct MindfulStreak: Codable, Sendable {
    // MARK: - Streak Data

    /// Current streak of consecutive days under goal
    var currentStreak: Int

    /// Longest streak ever achieved
    var longestStreak: Int

    /// The most recent date the user was under their goal
    var lastUnderGoalDate: Date?

    /// When the current streak began
    var streakStartDate: Date?

    // MARK: - Computed Properties

    /// Whether the user is currently on an active streak
    var hasActiveStreak: Bool {
        guard let lastDate = lastUnderGoalDate else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastDate)

        // Active if last under-goal day was today or yesterday
        let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        return daysDiff <= 1
    }

    /// Whether this is a new personal best
    var isPersonalBest: Bool {
        currentStreak > 0 && currentStreak >= longestStreak
    }

    /// Warm, encouraging message based on current state
    var message: String {
        if currentStreak == 0 {
            return "Today is a fresh start"
        } else if currentStreak == 1 {
            return "You're planting a seed"
        } else if currentStreak < 7 {
            return "Your mindfulness is growing"
        } else if currentStreak < 14 {
            return "A week of intention, well done"
        } else if currentStreak < 30 {
            return "Your practice is flourishing"
        } else {
            return "A month of mindful choices"
        }
    }

    /// Emoji representing the current streak state (growth metaphor)
    var emoji: String {
        if currentStreak == 0 {
            return "seeds" // Represents potential
        } else if currentStreak < 3 {
            return "seedling" // Just starting
        } else if currentStreak < 7 {
            return "herb" // Growing
        } else if currentStreak < 14 {
            return "potted plant" // Established
        } else if currentStreak < 30 {
            return "evergreen tree" // Strong
        } else {
            return "deciduous tree" // Flourishing
        }
    }

    /// Symbol name for SF Symbols (alternative to emoji)
    var symbolName: String {
        if currentStreak == 0 {
            return "leaf"
        } else if currentStreak < 3 {
            return "leaf.fill"
        } else if currentStreak < 7 {
            return "leaf.arrow.triangle.circlepath"
        } else {
            return "tree.fill"
        }
    }

    /// Short celebration text for UI
    var celebrationText: String {
        if currentStreak == 0 {
            return "Ready to begin"
        } else if currentStreak == 1 {
            return "1 mindful day"
        } else {
            return "\(currentStreak) mindful days"
        }
    }

    /// Detailed description for accessibility
    var accessibilityDescription: String {
        if currentStreak == 0 {
            return "No active streak. Today is a fresh opportunity to stay under your scroll goal."
        } else if currentStreak == 1 {
            return "One day streak. You stayed under your scroll goal yesterday. Keep it going today."
        } else {
            return "\(currentStreak) day streak. You've stayed under your scroll goal for \(currentStreak) consecutive days. Your longest streak is \(longestStreak) days."
        }
    }

    // MARK: - Streak Management

    /// Records a day under goal, updating streak counts
    /// - Parameter date: The date that was under goal (defaults to today)
    mutating func recordUnderGoalDay(for date: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        if let lastDate = lastUnderGoalDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDiff == 1 {
                // Consecutive day - extend streak
                currentStreak += 1
            } else if daysDiff > 1 {
                // Gap in days - start fresh (no negative messaging)
                currentStreak = 1
                streakStartDate = today
            }
            // If daysDiff == 0, already recorded today, no change
        } else {
            // First ever under-goal day
            currentStreak = 1
            streakStartDate = today
        }

        lastUnderGoalDate = today

        // Update personal best
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
    }

    /// Checks if the streak should be reset (called at start of day)
    /// Note: This doesn't show "broken" - just quietly resets for fresh start
    mutating func checkAndResetIfNeeded() {
        guard let lastDate = lastUnderGoalDate else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastDate)
        let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        // If more than 1 day has passed, quietly reset for fresh start
        if daysDiff > 1 {
            currentStreak = 0
            streakStartDate = nil
        }
    }

    // MARK: - Initialization

    init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastUnderGoalDate: Date? = nil,
        streakStartDate: Date? = nil
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastUnderGoalDate = lastUnderGoalDate
        self.streakStartDate = streakStartDate
    }

    /// Creates a fresh streak tracker
    static var fresh: MindfulStreak {
        MindfulStreak()
    }
}

// MARK: - Sample Data

extension MindfulStreak {
    /// Sample streak with active progress
    static var sampleActive: MindfulStreak {
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .day, value: -4, to: today)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)

        return MindfulStreak(
            currentStreak: 5,
            longestStreak: 12,
            lastUnderGoalDate: yesterday,
            streakStartDate: startDate
        )
    }

    /// Sample streak at personal best
    static var samplePersonalBest: MindfulStreak {
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .day, value: -13, to: today)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)

        return MindfulStreak(
            currentStreak: 14,
            longestStreak: 14,
            lastUnderGoalDate: yesterday,
            streakStartDate: startDate
        )
    }

    /// Sample streak ready for fresh start
    static var sampleFreshStart: MindfulStreak {
        let calendar = Calendar.current
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: Date())

        return MindfulStreak(
            currentStreak: 0,
            longestStreak: 7,
            lastUnderGoalDate: fiveDaysAgo,
            streakStartDate: nil
        )
    }

    /// Sample for brand new user
    static var sampleNew: MindfulStreak {
        MindfulStreak()
    }
}

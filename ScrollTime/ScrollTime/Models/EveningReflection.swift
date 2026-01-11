//
//  EveningReflection.swift
//  ScrollTime
//
//  End-of-day reflection tracking for mindful self-awareness.
//  Evening reflections help users connect their mood with their
//  screen time habits and celebrate progress toward their goals.
//

import Foundation

// MARK: - Mood Rating

/// A simple mood rating for end-of-day reflection.
/// Designed to be quick and judgment-free.
enum MoodRating: Int, Codable, CaseIterable, Sendable {
    case great = 3
    case okay = 2
    case tough = 1

    // MARK: - Display Properties

    /// An emoji representing this mood
    var emoji: String {
        switch self {
        case .great:
            return "😊"
        case .okay:
            return "😐"
        case .tough:
            return "😔"
        }
    }

    /// A short label for this mood
    var label: String {
        switch self {
        case .great:
            return "Great"
        case .okay:
            return "Okay"
        case .tough:
            return "Tough"
        }
    }

    /// A supportive response based on the mood
    var response: String {
        switch self {
        case .great:
            return "Wonderful! Those good days are worth celebrating."
        case .okay:
            return "That's perfectly valid. Not every day needs to be amazing."
        case .tough:
            return "I'm sorry today was hard. Tomorrow is a fresh start."
        }
    }

    /// A prompt for optional journaling based on mood
    var journalPrompt: String {
        switch self {
        case .great:
            return "What made today feel good?"
        case .okay:
            return "Anything on your mind?"
        case .tough:
            return "Want to share what made it difficult?"
        }
    }
}

// MARK: - Evening Reflection

/// A record of a user's end-of-day reflection.
/// Combines mood tracking with scroll time awareness to help users
/// understand the relationship between their habits and wellbeing.
struct EveningReflection: Codable, Identifiable, Sendable {
    /// Unique identifier
    let id: UUID

    /// The date this reflection is for (normalized to start of day)
    let date: Date

    /// The user's mood rating
    let mood: MoodRating

    /// Optional note or journal entry
    let note: String?

    /// Total scroll time for the day in minutes
    let scrollTimeMinutes: Int

    /// The user's daily goal in minutes
    let goalMinutes: Int

    /// Whether the user felt they met their morning intention (if set)
    let intentionMet: Bool?

    /// When the reflection was recorded
    let recordedAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        mood: MoodRating,
        note: String? = nil,
        scrollTimeMinutes: Int,
        goalMinutes: Int,
        intentionMet: Bool? = nil,
        recordedAt: Date = Date()
    ) {
        self.id = id
        // Normalize to start of day for consistent lookup
        self.date = Calendar.current.startOfDay(for: date)
        self.mood = mood
        self.note = note
        self.scrollTimeMinutes = scrollTimeMinutes
        self.goalMinutes = goalMinutes
        self.intentionMet = intentionMet
        self.recordedAt = recordedAt
    }

    // MARK: - Computed Properties

    /// Whether the user stayed under their daily goal
    var wasUnderGoal: Bool {
        scrollTimeMinutes <= goalMinutes
    }

    /// Minutes under or over the goal (positive = under, negative = over)
    var minutesFromGoal: Int {
        goalMinutes - scrollTimeMinutes
    }

    /// Percentage of goal used (can be over 100%)
    var goalProgress: Double {
        guard goalMinutes > 0 else { return 0 }
        return Double(scrollTimeMinutes) / Double(goalMinutes)
    }

    /// A supportive message about the user's progress
    var progressMessage: String {
        if wasUnderGoal {
            let minutesUnder = minutesFromGoal
            if minutesUnder >= 30 {
                return "You stayed well under your goal today. Nice work!"
            } else if minutesUnder >= 10 {
                return "You met your goal with time to spare."
            } else {
                return "You made it! Right at your goal."
            }
        } else {
            let minutesOver = abs(minutesFromGoal)
            if minutesOver <= 15 {
                return "Just a little over today. Tomorrow is a new day."
            } else if minutesOver <= 30 {
                return "Today was a bit over goal. Every day is a chance to try again."
            } else {
                return "Today was challenging. Be kind to yourself."
            }
        }
    }

    /// Formatted scroll time string
    var formattedScrollTime: String {
        let hours = scrollTimeMinutes / 60
        let minutes = scrollTimeMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Formatted goal time string
    var formattedGoalTime: String {
        let hours = goalMinutes / 60
        let minutes = goalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// The day of the week for this reflection
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    /// Whether the user added a note
    var hasNote: Bool {
        guard let note = note else { return false }
        return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Sample Data

extension EveningReflection {
    /// Sample reflection for previews
    static var sample: EveningReflection {
        EveningReflection(
            mood: .great,
            note: "Felt focused today and got a lot done!",
            scrollTimeMinutes: 45,
            goalMinutes: 60,
            intentionMet: true
        )
    }

    /// Sample week of reflections for previews
    static var sampleWeek: [EveningReflection] {
        let calendar = Calendar.current
        let moods: [MoodRating] = [.great, .okay, .great, .tough, .okay, .great, .okay]
        let scrollTimes = [45, 75, 50, 90, 60, 40, 55]
        let intentionsMet: [Bool?] = [true, false, true, false, nil, true, nil]
        let notes: [String?] = [
            "Great day!",
            nil,
            "Stayed focused on my project",
            "Tough meetings all day",
            nil,
            "Perfect balance today",
            nil
        ]

        return moods.enumerated().compactMap { index, mood in
            guard let date = calendar.date(byAdding: .day, value: -index, to: Date()),
                  let recordTime = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: date) else {
                return nil
            }
            return EveningReflection(
                date: date,
                mood: mood,
                note: notes[index],
                scrollTimeMinutes: scrollTimes[index],
                goalMinutes: 60,
                intentionMet: intentionsMet[index],
                recordedAt: recordTime
            )
        }
    }
}

// MARK: - Weekly Reflection Summary

/// A summary of reflections over a week period
struct WeeklyReflectionSummary: Codable, Sendable {
    let weekStartDate: Date
    let reflections: [EveningReflection]

    // MARK: - Computed Properties

    /// Average mood score for the week (1-3)
    var averageMood: Double {
        guard !reflections.isEmpty else { return 0 }
        let total = reflections.reduce(0) { $0 + $1.mood.rawValue }
        return Double(total) / Double(reflections.count)
    }

    /// Number of days where the goal was met
    var daysUnderGoal: Int {
        reflections.filter { $0.wasUnderGoal }.count
    }

    /// Number of days with reflections recorded
    var daysRecorded: Int {
        reflections.count
    }

    /// Total scroll time for the week in minutes
    var totalScrollMinutes: Int {
        reflections.reduce(0) { $0 + $1.scrollTimeMinutes }
    }

    /// Average daily scroll time in minutes
    var averageDailyScrollMinutes: Int {
        guard !reflections.isEmpty else { return 0 }
        return totalScrollMinutes / reflections.count
    }

    /// Days where intention was met (excluding days with no intention)
    var daysIntentionMet: Int {
        reflections.filter { $0.intentionMet == true }.count
    }

    /// Days where intention was set
    var daysWithIntention: Int {
        reflections.filter { $0.intentionMet != nil }.count
    }

    /// The most common mood this week
    var predominantMood: MoodRating? {
        guard !reflections.isEmpty else { return nil }
        let counts = Dictionary(grouping: reflections, by: { $0.mood })
            .mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// A supportive summary message
    var summaryMessage: String {
        let goalRate = daysRecorded > 0 ? Double(daysUnderGoal) / Double(daysRecorded) : 0

        if goalRate >= 0.8 {
            return "Excellent week! You're building strong habits."
        } else if goalRate >= 0.5 {
            return "Good progress this week. Keep it up!"
        } else if goalRate >= 0.3 {
            return "Some challenging days. Every week is a learning opportunity."
        } else {
            return "This week was tough. Remember, progress isn't always linear."
        }
    }
}

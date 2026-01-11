//
//  Insight.swift
//  ScrollTime
//
//  Pattern-based insights generated from user behavior data.
//  Designed to surface helpful observations without judgment,
//  and suggest actionable steps for mindful improvement.
//

import Foundation

// MARK: - Insight Type

/// Types of pattern-based insights that can be generated
enum InsightType: Codable, Sendable, Equatable {
    /// User's peak scrolling hour identified
    case peakUsageTime(hour: Int)

    /// Day of week with consistently lower scroll time
    case bestDay(dayOfWeek: Int) // 1 = Sunday, 7 = Saturday

    /// Trending change in app usage
    case appTrend(appName: String, changePercent: Double)

    /// Overall scroll time improvement noticed
    case improvementNotice(percentDecrease: Double)

    /// User consistently completes interventions
    case consistentPauser

    /// Better scroll habits on weekends
    case weekendWarrior

    /// Less scrolling before noon
    case morningPerson

    /// Evening is peak scroll time
    case nightOwl

    /// Scroll time increased this week
    case attentionNeeded(percentIncrease: Double)

    /// First-time insight for new users
    case welcomeInsight

    /// User has been consistent with their goal
    case steadyProgress(daysOnTrack: Int)
}

// MARK: - Insight

/// A single insight generated from user behavior patterns
struct Insight: Codable, Identifiable, Sendable {
    // MARK: - Properties

    /// Unique identifier for this insight
    let id: UUID

    /// The type of insight
    let type: InsightType

    /// User-friendly title
    let title: String

    /// Detailed, encouraging message
    let message: String

    /// Emoji representing this insight
    let emoji: String

    /// Optional actionable suggestion
    let actionSuggestion: String?

    /// When this insight was generated
    let generatedAt: Date

    /// When this insight expires and should be regenerated
    let expiresAt: Date?

    // MARK: - Computed Properties

    /// SF Symbol name for this insight type
    var symbolName: String {
        switch type {
        case .peakUsageTime:
            return "clock.fill"
        case .bestDay:
            return "star.fill"
        case .appTrend:
            return "app.fill"
        case .improvementNotice:
            return "arrow.down.circle.fill"
        case .consistentPauser:
            return "pause.circle.fill"
        case .weekendWarrior:
            return "sun.max.fill"
        case .morningPerson:
            return "sunrise.fill"
        case .nightOwl:
            return "moon.stars.fill"
        case .attentionNeeded:
            return "lightbulb.fill"
        case .welcomeInsight:
            return "hand.wave.fill"
        case .steadyProgress:
            return "chart.line.uptrend.xyaxis"
        }
    }

    /// Whether this insight has expired
    var isExpired: Bool {
        guard let expiry = expiresAt else { return false }
        return Date() > expiry
    }

    /// Whether this is a positive/celebratory insight
    var isPositive: Bool {
        switch type {
        case .improvementNotice, .consistentPauser, .weekendWarrior,
             .morningPerson, .bestDay, .welcomeInsight, .steadyProgress:
            return true
        case .attentionNeeded:
            return false
        default:
            return true // Most insights are neutral-to-positive
        }
    }

    /// Priority for display ordering (higher = more important)
    var priority: Int {
        switch type {
        case .welcomeInsight:
            return 100
        case .improvementNotice:
            return 90
        case .attentionNeeded:
            return 85
        case .steadyProgress:
            return 80
        case .consistentPauser:
            return 70
        case .bestDay, .weekendWarrior, .morningPerson:
            return 60
        case .appTrend:
            return 50
        case .peakUsageTime, .nightOwl:
            return 40
        }
    }

    /// Formatted generation date
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: generatedAt, relativeTo: Date())
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        type: InsightType,
        title: String,
        message: String,
        emoji: String,
        actionSuggestion: String? = nil,
        generatedAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.emoji = emoji
        self.actionSuggestion = actionSuggestion
        self.generatedAt = generatedAt
        self.expiresAt = expiresAt
    }
}

// MARK: - Insight Factory

/// Factory methods for creating standard insights
extension Insight {
    /// Creates a peak usage time insight
    static func peakUsageTime(hour: Int) -> Insight {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let hourDate = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        let hourString = formatter.string(from: hourDate)

        return Insight(
            type: .peakUsageTime(hour: hour),
            title: "Peak Scroll Time",
            message: "Your scrolling tends to peak around \(hourString). Knowing this can help you prepare.",
            emoji: "clock face \(hour > 12 ? hour - 12 : hour) oclock",
            actionSuggestion: "Try setting a gentle reminder before \(hourString) to check in with yourself.",
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())
        )
    }

    /// Creates a best day insight
    static func bestDay(dayOfWeek: Int) -> Insight {
        let formatter = DateFormatter()
        let dayName = formatter.weekdaySymbols[dayOfWeek - 1]

        return Insight(
            type: .bestDay(dayOfWeek: dayOfWeek),
            title: "Your Best Day",
            message: "\(dayName)s tend to be your most mindful days. What makes them different?",
            emoji: "star",
            actionSuggestion: "Reflect on what helps you scroll less on \(dayName)s and try it other days.",
            expiresAt: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }

    /// Creates an app trend insight
    static func appTrend(appName: String, changePercent: Double) -> Insight {
        let isDecreasing = changePercent < 0
        let absChange = Int(abs(changePercent))

        return Insight(
            type: .appTrend(appName: appName, changePercent: changePercent),
            title: "\(appName) \(isDecreasing ? "Down" : "Up")",
            message: "Your \(appName) time is \(isDecreasing ? "down" : "up") \(absChange)% this week\(isDecreasing ? ". Nice work!" : ".")",
            emoji: isDecreasing ? "chart with downwards trend" : "chart with upwards trend",
            actionSuggestion: isDecreasing ? nil : "Consider what's drawing you to \(appName) more lately.",
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())
        )
    }

    /// Creates an improvement notice insight
    static func improvementNotice(percentDecrease: Double) -> Insight {
        let decrease = Int(percentDecrease)

        return Insight(
            type: .improvementNotice(percentDecrease: percentDecrease),
            title: "You're Improving",
            message: "Your scroll time is down \(decrease)% compared to last week. Your effort is paying off.",
            emoji: "party popper",
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())
        )
    }

    /// Creates a consistent pauser insight
    static func consistentPauser() -> Insight {
        Insight(
            type: .consistentPauser,
            title: "Mindful Pauser",
            message: "You consistently complete your breathing exercises. This practice is building real awareness.",
            emoji: "person in lotus position",
            expiresAt: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }

    /// Creates a weekend warrior insight
    static func weekendWarrior() -> Insight {
        Insight(
            type: .weekendWarrior,
            title: "Weekend Warrior",
            message: "You scroll less on weekends. Perhaps work stress drives weekday scrolling?",
            emoji: "beach with umbrella",
            actionSuggestion: "Try bringing some weekend energy to your workday breaks.",
            expiresAt: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }

    /// Creates a morning person insight
    static func morningPerson() -> Insight {
        Insight(
            type: .morningPerson,
            title: "Morning Mindfulness",
            message: "Your mornings are scroll-free. This sets a wonderful tone for your day.",
            emoji: "sunrise over mountains",
            expiresAt: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }

    /// Creates a night owl insight
    static func nightOwl() -> Insight {
        Insight(
            type: .nightOwl,
            title: "Evening Scrolling",
            message: "Most of your scroll time happens after 8 PM. Evening scrolling can affect sleep quality.",
            emoji: "owl",
            actionSuggestion: "Try setting a wind-down reminder an hour before bed.",
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())
        )
    }

    /// Creates an attention needed insight
    static func attentionNeeded(percentIncrease: Double) -> Insight {
        let increase = Int(percentIncrease)

        return Insight(
            type: .attentionNeeded(percentIncrease: percentIncrease),
            title: "A Gentle Check-In",
            message: "Your scroll time is up \(increase)% this week. No judgment - just awareness. What's been on your mind?",
            emoji: "thought balloon",
            actionSuggestion: "Sometimes we scroll more when stressed. Be gentle with yourself.",
            expiresAt: Calendar.current.date(byAdding: .day, value: 3, to: Date())
        )
    }

    /// Creates a welcome insight for new users
    static func welcome() -> Insight {
        Insight(
            type: .welcomeInsight,
            title: "Welcome to Mindful Scrolling",
            message: "We'll learn your patterns over the next few days and share helpful insights. No judgment, just awareness.",
            emoji: "waving hand",
            expiresAt: Calendar.current.date(byAdding: .day, value: 3, to: Date())
        )
    }

    /// Creates a steady progress insight
    static func steadyProgress(daysOnTrack: Int) -> Insight {
        Insight(
            type: .steadyProgress(daysOnTrack: daysOnTrack),
            title: "Steady Progress",
            message: "You've been under your goal \(daysOnTrack) out of the last 7 days. Consistency builds habits.",
            emoji: "chart increasing",
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())
        )
    }
}

// MARK: - Sample Data

extension Insight {
    /// Sample peak usage insight
    static var samplePeakUsage: Insight {
        .peakUsageTime(hour: 21)
    }

    /// Sample improvement insight
    static var sampleImprovement: Insight {
        .improvementNotice(percentDecrease: 18)
    }

    /// Sample best day insight
    static var sampleBestDay: Insight {
        .bestDay(dayOfWeek: 7) // Saturday
    }

    /// Sample app trend insight
    static var sampleAppTrend: Insight {
        .appTrend(appName: "Instagram", changePercent: -15)
    }

    /// Collection of sample insights for previews
    static var sampleCollection: [Insight] {
        [
            .improvementNotice(percentDecrease: 12),
            .peakUsageTime(hour: 21),
            .bestDay(dayOfWeek: 7),
            .appTrend(appName: "TikTok", changePercent: -20),
            .consistentPauser(),
            .morningPerson()
        ].sorted { $0.priority > $1.priority }
    }

    /// Sample for new user
    static var sampleWelcome: Insight {
        .welcome()
    }
}

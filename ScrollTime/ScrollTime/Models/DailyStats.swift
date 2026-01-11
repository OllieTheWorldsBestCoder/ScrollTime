import Foundation

/// Daily usage statistics
struct DailyStats: Codable, Identifiable, Sendable {
    var id: Date { date }

    /// The date these stats represent
    let date: Date

    /// Total scroll time in seconds
    var totalScrollTimeSeconds: Int

    /// Number of scroll sessions
    var scrollSessionCount: Int

    /// Number of interventions triggered
    var interventionCount: Int

    /// Number of times user chose to stop after intervention
    var successfulInterventions: Int

    /// Per-app breakdown
    var appUsage: [AppUsageRecord]

    init(
        date: Date,
        totalScrollTimeSeconds: Int,
        scrollSessionCount: Int,
        interventionCount: Int,
        successfulInterventions: Int,
        appUsage: [AppUsageRecord]
    ) {
        self.date = date
        self.totalScrollTimeSeconds = totalScrollTimeSeconds
        self.scrollSessionCount = scrollSessionCount
        self.interventionCount = interventionCount
        self.successfulInterventions = successfulInterventions
        self.appUsage = appUsage
    }

    // MARK: - Computed Properties

    /// Computed success rate (0.0 to 1.0)
    var interventionSuccessRate: Double {
        guard interventionCount > 0 else { return 0 }
        return Double(successfulInterventions) / Double(interventionCount)
    }

    /// Formatted total time string
    var formattedTotalTime: String {
        let hours = totalScrollTimeSeconds / 3600
        let minutes = (totalScrollTimeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Total scroll time in minutes
    var totalScrollTimeMinutes: Int {
        totalScrollTimeSeconds / 60
    }

    /// Whether any activity was recorded
    var hasActivity: Bool {
        scrollSessionCount > 0 || totalScrollTimeSeconds > 0
    }

    /// Average session duration in seconds
    var averageSessionDuration: Int {
        guard scrollSessionCount > 0 else { return 0 }
        return totalScrollTimeSeconds / scrollSessionCount
    }

    /// Formatted average session duration
    var formattedAverageSessionDuration: String {
        let duration = averageSessionDuration
        let minutes = duration / 60
        let seconds = duration % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    // MARK: - Goal Tracking

    /// Calculates time under or over the daily goal.
    /// - Parameter goalMinutes: The daily goal in minutes
    /// - Returns: Positive if under goal, negative if over goal
    func timeFromGoal(goalMinutes: Int) -> Int {
        return goalMinutes - totalScrollTimeMinutes
    }

    /// Whether the user is under their daily goal.
    /// - Parameter goalMinutes: The daily goal in minutes
    func isUnderGoal(goalMinutes: Int) -> Bool {
        return totalScrollTimeMinutes <= goalMinutes
    }

    /// Percentage of daily goal used (can be over 100%)
    /// - Parameter goalMinutes: The daily goal in minutes
    func goalProgress(goalMinutes: Int) -> Double {
        guard goalMinutes > 0 else { return 0 }
        return Double(totalScrollTimeMinutes) / Double(goalMinutes)
    }

    /// Formatted string showing time relative to goal
    /// - Parameter goalMinutes: The daily goal in minutes
    func formattedGoalStatus(goalMinutes: Int) -> String {
        let diff = timeFromGoal(goalMinutes: goalMinutes)
        let absDiff = abs(diff)
        let hours = absDiff / 60
        let minutes = absDiff % 60

        if diff > 0 {
            if hours > 0 {
                return "\(hours)h \(minutes)m under goal"
            }
            return "\(minutes)m under goal"
        } else if diff < 0 {
            if hours > 0 {
                return "\(hours)h \(minutes)m over goal"
            }
            return "\(minutes)m over goal"
        } else {
            return "At goal"
        }
    }

    // MARK: - Static Constructors

    static var empty: DailyStats {
        DailyStats(
            date: Date(),
            totalScrollTimeSeconds: 0,
            scrollSessionCount: 0,
            interventionCount: 0,
            successfulInterventions: 0,
            appUsage: []
        )
    }

    /// Creates an empty stats object for a specific date
    public static func empty(for date: Date) -> DailyStats {
        DailyStats(
            date: date,
            totalScrollTimeSeconds: 0,
            scrollSessionCount: 0,
            interventionCount: 0,
            successfulInterventions: 0,
            appUsage: []
        )
    }

    /// Sample data for previews
    public static var sample: DailyStats {
        DailyStats(
            date: Date(),
            totalScrollTimeSeconds: 4500, // 1h 15m
            scrollSessionCount: 12,
            interventionCount: 5,
            successfulInterventions: 3,
            appUsage: [
                AppUsageRecord(appName: "Instagram", bundleId: "com.instagram.app", scrollTimeSeconds: 1800),
                AppUsageRecord(appName: "TikTok", bundleId: "com.tiktok.app", scrollTimeSeconds: 1500),
                AppUsageRecord(appName: "Twitter", bundleId: "com.twitter.app", scrollTimeSeconds: 900),
                AppUsageRecord(appName: "Reddit", bundleId: "com.reddit.app", scrollTimeSeconds: 300)
            ]
        )
    }

    /// Sample week data for previews
    public static var sampleWeek: [DailyStats] {
        let calendar = Calendar.current
        return (0..<7).reversed().compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { return nil }

            // Generate varied but realistic data
            let baseMinutes = Int.random(in: 30...120)
            let sessions = Int.random(in: 3...15)
            let interventions = Int.random(in: 0...5)
            let successful = Int.random(in: 0...interventions)

            return DailyStats(
                date: date,
                totalScrollTimeSeconds: baseMinutes * 60,
                scrollSessionCount: sessions,
                interventionCount: interventions,
                successfulInterventions: successful,
                appUsage: [
                    AppUsageRecord(appName: "Instagram", bundleId: "com.instagram.app", scrollTimeSeconds: baseMinutes * 30),
                    AppUsageRecord(appName: "TikTok", bundleId: "com.tiktok.app", scrollTimeSeconds: baseMinutes * 20),
                    AppUsageRecord(appName: "Twitter", bundleId: "com.twitter.app", scrollTimeSeconds: baseMinutes * 10)
                ]
            )
        }
    }
}

/// Usage record for a single app
struct AppUsageRecord: Codable, Identifiable {
    var id: String { bundleId }

    let appName: String
    let bundleId: String
    var scrollTimeSeconds: Int

    var formattedTime: String {
        let minutes = scrollTimeSeconds / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(minutes)m"
    }
}

/// Weekly statistics aggregation
struct WeeklyStats: Identifiable, Codable {
    var id: Date { weekStartDate }

    let weekStartDate: Date
    let dailyStats: [DailyStats]

    // MARK: - Computed Totals

    var totalScrollTimeSeconds: Int {
        dailyStats.reduce(0) { $0 + $1.totalScrollTimeSeconds }
    }

    var totalScrollTimeMinutes: Int {
        totalScrollTimeSeconds / 60
    }

    var totalSessions: Int {
        dailyStats.reduce(0) { $0 + $1.scrollSessionCount }
    }

    var totalInterventions: Int {
        dailyStats.reduce(0) { $0 + $1.interventionCount }
    }

    var totalSuccessfulInterventions: Int {
        dailyStats.reduce(0) { $0 + $1.successfulInterventions }
    }

    // MARK: - Computed Averages

    var averageDailyScrollMinutes: Int {
        guard !dailyStats.isEmpty else { return 0 }
        return (totalScrollTimeSeconds / 60) / dailyStats.count
    }

    var averageDailyScrollSeconds: Int {
        guard !dailyStats.isEmpty else { return 0 }
        return totalScrollTimeSeconds / dailyStats.count
    }

    var averageSessionsPerDay: Double {
        guard !dailyStats.isEmpty else { return 0 }
        return Double(totalSessions) / Double(dailyStats.count)
    }

    var averageInterventionsPerDay: Double {
        guard !dailyStats.isEmpty else { return 0 }
        return Double(totalInterventions) / Double(dailyStats.count)
    }

    var overallSuccessRate: Double {
        guard totalInterventions > 0 else { return 0 }
        return Double(totalSuccessfulInterventions) / Double(totalInterventions)
    }

    // MARK: - Formatted Strings

    var formattedTotalTime: String {
        let hours = totalScrollTimeSeconds / 3600
        let minutes = (totalScrollTimeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedAverageDailyTime: String {
        let seconds = averageDailyScrollSeconds
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedSuccessRate: String {
        return "\(Int(overallSuccessRate * 100))%"
    }

    // MARK: - Goal Tracking

    /// Calculates total time under or over the weekly goal (daily goal * 7).
    /// - Parameter dailyGoalMinutes: The daily goal in minutes
    /// - Returns: Positive if under goal, negative if over goal
    func timeFromWeeklyGoal(dailyGoalMinutes: Int) -> Int {
        let weeklyGoal = dailyGoalMinutes * 7
        return weeklyGoal - totalScrollTimeMinutes
    }

    /// Number of days under the daily goal
    func daysUnderGoal(dailyGoalMinutes: Int) -> Int {
        dailyStats.filter { $0.isUnderGoal(goalMinutes: dailyGoalMinutes) }.count
    }

    /// Best day (lowest scroll time) this week
    var bestDay: DailyStats? {
        dailyStats.min { $0.totalScrollTimeSeconds < $1.totalScrollTimeSeconds }
    }

    /// Worst day (highest scroll time) this week
    var worstDay: DailyStats? {
        dailyStats.max { $0.totalScrollTimeSeconds < $1.totalScrollTimeSeconds }
    }

    // MARK: - Trend Analysis

    /// Compares the second half of the week to the first half.
    /// Returns positive if improving (less scroll time), negative if worsening.
    var trendDirection: Double {
        let halfIndex = dailyStats.count / 2
        guard halfIndex > 0 else { return 0 }

        let firstHalf = dailyStats.prefix(halfIndex)
        let secondHalf = dailyStats.suffix(from: halfIndex)

        let firstAvg = firstHalf.reduce(0) { $0 + $1.totalScrollTimeSeconds } / firstHalf.count
        let secondAvg = secondHalf.reduce(0) { $0 + $1.totalScrollTimeSeconds } / secondHalf.count

        guard firstAvg > 0 else { return 0 }

        // Positive means improvement (less scrolling), negative means regression
        return Double(firstAvg - secondAvg) / Double(firstAvg)
    }

    /// Whether the trend is improving (scrolling less over the week)
    var isImproving: Bool {
        trendDirection > 0.05 // 5% improvement threshold
    }

    // MARK: - Sample Data

    static var sample: WeeklyStats {
        let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        return WeeklyStats(weekStartDate: weekStart, dailyStats: DailyStats.sampleWeek)
    }
}

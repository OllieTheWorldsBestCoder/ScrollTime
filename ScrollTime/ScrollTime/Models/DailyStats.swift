import Foundation

/// Daily usage statistics
struct DailyStats: Codable, Identifiable {
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

    /// Sample data for previews
    static var sample: DailyStats {
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
struct WeeklyStats: Identifiable {
    var id: Date { weekStartDate }

    let weekStartDate: Date
    let dailyStats: [DailyStats]

    var totalScrollTimeSeconds: Int {
        dailyStats.reduce(0) { $0 + $1.totalScrollTimeSeconds }
    }

    var totalInterventions: Int {
        dailyStats.reduce(0) { $0 + $1.interventionCount }
    }

    var totalSuccessfulInterventions: Int {
        dailyStats.reduce(0) { $0 + $1.successfulInterventions }
    }

    var averageDailyScrollMinutes: Int {
        guard !dailyStats.isEmpty else { return 0 }
        return (totalScrollTimeSeconds / 60) / dailyStats.count
    }

    var overallSuccessRate: Double {
        guard totalInterventions > 0 else { return 0 }
        return Double(totalSuccessfulInterventions) / Double(totalInterventions)
    }
}

//
//  WeeklyReport.swift
//  ScrollTime
//
//  A comprehensive weekly insights report that aggregates scroll data,
//  intervention outcomes, and usage patterns into actionable insights.
//  Designed for the analytics and insights system.
//

import Foundation

// MARK: - Weekly Report

/// A comprehensive weekly insights report containing aggregated scroll data,
/// intervention metrics, and usage patterns for a seven-day period.
struct WeeklyReport: Codable, Identifiable, Sendable {
    // MARK: - Identification

    /// Unique identifier for this report
    let id: UUID

    /// The start date of this week (typically Sunday or Monday)
    let weekStartDate: Date

    // MARK: - Time Metrics

    /// Total scroll time in seconds for the week
    let totalScrollTime: TimeInterval

    /// Total scroll time from the previous week for comparison
    let previousWeekScrollTime: TimeInterval

    // MARK: - Breakdown Data

    /// Daily breakdown of scroll activity
    let dailyBreakdown: [DailyScrollData]

    /// Top apps by usage duration, sorted descending
    let topApps: [AppUsageSummary]

    // MARK: - Intervention Metrics

    /// Total number of interventions triggered this week
    let interventionsTaken: Int

    /// Number of interventions the user completed (breathing, pause, etc.)
    let interventionsCompleted: Int

    // MARK: - Pattern Insights

    /// Hour of day with peak scrolling activity (0-23)
    let peakScrollHour: Int

    /// The day with the least scroll time
    let bestDay: Date

    /// Duration of scrolling on the best day
    let bestDayDuration: TimeInterval

    // MARK: - Computed Properties

    /// The end date of this week (6 days after start)
    var weekEndDate: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
    }

    /// Change in scroll time from previous week (negative means improvement)
    var scrollTimeChange: TimeInterval {
        totalScrollTime - previousWeekScrollTime
    }

    /// Percentage change from previous week (negative means improvement)
    var scrollTimeChangePercent: Double {
        guard previousWeekScrollTime > 0 else { return 0 }
        return (scrollTimeChange / previousWeekScrollTime) * 100
    }

    /// Intervention completion rate (0.0 to 1.0)
    var completionRate: Double {
        guard interventionsTaken > 0 else { return 0 }
        return Double(interventionsCompleted) / Double(interventionsTaken)
    }

    /// Whether scroll time decreased compared to last week
    var isImproving: Bool {
        scrollTimeChange < 0
    }

    /// Average daily scroll time in seconds
    var averageDailyScrollTime: TimeInterval {
        guard !dailyBreakdown.isEmpty else { return 0 }
        return totalScrollTime / Double(dailyBreakdown.count)
    }

    // MARK: - Formatted Strings

    /// Formatted total scroll time for display
    var formattedTotalTime: String {
        formatDuration(totalScrollTime)
    }

    /// Formatted change in scroll time
    var formattedScrollTimeChange: String {
        let absChange = abs(scrollTimeChange)
        let formatted = formatDuration(absChange)
        if scrollTimeChange < 0 {
            return "\(formatted) less"
        } else if scrollTimeChange > 0 {
            return "\(formatted) more"
        }
        return "same as last week"
    }

    /// Formatted completion rate as percentage
    var formattedCompletionRate: String {
        "\(Int(completionRate * 100))%"
    }

    /// Formatted peak scroll hour
    var formattedPeakHour: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let calendar = Calendar.current
        let components = DateComponents(hour: peakScrollHour)
        guard let date = calendar.date(from: components) else { return "\(peakScrollHour):00" }
        return formatter.string(from: date)
    }

    /// Warm, encouraging summary message
    var summaryMessage: String {
        if isImproving && scrollTimeChangePercent < -10 {
            return "You're making wonderful progress this week"
        } else if completionRate > 0.8 {
            return "Your mindfulness practice is really paying off"
        } else if dailyBreakdown.filter({ $0.totalDuration < averageDailyScrollTime }).count >= 4 {
            return "Most days this week were under your average"
        } else {
            return "Every week is a fresh opportunity to grow"
        }
    }

    // MARK: - Private Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        weekStartDate: Date,
        totalScrollTime: TimeInterval,
        previousWeekScrollTime: TimeInterval,
        dailyBreakdown: [DailyScrollData],
        topApps: [AppUsageSummary],
        interventionsTaken: Int,
        interventionsCompleted: Int,
        peakScrollHour: Int,
        bestDay: Date,
        bestDayDuration: TimeInterval
    ) {
        self.id = id
        self.weekStartDate = weekStartDate
        self.totalScrollTime = totalScrollTime
        self.previousWeekScrollTime = previousWeekScrollTime
        self.dailyBreakdown = dailyBreakdown
        self.topApps = topApps
        self.interventionsTaken = interventionsTaken
        self.interventionsCompleted = interventionsCompleted
        self.peakScrollHour = peakScrollHour
        self.bestDay = bestDay
        self.bestDayDuration = bestDayDuration
    }
}

// MARK: - Daily Scroll Data

/// A single day's scroll activity summary for weekly breakdown
struct DailyScrollData: Codable, Identifiable, Sendable {
    /// Unique identifier
    let id: UUID

    /// The date this data represents
    let date: Date

    /// Total scroll duration in seconds
    let totalDuration: TimeInterval

    /// Number of separate scroll sessions
    let sessionCount: Int

    /// Number of interventions triggered
    let interventionCount: Int

    // MARK: - Computed Properties

    /// Day of week abbreviation (Mon, Tue, etc.)
    var dayAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    /// Formatted duration for display
    var formattedDuration: String {
        let totalSeconds = Int(totalDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Whether this was a low-activity day (under 30 minutes)
    var isLowActivity: Bool {
        totalDuration < 1800 // 30 minutes
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        date: Date,
        totalDuration: TimeInterval,
        sessionCount: Int,
        interventionCount: Int
    ) {
        self.id = id
        self.date = date
        self.totalDuration = totalDuration
        self.sessionCount = sessionCount
        self.interventionCount = interventionCount
    }
}

// MARK: - App Usage Summary

/// Summary of usage for a single app within a weekly report
struct AppUsageSummary: Codable, Identifiable, Sendable {
    /// Unique identifier
    let id: UUID

    /// Display name of the app
    let appName: String

    /// Bundle identifier for the app
    let bundleId: String

    /// Total usage duration in seconds
    let duration: TimeInterval

    // MARK: - Computed Properties

    /// Formatted duration for display
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        appName: String,
        bundleId: String,
        duration: TimeInterval
    ) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.duration = duration
    }
}

// MARK: - Sample Data

extension WeeklyReport {
    /// Sample report for previews and testing
    static var sample: WeeklyReport {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today

        // Generate daily breakdown
        let dailyData: [DailyScrollData] = (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) ?? today
            let baseMinutes = [45, 62, 38, 55, 70, 42, 50][dayOffset]
            return DailyScrollData(
                date: date,
                totalDuration: TimeInterval(baseMinutes * 60),
                sessionCount: Int.random(in: 3...12),
                interventionCount: Int.random(in: 0...4)
            )
        }

        let bestDayData = dailyData.min { $0.totalDuration < $1.totalDuration }!

        return WeeklyReport(
            weekStartDate: weekStart,
            totalScrollTime: dailyData.reduce(0) { $0 + $1.totalDuration },
            previousWeekScrollTime: 25200, // 7 hours
            dailyBreakdown: dailyData,
            topApps: [
                AppUsageSummary(appName: "Instagram", bundleId: "com.instagram.app", duration: 7200),
                AppUsageSummary(appName: "TikTok", bundleId: "com.tiktok.app", duration: 5400),
                AppUsageSummary(appName: "Twitter", bundleId: "com.twitter.app", duration: 3600),
                AppUsageSummary(appName: "Reddit", bundleId: "com.reddit.app", duration: 2400)
            ],
            interventionsTaken: 18,
            interventionsCompleted: 14,
            peakScrollHour: 21, // 9 PM
            bestDay: bestDayData.date,
            bestDayDuration: bestDayData.totalDuration
        )
    }
}

extension DailyScrollData {
    /// Sample daily data for previews
    static var sample: DailyScrollData {
        DailyScrollData(
            date: Date(),
            totalDuration: 3600, // 1 hour
            sessionCount: 8,
            interventionCount: 2
        )
    }
}

extension AppUsageSummary {
    /// Sample app usage for previews
    static var sample: AppUsageSummary {
        AppUsageSummary(
            appName: "Instagram",
            bundleId: "com.instagram.app",
            duration: 3600
        )
    }
}

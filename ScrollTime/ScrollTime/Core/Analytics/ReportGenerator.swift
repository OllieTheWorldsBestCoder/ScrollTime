//
//  ReportGenerator.swift
//  ScrollTime
//
//  Generates WeeklyReport objects from persisted session data.
//  Provides analysis of scroll patterns, intervention outcomes,
//  and usage trends for the analytics and insights system.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Report Generator

/// Service for generating weekly reports from persisted scroll session data.
/// Uses StatsProvider and DataManager to aggregate data into WeeklyReport objects.
@MainActor
@Observable
final class ReportGenerator {

    // MARK: - Singleton

    /// Shared instance for app-wide report generation
    static let shared = ReportGenerator()

    // MARK: - Published State

    /// The current week's report (automatically generated)
    private(set) var currentWeekReport: WeeklyReport?

    /// The previous week's report (for comparison)
    private(set) var previousWeekReport: WeeklyReport?

    /// Whether a report is currently being generated
    private(set) var isGenerating: Bool = false

    /// Last time reports were generated
    private(set) var lastGeneratedAt: Date?

    // MARK: - Dependencies

    private let dataManager: DataManager
    private let calendar: Calendar

    // MARK: - Initialization

    private init(dataManager: DataManager = .shared) {
        self.dataManager = dataManager
        self.calendar = Calendar.current

        // Generate initial reports
        Task {
            await generateReports()
        }
    }

    // MARK: - Public Methods

    /// Generates a WeeklyReport for a specific week.
    /// - Parameter weekStartDate: The start date of the week (typically Sunday or Monday)
    /// - Returns: A WeeklyReport containing aggregated data for that week
    func generateReport(for weekStartDate: Date) -> WeeklyReport {
        let normalizedStart = calendar.startOfDay(for: weekStartDate)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: normalizedStart) else {
            return createEmptyReport(for: normalizedStart)
        }

        // Get all sessions for this week
        let sessions = dataManager.getSessions(from: normalizedStart, to: weekEnd)

        // Get previous week's sessions for comparison
        guard let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: normalizedStart) else {
            return createEmptyReport(for: normalizedStart)
        }
        let previousWeekSessions = dataManager.getSessions(from: previousWeekStart, to: normalizedStart)
        let previousWeekScrollTime = calculateTotalScrollTime(from: previousWeekSessions)

        // Calculate metrics
        let totalScrollTime = calculateTotalScrollTime(from: sessions)
        let dailyBreakdown = getDailyBreakdown(from: normalizedStart, to: weekEnd)
        let topApps = getTopApps(sessions: sessions)
        let (interventionsTaken, interventionsCompleted) = calculateInterventionMetrics(from: sessions)
        let peakHour = findPeakHour(sessions: sessions)
        let (bestDay, bestDayDuration) = findBestDay(daily: dailyBreakdown)

        return WeeklyReport(
            weekStartDate: normalizedStart,
            totalScrollTime: totalScrollTime,
            previousWeekScrollTime: previousWeekScrollTime,
            dailyBreakdown: dailyBreakdown,
            topApps: topApps,
            interventionsTaken: interventionsTaken,
            interventionsCompleted: interventionsCompleted,
            peakScrollHour: peakHour,
            bestDay: bestDay,
            bestDayDuration: bestDayDuration
        )
    }

    /// Generates the current week's report and updates published state.
    func generateCurrentWeekReport() {
        isGenerating = true
        defer {
            isGenerating = false
            lastGeneratedAt = Date()
        }

        let weekStart = getWeekStartDate(for: Date())
        currentWeekReport = generateReport(for: weekStart)
    }

    /// Generates both current and previous week reports.
    func generateReports() async {
        isGenerating = true
        defer {
            isGenerating = false
            lastGeneratedAt = Date()
        }

        let currentWeekStart = getWeekStartDate(for: Date())
        currentWeekReport = generateReport(for: currentWeekStart)

        if let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) {
            previousWeekReport = generateReport(for: previousWeekStart)
        }
    }

    /// Refreshes reports if needed (e.g., after new session data)
    func refreshIfNeeded() {
        // Only regenerate if it's been more than 5 minutes since last generation
        if let lastGen = lastGeneratedAt,
           Date().timeIntervalSince(lastGen) < 300 {
            return
        }

        Task {
            await generateReports()
        }
    }

    // MARK: - Private Methods

    /// Gets the daily breakdown of scroll activity for a date range.
    /// - Parameters:
    ///   - from: Start date (inclusive)
    ///   - to: End date (exclusive)
    /// - Returns: Array of DailyScrollData for each day in the range
    private func getDailyBreakdown(from startDate: Date, to endDate: Date) -> [DailyScrollData] {
        var dailyData: [DailyScrollData] = []
        var currentDate = startDate

        while currentDate < endDate {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }

            let daySessions = dataManager.getSessions(from: currentDate, to: nextDay)

            let totalDuration = daySessions.reduce(0) { $0 + TimeInterval($1.durationSeconds) }
            let sessionCount = daySessions.count
            let interventionCount = daySessions.filter { $0.interventionShown }.count

            dailyData.append(DailyScrollData(
                date: currentDate,
                totalDuration: totalDuration,
                sessionCount: sessionCount,
                interventionCount: interventionCount
            ))

            currentDate = nextDay
        }

        return dailyData
    }

    /// Aggregates sessions by app and returns top apps sorted by usage duration.
    /// - Parameter sessions: Array of sessions to aggregate
    /// - Returns: Array of AppUsageSummary sorted by duration (descending)
    private func getTopApps(sessions: [PersistedScrollSession]) -> [AppUsageSummary] {
        // Group sessions by app bundle ID
        var appUsageDict: [String: (name: String, duration: TimeInterval)] = [:]

        for session in sessions {
            let existing = appUsageDict[session.appBundleId] ?? (session.appName, 0)
            appUsageDict[session.appBundleId] = (existing.name, existing.duration + TimeInterval(session.durationSeconds))
        }

        // Convert to AppUsageSummary and sort
        let summaries = appUsageDict.map { bundleId, data in
            AppUsageSummary(
                appName: data.name,
                bundleId: bundleId,
                duration: data.duration
            )
        }.sorted { $0.duration > $1.duration }

        // Return top 5 apps
        return Array(summaries.prefix(5))
    }

    /// Finds the hour of day with the most scrolling activity.
    /// - Parameter sessions: Array of sessions to analyze
    /// - Returns: Hour of day (0-23) with peak activity, defaults to 21 (9 PM) if no data
    private func findPeakHour(sessions: [PersistedScrollSession]) -> Int {
        guard !sessions.isEmpty else { return 21 } // Default to evening

        // Group scroll time by hour
        var hourlyDurations: [Int: TimeInterval] = [:]

        for session in sessions {
            let hour = calendar.component(.hour, from: session.startTime)
            let existingDuration = hourlyDurations[hour] ?? 0
            hourlyDurations[hour] = existingDuration + TimeInterval(session.durationSeconds)
        }

        // Find hour with maximum duration
        let peakHour = hourlyDurations.max { $0.value < $1.value }?.key ?? 21
        return peakHour
    }

    /// Finds the day with the least scrolling activity.
    /// - Parameter daily: Array of daily scroll data
    /// - Returns: Tuple of (date, duration) for the best day
    private func findBestDay(daily: [DailyScrollData]) -> (date: Date, duration: TimeInterval) {
        guard let bestDay = daily.min(by: { $0.totalDuration < $1.totalDuration }) else {
            return (Date(), 0)
        }
        return (bestDay.date, bestDay.totalDuration)
    }

    /// Calculates intervention metrics from sessions.
    /// - Parameter sessions: Array of sessions to analyze
    /// - Returns: Tuple of (interventionsTaken, interventionsCompleted)
    private func calculateInterventionMetrics(from sessions: [PersistedScrollSession]) -> (taken: Int, completed: Int) {
        let sessionsWithInterventions = sessions.filter { $0.interventionShown }
        let taken = sessionsWithInterventions.count
        let completed = sessionsWithInterventions.filter { $0.wasInterventionSuccessful }.count
        return (taken, completed)
    }

    /// Calculates total scroll time from an array of sessions.
    /// - Parameter sessions: Array of sessions
    /// - Returns: Total scroll time in seconds
    private func calculateTotalScrollTime(from sessions: [PersistedScrollSession]) -> TimeInterval {
        sessions.reduce(0) { $0 + TimeInterval($1.durationSeconds) }
    }

    /// Gets the start of the week for a given date.
    /// Uses Sunday as the first day of the week by default.
    /// - Parameter date: Any date within the week
    /// - Returns: The start of that week (Sunday at 00:00)
    private func getWeekStartDate(for date: Date) -> Date {
        var cal = calendar
        cal.firstWeekday = 1 // Sunday = 1

        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? cal.startOfDay(for: date)
    }

    /// Creates an empty report for a given week start date.
    /// - Parameter weekStartDate: The start date of the week
    /// - Returns: A WeeklyReport with zero values
    private func createEmptyReport(for weekStartDate: Date) -> WeeklyReport {
        WeeklyReport(
            weekStartDate: weekStartDate,
            totalScrollTime: 0,
            previousWeekScrollTime: 0,
            dailyBreakdown: [],
            topApps: [],
            interventionsTaken: 0,
            interventionsCompleted: 0,
            peakScrollHour: 21,
            bestDay: weekStartDate,
            bestDayDuration: 0
        )
    }
}

// MARK: - Preview Support

extension ReportGenerator {
    /// Creates a report generator with sample data for previews
    @MainActor
    static var preview: ReportGenerator {
        let generator = ReportGenerator.shared
        generator.currentWeekReport = .sample
        return generator
    }
}

// MARK: - SwiftUI Environment

private struct ReportGeneratorKey: EnvironmentKey {
    @MainActor
    static let defaultValue: ReportGenerator = .shared
}

extension EnvironmentValues {
    /// Access to the report generator
    var reportGenerator: ReportGenerator {
        get { self[ReportGeneratorKey.self] }
        set { self[ReportGeneratorKey.self] = newValue }
    }
}

extension View {
    /// Adds the report generator to the environment
    @MainActor
    func withReportGenerator() -> some View {
        self.environment(\.reportGenerator, ReportGenerator.shared)
    }
}

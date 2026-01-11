//
//  PatternAnalyzer.swift
//  ScrollTime
//
//  Analyzes user scroll sessions to generate meaningful insights.
//  Designed to surface helpful observations without judgment and
//  suggest actionable steps for mindful improvement.
//
//  Insight Philosophy:
//  - Warm, encouraging titles and messages
//  - Celebrate progress, no matter how small
//  - Offer gentle suggestions, not commands
//  - Insights should feel fresh and relevant
//

import Foundation
import Combine
import SwiftUI

// MARK: - Pattern Analyzer

/// Service that analyzes scroll patterns and generates insights.
/// Uses data from StatsProvider to detect behavioral patterns and
/// create encouraging, actionable insights for the user.
@MainActor
final class PatternAnalyzer: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide access
    static let shared = PatternAnalyzer()

    // MARK: - Published Properties

    /// Currently active insights, sorted by priority
    @Published private(set) var currentInsights: [Insight] = []

    /// Whether analysis is in progress
    @Published private(set) var isAnalyzing: Bool = false

    /// When the last analysis was performed
    @Published private(set) var lastAnalysisTime: Date?

    // MARK: - Private Properties

    private let statsProvider = StatsProvider.shared
    private let dataManager = DataManager.shared
    private var cancellables = Set<AnyCancellable>()

    /// Minimum sessions needed before generating meaningful insights
    private let minimumSessionsForAnalysis = 5

    /// Minimum days of data needed for trend analysis
    private let minimumDaysForTrends = 3

    /// Key for persisting insights
    private let insightsStorageKey = "com.scrolltime.insights"

    // MARK: - Initialization

    private init() {
        loadPersistedInsights()
        setupObservers()
    }

    // MARK: - Public Methods

    /// Analyzes recent sessions and generates insights.
    /// Call this when the app becomes active or after significant user activity.
    func analyzePatterns() async {
        guard !isAnalyzing else { return }

        isAnalyzing = true
        defer { isAnalyzing = false }

        // Refresh stats first
        await statsProvider.refreshAll()

        // Check if we have enough data
        let allSessions = getAllRecentSessions()
        guard allSessions.count >= minimumSessionsForAnalysis else {
            // Not enough data - show welcome insight for new users
            if currentInsights.isEmpty || currentInsights.allSatisfy({ $0.type != .welcomeInsight }) {
                addInsightIfNew(.welcome())
            }
            lastAnalysisTime = Date()
            return
        }

        // Generate insights from various pattern detectors
        var newInsights: [Insight] = []

        // Run all pattern detection methods
        if let peakInsight = detectPeakUsageTime() {
            newInsights.append(peakInsight)
        }

        if let bestDayInsight = detectBestDay() {
            newInsights.append(bestDayInsight)
        }

        if let appTrendInsight = detectAppTrends() {
            newInsights.append(appTrendInsight)
        }

        if let improvementInsight = detectImprovement() {
            newInsights.append(improvementInsight)
        }

        if let pauserInsight = detectConsistentPauser() {
            newInsights.append(pauserInsight)
        }

        if let weekendInsight = detectWeekendWarrior() {
            newInsights.append(weekendInsight)
        }

        if let morningInsight = detectMorningPerson() {
            newInsights.append(morningInsight)
        }

        if let nightOwlInsight = detectNightOwl() {
            newInsights.append(nightOwlInsight)
        }

        if let progressInsight = detectSteadyProgress() {
            newInsights.append(progressInsight)
        }

        if let attentionInsight = detectAttentionNeeded() {
            newInsights.append(attentionInsight)
        }

        // Add new insights, avoiding duplicates of the same type
        for insight in newInsights {
            addInsightIfNew(insight)
        }

        // Clean up expired insights
        filterExpiredInsights()

        // Sort by priority
        currentInsights.sort { $0.priority > $1.priority }

        // Persist insights
        persistInsights()

        lastAnalysisTime = Date()
    }

    /// Removes a specific insight
    func dismissInsight(_ insight: Insight) {
        currentInsights.removeAll { $0.id == insight.id }
        persistInsights()
    }

    /// Forces regeneration of all insights
    func refreshInsights() async {
        currentInsights.removeAll()
        await analyzePatterns()
    }

    // MARK: - Pattern Detection Methods

    /// Detects the hour with peak scrolling activity.
    /// Returns an insight if a clear peak hour is identified.
    private func detectPeakUsageTime() -> Insight? {
        let sessions = getAllRecentSessions()
        guard sessions.count >= minimumSessionsForAnalysis else { return nil }

        // Group sessions by hour of day
        var hourlyDurations: [Int: Int] = [:]
        let calendar = Calendar.current

        for session in sessions {
            let hour = calendar.component(.hour, from: session.startTime)
            hourlyDurations[hour, default: 0] += session.durationSeconds
        }

        guard !hourlyDurations.isEmpty else { return nil }

        // Find the peak hour
        let peakHour = hourlyDurations.max(by: { $0.value < $1.value })
        guard let peak = peakHour else { return nil }

        // Calculate if this peak is significantly higher than average
        let totalDuration = hourlyDurations.values.reduce(0, +)
        let averageDuration = totalDuration / max(hourlyDurations.count, 1)

        // Only report if peak is at least 50% higher than average
        guard peak.value > Int(Double(averageDuration) * 1.5) else { return nil }

        // Check if we already have a similar insight
        if hasSimilarInsight(ofType: .peakUsageTime(hour: peak.key)) {
            return nil
        }

        return .peakUsageTime(hour: peak.key)
    }

    /// Detects the day of week with consistently lower scroll time.
    private func detectBestDay() -> Insight? {
        let weeklyStats = statsProvider.weeklyStats
        guard weeklyStats.count >= minimumDaysForTrends else { return nil }

        // Find the day with minimum scroll time (excluding days with zero activity)
        let activeDays = weeklyStats.filter { $0.hasActivity }
        guard activeDays.count >= 3 else { return nil }

        let bestDay = activeDays.min(by: { $0.totalScrollTimeSeconds < $1.totalScrollTimeSeconds })
        guard let best = bestDay else { return nil }

        // Get day of week (1 = Sunday, 7 = Saturday)
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: best.date)

        // Calculate if this day is significantly better than average
        let totalSeconds = activeDays.reduce(0) { $0 + $1.totalScrollTimeSeconds }
        let averageSeconds = totalSeconds / activeDays.count

        // Only report if best day is at least 30% lower than average
        guard best.totalScrollTimeSeconds < Int(Double(averageSeconds) * 0.7) else { return nil }

        // Check for existing similar insight
        if hasSimilarInsight(ofType: .bestDay(dayOfWeek: dayOfWeek)) {
            return nil
        }

        return .bestDay(dayOfWeek: dayOfWeek)
    }

    /// Detects significant changes in per-app usage compared to previous week.
    private func detectAppTrends() -> Insight? {
        let weeklyStats = statsProvider.weeklyStats
        guard weeklyStats.count >= 7 else { return nil }

        // Split into this week (last 3-4 days) and previous (earlier days)
        let recentDays = Array(weeklyStats.suffix(3))
        let earlierDays = Array(weeklyStats.prefix(4))

        guard !recentDays.isEmpty && !earlierDays.isEmpty else { return nil }

        // Aggregate app usage for each period
        var recentAppUsage: [String: Int] = [:]
        var earlierAppUsage: [String: Int] = [:]

        for day in recentDays {
            for app in day.appUsage {
                recentAppUsage[app.appName, default: 0] += app.scrollTimeSeconds
            }
        }

        for day in earlierDays {
            for app in day.appUsage {
                earlierAppUsage[app.appName, default: 0] += app.scrollTimeSeconds
            }
        }

        // Normalize by number of days
        for (app, seconds) in recentAppUsage {
            recentAppUsage[app] = seconds / recentDays.count
        }
        for (app, seconds) in earlierAppUsage {
            earlierAppUsage[app] = seconds / earlierDays.count
        }

        // Find the most significant change (positive improvement preferred)
        var bestChange: (app: String, percent: Double)? = nil

        for (app, recentSeconds) in recentAppUsage {
            guard let earlierSeconds = earlierAppUsage[app], earlierSeconds > 60 else { continue }

            let changePercent = ((Double(earlierSeconds) - Double(recentSeconds)) / Double(earlierSeconds)) * 100

            // Only consider changes of at least 20%
            guard abs(changePercent) >= 20 else { continue }

            if let current = bestChange {
                // Prefer improvements (positive changes)
                if changePercent > 0 && (current.percent < 0 || changePercent > current.percent) {
                    bestChange = (app, changePercent)
                } else if changePercent < 0 && current.percent < 0 && changePercent < current.percent {
                    bestChange = (app, changePercent)
                }
            } else {
                bestChange = (app, changePercent)
            }
        }

        guard let change = bestChange else { return nil }

        // Check for existing similar insight
        if hasSimilarInsight(ofType: .appTrend(appName: change.app, changePercent: change.percent)) {
            return nil
        }

        // Note: changePercent is positive for improvement, negative for increase
        // The Insight factory expects negative for decrease, positive for increase
        return .appTrend(appName: change.app, changePercent: -change.percent)
    }

    /// Detects overall scroll time improvement compared to previous period.
    private func detectImprovement() -> Insight? {
        let weeklyStats = statsProvider.weeklyStats
        guard weeklyStats.count >= minimumDaysForTrends else { return nil }

        // Compare recent half vs earlier half
        let midpoint = weeklyStats.count / 2
        let recentDays = Array(weeklyStats.suffix(from: midpoint))
        let earlierDays = Array(weeklyStats.prefix(midpoint))

        guard !recentDays.isEmpty && !earlierDays.isEmpty else { return nil }

        let recentAverage = recentDays.reduce(0) { $0 + $1.totalScrollTimeSeconds } / recentDays.count
        let earlierAverage = earlierDays.reduce(0) { $0 + $1.totalScrollTimeSeconds } / earlierDays.count

        // Need earlier activity to compare against
        guard earlierAverage > 120 else { return nil } // At least 2 minutes average

        let percentDecrease = ((Double(earlierAverage) - Double(recentAverage)) / Double(earlierAverage)) * 100

        // Only celebrate improvements of at least 10%
        guard percentDecrease >= 10 else { return nil }

        // Check for existing similar insight
        if hasSimilarInsight(ofType: .improvementNotice(percentDecrease: percentDecrease)) {
            return nil
        }

        return .improvementNotice(percentDecrease: percentDecrease)
    }

    /// Detects if user consistently completes interventions (>80% success rate).
    private func detectConsistentPauser() -> Insight? {
        let sessions = getAllRecentSessions()

        // Filter to sessions with interventions
        let sessionsWithInterventions = sessions.filter { $0.interventionShown }

        // Need at least 5 interventions to assess consistency
        guard sessionsWithInterventions.count >= 5 else { return nil }

        let successfulInterventions = sessionsWithInterventions.filter { $0.wasInterventionSuccessful }
        let successRate = Double(successfulInterventions.count) / Double(sessionsWithInterventions.count)

        // Must have >80% success rate
        guard successRate > 0.8 else { return nil }

        // Check for existing similar insight
        if hasSimilarInsight(ofType: .consistentPauser) {
            return nil
        }

        return .consistentPauser()
    }

    /// Detects if weekend scroll time is significantly lower than weekdays.
    private func detectWeekendWarrior() -> Insight? {
        let weeklyStats = statsProvider.weeklyStats
        guard weeklyStats.count >= 7 else { return nil }

        let calendar = Calendar.current

        var weekdayTotal = 0
        var weekdayCount = 0
        var weekendTotal = 0
        var weekendCount = 0

        for day in weeklyStats where day.hasActivity {
            let weekday = calendar.component(.weekday, from: day.date)
            let isWeekend = weekday == 1 || weekday == 7 // Sunday or Saturday

            if isWeekend {
                weekendTotal += day.totalScrollTimeSeconds
                weekendCount += 1
            } else {
                weekdayTotal += day.totalScrollTimeSeconds
                weekdayCount += 1
            }
        }

        // Need data for both periods
        guard weekdayCount >= 2 && weekendCount >= 1 else { return nil }

        let weekdayAverage = weekdayTotal / weekdayCount
        let weekendAverage = weekendTotal / weekendCount

        // Weekend must be at least 30% lower than weekdays
        guard weekdayAverage > 0 else { return nil }
        let reduction = ((Double(weekdayAverage) - Double(weekendAverage)) / Double(weekdayAverage)) * 100

        guard reduction >= 30 else { return nil }

        // Check for existing similar insight
        if hasSimilarInsight(ofType: .weekendWarrior) {
            return nil
        }

        return .weekendWarrior()
    }

    /// Detects if morning scroll time is significantly lower than afternoon/evening.
    private func detectMorningPerson() -> Insight? {
        let sessions = getAllRecentSessions()
        guard sessions.count >= minimumSessionsForAnalysis else { return nil }

        let calendar = Calendar.current

        var morningDuration = 0  // Before noon (12 PM)
        var afternoonDuration = 0 // Noon to 8 PM
        var morningCount = 0
        var afternoonCount = 0

        for session in sessions {
            let hour = calendar.component(.hour, from: session.startTime)

            if hour < 12 {
                morningDuration += session.durationSeconds
                morningCount += 1
            } else if hour < 20 {
                afternoonDuration += session.durationSeconds
                afternoonCount += 1
            }
        }

        // Need meaningful data in both periods
        guard morningCount >= 2 && afternoonCount >= 3 else { return nil }

        let morningAverage = morningDuration / morningCount
        let afternoonAverage = afternoonDuration / afternoonCount

        // Morning must be at least 50% lower than afternoon
        guard afternoonAverage > 60 else { return nil } // At least 1 minute average
        let reduction = ((Double(afternoonAverage) - Double(morningAverage)) / Double(afternoonAverage)) * 100

        guard reduction >= 50 else { return nil }

        // Check for existing similar insight
        if hasSimilarInsight(ofType: .morningPerson) {
            return nil
        }

        return .morningPerson()
    }

    /// Detects if evening (after 8 PM) is the peak scroll time.
    private func detectNightOwl() -> Insight? {
        let sessions = getAllRecentSessions()
        guard sessions.count >= minimumSessionsForAnalysis else { return nil }

        let calendar = Calendar.current

        var eveningDuration = 0  // After 8 PM
        var otherDuration = 0    // Before 8 PM

        for session in sessions {
            let hour = calendar.component(.hour, from: session.startTime)

            if hour >= 20 {
                eveningDuration += session.durationSeconds
            } else {
                otherDuration += session.durationSeconds
            }
        }

        let totalDuration = eveningDuration + otherDuration
        guard totalDuration > 0 else { return nil }

        // Evening must account for at least 50% of total scroll time
        let eveningPercent = (Double(eveningDuration) / Double(totalDuration)) * 100

        guard eveningPercent >= 50 else { return nil }

        // Check for existing similar insight
        if hasSimilarInsight(ofType: .nightOwl) {
            return nil
        }

        return .nightOwl()
    }

    /// Detects if user has been consistently under their goal.
    private func detectSteadyProgress() -> Insight? {
        let weeklyStats = statsProvider.weeklyStats
        let goalMinutes = statsProvider.dailyGoalMinutes

        guard weeklyStats.count >= 7 else { return nil }

        let daysOnTrack = weeklyStats.filter { $0.isUnderGoal(goalMinutes: goalMinutes) }.count

        // Need at least 4 days under goal to celebrate
        guard daysOnTrack >= 4 else { return nil }

        // Check for existing similar insight
        if hasSimilarInsight(ofType: .steadyProgress(daysOnTrack: daysOnTrack)) {
            return nil
        }

        return .steadyProgress(daysOnTrack: daysOnTrack)
    }

    /// Detects if scroll time has significantly increased and gently alerts the user.
    private func detectAttentionNeeded() -> Insight? {
        let weeklyStats = statsProvider.weeklyStats
        guard weeklyStats.count >= minimumDaysForTrends else { return nil }

        // Compare recent half vs earlier half
        let midpoint = weeklyStats.count / 2
        let recentDays = Array(weeklyStats.suffix(from: midpoint))
        let earlierDays = Array(weeklyStats.prefix(midpoint))

        guard !recentDays.isEmpty && !earlierDays.isEmpty else { return nil }

        let recentAverage = recentDays.reduce(0) { $0 + $1.totalScrollTimeSeconds } / recentDays.count
        let earlierAverage = earlierDays.reduce(0) { $0 + $1.totalScrollTimeSeconds } / earlierDays.count

        // Need earlier activity to compare against
        guard earlierAverage > 60 else { return nil } // At least 1 minute average

        let percentIncrease = ((Double(recentAverage) - Double(earlierAverage)) / Double(earlierAverage)) * 100

        // Only alert for increases of at least 25%
        guard percentIncrease >= 25 else { return nil }

        // Check for existing similar insight
        if hasSimilarInsight(ofType: .attentionNeeded(percentIncrease: percentIncrease)) {
            return nil
        }

        return .attentionNeeded(percentIncrease: percentIncrease)
    }

    // MARK: - Helper Methods

    /// Gets all sessions from the past 14 days for analysis.
    private func getAllRecentSessions() -> [PersistedScrollSession] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -14, to: Date()) else {
            return []
        }
        return dataManager.getSessions(from: startDate, to: Date())
    }

    /// Checks if we already have a similar insight (same type) that hasn't expired.
    private func hasSimilarInsight(ofType type: InsightType) -> Bool {
        for insight in currentInsights {
            guard !insight.isExpired else { continue }

            switch (insight.type, type) {
            case (.peakUsageTime, .peakUsageTime),
                 (.bestDay, .bestDay),
                 (.consistentPauser, .consistentPauser),
                 (.weekendWarrior, .weekendWarrior),
                 (.morningPerson, .morningPerson),
                 (.nightOwl, .nightOwl),
                 (.welcomeInsight, .welcomeInsight):
                return true
            case (.appTrend(let name1, _), .appTrend(let name2, _)):
                return name1 == name2
            case (.improvementNotice, .improvementNotice),
                 (.attentionNeeded, .attentionNeeded),
                 (.steadyProgress, .steadyProgress):
                return true
            default:
                continue
            }
        }
        return false
    }

    /// Adds an insight if we don't already have a similar one.
    private func addInsightIfNew(_ insight: Insight) {
        if !hasSimilarInsight(ofType: insight.type) {
            currentInsights.append(insight)
        }
    }

    /// Removes insights that have expired.
    private func filterExpiredInsights() {
        currentInsights.removeAll { $0.isExpired }
    }

    // MARK: - Observers

    /// Sets up observers for automatic analysis.
    private func setupObservers() {
        // Analyze when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.analyzePatterns()
                }
            }
            .store(in: &cancellables)

        // Analyze at midnight
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.analyzePatterns()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Persistence

    /// Persists current insights to UserDefaults.
    private func persistInsights() {
        do {
            let data = try JSONEncoder().encode(currentInsights)
            UserDefaults.standard.set(data, forKey: insightsStorageKey)
        } catch {
            print("PatternAnalyzer: Failed to persist insights: \(error)")
        }
    }

    /// Loads persisted insights from UserDefaults.
    private func loadPersistedInsights() {
        guard let data = UserDefaults.standard.data(forKey: insightsStorageKey) else { return }

        do {
            currentInsights = try JSONDecoder().decode([Insight].self, from: data)
            // Clean up any expired insights on load
            filterExpiredInsights()
        } catch {
            print("PatternAnalyzer: Failed to load persisted insights: \(error)")
            currentInsights = []
        }
    }
}

// MARK: - Preview Support

extension PatternAnalyzer {
    /// Creates sample insights for previews.
    @MainActor
    static var preview: PatternAnalyzer {
        let analyzer = PatternAnalyzer.shared
        analyzer.currentInsights = Insight.sampleCollection
        return analyzer
    }
}

// MARK: - SwiftUI Environment

/// Environment key for PatternAnalyzer
private struct PatternAnalyzerKey: EnvironmentKey {
    @MainActor
    static let defaultValue: PatternAnalyzer = .shared
}

extension EnvironmentValues {
    /// Access to the pattern analyzer
    var patternAnalyzer: PatternAnalyzer {
        get { self[PatternAnalyzerKey.self] }
        set { self[PatternAnalyzerKey.self] = newValue }
    }
}

extension View {
    /// Adds the pattern analyzer to the environment.
    @MainActor
    func withPatternAnalyzer() -> some View {
        self.environment(\.patternAnalyzer, PatternAnalyzer.shared)
    }
}

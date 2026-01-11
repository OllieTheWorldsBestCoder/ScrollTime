//
//  StatsProvider.swift
//  ScrollTime
//
//  A SwiftUI-friendly stats provider that publishes real-time statistics
//  from the DataManager. Use this in your views for reactive updates.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Stats Provider

/// Observable stats provider for SwiftUI views.
/// Provides reactive access to daily and weekly statistics.
@MainActor
@Observable
final class StatsProvider {

    // MARK: - Singleton

    /// Shared instance for app-wide stats access
    static let shared = StatsProvider()

    // MARK: - Published Stats

    /// Today's statistics
    private(set) var todayStats: DailyStats = .empty

    /// Weekly statistics (past 7 days)
    private(set) var weeklyStats: [DailyStats] = []

    /// Weekly aggregate
    private(set) var weeklyAggregate: WeeklyStats?

    /// Recent sessions (last 10)
    private(set) var recentSessions: [PersistedScrollSession] = []

    /// Whether data is currently loading
    private(set) var isLoading: Bool = false

    /// Last refresh time
    private(set) var lastRefresh: Date?

    // MARK: - User Preferences

    /// Daily goal from user preferences (for goal tracking)
    var dailyGoalMinutes: Int = 60

    // MARK: - Private Properties

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Initial load
        Task {
            await refreshAll()
        }

        // Set up periodic refresh (every 30 seconds when app is active)
        setupPeriodicRefresh()

        // Listen for significant time changes
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshAll()
                }
            }
            .store(in: &cancellables)

        // Refresh when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshAll()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Refresh Methods

    /// Refreshes all statistics from the data manager.
    func refreshAll() async {
        isLoading = true
        defer { isLoading = false }

        let dataManager = DataManager.shared

        // Refresh DataManager's today stats first
        await dataManager.refreshTodayStats()

        // Get fresh data
        todayStats = dataManager.getDailyStats(for: Date())
        weeklyStats = dataManager.getWeeklyStats()
        weeklyAggregate = dataManager.getWeeklyAggregate()
        recentSessions = dataManager.getRecentSessions(limit: 10)
        lastRefresh = Date()
    }

    /// Refreshes only today's stats (faster)
    func refreshToday() async {
        let dataManager = DataManager.shared
        await dataManager.refreshTodayStats()
        todayStats = dataManager.getDailyStats(for: Date())
        lastRefresh = Date()
    }

    // MARK: - Goal Tracking

    /// Time remaining under daily goal (in minutes)
    var timeUnderGoal: Int {
        todayStats.timeFromGoal(goalMinutes: dailyGoalMinutes)
    }

    /// Whether currently under the daily goal
    var isUnderDailyGoal: Bool {
        todayStats.isUnderGoal(goalMinutes: dailyGoalMinutes)
    }

    /// Goal progress as a percentage (0.0 to 1.0+)
    var goalProgress: Double {
        todayStats.goalProgress(goalMinutes: dailyGoalMinutes)
    }

    /// Formatted goal status string
    var goalStatusText: String {
        todayStats.formattedGoalStatus(goalMinutes: dailyGoalMinutes)
    }

    /// Days under goal this week
    var daysUnderGoalThisWeek: Int {
        weeklyStats.filter { $0.isUnderGoal(goalMinutes: dailyGoalMinutes) }.count
    }

    // MARK: - Trend Analysis

    /// Whether the user is improving this week
    var isImprovingThisWeek: Bool {
        weeklyAggregate?.isImproving ?? false
    }

    /// Trend direction (-1.0 to 1.0, positive is improving)
    var trendDirection: Double {
        weeklyAggregate?.trendDirection ?? 0
    }

    /// Formatted trend text
    var trendText: String {
        let direction = trendDirection
        if direction > 0.1 {
            return "Improving"
        } else if direction < -0.1 {
            return "Needs attention"
        }
        return "Steady"
    }

    // MARK: - Private Methods

    private func setupPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshToday()
            }
        }
    }

    // Note: Since this is a singleton, deinit should never be called.
    // Timer cleanup is handled by the Timer's weak reference to self.
}

// MARK: - SwiftUI Environment

/// Environment key for StatsProvider
private struct StatsProviderKey: EnvironmentKey {
    @MainActor
    static let defaultValue: StatsProvider = .shared
}

extension EnvironmentValues {
    /// Access to the stats provider
    var statsProvider: StatsProvider {
        get { self[StatsProviderKey.self] }
        set { self[StatsProviderKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    /// Adds the stats provider to the environment
    @MainActor
    func withStatsProvider() -> some View {
        self.environment(\.statsProvider, StatsProvider.shared)
    }
}

// MARK: - Stats Summary

/// A lightweight summary of key stats for dashboard display
struct StatsSummary {
    let todayScrollMinutes: Int
    let todaySessions: Int
    let todayInterventions: Int
    let successRate: Double
    let weeklyAverageMinutes: Int
    let isUnderGoal: Bool
    let goalProgress: Double
    let isImproving: Bool

    @MainActor
    init(from provider: StatsProvider) {
        self.todayScrollMinutes = provider.todayStats.totalScrollTimeMinutes
        self.todaySessions = provider.todayStats.scrollSessionCount
        self.todayInterventions = provider.todayStats.interventionCount
        self.successRate = provider.todayStats.interventionSuccessRate
        self.weeklyAverageMinutes = provider.weeklyAggregate?.averageDailyScrollMinutes ?? 0
        self.isUnderGoal = provider.isUnderDailyGoal
        self.goalProgress = provider.goalProgress
        self.isImproving = provider.isImprovingThisWeek
    }
}

// MARK: - Preview Support

extension StatsProvider {
    /// Creates a preview instance with sample data
    @MainActor
    static var preview: StatsProvider {
        let provider = StatsProvider.shared
        provider.todayStats = .sample
        provider.weeklyStats = DailyStats.sampleWeek
        provider.weeklyAggregate = .sample
        provider.recentSessions = PersistedScrollSession.sampleDay
        return provider
    }
}

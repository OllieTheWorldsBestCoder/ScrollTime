//
//  MilestoneTracker.swift
//  ScrollTime
//
//  Tracks user progress and triggers milestone achievements with a
//  gentle, encouraging approach. Celebrates progress without guilt -
//  when streaks "break", we don't announce it, just offer a fresh start.
//
//  Philosophy: GENTLE CELEBRATION
//  - Always frame progress positively
//  - Never guilt or shame the user
//  - Celebrate small wins
//  - Offer fresh starts, not broken streaks
//

import Foundation
import Combine
import SwiftUI

// MARK: - Milestone Tracker

/// Tracks user progress toward milestones and manages achievement celebrations.
/// Uses a positive, encouraging approach - never guilt, only celebration.
@MainActor
@Observable
final class MilestoneTracker {

    // MARK: - Singleton

    /// Shared instance for app-wide milestone tracking
    static let shared = MilestoneTracker()

    // MARK: - Published State

    /// All milestones the user has achieved
    private(set) var achievedMilestones: [Milestone] = []

    /// The next milestone ready to be celebrated (not yet acknowledged by user)
    private(set) var pendingCelebration: Milestone?

    /// Current mindful streak information
    private(set) var currentStreak: MindfulStreak = .fresh

    /// Total hours reclaimed from mindless scrolling
    private(set) var totalHoursReclaimed: Double = 0

    /// Total number of breathing exercises completed
    private(set) var totalBreathingExercises: Int = 0

    /// Total number of mindful days (non-consecutive)
    private(set) var totalMindfulDays: Int = 0

    /// Whether the user has mastered interventions this week (90%+ completion)
    private(set) var hasInterventionsMastered: Bool = false

    /// Whether this week is an improving week
    private(set) var isFirstImprovingWeek: Bool = false

    // MARK: - Dependencies

    private var statsProvider: StatsProvider { StatsProvider.shared }
    private var dataManager: DataManager { DataManager.shared }

    // MARK: - Configuration

    /// Daily goal in minutes (synced with user preferences)
    var dailyGoalMinutes: Int = 60

    /// Estimated extra time user would have scrolled without intervention (minutes)
    private let estimatedSavedTimePerIntervention: Double = 10.0

    // MARK: - Persistence Keys

    private let achievedMilestonesKey = "com.scrolltime.achievedMilestones"
    private let currentStreakKey = "com.scrolltime.currentStreak"
    private let totalBreathingExercisesKey = "com.scrolltime.totalBreathingExercises"
    private let totalMindfulDaysKey = "com.scrolltime.totalMindfulDays"
    private let lastCheckedDateKey = "com.scrolltime.lastMilestoneCheckDate"
    private let hasAchievedImprovingWeekKey = "com.scrolltime.hasAchievedImprovingWeek"
    private let hasAchievedInterventionsMasteredKey = "com.scrolltime.hasAchievedInterventionsMastered"

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var hasCompletedInitialLoad = false

    // MARK: - Initialization

    private init() {
        loadPersistedData()
        setupObservers()

        // Check milestones after initial load
        Task {
            await statsProvider.refreshAll()
            checkMilestones()
            hasCompletedInitialLoad = true
        }
    }

    // MARK: - Public Methods

    /// Checks for new milestones based on current progress.
    /// Call this after significant events (session end, day change, etc.)
    func checkMilestones() {
        // Update calculated values
        updateCalculatedValues()

        // Check each milestone type
        var newMilestones: [Milestone] = []

        if let milestone = checkFirstMindfulDay() {
            newMilestones.append(milestone)
        }

        if let milestone = checkStreakMilestones() {
            newMilestones.append(milestone)
        }

        if let milestone = checkHoursReclaimedMilestones() {
            newMilestones.append(milestone)
        }

        if let milestone = checkBreathingMilestones() {
            newMilestones.append(milestone)
        }

        if let milestone = checkTotalMindfulDaysMilestones() {
            newMilestones.append(milestone)
        }

        if let milestone = checkInterventionsMastered() {
            newMilestones.append(milestone)
        }

        if let milestone = checkFirstImprovingWeek() {
            newMilestones.append(milestone)
        }

        // Add new milestones and set pending celebration
        for milestone in newMilestones {
            achievedMilestones.append(milestone)
        }

        // Set the first uncelebrated milestone as pending
        if pendingCelebration == nil, let uncelebrated = newMilestones.first {
            pendingCelebration = uncelebrated
        }

        // Persist changes
        if !newMilestones.isEmpty {
            savePersistedData()
        }
    }

    /// Updates the streak at the end of the day.
    /// Call this when checking if today was a mindful day.
    func updateStreakForToday() {
        let todayStats = statsProvider.todayStats
        let wasUnderGoal = todayStats.isUnderGoal(goalMinutes: dailyGoalMinutes)

        if wasUnderGoal {
            currentStreak.recordUnderGoalDay()

            // Track total mindful days (only increment once per day)
            let today = Calendar.current.startOfDay(for: Date())
            if currentStreak.lastUnderGoalDate == today {
                // Check if this is a new mindful day we haven't counted
                let lastChecked = UserDefaults.standard.object(forKey: lastCheckedDateKey) as? Date
                let lastCheckedDay = lastChecked.map { Calendar.current.startOfDay(for: $0) }

                if lastCheckedDay != today {
                    totalMindfulDays += 1
                    UserDefaults.standard.set(today, forKey: lastCheckedDateKey)
                }
            }
        } else {
            // Quietly check if streak needs reset - no announcement
            currentStreak.checkAndResetIfNeeded()
        }

        savePersistedData()
        checkMilestones()
    }

    /// Calculates the total time reclaimed from interventions.
    /// Includes actual intervention time + estimated "would have scrolled" time.
    func calculateTimeReclaimed() -> Double {
        let sessions = getAllSessionsWithInterventions()

        var totalMinutes: Double = 0

        for session in sessions {
            guard session.interventionShown else { continue }

            // Add actual intervention duration (converted to minutes)
            if let interventionType = session.interventionType {
                totalMinutes += interventionType.defaultDuration / 60.0
            }

            // Add estimated saved time for successful interventions
            if session.wasInterventionSuccessful {
                totalMinutes += estimatedSavedTimePerIntervention
            }
        }

        return totalMinutes / 60.0 // Convert to hours
    }

    /// Marks a milestone as celebrated (user has acknowledged it).
    func markCelebrated(_ milestone: Milestone) {
        if let index = achievedMilestones.firstIndex(where: { $0.id == milestone.id }) {
            achievedMilestones[index].celebrated = true
        }

        // Clear pending celebration
        if pendingCelebration?.id == milestone.id {
            // Find next uncelebrated milestone
            pendingCelebration = achievedMilestones.first { !$0.celebrated }
        }

        savePersistedData()
    }

    /// Gets the next milestones the user is working toward.
    func getNextMilestones() -> [MilestoneType] {
        var nextMilestones: [MilestoneType] = []

        // Next streak milestone
        let achievedStreaks = achievedMilestones.compactMap { milestone -> Int? in
            if case .streakDays(let days) = milestone.type { return days }
            return nil
        }

        if let nextStreakThreshold = MilestoneType.streakThresholds.first(where: { !achievedStreaks.contains($0) }) {
            nextMilestones.append(.streakDays(nextStreakThreshold))
        }

        // Next hours reclaimed milestone
        let achievedHours = achievedMilestones.compactMap { milestone -> Int? in
            if case .hoursReclaimed(let hours) = milestone.type { return hours }
            return nil
        }

        if let nextHoursThreshold = MilestoneType.hoursThresholds.first(where: { !achievedHours.contains($0) }) {
            nextMilestones.append(.hoursReclaimed(nextHoursThreshold))
        }

        // Next breathing milestone
        let achievedBreathing = achievedMilestones.compactMap { milestone -> Int? in
            if case .breathingExercises(let count) = milestone.type { return count }
            return nil
        }

        if let nextBreathingThreshold = MilestoneType.breathingThresholds.first(where: { !achievedBreathing.contains($0) }) {
            nextMilestones.append(.breathingExercises(nextBreathingThreshold))
        }

        // Next total mindful days milestone
        let achievedTotalDays = achievedMilestones.compactMap { milestone -> Int? in
            if case .totalMindfulDays(let days) = milestone.type { return days }
            return nil
        }

        if let nextTotalDaysThreshold = MilestoneType.totalDaysThresholds.first(where: { !achievedTotalDays.contains($0) }) {
            nextMilestones.append(.totalMindfulDays(nextTotalDaysThreshold))
        }

        return nextMilestones
    }

    /// Records a completed breathing exercise.
    func recordBreathingExercise() {
        totalBreathingExercises += 1
        savePersistedData()
        checkMilestones()
    }

    /// Gets progress toward a specific milestone type.
    func getProgress(for milestoneType: MilestoneType) -> (current: Int, target: Int)? {
        switch milestoneType {
        case .firstMindfulDay:
            return totalMindfulDays > 0 ? nil : (totalMindfulDays, 1)

        case .streakDays(let target):
            return (currentStreak.currentStreak, target)

        case .hoursReclaimed(let target):
            return (Int(totalHoursReclaimed), target)

        case .breathingExercises(let target):
            return (totalBreathingExercises, target)

        case .totalMindfulDays(let target):
            return (totalMindfulDays, target)

        case .interventionsMastered:
            let weeklyStats = statsProvider.weeklyAggregate
            let successRate = weeklyStats?.overallSuccessRate ?? 0
            return (Int(successRate * 100), 90)

        case .firstImprovingWeek:
            let isImproving = statsProvider.isImprovingThisWeek
            return isImproving ? nil : (0, 1)
        }
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Refresh when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.currentStreak.checkAndResetIfNeeded()
                    self?.checkMilestones()
                }
            }
            .store(in: &cancellables)

        // Check at midnight
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateStreakForToday()
                }
            }
            .store(in: &cancellables)
    }

    private func updateCalculatedValues() {
        // Update hours reclaimed
        totalHoursReclaimed = calculateTimeReclaimed()

        // Update intervention mastery status
        if let weeklyStats = statsProvider.weeklyAggregate {
            hasInterventionsMastered = weeklyStats.overallSuccessRate >= 0.9
            isFirstImprovingWeek = weeklyStats.isImproving
        }
    }

    // MARK: - Milestone Checkers

    private func checkFirstMindfulDay() -> Milestone? {
        // Check if we've already achieved this
        let hasAchieved = achievedMilestones.contains { $0.type == .firstMindfulDay }
        guard !hasAchieved else { return nil }

        // Check if today or any day was under goal
        guard totalMindfulDays >= 1 else { return nil }

        return Milestone(type: .firstMindfulDay)
    }

    private func checkStreakMilestones() -> Milestone? {
        let currentStreakDays = currentStreak.currentStreak
        guard currentStreakDays > 0 else { return nil }

        // Get achieved streak thresholds
        let achievedThresholds = achievedMilestones.compactMap { milestone -> Int? in
            if case .streakDays(let days) = milestone.type { return days }
            return nil
        }

        // Find the highest threshold we've reached but haven't achieved yet
        for threshold in MilestoneType.streakThresholds {
            if currentStreakDays >= threshold && !achievedThresholds.contains(threshold) {
                return Milestone(type: .streakDays(threshold))
            }
        }

        return nil
    }

    private func checkHoursReclaimedMilestones() -> Milestone? {
        let hours = Int(totalHoursReclaimed)
        guard hours > 0 else { return nil }

        // Get achieved hours thresholds
        let achievedThresholds = achievedMilestones.compactMap { milestone -> Int? in
            if case .hoursReclaimed(let h) = milestone.type { return h }
            return nil
        }

        // Find the highest threshold we've reached but haven't achieved yet
        for threshold in MilestoneType.hoursThresholds {
            if hours >= threshold && !achievedThresholds.contains(threshold) {
                return Milestone(type: .hoursReclaimed(threshold))
            }
        }

        return nil
    }

    private func checkBreathingMilestones() -> Milestone? {
        guard totalBreathingExercises > 0 else { return nil }

        // Get achieved breathing thresholds
        let achievedThresholds = achievedMilestones.compactMap { milestone -> Int? in
            if case .breathingExercises(let count) = milestone.type { return count }
            return nil
        }

        // Find the highest threshold we've reached but haven't achieved yet
        for threshold in MilestoneType.breathingThresholds {
            if totalBreathingExercises >= threshold && !achievedThresholds.contains(threshold) {
                return Milestone(type: .breathingExercises(threshold))
            }
        }

        return nil
    }

    private func checkTotalMindfulDaysMilestones() -> Milestone? {
        guard totalMindfulDays > 0 else { return nil }

        // Get achieved total days thresholds
        let achievedThresholds = achievedMilestones.compactMap { milestone -> Int? in
            if case .totalMindfulDays(let days) = milestone.type { return days }
            return nil
        }

        // Find the highest threshold we've reached but haven't achieved yet
        for threshold in MilestoneType.totalDaysThresholds {
            if totalMindfulDays >= threshold && !achievedThresholds.contains(threshold) {
                return Milestone(type: .totalMindfulDays(threshold))
            }
        }

        return nil
    }

    private func checkInterventionsMastered() -> Milestone? {
        // Only achieve this once
        let hasAchieved = achievedMilestones.contains { $0.type == .interventionsMastered }
        guard !hasAchieved else { return nil }

        // Check if already achieved in a previous session
        let previouslyAchieved = UserDefaults.standard.bool(forKey: hasAchievedInterventionsMasteredKey)
        guard !previouslyAchieved else { return nil }

        // Need at least a week of data with interventions
        guard let weeklyStats = statsProvider.weeklyAggregate,
              weeklyStats.totalInterventions >= 5,
              weeklyStats.overallSuccessRate >= 0.9 else {
            return nil
        }

        UserDefaults.standard.set(true, forKey: hasAchievedInterventionsMasteredKey)
        return Milestone(type: .interventionsMastered)
    }

    private func checkFirstImprovingWeek() -> Milestone? {
        // Only achieve this once
        let hasAchieved = achievedMilestones.contains { $0.type == .firstImprovingWeek }
        guard !hasAchieved else { return nil }

        // Check if already achieved in a previous session
        let previouslyAchieved = UserDefaults.standard.bool(forKey: hasAchievedImprovingWeekKey)
        guard !previouslyAchieved else { return nil }

        // Need at least a week of data
        guard let weeklyStats = statsProvider.weeklyAggregate,
              weeklyStats.dailyStats.count >= 7,
              weeklyStats.isImproving else {
            return nil
        }

        UserDefaults.standard.set(true, forKey: hasAchievedImprovingWeekKey)
        return Milestone(type: .firstImprovingWeek)
    }

    // MARK: - Data Helpers

    private func getAllSessionsWithInterventions() -> [PersistedScrollSession] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        return dataManager.getSessions(from: startDate, to: Date())
            .filter { $0.interventionShown }
    }

    // MARK: - Persistence

    private func loadPersistedData() {
        // Load achieved milestones
        if let data = UserDefaults.standard.data(forKey: achievedMilestonesKey),
           let milestones = try? JSONDecoder().decode([Milestone].self, from: data) {
            achievedMilestones = milestones
            pendingCelebration = milestones.first { !$0.celebrated }
        }

        // Load current streak
        if let data = UserDefaults.standard.data(forKey: currentStreakKey),
           let streak = try? JSONDecoder().decode(MindfulStreak.self, from: data) {
            currentStreak = streak
            currentStreak.checkAndResetIfNeeded()
        }

        // Load breathing exercises count
        totalBreathingExercises = UserDefaults.standard.integer(forKey: totalBreathingExercisesKey)

        // Load total mindful days
        totalMindfulDays = UserDefaults.standard.integer(forKey: totalMindfulDaysKey)
    }

    private func savePersistedData() {
        // Save achieved milestones
        if let data = try? JSONEncoder().encode(achievedMilestones) {
            UserDefaults.standard.set(data, forKey: achievedMilestonesKey)
        }

        // Save current streak
        if let data = try? JSONEncoder().encode(currentStreak) {
            UserDefaults.standard.set(data, forKey: currentStreakKey)
        }

        // Save breathing exercises count
        UserDefaults.standard.set(totalBreathingExercises, forKey: totalBreathingExercisesKey)

        // Save total mindful days
        UserDefaults.standard.set(totalMindfulDays, forKey: totalMindfulDaysKey)
    }
}

// MARK: - SwiftUI Environment

/// Environment key for MilestoneTracker
private struct MilestoneTrackerKey: EnvironmentKey {
    @MainActor
    static let defaultValue: MilestoneTracker = .shared
}

extension EnvironmentValues {
    /// Access to the milestone tracker
    var milestoneTracker: MilestoneTracker {
        get { self[MilestoneTrackerKey.self] }
        set { self[MilestoneTrackerKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    /// Adds the milestone tracker to the environment.
    @MainActor
    func withMilestoneTracker() -> some View {
        self.environment(\.milestoneTracker, MilestoneTracker.shared)
    }
}

// MARK: - Convenience Extensions

extension MilestoneTracker {
    /// Whether there's a milestone waiting to be celebrated
    var hasPendingCelebration: Bool {
        pendingCelebration != nil
    }

    /// Total count of achieved milestones
    var achievementCount: Int {
        achievedMilestones.count
    }

    /// Most recent milestone achieved
    var latestMilestone: Milestone? {
        achievedMilestones.max { $0.achievedAt < $1.achievedAt }
    }

    /// Gets milestones of a specific type
    func milestones(ofType type: MilestoneType) -> [Milestone] {
        achievedMilestones.filter { milestone in
            switch (milestone.type, type) {
            case (.firstMindfulDay, .firstMindfulDay):
                return true
            case (.streakDays, .streakDays):
                return true
            case (.hoursReclaimed, .hoursReclaimed):
                return true
            case (.breathingExercises, .breathingExercises):
                return true
            case (.interventionsMastered, .interventionsMastered):
                return true
            case (.totalMindfulDays, .totalMindfulDays):
                return true
            case (.firstImprovingWeek, .firstImprovingWeek):
                return true
            default:
                return false
            }
        }
    }

    /// Formatted string for total hours reclaimed
    var formattedHoursReclaimed: String {
        if totalHoursReclaimed < 1 {
            let minutes = Int(totalHoursReclaimed * 60)
            return "\(minutes)m"
        } else if totalHoursReclaimed < 24 {
            return String(format: "%.1fh", totalHoursReclaimed)
        } else {
            let days = totalHoursReclaimed / 24
            return String(format: "%.1f days", days)
        }
    }
}

// MARK: - Preview Support

extension MilestoneTracker {
    /// Creates a preview instance with sample data
    @MainActor
    static var preview: MilestoneTracker {
        let tracker = MilestoneTracker.shared

        // Add sample milestones
        tracker.achievedMilestones = Milestone.sampleCollection
        tracker.currentStreak = .sampleActive
        tracker.totalHoursReclaimed = 12.5
        tracker.totalBreathingExercises = 35
        tracker.totalMindfulDays = 18
        tracker.pendingCelebration = Milestone.sampleHours

        return tracker
    }
}

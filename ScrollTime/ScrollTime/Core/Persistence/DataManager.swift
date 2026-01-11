//
//  DataManager.swift
//  ScrollTime
//
//  Central data persistence layer for scroll sessions and statistics.
//  Uses UserDefaults for simplicity with a clear migration path to SwiftData.
//
//  Thread-safe implementation with automatic data cleanup and efficient
//  date-based querying for statistics calculation.
//

import Foundation
import Combine

// MARK: - Data Manager

/// Singleton manager for persisting and retrieving scroll session data.
/// Provides methods for session tracking, statistics calculation, and data export.
@MainActor
public final class DataManager: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide data access
    static let shared = DataManager()

    // MARK: - Published State

    /// Currently active session being tracked
    @Published private(set) var activeSession: ActiveSessionTracker?

    /// Today's statistics (cached and updated automatically)
    @Published private(set) var todayStats: DailyStats = .empty

    /// Whether data is currently being loaded
    @Published private(set) var isLoading: Bool = false

    // MARK: - Private Properties

    /// UserDefaults storage key for sessions
    private let sessionsKey = "com.scrolltime.persistedSessions"

    /// UserDefaults storage key for daily stats cache
    private let dailyStatsCacheKey = "com.scrolltime.dailyStatsCache"

    /// Maximum number of days to retain session data
    private let retentionDays: Int = 90

    /// Maximum sessions to keep in memory/storage
    private let maxStoredSessions: Int = 1000

    /// Lock for thread-safe access
    private let lock = NSLock()

    /// In-memory cache of sessions (lazy-loaded)
    private var sessionsCache: [PersistedScrollSession]?

    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()

    /// Date formatter for cache keys
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Initialization

    private init() {
        // Load today's stats on init
        Task {
            await refreshTodayStats()
        }

        // Set up daily refresh at midnight
        setupMidnightRefresh()
    }

    // MARK: - Session Lifecycle

    /// Starts a new scroll session for the given app.
    /// - Parameters:
    ///   - appBundleId: Bundle identifier of the app being monitored
    ///   - appName: Human-readable name of the app
    /// - Returns: The UUID of the new session
    @discardableResult
    func startSession(appBundleId: String, appName: String? = nil) -> UUID {
        // End any existing session first
        if activeSession != nil {
            endCurrentSession()
        }

        let displayName = appName ?? Self.appNameFromBundleId(appBundleId)
        let tracker = ActiveSessionTracker(appBundleId: appBundleId, appName: displayName)
        activeSession = tracker

        return tracker.id
    }

    /// Updates the current session with scroll activity.
    /// - Parameters:
    ///   - sessionId: The session ID to update (must match active session)
    ///   - scrollCount: Number of new scrolls to add
    ///   - velocity: Optional velocity of the scroll
    ///   - isDownward: Whether the scroll was downward
    ///   - wasDoomScrolling: Whether doom scrolling was detected
    func updateSession(
        id sessionId: UUID,
        scrollCount: Int = 1,
        velocity: Double = 0,
        isDownward: Bool = true,
        wasDoomScrolling: Bool = false
    ) {
        guard let session = activeSession, session.id == sessionId else { return }

        for _ in 0..<scrollCount {
            session.recordScroll(velocity: velocity, isDownward: isDownward)
        }

        if wasDoomScrolling {
            session.markDoomScrollingDetected()
        }
    }

    /// Updates the intensity score for the current session.
    /// - Parameters:
    ///   - sessionId: The session ID to update
    ///   - intensityScore: The new intensity score (0.0 - 1.0)
    func updateSessionIntensity(id sessionId: UUID, intensityScore: Double) {
        guard let session = activeSession, session.id == sessionId else { return }
        session.updateIntensity(intensityScore)
    }

    /// Records that an intervention was shown for the current session.
    /// - Parameters:
    ///   - sessionId: The session ID
    ///   - interventionType: The type of intervention shown
    func recordIntervention(id sessionId: UUID, interventionType: InterventionType) {
        guard let session = activeSession, session.id == sessionId else { return }
        session.recordIntervention(type: interventionType)
    }

    /// Updates the result of an intervention for the current session.
    /// - Parameters:
    ///   - sessionId: The session ID
    ///   - result: The result of the intervention
    func updateInterventionResult(id sessionId: UUID, result: InterventionResult) {
        guard let session = activeSession, session.id == sessionId else { return }
        session.updateInterventionResult(result)
    }

    /// Ends the specified session and persists it.
    /// - Parameter sessionId: The session ID to end (optional, ends current if nil)
    func endSession(id sessionId: UUID? = nil) {
        guard let session = activeSession else { return }

        // Verify session ID if provided
        if let id = sessionId, session.id != id { return }

        endCurrentSession()
    }

    /// Ends and persists the current active session
    private func endCurrentSession() {
        guard let session = activeSession else { return }

        // Only persist sessions with meaningful activity
        let persistedSession = session.finalize()
        if persistedSession.durationSeconds >= 5 || persistedSession.scrollCount > 0 {
            persistSession(persistedSession)
        }

        activeSession = nil

        // Refresh today's stats
        Task {
            await refreshTodayStats()
        }
    }

    // MARK: - Data Retrieval

    /// Gets daily statistics for a specific date.
    /// - Parameter date: The date to get stats for
    /// - Returns: DailyStats for that date
    func getDailyStats(for date: Date) -> DailyStats {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let sessions = loadSessions().filter { session in
            session.startTime >= dayStart && session.startTime < dayEnd
        }

        return calculateDailyStats(from: sessions, for: date)
    }

    /// Gets statistics for the past week (7 days including today).
    /// - Returns: Array of DailyStats for each day
    func getWeeklyStats() -> [DailyStats] {
        var weeklyStats: [DailyStats] = []
        let calendar = Calendar.current

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            weeklyStats.append(getDailyStats(for: date))
        }

        return weeklyStats
    }

    /// Gets a WeeklyStats aggregate for the past week.
    /// - Returns: WeeklyStats object with aggregated data
    func getWeeklyAggregate() -> WeeklyStats {
        let dailyStats = getWeeklyStats()
        let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        return WeeklyStats(weekStartDate: weekStart, dailyStats: dailyStats)
    }

    /// Gets all sessions for a specific date.
    /// - Parameter date: The date to query
    /// - Returns: Array of PersistedScrollSession for that date
    func getSessions(for date: Date) -> [PersistedScrollSession] {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        return loadSessions().filter { session in
            session.startTime >= dayStart && session.startTime < dayEnd
        }
    }

    /// Gets all sessions within a date range.
    /// - Parameters:
    ///   - startDate: Start of the range (inclusive)
    ///   - endDate: End of the range (exclusive)
    /// - Returns: Array of sessions within the range
    func getSessions(from startDate: Date, to endDate: Date) -> [PersistedScrollSession] {
        return loadSessions().filter { session in
            session.startTime >= startDate && session.startTime < endDate
        }
    }

    /// Gets the most recent sessions.
    /// - Parameter limit: Maximum number of sessions to return
    /// - Returns: Array of most recent sessions
    func getRecentSessions(limit: Int = 10) -> [PersistedScrollSession] {
        return Array(loadSessions().suffix(limit))
    }

    // MARK: - Statistics Calculation

    /// Calculates DailyStats from an array of sessions.
    private func calculateDailyStats(from sessions: [PersistedScrollSession], for date: Date) -> DailyStats {
        guard !sessions.isEmpty else {
            return DailyStats(
                date: date,
                totalScrollTimeSeconds: 0,
                scrollSessionCount: 0,
                interventionCount: 0,
                successfulInterventions: 0,
                appUsage: []
            )
        }

        // Calculate totals
        let totalSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
        let interventionCount = sessions.filter { $0.interventionShown }.count
        let successfulInterventions = sessions.filter { $0.wasInterventionSuccessful }.count

        // Calculate per-app usage
        var appUsageDict: [String: (name: String, seconds: Int)] = [:]
        for session in sessions {
            let existing = appUsageDict[session.appBundleId] ?? (session.appName, 0)
            appUsageDict[session.appBundleId] = (existing.name, existing.seconds + session.durationSeconds)
        }

        let appUsage = appUsageDict.map { bundleId, data in
            AppUsageRecord(appName: data.name, bundleId: bundleId, scrollTimeSeconds: data.seconds)
        }.sorted { $0.scrollTimeSeconds > $1.scrollTimeSeconds }

        return DailyStats(
            date: date,
            totalScrollTimeSeconds: totalSeconds,
            scrollSessionCount: sessions.count,
            interventionCount: interventionCount,
            successfulInterventions: successfulInterventions,
            appUsage: appUsage
        )
    }

    /// Refreshes the cached today's stats
    func refreshTodayStats() async {
        let stats = getDailyStats(for: Date())
        await MainActor.run {
            self.todayStats = stats
        }
    }

    // MARK: - Persistence

    /// Persists a single session to storage.
    private func persistSession(_ session: PersistedScrollSession) {
        lock.lock()
        defer { lock.unlock() }

        var sessions = loadSessionsInternal()
        sessions.append(session)

        // Enforce limits
        sessions = enforceRetentionPolicy(sessions)

        // Save to UserDefaults
        saveSessions(sessions)

        // Update cache
        sessionsCache = sessions
    }

    /// Loads all sessions from storage.
    private func loadSessions() -> [PersistedScrollSession] {
        lock.lock()
        defer { lock.unlock() }

        return loadSessionsInternal()
    }

    /// Internal load without locking (must be called within lock)
    private func loadSessionsInternal() -> [PersistedScrollSession] {
        if let cached = sessionsCache {
            return cached
        }

        guard let data = UserDefaults.standard.data(forKey: sessionsKey) else {
            sessionsCache = []
            return []
        }

        do {
            let sessions = try JSONDecoder().decode([PersistedScrollSession].self, from: data)
            sessionsCache = sessions
            return sessions
        } catch {
            print("DataManager: Failed to decode sessions: \(error)")
            sessionsCache = []
            return []
        }
    }

    /// Saves sessions to UserDefaults.
    private func saveSessions(_ sessions: [PersistedScrollSession]) {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: sessionsKey)
        } catch {
            print("DataManager: Failed to encode sessions: \(error)")
        }
    }

    /// Enforces retention policy by removing old sessions.
    private func enforceRetentionPolicy(_ sessions: [PersistedScrollSession]) -> [PersistedScrollSession] {
        var filtered = sessions

        // Remove sessions older than retention period
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        filtered = filtered.filter { $0.startTime >= cutoffDate }

        // Enforce maximum count
        if filtered.count > maxStoredSessions {
            filtered = Array(filtered.suffix(maxStoredSessions))
        }

        return filtered
    }

    // MARK: - Maintenance

    /// Cleans up old data (call periodically or on app launch)
    func performMaintenance() {
        lock.lock()
        defer { lock.unlock() }

        var sessions = loadSessionsInternal()
        let originalCount = sessions.count

        sessions = enforceRetentionPolicy(sessions)

        if sessions.count != originalCount {
            saveSessions(sessions)
            sessionsCache = sessions
            print("DataManager: Cleaned up \(originalCount - sessions.count) old sessions")
        }
    }

    /// Clears all stored data (use with caution)
    func clearAllData() {
        lock.lock()
        defer { lock.unlock() }

        UserDefaults.standard.removeObject(forKey: sessionsKey)
        UserDefaults.standard.removeObject(forKey: dailyStatsCacheKey)
        sessionsCache = []
        activeSession = nil
        todayStats = .empty
    }

    /// Exports all session data as JSON.
    /// - Returns: JSON string of all sessions, or nil on failure
    func exportDataAsJSON() -> String? {
        let sessions = loadSessions()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(sessions)
            return String(data: data, encoding: .utf8)
        } catch {
            print("DataManager: Failed to export data: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    /// Extracts a human-readable app name from a bundle ID.
    public static func appNameFromBundleId(_ bundleId: String) -> String {
        let components = bundleId.split(separator: ".")
        if let last = components.last {
            // Handle common patterns
            let name = String(last)
            switch name.lowercased() {
            case "instagram": return "Instagram"
            case "tiktok": return "TikTok"
            case "twitter", "x": return "Twitter"
            case "reddit": return "Reddit"
            case "facebook": return "Facebook"
            case "youtube": return "YouTube"
            case "snapchat": return "Snapchat"
            case "threads": return "Threads"
            case "bluesky": return "Bluesky"
            case "mastodon": return "Mastodon"
            default: return name.capitalized
            }
        }
        return bundleId
    }

    /// Sets up a timer to refresh stats at midnight
    private func setupMidnightRefresh() {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
              let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            return
        }

        let timeUntilMidnight = midnight.timeIntervalSinceNow

        // Schedule refresh at midnight
        DispatchQueue.main.asyncAfter(deadline: .now() + timeUntilMidnight) { [weak self] in
            Task { @MainActor in
                await self?.refreshTodayStats()
                self?.setupMidnightRefresh() // Reschedule for next midnight
            }
        }
    }
}

// MARK: - Convenience Extensions

extension DataManager {
    /// Quick check if user has any scroll activity today
    var hasActivityToday: Bool {
        todayStats.scrollSessionCount > 0
    }

    /// Current session duration in seconds (0 if no active session)
    var currentSessionDuration: Int {
        guard let session = activeSession else { return 0 }
        return Int(Date().timeIntervalSince(session.startTime))
    }

    /// Whether an intervention has been shown in the current session
    var currentSessionHasIntervention: Bool {
        activeSession?.interventionData?.shown ?? false
    }
}

// MARK: - Preview Support

extension DataManager {
    /// Creates a preview instance with sample data
    public static var preview: DataManager {
        let manager = DataManager.shared

        // Add sample sessions for preview
        let sampleSessions = PersistedScrollSession.sampleDay
        for session in sampleSessions {
            manager.persistSession(session)
        }

        return manager
    }
}

//
//  PersistedScrollSession.swift
//  ScrollTime
//
//  A persistable representation of a scroll session with all data needed
//  for statistics, history, and analysis. Designed for UserDefaults storage
//  with a clear migration path to SwiftData.
//

import Foundation

// MARK: - Persisted Scroll Session

/// A complete record of a scroll session designed for persistence.
/// Contains all fields needed for statistics and intervention tracking.
public struct PersistedScrollSession: Codable, Identifiable, Equatable {
    // MARK: - Identification

    /// Unique identifier for this session
    public let id: UUID

    /// App information
    public let appBundleId: String
    public let appName: String

    // MARK: - Timing

    /// When the session started
    public let startTime: Date

    /// When the session ended
    public let endTime: Date

    /// Duration in seconds (cached for quick access)
    public let durationSeconds: Int

    // MARK: - Scroll Metrics

    /// Total number of scroll events detected
    public let scrollCount: Int

    /// Average scroll velocity during the session
    public let averageVelocity: Double

    /// Ratio of downward scrolls (0.0 - 1.0)
    public let downwardScrollRatio: Double

    /// Scrolls per minute rate
    public let scrollsPerMinute: Double

    // MARK: - Detection Flags

    /// Whether doom scrolling was detected during this session
    public let wasDoomScrolling: Bool

    /// The maximum intensity score reached during the session (0.0 - 1.0)
    public let peakIntensityScore: Double

    // MARK: - Intervention Data

    /// Whether an intervention was shown during this session
    public let interventionShown: Bool

    /// The type of intervention shown (if any)
    public let interventionType: InterventionType?

    /// The result of the intervention (if any)
    public let interventionResult: InterventionResult?

    /// When the intervention was triggered (if any)
    public let interventionTime: Date?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        appBundleId: String,
        appName: String,
        startTime: Date,
        endTime: Date,
        scrollCount: Int,
        averageVelocity: Double = 0,
        downwardScrollRatio: Double = 0,
        scrollsPerMinute: Double = 0,
        wasDoomScrolling: Bool = false,
        peakIntensityScore: Double = 0,
        interventionShown: Bool = false,
        interventionType: InterventionType? = nil,
        interventionResult: InterventionResult? = nil,
        interventionTime: Date? = nil
    ) {
        self.id = id
        self.appBundleId = appBundleId
        self.appName = appName
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = Int(endTime.timeIntervalSince(startTime))
        self.scrollCount = scrollCount
        self.averageVelocity = averageVelocity
        self.downwardScrollRatio = downwardScrollRatio
        self.scrollsPerMinute = scrollsPerMinute
        self.wasDoomScrolling = wasDoomScrolling
        self.peakIntensityScore = peakIntensityScore
        self.interventionShown = interventionShown
        self.interventionType = interventionType
        self.interventionResult = interventionResult
        self.interventionTime = interventionTime
    }

    /// Creates a PersistedScrollSession from a ScrollSessionSummary
    public init(from summary: ScrollSessionSummary, interventionData: InterventionData? = nil) {
        self.id = summary.id
        self.appBundleId = summary.appBundleID ?? "unknown"
        self.appName = summary.appName
        self.startTime = summary.startTime
        self.endTime = summary.endTime
        self.durationSeconds = Int(summary.duration)
        self.scrollCount = summary.totalScrollCount
        self.averageVelocity = summary.averageVelocity
        self.downwardScrollRatio = summary.downwardScrollRatio
        self.scrollsPerMinute = summary.scrollsPerMinute
        self.wasDoomScrolling = summary.wasDoomScrolling
        self.peakIntensityScore = 0  // Would need to be passed separately
        self.interventionShown = interventionData?.shown ?? false
        self.interventionType = interventionData?.type
        self.interventionResult = interventionData?.result
        self.interventionTime = interventionData?.time
    }

    // MARK: - Computed Properties

    /// Formatted duration string for display
    public var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    /// Whether the intervention was successful (user took a break)
    public var wasInterventionSuccessful: Bool {
        guard let result = interventionResult else { return false }
        return result.wasPositiveEngagement
    }

    /// The date component (start of day) for grouping
    public var dateKey: Date {
        Calendar.current.startOfDay(for: startTime)
    }
}

// MARK: - Intervention Data Container

/// Container for intervention-related data during session creation
public struct InterventionData {
    public let shown: Bool
    public let type: InterventionType?
    public let result: InterventionResult?
    public let time: Date?

    public init(shown: Bool = false, type: InterventionType? = nil, result: InterventionResult? = nil, time: Date? = nil) {
        self.shown = shown
        self.type = type
        self.result = result
        self.time = time
    }
}

// MARK: - Active Session Tracker

/// Tracks an in-progress session before it's persisted
public final class ActiveSessionTracker: ObservableObject {
    public let id: UUID
    public let appBundleId: String
    public let appName: String
    public let startTime: Date

    @Published public var scrollCount: Int = 0
    @Published public var wasDoomScrolling: Bool = false
    @Published public var peakIntensityScore: Double = 0
    @Published public var interventionData: InterventionData?

    // Running totals for averages
    private var accumulatedVelocity: Double = 0
    private var downwardScrolls: Int = 0

    public init(appBundleId: String, appName: String) {
        self.id = UUID()
        self.appBundleId = appBundleId
        self.appName = appName
        self.startTime = Date()
    }

    /// Records a scroll event
    public func recordScroll(velocity: Double, isDownward: Bool) {
        scrollCount += 1
        accumulatedVelocity += velocity
        if isDownward {
            downwardScrolls += 1
        }
    }

    /// Updates the peak intensity score
    public func updateIntensity(_ score: Double) {
        if score > peakIntensityScore {
            peakIntensityScore = score
        }
    }

    /// Records that doom scrolling was detected
    public func markDoomScrollingDetected() {
        wasDoomScrolling = true
    }

    /// Records an intervention
    public func recordIntervention(type: InterventionType, result: InterventionResult? = nil) {
        interventionData = InterventionData(
            shown: true,
            type: type,
            result: result,
            time: Date()
        )
    }

    /// Updates the intervention result
    public func updateInterventionResult(_ result: InterventionResult) {
        guard let existing = interventionData else { return }
        interventionData = InterventionData(
            shown: existing.shown,
            type: existing.type,
            result: result,
            time: existing.time
        )
    }

    /// Finalizes the session into a persistable format
    public func finalize() -> PersistedScrollSession {
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let minutes = duration / 60.0

        return PersistedScrollSession(
            id: id,
            appBundleId: appBundleId,
            appName: appName,
            startTime: startTime,
            endTime: endTime,
            scrollCount: scrollCount,
            averageVelocity: scrollCount > 0 ? accumulatedVelocity / Double(scrollCount) : 0,
            downwardScrollRatio: scrollCount > 0 ? Double(downwardScrolls) / Double(scrollCount) : 0,
            scrollsPerMinute: minutes > 0 ? Double(scrollCount) / minutes : 0,
            wasDoomScrolling: wasDoomScrolling,
            peakIntensityScore: peakIntensityScore,
            interventionShown: interventionData?.shown ?? false,
            interventionType: interventionData?.type,
            interventionResult: interventionData?.result,
            interventionTime: interventionData?.time
        )
    }
}

// MARK: - Sample Data

extension PersistedScrollSession {
    /// Sample session for previews
    public static var sample: PersistedScrollSession {
        PersistedScrollSession(
            appBundleId: "com.instagram.app",
            appName: "Instagram",
            startTime: Date().addingTimeInterval(-600),
            endTime: Date().addingTimeInterval(-60),
            scrollCount: 150,
            averageVelocity: 450,
            downwardScrollRatio: 0.85,
            scrollsPerMinute: 16.7,
            wasDoomScrolling: true,
            peakIntensityScore: 0.72,
            interventionShown: true,
            interventionType: .breathingExercise,
            interventionResult: .completed,
            interventionTime: Date().addingTimeInterval(-180)
        )
    }

    /// Sample sessions for a full day
    public static var sampleDay: [PersistedScrollSession] {
        let now = Date()
        return [
            PersistedScrollSession(
                appBundleId: "com.instagram.app",
                appName: "Instagram",
                startTime: now.addingTimeInterval(-14400), // 4 hours ago
                endTime: now.addingTimeInterval(-13200),   // 3h 40m ago
                scrollCount: 200,
                wasDoomScrolling: true,
                interventionShown: true,
                interventionType: .gentleReminder,
                interventionResult: .tookBreak
            ),
            PersistedScrollSession(
                appBundleId: "com.tiktok.app",
                appName: "TikTok",
                startTime: now.addingTimeInterval(-10800), // 3 hours ago
                endTime: now.addingTimeInterval(-9000),    // 2h 30m ago
                scrollCount: 350,
                wasDoomScrolling: true,
                interventionShown: true,
                interventionType: .breathingExercise,
                interventionResult: .completed
            ),
            PersistedScrollSession(
                appBundleId: "com.twitter.app",
                appName: "Twitter",
                startTime: now.addingTimeInterval(-7200),  // 2 hours ago
                endTime: now.addingTimeInterval(-6600),    // 1h 50m ago
                scrollCount: 80,
                wasDoomScrolling: false
            ),
            PersistedScrollSession(
                appBundleId: "com.reddit.app",
                appName: "Reddit",
                startTime: now.addingTimeInterval(-3600),  // 1 hour ago
                endTime: now.addingTimeInterval(-2400),    // 40m ago
                scrollCount: 120,
                wasDoomScrolling: true,
                interventionShown: true,
                interventionType: .timedPause,
                interventionResult: .skipped
            )
        ]
    }
}

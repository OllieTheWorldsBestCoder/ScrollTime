//
//  ScrollSession.swift
//  ScrollTime
//
//  Tracks individual scroll sessions with start/end times, scroll counts,
//  and a rolling window of recent scroll events for pattern analysis.
//

import Foundation
import Combine

// MARK: - Scroll Direction

/// Direction of a scroll gesture
public enum ScrollDirection: String, Codable {
    case up
    case down
    case left
    case right
    case unknown

    /// Returns true if the scroll is vertical (up or down)
    public var isVertical: Bool {
        self == .up || self == .down
    }

    /// Returns true if this is a "feed scrolling" direction (typically down)
    public var isFeedDirection: Bool {
        self == .down
    }
}

// MARK: - Scroll Event

/// Represents a single scroll gesture event with all relevant metrics.
public struct ScrollEvent: Identifiable, Codable {
    /// Unique identifier for this event
    public let id: UUID

    /// Timestamp when the scroll occurred
    public let timestamp: Date

    /// Direction of the scroll
    public let direction: ScrollDirection

    /// Velocity of the scroll in points per second
    public let velocity: Double

    /// Acceleration at the start of the scroll (if available)
    public let acceleration: Double?

    /// Distance scrolled in points (if available)
    public let distance: Double?

    /// Duration of the scroll gesture in seconds
    public let duration: TimeInterval?

    /// Creates a new scroll event with all properties
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        direction: ScrollDirection,
        velocity: Double,
        acceleration: Double? = nil,
        distance: Double? = nil,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.direction = direction
        self.velocity = velocity
        self.acceleration = acceleration
        self.distance = distance
        self.duration = duration
    }

    /// Creates a simplified scroll event with just direction and velocity
    public static func simple(
        direction: ScrollDirection,
        velocity: Double,
        timestamp: Date = Date()
    ) -> ScrollEvent {
        ScrollEvent(
            timestamp: timestamp,
            direction: direction,
            velocity: velocity
        )
    }
}

// MARK: - Session State

/// Current state of a scroll session
public enum SessionState: String, Codable {
    /// Session is currently active and tracking scrolls
    case active

    /// Session is paused (user stopped scrolling temporarily)
    case paused

    /// Session has ended
    case ended
}

// MARK: - Scroll Session

/// Tracks an individual scroll session from start to end.
/// Maintains a rolling window of recent scroll events for pattern analysis.
public final class ScrollSession: ObservableObject, Identifiable, Codable {

    // MARK: - Published Properties

    /// Unique identifier for this session
    public let id: UUID

    /// Bundle identifier of the app being monitored
    public let appBundleID: String?

    /// When the session started
    public let startTime: Date

    /// When the session ended (nil if still active)
    @Published public private(set) var endTime: Date?

    /// Current state of the session
    @Published public private(set) var state: SessionState

    /// Total number of scroll events in this session
    @Published public private(set) var totalScrollCount: Int

    /// Rolling window of recent scroll events for pattern analysis
    @Published public private(set) var recentEvents: [ScrollEvent]

    // MARK: - Private Properties

    /// Maximum number of events to keep in the rolling window
    private let windowSize: Int

    /// Lock for thread-safe access to mutable properties
    private let lock = NSLock()

    /// Accumulated metrics for the session
    private var accumulatedVelocity: Double = 0
    private var downwardScrollCount: Int = 0
    private var directionChanges: Int = 0
    private var lastDirection: ScrollDirection?

    // MARK: - Initialization

    /// Creates a new scroll session
    public init(
        id: UUID = UUID(),
        appBundleID: String? = nil,
        startTime: Date = Date(),
        windowSize: Int = 75
    ) {
        self.id = id
        self.appBundleID = appBundleID
        self.startTime = startTime
        self.windowSize = max(10, windowSize)
        self.state = .active
        self.totalScrollCount = 0
        self.recentEvents = []
    }

    // MARK: - Codable Conformance

    private enum CodingKeys: String, CodingKey {
        case id, appBundleID, startTime, endTime, state
        case totalScrollCount, recentEvents, windowSize
        case accumulatedVelocity, downwardScrollCount, directionChanges
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        appBundleID = try container.decodeIfPresent(String.self, forKey: .appBundleID)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        state = try container.decode(SessionState.self, forKey: .state)
        totalScrollCount = try container.decode(Int.self, forKey: .totalScrollCount)
        recentEvents = try container.decode([ScrollEvent].self, forKey: .recentEvents)
        windowSize = try container.decode(Int.self, forKey: .windowSize)
        accumulatedVelocity = try container.decode(Double.self, forKey: .accumulatedVelocity)
        downwardScrollCount = try container.decode(Int.self, forKey: .downwardScrollCount)
        directionChanges = try container.decode(Int.self, forKey: .directionChanges)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(appBundleID, forKey: .appBundleID)
        try container.encode(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(state, forKey: .state)
        try container.encode(totalScrollCount, forKey: .totalScrollCount)
        try container.encode(recentEvents, forKey: .recentEvents)
        try container.encode(windowSize, forKey: .windowSize)
        try container.encode(accumulatedVelocity, forKey: .accumulatedVelocity)
        try container.encode(downwardScrollCount, forKey: .downwardScrollCount)
        try container.encode(directionChanges, forKey: .directionChanges)
    }

    // MARK: - Event Recording

    /// Records a new scroll event to the session.
    /// Thread-safe operation.
    public func recordEvent(_ event: ScrollEvent) {
        lock.lock()
        defer { lock.unlock() }

        guard state == .active else { return }

        // Track direction changes for pattern detection
        if let last = lastDirection, last != event.direction, event.direction != .unknown {
            directionChanges += 1
        }
        lastDirection = event.direction

        // Update counters
        totalScrollCount += 1
        accumulatedVelocity += event.velocity

        if event.direction.isFeedDirection {
            downwardScrollCount += 1
        }

        // Add to rolling window
        recentEvents.append(event)

        // Trim window if needed
        if recentEvents.count > windowSize {
            recentEvents.removeFirst(recentEvents.count - windowSize)
        }

        // Resume from paused state if needed
        if state == .paused {
            state = .active
        }
    }

    /// Records a simple scroll with direction and velocity
    public func recordScroll(direction: ScrollDirection, velocity: Double) {
        let event = ScrollEvent.simple(direction: direction, velocity: velocity)
        recordEvent(event)
    }

    /// Pauses the session (user stopped scrolling temporarily)
    public func pause() {
        lock.lock()
        defer { lock.unlock() }

        guard state == .active else { return }
        state = .paused
    }

    /// Ends the session
    public func end() {
        lock.lock()
        defer { lock.unlock() }

        guard state != .ended else { return }
        state = .ended
        endTime = Date()
    }

    // MARK: - Computed Metrics

    /// Total duration of the session in seconds
    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    /// Average velocity across all scrolls in the session
    public var averageVelocity: Double {
        guard totalScrollCount > 0 else { return 0 }
        return accumulatedVelocity / Double(totalScrollCount)
    }

    /// Average velocity in the recent rolling window
    public var recentAverageVelocity: Double {
        guard !recentEvents.isEmpty else { return 0 }
        let sum = recentEvents.reduce(0.0) { $0 + $1.velocity }
        return sum / Double(recentEvents.count)
    }

    /// Ratio of downward scrolls to total scrolls (0.0 - 1.0)
    public var downwardScrollRatio: Double {
        guard totalScrollCount > 0 else { return 0 }
        return Double(downwardScrollCount) / Double(totalScrollCount)
    }

    /// Scrolls per minute rate
    public var scrollsPerMinute: Double {
        let minutes = duration / 60.0
        guard minutes > 0 else { return 0 }
        return Double(totalScrollCount) / minutes
    }

    /// Direction changes per minute
    public var directionChangesPerMinute: Double {
        let minutes = duration / 60.0
        guard minutes > 0 else { return 0 }
        return Double(directionChanges) / minutes
    }

    /// Returns events within a specific time window from now
    public func events(within timeWindow: TimeInterval) -> [ScrollEvent] {
        let cutoff = Date().addingTimeInterval(-timeWindow)
        return recentEvents.filter { $0.timestamp >= cutoff }
    }

    /// Calculates the time gap between the most recent scroll events.
    /// Returns nil if there are fewer than 2 events.
    public var recentScrollGap: TimeInterval? {
        guard recentEvents.count >= 2 else { return nil }
        let last = recentEvents[recentEvents.count - 1]
        let secondLast = recentEvents[recentEvents.count - 2]
        return last.timestamp.timeIntervalSince(secondLast.timestamp)
    }

    /// Time elapsed since the last scroll event until now.
    /// This is useful for detecting meaningful pauses (e.g., reading content).
    /// Returns nil if there are no events.
    public var timeSinceLastScroll: TimeInterval? {
        guard let lastEvent = recentEvents.last else { return nil }
        return Date().timeIntervalSince(lastEvent.timestamp)
    }

    /// Average time between scrolls in the recent window
    public var averageScrollInterval: TimeInterval? {
        guard recentEvents.count >= 2 else { return nil }

        var totalInterval: TimeInterval = 0
        for i in 1..<recentEvents.count {
            totalInterval += recentEvents[i].timestamp.timeIntervalSince(recentEvents[i - 1].timestamp)
        }

        return totalInterval / Double(recentEvents.count - 1)
    }

    /// Maximum velocity seen in the session
    public var maxVelocity: Double {
        recentEvents.map(\.velocity).max() ?? 0
    }

    /// Minimum velocity seen in the session
    public var minVelocity: Double {
        recentEvents.map(\.velocity).min() ?? 0
    }

    /// Standard deviation of velocity (measures consistency)
    public var velocityStandardDeviation: Double {
        guard recentEvents.count > 1 else { return 0 }

        let mean = recentAverageVelocity
        let squaredDiffs = recentEvents.map { pow($0.velocity - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(recentEvents.count - 1)
        return sqrt(variance)
    }
}

// MARK: - Session Summary

/// A lightweight summary of a scroll session for storage and analysis
public struct ScrollSessionSummary: Codable, Identifiable {
    public let id: UUID
    public let appBundleID: String?
    public let startTime: Date
    public let endTime: Date
    public let duration: TimeInterval
    public let totalScrollCount: Int
    public let averageVelocity: Double
    public let downwardScrollRatio: Double
    public let scrollsPerMinute: Double
    public let directionChangesPerMinute: Double
    public let wasDoomScrolling: Bool

    /// Creates a summary from an active or ended session
    public init(from session: ScrollSession, wasDoomScrolling: Bool = false) {
        self.id = session.id
        self.appBundleID = session.appBundleID
        self.startTime = session.startTime
        self.endTime = session.endTime ?? Date()
        self.duration = session.duration
        self.totalScrollCount = session.totalScrollCount
        self.averageVelocity = session.averageVelocity
        self.downwardScrollRatio = session.downwardScrollRatio
        self.scrollsPerMinute = session.scrollsPerMinute
        self.directionChangesPerMinute = session.directionChangesPerMinute
        self.wasDoomScrolling = wasDoomScrolling
    }

    // MARK: - UI Helpers

    /// Whether an intervention was triggered (alias for wasDoomScrolling for UI compatibility)
    public var interventionTriggered: Bool { wasDoomScrolling }

    /// Human-readable app name derived from bundle ID
    public var appName: String {
        guard let bundleID = appBundleID else { return "Unknown" }
        // Extract app name from common bundle patterns
        let components = bundleID.split(separator: ".")
        if components.count >= 2 {
            return components.last.map { String($0).capitalized } ?? bundleID
        }
        return bundleID
    }

    /// Formatted duration string for UI display
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    /// Creates a summary directly for previews and sample data
    public init(
        id: UUID = UUID(),
        appBundleID: String?,
        startTime: Date,
        endTime: Date,
        totalScrollCount: Int,
        wasDoomScrolling: Bool = false
    ) {
        self.id = id
        self.appBundleID = appBundleID
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
        self.totalScrollCount = totalScrollCount
        self.averageVelocity = 500  // Default for sample data
        self.downwardScrollRatio = 0.8
        self.scrollsPerMinute = Double(totalScrollCount) / max(1, duration / 60)
        self.directionChangesPerMinute = 5
        self.wasDoomScrolling = wasDoomScrolling
    }
}

// MARK: - Hashable Conformance

extension ScrollSession: Hashable {
    public static func == (lhs: ScrollSession, rhs: ScrollSession) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

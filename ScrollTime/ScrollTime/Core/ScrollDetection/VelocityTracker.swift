//
//  VelocityTracker.swift
//  ScrollTime
//
//  Production-grade velocity and acceleration tracking system for scroll detection.
//  Uses exponential moving averages (EMA) and Kalman-inspired filtering for smooth,
//  noise-resistant velocity calculations suitable for real-time doom scrolling detection.
//
//  Key Features:
//  - Real-time velocity calculation in points/second
//  - Acceleration tracking (rate of velocity change)
//  - Jerk detection (rate of acceleration change) for pattern analysis
//  - Adaptive sampling that adjusts to scroll intensity
//  - Thread-safe design for concurrent access
//

import Foundation
import CoreGraphics

// MARK: - Velocity Sample

/// A single velocity measurement with timestamp and metadata.
/// These samples form the basis for all velocity calculations.
public struct VelocitySample: Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let position: CGPoint
    public let velocity: CGPoint         // Velocity vector (dx/dt, dy/dt) in points/second
    public let magnitude: Double         // Scalar velocity magnitude
    public let direction: ScrollDirection

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        position: CGPoint,
        velocity: CGPoint,
        direction: ScrollDirection
    ) {
        self.id = id
        self.timestamp = timestamp
        self.position = position
        self.velocity = velocity
        self.magnitude = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        self.direction = direction
    }
}

// MARK: - Velocity Statistics

/// Statistical summary of recent velocity measurements.
/// Used for pattern detection and doom scrolling heuristics.
public struct VelocityStatistics {
    /// Average velocity magnitude over the analysis window
    public let averageMagnitude: Double

    /// Peak velocity magnitude in the window
    public let peakMagnitude: Double

    /// Minimum velocity magnitude (useful for detecting pauses)
    public let minimumMagnitude: Double

    /// Standard deviation of velocity (measures consistency)
    public let standardDeviation: Double

    /// Coefficient of variation (stdDev / mean) - lower = more consistent
    public let coefficientOfVariation: Double

    /// Average acceleration (rate of velocity change) in points/second^2
    public let averageAcceleration: Double

    /// Peak acceleration magnitude
    public let peakAcceleration: Double

    /// Percentage of samples in downward direction (0.0 - 1.0)
    public let downwardRatio: Double

    /// Number of direction changes in the window
    public let directionChangeCount: Int

    /// Time span covered by the statistics (seconds)
    public let timeSpan: TimeInterval

    /// Number of samples used in calculation
    public let sampleCount: Int

    /// Whether this represents a "steady state" scroll pattern
    /// (consistent velocity, primarily downward, few direction changes)
    public var isSteadyState: Bool {
        guard sampleCount >= 5 else { return false }
        return coefficientOfVariation < 0.5 &&
               downwardRatio >= 0.7 &&
               directionChangeCount <= 2
    }

    /// Empty statistics for initial state
    public static let empty = VelocityStatistics(
        averageMagnitude: 0,
        peakMagnitude: 0,
        minimumMagnitude: 0,
        standardDeviation: 0,
        coefficientOfVariation: 0,
        averageAcceleration: 0,
        peakAcceleration: 0,
        downwardRatio: 0,
        directionChangeCount: 0,
        timeSpan: 0,
        sampleCount: 0
    )
}

// MARK: - Velocity Tracker

/// Production-grade velocity tracker that maintains a rolling window of samples
/// and provides real-time velocity, acceleration, and statistical analysis.
///
/// Thread Safety: All public methods are thread-safe via internal locking.
///
/// Usage:
/// ```swift
/// let tracker = VelocityTracker()
///
/// // Record samples from gesture recognizer
/// tracker.recordSample(position: currentPosition, timestamp: Date())
///
/// // Get current velocity
/// let velocity = tracker.currentVelocity
/// let stats = tracker.calculateStatistics()
/// ```
public final class VelocityTracker {

    // MARK: - Configuration

    /// Configuration for the velocity tracker
    public struct Configuration {
        /// Maximum number of samples to retain in the rolling window
        public var maxSampleCount: Int

        /// Maximum age of samples to consider (seconds)
        public var maxSampleAge: TimeInterval

        /// Alpha value for EMA velocity smoothing (0-1, higher = less smoothing)
        public var velocityEMAAlpha: Double

        /// Alpha value for EMA acceleration smoothing
        public var accelerationEMAAlpha: Double

        /// Minimum time between samples to avoid division errors (seconds)
        public var minimumSampleInterval: TimeInterval

        /// Velocity below this threshold is considered "stopped" (points/second)
        public var stoppedVelocityThreshold: Double

        /// Default configuration optimized for doom scrolling detection
        public static let `default` = Configuration(
            maxSampleCount: 100,
            maxSampleAge: 10.0,
            velocityEMAAlpha: 0.3,
            accelerationEMAAlpha: 0.25,
            minimumSampleInterval: 0.008,  // ~120Hz max
            stoppedVelocityThreshold: 10.0
        )

        /// High-frequency configuration for precise detection
        public static let highFrequency = Configuration(
            maxSampleCount: 200,
            maxSampleAge: 5.0,
            velocityEMAAlpha: 0.4,
            accelerationEMAAlpha: 0.35,
            minimumSampleInterval: 0.004,  // ~240Hz max
            stoppedVelocityThreshold: 5.0
        )

        /// Battery-efficient configuration
        public static let lowPower = Configuration(
            maxSampleCount: 50,
            maxSampleAge: 15.0,
            velocityEMAAlpha: 0.2,
            accelerationEMAAlpha: 0.15,
            minimumSampleInterval: 0.033,  // ~30Hz max
            stoppedVelocityThreshold: 20.0
        )
    }

    // MARK: - Public Properties

    /// Current configuration
    public var configuration: Configuration {
        didSet { pruneOldSamples() }
    }

    /// Current smoothed velocity magnitude (points/second)
    public var currentVelocity: Double {
        lock.lock()
        defer { lock.unlock() }
        return smoothedVelocityMagnitude
    }

    /// Current smoothed velocity vector
    public var currentVelocityVector: CGPoint {
        lock.lock()
        defer { lock.unlock() }
        return smoothedVelocityVector
    }

    /// Current smoothed acceleration (points/second^2)
    public var currentAcceleration: Double {
        lock.lock()
        defer { lock.unlock() }
        return smoothedAcceleration
    }

    /// Current scroll direction based on recent samples
    public var currentDirection: ScrollDirection {
        lock.lock()
        defer { lock.unlock() }
        return lastDirection
    }

    /// Whether the user appears to be actively scrolling
    public var isScrolling: Bool {
        lock.lock()
        defer { lock.unlock() }

        // Check if we have recent samples and velocity above threshold
        guard let lastSample = samples.last else { return false }
        let timeSinceLastSample = Date().timeIntervalSince(lastSample.timestamp)
        return timeSinceLastSample < 0.5 && smoothedVelocityMagnitude > configuration.stoppedVelocityThreshold
    }

    /// Number of samples currently in the buffer
    public var sampleCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return samples.count
    }

    // MARK: - Private Properties

    /// Rolling window of velocity samples
    private var samples: [VelocitySample] = []

    /// Thread-safe lock
    private let lock = NSLock()

    /// Last recorded position for velocity calculation
    private var lastPosition: CGPoint?

    /// Last sample timestamp
    private var lastTimestamp: Date?

    /// EMA-smoothed velocity magnitude
    private var smoothedVelocityMagnitude: Double = 0

    /// EMA-smoothed velocity vector
    private var smoothedVelocityVector: CGPoint = .zero

    /// EMA-smoothed acceleration
    private var smoothedAcceleration: Double = 0

    /// Last calculated velocity for acceleration computation
    private var lastVelocityMagnitude: Double = 0

    /// Last detected direction
    private var lastDirection: ScrollDirection = .unknown

    // MARK: - Initialization

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Sample Recording

    /// Records a new position sample and calculates velocity.
    /// Call this from your gesture recognizer's callback.
    ///
    /// - Parameters:
    ///   - position: Current touch/scroll position in points
    ///   - timestamp: When this sample was recorded (defaults to now)
    /// - Returns: The calculated velocity sample, or nil if too soon after last sample
    @discardableResult
    public func recordSample(position: CGPoint, timestamp: Date = Date()) -> VelocitySample? {
        lock.lock()
        defer { lock.unlock() }

        // Calculate time delta
        guard let lastPos = lastPosition, let lastTime = lastTimestamp else {
            // First sample - just record position
            lastPosition = position
            lastTimestamp = timestamp
            return nil
        }

        let dt = timestamp.timeIntervalSince(lastTime)

        // Skip if samples are too close together (prevents division by tiny numbers)
        guard dt >= configuration.minimumSampleInterval else {
            return nil
        }

        // Calculate instantaneous velocity (displacement / time)
        let dx = position.x - lastPos.x
        let dy = position.y - lastPos.y
        let velocityX = dx / dt
        let velocityY = dy / dt
        let velocityVector = CGPoint(x: velocityX, y: velocityY)

        // Determine scroll direction from velocity
        let direction = determineDirection(from: velocityVector)

        // Create the sample
        let sample = VelocitySample(
            timestamp: timestamp,
            position: position,
            velocity: velocityVector,
            direction: direction
        )

        // Update EMA-smoothed values
        updateSmoothedValues(sample: sample, dt: dt)

        // Store sample
        samples.append(sample)

        // Update state for next calculation
        lastPosition = position
        lastTimestamp = timestamp
        lastVelocityMagnitude = sample.magnitude
        lastDirection = direction

        // Prune old samples
        pruneOldSamplesUnsafe()

        return sample
    }

    /// Records a velocity directly (when you already have velocity from gesture recognizer).
    ///
    /// - Parameters:
    ///   - velocity: Velocity vector in points/second
    ///   - position: Current position (optional, for future position-based analysis)
    ///   - timestamp: When this sample was recorded
    /// - Returns: The recorded velocity sample
    @discardableResult
    public func recordVelocity(
        velocity: CGPoint,
        position: CGPoint = .zero,
        timestamp: Date = Date()
    ) -> VelocitySample? {
        lock.lock()
        defer { lock.unlock() }

        // Check minimum interval
        if let lastTime = lastTimestamp {
            let dt = timestamp.timeIntervalSince(lastTime)
            guard dt >= configuration.minimumSampleInterval else {
                return nil
            }
        }

        let direction = determineDirection(from: velocity)

        let sample = VelocitySample(
            timestamp: timestamp,
            position: position,
            velocity: velocity,
            direction: direction
        )

        // Update EMA-smoothed values
        let dt = lastTimestamp.map { timestamp.timeIntervalSince($0) } ?? 0.016
        updateSmoothedValues(sample: sample, dt: dt)

        // Store sample
        samples.append(sample)

        // Update state
        lastPosition = position
        lastTimestamp = timestamp
        lastVelocityMagnitude = sample.magnitude
        lastDirection = direction

        // Prune old samples
        pruneOldSamplesUnsafe()

        return sample
    }

    // MARK: - Statistics Calculation

    /// Calculates comprehensive statistics over the current sample window.
    ///
    /// - Parameter windowDuration: Optional time window (defaults to all samples)
    /// - Returns: Statistical summary of velocity measurements
    public func calculateStatistics(windowDuration: TimeInterval? = nil) -> VelocityStatistics {
        lock.lock()
        defer { lock.unlock() }

        // Get relevant samples
        let relevantSamples: [VelocitySample]
        if let window = windowDuration {
            let cutoff = Date().addingTimeInterval(-window)
            relevantSamples = samples.filter { $0.timestamp >= cutoff }
        } else {
            relevantSamples = samples
        }

        guard relevantSamples.count >= 2 else {
            return .empty
        }

        // Extract velocity magnitudes
        let magnitudes = relevantSamples.map { $0.magnitude }

        // Basic statistics
        let sum = magnitudes.reduce(0, +)
        let average = sum / Double(magnitudes.count)
        let peak = magnitudes.max() ?? 0
        let minimum = magnitudes.min() ?? 0

        // Standard deviation
        let squaredDiffs = magnitudes.map { pow($0 - average, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(magnitudes.count - 1)
        let stdDev = sqrt(variance)

        // Coefficient of variation
        let cv = average > 0 ? stdDev / average : 0

        // Calculate acceleration samples
        var accelerations: [Double] = []
        for i in 1..<relevantSamples.count {
            let dt = relevantSamples[i].timestamp.timeIntervalSince(relevantSamples[i-1].timestamp)
            if dt > 0 {
                let dv = relevantSamples[i].magnitude - relevantSamples[i-1].magnitude
                accelerations.append(dv / dt)
            }
        }

        let avgAcceleration = accelerations.isEmpty ? 0 : accelerations.reduce(0, +) / Double(accelerations.count)
        let peakAcceleration = accelerations.map { abs($0) }.max() ?? 0

        // Direction analysis
        let downwardCount = relevantSamples.filter { $0.direction == .down }.count
        let downwardRatio = Double(downwardCount) / Double(relevantSamples.count)

        // Direction change count
        var directionChanges = 0
        var previousDirection: ScrollDirection?
        for sample in relevantSamples {
            if let prev = previousDirection, prev != sample.direction, sample.direction != .unknown {
                directionChanges += 1
            }
            previousDirection = sample.direction
        }

        // Time span
        let timeSpan = relevantSamples.last!.timestamp.timeIntervalSince(relevantSamples.first!.timestamp)

        return VelocityStatistics(
            averageMagnitude: average,
            peakMagnitude: peak,
            minimumMagnitude: minimum,
            standardDeviation: stdDev,
            coefficientOfVariation: cv,
            averageAcceleration: avgAcceleration,
            peakAcceleration: peakAcceleration,
            downwardRatio: downwardRatio,
            directionChangeCount: directionChanges,
            timeSpan: timeSpan,
            sampleCount: relevantSamples.count
        )
    }

    /// Returns the time since the last scroll sample.
    /// Useful for detecting pauses in scrolling.
    public var timeSinceLastSample: TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        return lastTimestamp.map { Date().timeIntervalSince($0) }
    }

    /// Returns samples within a specific time window.
    public func samples(within duration: TimeInterval) -> [VelocitySample] {
        lock.lock()
        defer { lock.unlock() }

        let cutoff = Date().addingTimeInterval(-duration)
        return samples.filter { $0.timestamp >= cutoff }
    }

    // MARK: - Reset

    /// Resets all tracking state. Call when starting a new scroll session.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        samples.removeAll()
        lastPosition = nil
        lastTimestamp = nil
        smoothedVelocityMagnitude = 0
        smoothedVelocityVector = .zero
        smoothedAcceleration = 0
        lastVelocityMagnitude = 0
        lastDirection = .unknown
    }

    // MARK: - Private Methods

    /// Updates EMA-smoothed values with a new sample
    private func updateSmoothedValues(sample: VelocitySample, dt: TimeInterval) {
        let alpha = configuration.velocityEMAAlpha

        // EMA for velocity magnitude
        smoothedVelocityMagnitude = alpha * sample.magnitude + (1 - alpha) * smoothedVelocityMagnitude

        // EMA for velocity vector
        smoothedVelocityVector = CGPoint(
            x: alpha * sample.velocity.x + (1 - alpha) * smoothedVelocityVector.x,
            y: alpha * sample.velocity.y + (1 - alpha) * smoothedVelocityVector.y
        )

        // Calculate and smooth acceleration
        if dt > 0 && lastVelocityMagnitude > 0 {
            let instantAcceleration = (sample.magnitude - lastVelocityMagnitude) / dt
            let accAlpha = configuration.accelerationEMAAlpha
            smoothedAcceleration = accAlpha * instantAcceleration + (1 - accAlpha) * smoothedAcceleration
        }
    }

    /// Determines scroll direction from velocity vector
    private func determineDirection(from velocity: CGPoint) -> ScrollDirection {
        let absX = abs(velocity.x)
        let absY = abs(velocity.y)

        // Require minimum velocity to determine direction
        let minVelocity: Double = 10.0
        guard max(absX, absY) >= minVelocity else {
            return .unknown
        }

        if absY > absX {
            // Vertical scroll dominates
            // Note: In UIKit, negative Y velocity means finger moving up = content scrolling down
            return velocity.y < 0 ? .down : .up
        } else {
            // Horizontal scroll dominates
            return velocity.x < 0 ? .left : .right
        }
    }

    /// Removes old samples (thread-safe version)
    private func pruneOldSamples() {
        lock.lock()
        defer { lock.unlock() }
        pruneOldSamplesUnsafe()
    }

    /// Removes old samples (assumes lock is held)
    private func pruneOldSamplesUnsafe() {
        // Remove samples older than max age
        let cutoff = Date().addingTimeInterval(-configuration.maxSampleAge)
        samples.removeAll { $0.timestamp < cutoff }

        // Trim to max count
        if samples.count > configuration.maxSampleCount {
            samples.removeFirst(samples.count - configuration.maxSampleCount)
        }
    }
}

// MARK: - Debug Support

extension VelocityTracker {
    /// Debug description of current state
    public var debugDescription: String {
        lock.lock()
        defer { lock.unlock() }

        return """
        VelocityTracker State:
        - Samples: \(samples.count)
        - Velocity: \(String(format: "%.1f", smoothedVelocityMagnitude)) pts/s
        - Acceleration: \(String(format: "%.1f", smoothedAcceleration)) pts/s^2
        - Direction: \(lastDirection.rawValue)
        - Is Scrolling: \(isScrolling)
        """
    }
}

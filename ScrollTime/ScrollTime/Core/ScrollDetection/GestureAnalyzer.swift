//
//  GestureAnalyzer.swift
//  ScrollTime
//
//  Analyzes scroll gestures to detect compulsive scrolling patterns.
//  Uses velocity analysis, direction tracking, and statistical methods
//  to calculate scroll "intensity" scores for doom scrolling detection.
//

import Foundation
import UIKit
import Combine

// MARK: - Scroll Intensity

/// Represents the calculated intensity of scrolling behavior.
/// Higher scores indicate more compulsive/doom scrolling patterns.
public struct ScrollIntensity: Codable {
    /// Overall intensity score from 0.0 (no activity) to 1.0 (maximum doom scrolling)
    public let score: Double

    /// Component scores that contribute to the overall intensity
    public let velocityScore: Double
    public let frequencyScore: Double
    public let directionScore: Double
    public let consistencyScore: Double

    /// Timestamp when this intensity was calculated
    public let timestamp: Date

    /// Human-readable description of the intensity level
    public var level: IntensityLevel {
        switch score {
        case 0..<0.3: return .low
        case 0.3..<0.5: return .moderate
        case 0.5..<0.7: return .elevated
        case 0.7..<0.85: return .high
        default: return .critical
        }
    }

    public enum IntensityLevel: String {
        case low = "Low"
        case moderate = "Moderate"
        case elevated = "Elevated"
        case high = "High"
        case critical = "Critical"
    }
}

// MARK: - Gesture Analyzer

/// Analyzes scroll gestures to detect compulsive scrolling patterns.
/// Uses exponential moving averages for smooth, responsive detection
/// while filtering out noise from erratic input.
public final class GestureAnalyzer: ObservableObject {

    // MARK: - Published State

    /// Current calculated scroll intensity
    @Published public private(set) var currentIntensity: ScrollIntensity?

    /// Exponentially smoothed average velocity
    @Published public private(set) var smoothedVelocity: Double = 0

    /// Current scroll direction
    @Published public private(set) var currentDirection: ScrollDirection = .unknown

    /// Whether the analyzer detects active scrolling
    @Published public private(set) var isScrolling: Bool = false

    // MARK: - Configuration

    /// Configuration used for analysis thresholds
    public var config: DetectionConfig {
        didSet {
            // Recalculate intensity when config changes
            if let session = lastAnalyzedSession {
                _ = analyzeSession(session)
            }
        }
    }

    // MARK: - Private State

    /// Last time we processed a scroll event
    private var lastProcessTime: Date?

    /// EMA (exponential moving average) of velocity
    private var velocityEMA: Double = 0

    /// EMA of scroll frequency (scrolls per second)
    private var frequencyEMA: Double = 0

    /// Timestamps of recent scrolls for frequency calculation
    private var recentScrollTimes: [Date] = []

    /// Maximum recent scroll times to track
    private let maxRecentScrollTimes = 30

    /// Reference to last analyzed session for recalculation
    private weak var lastAnalyzedSession: ScrollSession?

    /// Thread-safe lock for mutable state
    private let lock = NSLock()

    // MARK: - Initialization

    public init(config: DetectionConfig = .default) {
        self.config = config
    }

    // MARK: - Gesture Processing

    /// Processes a raw pan gesture recognizer and extracts scroll metrics.
    /// Call this from your gesture recognizer callback.
    ///
    /// - Parameters:
    ///   - recognizer: The pan gesture recognizer
    ///   - session: The current scroll session to record events to
    /// - Returns: The scroll event that was recorded, or nil if filtered out
    @discardableResult
    public func processPanGesture(
        _ recognizer: UIPanGestureRecognizer,
        session: ScrollSession
    ) -> ScrollEvent? {

        // Rate limit processing for battery efficiency
        let now = Date()
        if let lastProcess = lastProcessTime,
           now.timeIntervalSince(lastProcess) < config.minimumProcessingInterval {
            return nil
        }
        lastProcessTime = now

        // Extract velocity from gesture recognizer
        let velocity = recognizer.velocity(in: recognizer.view)
        let translation = recognizer.translation(in: recognizer.view)

        // Calculate magnitude and direction
        let velocityMagnitude = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        let direction = determineDirection(from: velocity, translation: translation)

        // Filter out very low velocity scrolls (noise)
        guard velocityMagnitude >= config.minimumVelocity else {
            return nil
        }

        // Clamp velocity to prevent outliers from skewing averages
        let clampedVelocity = min(velocityMagnitude, config.velocityClampMax)

        // Create and record the scroll event
        let event = ScrollEvent(
            direction: direction,
            velocity: clampedVelocity,
            distance: sqrt(translation.x * translation.x + translation.y * translation.y)
        )

        // Record to session
        session.recordEvent(event)

        // Update our smoothed metrics
        updateSmoothedMetrics(velocity: clampedVelocity, direction: direction, timestamp: now)

        // Update scrolling state based on gesture state
        switch recognizer.state {
        case .began, .changed:
            isScrolling = true
        case .ended, .cancelled, .failed:
            isScrolling = false
        default:
            break
        }

        return event
    }

    /// Processes scroll metrics directly (for when you don't have a gesture recognizer).
    /// Useful for simulated scrolling or testing.
    ///
    /// - Parameters:
    ///   - velocity: Scroll velocity in points per second
    ///   - direction: Direction of the scroll
    ///   - session: The current scroll session to record events to
    /// - Returns: The scroll event that was recorded, or nil if filtered out
    @discardableResult
    public func processScroll(
        velocity: Double,
        direction: ScrollDirection,
        session: ScrollSession
    ) -> ScrollEvent? {

        let now = Date()

        // Rate limit processing
        if let lastProcess = lastProcessTime,
           now.timeIntervalSince(lastProcess) < config.minimumProcessingInterval {
            return nil
        }
        lastProcessTime = now

        // Filter out very low velocity scrolls
        guard velocity >= config.minimumVelocity else {
            return nil
        }

        // Clamp velocity
        let clampedVelocity = min(velocity, config.velocityClampMax)

        // Create and record the event
        let event = ScrollEvent.simple(
            direction: direction,
            velocity: clampedVelocity,
            timestamp: now
        )

        session.recordEvent(event)

        // Update smoothed metrics
        updateSmoothedMetrics(velocity: clampedVelocity, direction: direction, timestamp: now)

        return event
    }

    // MARK: - Direction Detection

    /// Determines scroll direction from velocity and translation vectors
    private func determineDirection(from velocity: CGPoint, translation: CGPoint) -> ScrollDirection {
        // Use the dominant axis based on velocity magnitude
        let absVelocityX = abs(velocity.x)
        let absVelocityY = abs(velocity.y)

        // Require a minimum difference to determine axis
        let axisDifferenceThreshold: CGFloat = 50

        if abs(absVelocityX - absVelocityY) < axisDifferenceThreshold {
            // Velocities are similar - use translation to determine
            let absTranslationX = abs(translation.x)
            let absTranslationY = abs(translation.y)

            if absTranslationY > absTranslationX {
                return translation.y < 0 ? .up : .down
            } else if absTranslationX > absTranslationY {
                return translation.x < 0 ? .left : .right
            }
            return .unknown
        }

        if absVelocityY > absVelocityX {
            // Vertical scroll
            // Note: negative velocity.y means scrolling down (content moves up)
            return velocity.y < 0 ? .down : .up
        } else {
            // Horizontal scroll
            return velocity.x < 0 ? .left : .right
        }
    }

    // MARK: - Smoothed Metrics

    /// Updates exponential moving averages for velocity and frequency
    private func updateSmoothedMetrics(velocity: Double, direction: ScrollDirection, timestamp: Date) {
        lock.lock()
        defer { lock.unlock() }

        // Update velocity EMA
        // EMA = alpha * current + (1 - alpha) * previous
        velocityEMA = config.velocityEMAAlpha * velocity + (1 - config.velocityEMAAlpha) * velocityEMA
        smoothedVelocity = velocityEMA

        // Update direction
        currentDirection = direction

        // Track scroll times for frequency calculation
        recentScrollTimes.append(timestamp)

        // Remove old scroll times outside our window
        let windowCutoff = timestamp.addingTimeInterval(-config.analysisWindowDuration)
        recentScrollTimes.removeAll { $0 < windowCutoff }

        // Trim to max size
        if recentScrollTimes.count > maxRecentScrollTimes {
            recentScrollTimes.removeFirst(recentScrollTimes.count - maxRecentScrollTimes)
        }

        // Calculate frequency (scrolls per second)
        if recentScrollTimes.count >= 2 {
            let timeSpan = recentScrollTimes.last!.timeIntervalSince(recentScrollTimes.first!)
            if timeSpan > 0 {
                let instantFrequency = Double(recentScrollTimes.count - 1) / timeSpan
                frequencyEMA = config.velocityEMAAlpha * instantFrequency + (1 - config.velocityEMAAlpha) * frequencyEMA
            }
        }
    }

    // MARK: - Session Analysis

    /// Analyzes a scroll session and calculates the current intensity score.
    /// This is the main entry point for doom scrolling detection.
    ///
    /// - Parameter session: The scroll session to analyze
    /// - Returns: The calculated scroll intensity
    public func analyzeSession(_ session: ScrollSession) -> ScrollIntensity {
        lastAnalyzedSession = session

        // Calculate individual component scores (each 0.0 - 1.0)
        let velocityScore = calculateVelocityScore(session: session)
        let frequencyScore = calculateFrequencyScore(session: session)
        let directionScore = calculateDirectionScore(session: session)
        let consistencyScore = calculateConsistencyScore(session: session)

        // Weighted combination of scores
        // Weights tuned for doom scrolling detection:
        // - Velocity is important but not dominant (25%)
        // - Frequency (compulsive rapid scrolling) is very important (30%)
        // - Direction (mostly downward) is a key indicator (25%)
        // - Consistency (steady pattern vs erratic) matters (20%)
        let weightedScore =
            velocityScore * 0.25 +
            frequencyScore * 0.30 +
            directionScore * 0.25 +
            consistencyScore * 0.20

        // Apply session duration multiplier
        // Longer sessions increase the intensity score
        let durationMultiplier = calculateDurationMultiplier(session: session)
        let finalScore = min(1.0, weightedScore * durationMultiplier)

        let intensity = ScrollIntensity(
            score: finalScore,
            velocityScore: velocityScore,
            frequencyScore: frequencyScore,
            directionScore: directionScore,
            consistencyScore: consistencyScore,
            timestamp: Date()
        )

        // Update published state
        currentIntensity = intensity

        return intensity
    }

    // MARK: - Score Components

    /// Calculates velocity score based on average and recent velocity.
    /// Higher velocities indicate less engagement with content.
    private func calculateVelocityScore(session: ScrollSession) -> Double {
        let avgVelocity = session.recentAverageVelocity

        // Normalize to 0-1 range based on config thresholds
        // Score increases as velocity approaches rapidScrollVelocity
        let normalized = (avgVelocity - config.minimumVelocity) /
                        (config.rapidScrollVelocity - config.minimumVelocity)

        return clamp(normalized, min: 0, max: 1)
    }

    /// Calculates frequency score based on scrolls per minute.
    /// Higher frequency indicates more compulsive behavior.
    private func calculateFrequencyScore(session: ScrollSession) -> Double {
        let scrollsPerMinute = session.scrollsPerMinute

        // Typical reading/browsing: 10-20 scrolls per minute
        // Doom scrolling: 40+ scrolls per minute
        // Normalize with reference points
        let minFreq: Double = 10  // Below this is very slow browsing
        let maxFreq: Double = 60  // Above this is intense doom scrolling

        let normalized = (scrollsPerMinute - minFreq) / (maxFreq - minFreq)
        return clamp(normalized, min: 0, max: 1)
    }

    /// Calculates direction score based on downward scroll ratio.
    /// Doom scrolling is characterized by predominantly downward scrolling.
    private func calculateDirectionScore(session: ScrollSession) -> Double {
        let downwardRatio = session.downwardScrollRatio

        // Score increases as ratio approaches the configured threshold
        // Below 50% downward is definitely not doom scrolling
        // Above threshold (e.g., 75%) is likely doom scrolling
        let minRatio: Double = 0.5
        let targetRatio = config.downwardScrollRatio

        if downwardRatio < minRatio {
            return 0
        }

        let normalized = (downwardRatio - minRatio) / (targetRatio - minRatio)
        return clamp(normalized, min: 0, max: 1)
    }

    /// Calculates consistency score based on velocity variance.
    /// Consistent, steady scrolling indicates mindless doom scrolling.
    /// Erratic scrolling may indicate actually looking at content.
    private func calculateConsistencyScore(session: ScrollSession) -> Double {
        let stdDev = session.velocityStandardDeviation
        let avgVelocity = session.recentAverageVelocity

        // Coefficient of variation (CV) = stdDev / mean
        // Lower CV = more consistent = higher doom scroll likelihood
        guard avgVelocity > 0 else { return 0.5 }

        let cv = stdDev / avgVelocity

        // CV thresholds (empirically determined):
        // CV < 0.3: Very consistent, likely doom scrolling
        // CV > 0.8: Erratic, likely engaged browsing
        let minCV: Double = 0.2
        let maxCV: Double = 0.8

        // Invert the score: lower CV = higher score
        let normalized = 1.0 - (cv - minCV) / (maxCV - minCV)
        return clamp(normalized, min: 0, max: 1)
    }

    /// Calculates a duration multiplier that increases intensity for longer sessions.
    private func calculateDurationMultiplier(session: ScrollSession) -> Double {
        let duration = session.duration

        if duration < config.minimumSessionDuration {
            // Session too short - reduce intensity
            return duration / config.minimumSessionDuration
        } else if duration < config.extendedSessionDuration {
            // Normal session range - no modification
            return 1.0
        } else if duration < config.maximumSessionDuration {
            // Extended session - gradually increase
            let progress = (duration - config.extendedSessionDuration) /
                          (config.maximumSessionDuration - config.extendedSessionDuration)
            return 1.0 + (progress * 0.3)  // Up to 30% increase
        } else {
            // Maximum session exceeded - maximum multiplier
            return 1.5
        }
    }

    // MARK: - Pattern Detection

    /// Detects if there has been a significant pause in scrolling.
    /// Used to determine if the user might be reading content.
    public func detectPause(in session: ScrollSession) -> Bool {
        guard let lastGap = session.recentScrollGap else {
            return false
        }
        return lastGap >= config.pauseBreakThreshold
    }

    /// Detects rapid direction changes that might indicate erratic behavior.
    public func detectErraticBehavior(in session: ScrollSession) -> Bool {
        let changesPerMinute = session.directionChangesPerMinute
        return changesPerMinute >= config.directionChangeRateThreshold
    }

    /// Detects if the current scrolling pattern matches doom scrolling characteristics.
    public func isDoomScrollingPattern(in session: ScrollSession) -> Bool {
        guard session.totalScrollCount >= config.minimumScrollCount,
              session.duration >= config.minimumSessionDuration else {
            return false
        }

        // Check multiple indicators
        let hasHighDownwardRatio = session.downwardScrollRatio >= config.downwardScrollRatio
        let hasHighFrequency = session.scrollsPerMinute >= 30  // 30+ scrolls per minute
        let noPauses = !detectPause(in: session)
        let notErratic = !detectErraticBehavior(in: session)

        // Doom scrolling requires: high downward ratio + high frequency + no pauses + consistent pattern
        return hasHighDownwardRatio && hasHighFrequency && noPauses && notErratic
    }

    // MARK: - Reset

    /// Resets the analyzer state. Call when starting a new monitoring period.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        velocityEMA = 0
        frequencyEMA = 0
        smoothedVelocity = 0
        currentDirection = .unknown
        currentIntensity = nil
        isScrolling = false
        recentScrollTimes.removeAll()
        lastProcessTime = nil
        lastAnalyzedSession = nil
    }

    // MARK: - Utilities

    /// Clamps a value between min and max
    private func clamp(_ value: Double, min minVal: Double, max maxVal: Double) -> Double {
        Swift.max(minVal, Swift.min(maxVal, value))
    }
}

// MARK: - SwiftUI Gesture Support

extension GestureAnalyzer {

    /// Processes a SwiftUI DragGesture value.
    /// Use this when working with SwiftUI gestures instead of UIKit.
    ///
    /// - Parameters:
    ///   - value: The DragGesture.Value from the gesture
    ///   - session: The current scroll session
    /// - Returns: The scroll event that was recorded, or nil if filtered out
    @discardableResult
    public func processDragGesture(
        translation: CGSize,
        predictedEndTranslation: CGSize,
        session: ScrollSession
    ) -> ScrollEvent? {
        let now = Date()

        // Rate limit
        if let lastProcess = lastProcessTime,
           now.timeIntervalSince(lastProcess) < config.minimumProcessingInterval {
            return nil
        }

        // Calculate velocity from predicted end translation
        // The difference between current and predicted gives us velocity indication
        let velocityX = predictedEndTranslation.width - translation.width
        let velocityY = predictedEndTranslation.height - translation.height
        let velocityMagnitude = sqrt(velocityX * velocityX + velocityY * velocityY)

        // Determine direction
        let direction: ScrollDirection
        if abs(velocityY) > abs(velocityX) {
            direction = velocityY < 0 ? .up : .down
        } else if abs(velocityX) > abs(velocityY) {
            direction = velocityX < 0 ? .left : .right
        } else {
            direction = .unknown
        }

        // Scale velocity (SwiftUI velocities tend to be smaller)
        let scaledVelocity = velocityMagnitude * 10

        return processScroll(velocity: scaledVelocity, direction: direction, session: session)
    }
}

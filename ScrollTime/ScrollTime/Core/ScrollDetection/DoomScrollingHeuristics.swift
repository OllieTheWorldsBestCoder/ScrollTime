//
//  DoomScrollingHeuristics.swift
//  ScrollTime
//
//  Production-grade heuristics engine for detecting doom scrolling patterns.
//  Uses multi-factor analysis combining:
//  - Duration metrics (continuous scrolling without meaningful breaks)
//  - Velocity patterns (consistent speed without reading pauses)
//  - Direction uniformity (predominantly downward scrolling)
//  - Interaction gaps (lack of taps or content engagement)
//  - Session frequency (compulsive checking patterns)
//
//  The algorithm is designed to minimize false positives while catching
//  genuine doom scrolling behavior. All thresholds are configurable and
//  have been tuned based on behavioral research.
//

import Foundation
import Combine

// MARK: - Doom Scroll Score

/// Comprehensive score representing the likelihood of doom scrolling behavior.
/// Each component score is weighted and combined into a final score.
public struct DoomScrollScore: Equatable {
    /// Overall score from 0.0 (not doom scrolling) to 1.0 (definitely doom scrolling)
    public let overallScore: Double

    /// Duration component: How long has the user been scrolling continuously?
    /// Higher scores for longer sessions without breaks.
    public let durationScore: Double

    /// Velocity component: Is the scrolling speed consistent with "browsing mode"?
    /// Higher scores for medium-speed consistent scrolling (not reading, not rapid flicking)
    public let velocityScore: Double

    /// Direction component: Is scrolling predominantly in one direction (typically down)?
    /// Higher scores indicate feed-like scrolling behavior.
    public let directionScore: Double

    /// Consistency component: Is the scrolling pattern steady without pauses for reading?
    /// Higher scores for machine-like consistent scrolling.
    public let consistencyScore: Double

    /// Engagement component: Are there meaningful interactions (taps, long pauses)?
    /// Higher scores when there's NO engagement (inverse relationship).
    public let engagementScore: Double

    /// Timestamp when this score was calculated
    public let timestamp: Date

    /// The contributing factors that pushed the score up
    public var primaryFactors: [String] {
        var factors: [String] = []
        if durationScore > 0.6 { factors.append("Extended session duration") }
        if velocityScore > 0.6 { factors.append("Consistent scroll velocity") }
        if directionScore > 0.7 { factors.append("Predominantly downward scrolling") }
        if consistencyScore > 0.6 { factors.append("Lack of reading pauses") }
        if engagementScore > 0.6 { factors.append("No content engagement detected") }
        return factors
    }

    /// Human-readable description of the score level
    public var level: DoomScrollLevel {
        switch overallScore {
        case 0..<0.25: return .none
        case 0.25..<0.45: return .mild
        case 0.45..<0.65: return .moderate
        case 0.65..<0.80: return .elevated
        default: return .severe
        }
    }

    /// Empty score for initial state
    public static let empty = DoomScrollScore(
        overallScore: 0,
        durationScore: 0,
        velocityScore: 0,
        directionScore: 0,
        consistencyScore: 0,
        engagementScore: 0,
        timestamp: Date()
    )
}

// MARK: - Doom Scroll Level

/// Categorical levels of doom scrolling intensity
public enum DoomScrollLevel: String, CaseIterable {
    case none = "None"
    case mild = "Mild"
    case moderate = "Moderate"
    case elevated = "Elevated"
    case severe = "Severe"

    /// Whether this level should trigger an intervention
    public var shouldIntervene: Bool {
        switch self {
        case .none, .mild: return false
        case .moderate, .elevated, .severe: return true
        }
    }

    /// The recommended intervention type for this level
    public var recommendedIntervention: InterventionType? {
        switch self {
        case .none, .mild: return nil
        case .moderate: return .gentleReminder
        case .elevated: return .breathingExercise
        case .severe: return .timedPause
        }
    }
}

// MARK: - Heuristics Configuration

/// Configuration for the doom scrolling detection heuristics
public struct HeuristicsConfiguration: Codable, Equatable {
    // MARK: - Duration Thresholds

    /// Minimum session duration (seconds) before doom scroll detection activates
    public var minimumSessionDuration: TimeInterval

    /// Duration (seconds) at which duration score reaches 50%
    public var midpointDuration: TimeInterval

    /// Duration (seconds) at which duration score reaches maximum
    public var maximumDuration: TimeInterval

    // MARK: - Velocity Thresholds

    /// Minimum velocity (pts/s) for active scrolling consideration
    public var minimumVelocity: Double

    /// Velocity range (pts/s) considered "browsing mode" (not reading, not flicking)
    /// Doom scrolling typically occurs in this range
    public var doomScrollVelocityRange: ClosedRange<Double>

    /// Velocity (pts/s) above which scrolling is too fast to be doom scrolling
    /// (rapid flicking to find specific content)
    public var rapidFlickVelocity: Double

    // MARK: - Direction Thresholds

    /// Minimum ratio of downward scrolls for direction score to activate
    public var minimumDownwardRatio: Double

    /// Target downward ratio for maximum direction score
    public var targetDownwardRatio: Double

    // MARK: - Consistency Thresholds

    /// Maximum coefficient of variation (CV) for "consistent" scrolling
    /// Lower CV = more consistent = higher doom scroll likelihood
    public var consistentScrollingMaxCV: Double

    /// CV below which scrolling is considered very consistent
    public var veryConsistentCV: Double

    // MARK: - Pause/Engagement Thresholds

    /// Pause duration (seconds) that indicates content reading
    public var readingPauseDuration: TimeInterval

    /// Pause duration (seconds) that counts as a meaningful break
    public var meaningfulBreakDuration: TimeInterval

    /// Maximum direction changes per minute for "engaged" browsing
    public var maxDirectionChangesPerMinute: Double

    // MARK: - Score Weights

    /// Weight for duration component (0-1, all weights should sum to 1)
    public var durationWeight: Double

    /// Weight for velocity component
    public var velocityWeight: Double

    /// Weight for direction component
    public var directionWeight: Double

    /// Weight for consistency component
    public var consistencyWeight: Double

    /// Weight for engagement component
    public var engagementWeight: Double

    // MARK: - Presets

    /// Default configuration balanced for most users
    public static let `default` = HeuristicsConfiguration(
        minimumSessionDuration: 60,          // 1 minute before detection starts
        midpointDuration: 180,               // 3 minutes for 50% duration score
        maximumDuration: 600,                // 10 minutes for max duration score
        minimumVelocity: 50,
        doomScrollVelocityRange: 200...1000, // "Browsing mode" velocity range
        rapidFlickVelocity: 1500,
        minimumDownwardRatio: 0.55,
        targetDownwardRatio: 0.85,
        consistentScrollingMaxCV: 0.6,
        veryConsistentCV: 0.25,
        readingPauseDuration: 3.0,
        meaningfulBreakDuration: 10.0,
        maxDirectionChangesPerMinute: 15,
        durationWeight: 0.20,
        velocityWeight: 0.25,
        directionWeight: 0.20,
        consistencyWeight: 0.20,
        engagementWeight: 0.15
    )

    /// Strict configuration - detects doom scrolling earlier
    public static let strict = HeuristicsConfiguration(
        minimumSessionDuration: 30,
        midpointDuration: 90,
        maximumDuration: 300,
        minimumVelocity: 30,
        doomScrollVelocityRange: 150...1200,
        rapidFlickVelocity: 1200,
        minimumDownwardRatio: 0.50,
        targetDownwardRatio: 0.75,
        consistentScrollingMaxCV: 0.7,
        veryConsistentCV: 0.35,
        readingPauseDuration: 2.0,
        meaningfulBreakDuration: 8.0,
        maxDirectionChangesPerMinute: 20,
        durationWeight: 0.15,
        velocityWeight: 0.30,
        directionWeight: 0.20,
        consistencyWeight: 0.20,
        engagementWeight: 0.15
    )

    /// Relaxed configuration - fewer false positives
    public static let relaxed = HeuristicsConfiguration(
        minimumSessionDuration: 120,
        midpointDuration: 300,
        maximumDuration: 900,
        minimumVelocity: 80,
        doomScrollVelocityRange: 300...800,
        rapidFlickVelocity: 1800,
        minimumDownwardRatio: 0.65,
        targetDownwardRatio: 0.90,
        consistentScrollingMaxCV: 0.5,
        veryConsistentCV: 0.2,
        readingPauseDuration: 5.0,
        meaningfulBreakDuration: 15.0,
        maxDirectionChangesPerMinute: 10,
        durationWeight: 0.25,
        velocityWeight: 0.20,
        directionWeight: 0.20,
        consistencyWeight: 0.20,
        engagementWeight: 0.15
    )
}

// MARK: - Doom Scrolling Heuristics Engine

/// The main heuristics engine that analyzes scroll behavior and calculates
/// doom scrolling likelihood scores.
///
/// This engine is designed to be called periodically (e.g., every second) with
/// updated session data. It maintains internal state for tracking engagement
/// patterns and provides both real-time scores and historical analysis.
public final class DoomScrollingHeuristics: ObservableObject {

    // MARK: - Published State

    /// Current doom scroll score
    @Published public private(set) var currentScore: DoomScrollScore = .empty

    /// Whether doom scrolling is currently detected
    @Published public private(set) var isDoomScrollingDetected: Bool = false

    /// Time when doom scrolling was first detected in current session
    @Published public private(set) var doomScrollingStartTime: Date?

    // MARK: - Configuration

    /// Heuristics configuration
    public var configuration: HeuristicsConfiguration

    // MARK: - Private State

    /// Timestamp of last reading pause detected
    private var lastReadingPause: Date?

    /// Count of reading pauses in current session
    private var readingPauseCount: Int = 0

    /// Timestamp of last meaningful interaction (tap, etc.)
    private var lastInteraction: Date?

    /// Count of interactions in current session
    private var interactionCount: Int = 0

    /// Historical scores for trend analysis
    private var scoreHistory: [DoomScrollScore] = []
    private let maxScoreHistory = 60  // Keep last 60 scores (~1 minute at 1Hz)

    /// Thread safety
    private let lock = NSLock()

    // MARK: - Initialization

    public init(configuration: HeuristicsConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Score Calculation

    /// Calculates the current doom scroll score based on session data.
    ///
    /// Call this periodically (recommended: once per second) with updated session data.
    ///
    /// - Parameters:
    ///   - session: The current scroll session
    ///   - velocityStats: Recent velocity statistics from VelocityTracker
    /// - Returns: The calculated doom scroll score
    @discardableResult
    public func calculateScore(
        session: ScrollSession,
        velocityStats: VelocityStatistics
    ) -> DoomScrollScore {
        lock.lock()
        defer { lock.unlock() }

        // Calculate individual component scores
        let durationScore = calculateDurationScore(session: session)
        let velocityScore = calculateVelocityScore(stats: velocityStats)
        let directionScore = calculateDirectionScore(session: session)
        let consistencyScore = calculateConsistencyScore(stats: velocityStats, session: session)
        let engagementScore = calculateEngagementScore(session: session)

        // Combine with weights
        let config = configuration
        let weightedScore =
            durationScore * config.durationWeight +
            velocityScore * config.velocityWeight +
            directionScore * config.directionWeight +
            consistencyScore * config.consistencyWeight +
            engagementScore * config.engagementWeight

        // Apply duration gating: scores are reduced if session is too short
        let durationGate = min(1.0, session.duration / configuration.minimumSessionDuration)
        let gatedScore = weightedScore * durationGate

        // Clamp to valid range
        let finalScore = min(1.0, max(0.0, gatedScore))

        let score = DoomScrollScore(
            overallScore: finalScore,
            durationScore: durationScore,
            velocityScore: velocityScore,
            directionScore: directionScore,
            consistencyScore: consistencyScore,
            engagementScore: engagementScore,
            timestamp: Date()
        )

        // Update state
        currentScore = score

        // Track doom scrolling state
        let wasDetected = isDoomScrollingDetected
        isDoomScrollingDetected = score.level.shouldIntervene

        if isDoomScrollingDetected && !wasDetected {
            doomScrollingStartTime = Date()
        } else if !isDoomScrollingDetected && wasDetected {
            doomScrollingStartTime = nil
        }

        // Store in history
        scoreHistory.append(score)
        if scoreHistory.count > maxScoreHistory {
            scoreHistory.removeFirst()
        }

        return score
    }

    // MARK: - Component Score Calculations

    /// Calculates duration score using a sigmoid-like curve
    private func calculateDurationScore(session: ScrollSession) -> Double {
        let duration = session.duration
        let config = configuration

        // No score if session is too short
        guard duration >= config.minimumSessionDuration else {
            return 0
        }

        // Use sigmoid-like curve for smooth transition
        // Score approaches 1.0 as duration approaches maximum
        let normalized = (duration - config.minimumSessionDuration) /
                        (config.maximumDuration - config.minimumSessionDuration)

        // Apply sigmoid transformation for natural progression
        let k = 3.0  // Steepness factor
        let midpoint = (config.midpointDuration - config.minimumSessionDuration) /
                       (config.maximumDuration - config.minimumSessionDuration)
        let sigmoid = 1.0 / (1.0 + exp(-k * (normalized - midpoint)))

        return min(1.0, sigmoid)
    }

    /// Calculates velocity score based on whether velocity is in "doom scroll range"
    private func calculateVelocityScore(stats: VelocityStatistics) -> Double {
        let config = configuration

        // Need minimum samples
        guard stats.sampleCount >= 3 else { return 0 }

        let avgVelocity = stats.averageMagnitude

        // Very low velocity = not really scrolling
        guard avgVelocity >= config.minimumVelocity else { return 0 }

        // Rapid flicking = probably searching, not doom scrolling
        if avgVelocity > config.rapidFlickVelocity {
            return 0.2  // Low score for rapid flicking
        }

        // Check if velocity is in the "doom scroll zone"
        let range = config.doomScrollVelocityRange
        if range.contains(avgVelocity) {
            // Within doom scroll range - calculate how centered it is
            let rangeCenter = (range.lowerBound + range.upperBound) / 2
            let distanceFromCenter = abs(avgVelocity - rangeCenter)
            let maxDistance = (range.upperBound - range.lowerBound) / 2
            let centeredness = 1.0 - (distanceFromCenter / maxDistance)
            return 0.5 + (centeredness * 0.5)  // Score from 0.5 to 1.0
        }

        // Outside doom scroll range
        if avgVelocity < range.lowerBound {
            // Slower than doom scroll range - might be reading
            let ratio = avgVelocity / range.lowerBound
            return 0.3 * ratio
        } else {
            // Faster than doom scroll range but not rapid flicking
            let ratio = range.upperBound / avgVelocity
            return 0.4 * ratio
        }
    }

    /// Calculates direction score based on downward scroll ratio
    private func calculateDirectionScore(session: ScrollSession) -> Double {
        let config = configuration
        let downwardRatio = session.downwardScrollRatio

        // Below minimum ratio = not doom scrolling behavior
        guard downwardRatio >= config.minimumDownwardRatio else {
            return downwardRatio / config.minimumDownwardRatio * 0.3
        }

        // Linear interpolation from minimum to target
        let normalized = (downwardRatio - config.minimumDownwardRatio) /
                        (config.targetDownwardRatio - config.minimumDownwardRatio)

        return min(1.0, 0.3 + (normalized * 0.7))
    }

    /// Calculates consistency score based on velocity variance
    private func calculateConsistencyScore(stats: VelocityStatistics, session: ScrollSession) -> Double {
        let config = configuration

        guard stats.sampleCount >= 5 else { return 0 }

        let cv = stats.coefficientOfVariation

        // Very consistent scrolling (low CV) = higher doom scroll likelihood
        if cv <= config.veryConsistentCV {
            return 1.0
        } else if cv <= config.consistentScrollingMaxCV {
            // Moderate consistency
            let normalized = (config.consistentScrollingMaxCV - cv) /
                            (config.consistentScrollingMaxCV - config.veryConsistentCV)
            return 0.5 + (normalized * 0.5)
        } else {
            // High variance = erratic scrolling = likely engaged browsing
            let normalized = min(1.0, (cv - config.consistentScrollingMaxCV) / 0.5)
            return max(0, 0.5 - (normalized * 0.4))
        }
    }

    /// Calculates engagement score (inverse - high score means LOW engagement)
    private func calculateEngagementScore(session: ScrollSession) -> Double {
        let config = configuration

        var engagementIndicators: Double = 0
        var maxIndicators: Double = 3

        // Check for reading pauses (time since last scroll > threshold indicates user is reading)
        // Use timeSinceLastScroll for real-time pause detection, fallback to recentScrollGap
        // for historical gap analysis within the scroll event stream
        let currentPause = session.timeSinceLastScroll ?? 0
        let lastRecordedGap = session.recentScrollGap ?? 0
        let effectivePause = max(currentPause, lastRecordedGap)

        if effectivePause >= config.readingPauseDuration {
            engagementIndicators += 1
            recordReadingPause()
        }

        // Check direction change rate (engaged browsing has more back-and-forth)
        let directionChanges = session.directionChangesPerMinute
        if directionChanges > config.maxDirectionChangesPerMinute {
            engagementIndicators += 1
        }

        // Check for meaningful pauses in the recent history
        if readingPauseCount >= 2 {
            engagementIndicators += 1
        }

        // Inverse score: more engagement indicators = lower doom scroll score
        let engagementRatio = engagementIndicators / maxIndicators
        return max(0, 1.0 - engagementRatio)
    }

    // MARK: - Engagement Tracking

    /// Records that a reading pause was detected
    public func recordReadingPause() {
        lock.lock()
        defer { lock.unlock() }

        lastReadingPause = Date()
        readingPauseCount += 1
    }

    /// Records a user interaction (tap, long press, etc.)
    public func recordInteraction() {
        lock.lock()
        defer { lock.unlock() }

        lastInteraction = Date()
        interactionCount += 1
    }

    // MARK: - Trend Analysis

    /// Returns the trend direction of doom scroll scores
    /// Positive = increasing, Negative = decreasing, Zero = stable
    public func scoreTrend(windowSize: Int = 10) -> Double {
        lock.lock()
        defer { lock.unlock() }

        guard scoreHistory.count >= windowSize else { return 0 }

        let recentScores = scoreHistory.suffix(windowSize)
        let firstHalf = Array(recentScores.prefix(windowSize / 2))
        let secondHalf = Array(recentScores.suffix(windowSize / 2))

        let firstAvg = firstHalf.map { $0.overallScore }.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map { $0.overallScore }.reduce(0, +) / Double(secondHalf.count)

        return secondAvg - firstAvg
    }

    /// Returns whether the user appears to be escalating into deeper doom scrolling
    public var isEscalating: Bool {
        scoreTrend() > 0.05  // Score increasing by more than 5%
    }

    // MARK: - Reset

    /// Resets all heuristics state. Call when starting a new session.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        currentScore = .empty
        isDoomScrollingDetected = false
        doomScrollingStartTime = nil
        lastReadingPause = nil
        readingPauseCount = 0
        lastInteraction = nil
        interactionCount = 0
        scoreHistory.removeAll()
    }
}

// MARK: - Debug Support

extension DoomScrollingHeuristics {
    /// Debug description of current state
    public var debugDescription: String {
        """
        DoomScrollingHeuristics:
        - Overall Score: \(String(format: "%.2f", currentScore.overallScore))
        - Level: \(currentScore.level.rawValue)
        - Detected: \(isDoomScrollingDetected)
        - Components:
          - Duration: \(String(format: "%.2f", currentScore.durationScore))
          - Velocity: \(String(format: "%.2f", currentScore.velocityScore))
          - Direction: \(String(format: "%.2f", currentScore.directionScore))
          - Consistency: \(String(format: "%.2f", currentScore.consistencyScore))
          - Engagement: \(String(format: "%.2f", currentScore.engagementScore))
        - Reading Pauses: \(readingPauseCount)
        - Interactions: \(interactionCount)
        - Trend: \(String(format: "%.3f", scoreTrend()))
        """
    }
}

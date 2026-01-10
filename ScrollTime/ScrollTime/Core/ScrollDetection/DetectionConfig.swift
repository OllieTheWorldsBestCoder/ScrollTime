//
//  DetectionConfig.swift
//  ScrollTime
//
//  Configuration for scroll detection sensitivity and thresholds.
//  Provides preset sensitivity levels and customizable threshold values
//  for detecting doom scrolling behavior patterns.
//

import Foundation

// MARK: - Sensitivity Level

/// Predefined sensitivity levels for scroll detection.
/// Higher sensitivity means faster detection but more potential false positives.
public enum SensitivityLevel: String, CaseIterable, Codable, Identifiable {
    case low
    case medium
    case high

    public var id: String { rawValue }

    /// Human-readable display name for UI
    public var displayName: String {
        switch self {
        case .low: return "Relaxed"
        case .medium: return "Balanced"
        case .high: return "Strict"
        }
    }

    /// Description explaining what this sensitivity level means
    public var description: String {
        switch self {
        case .low:
            return "Intervene only after extended scrolling sessions. Best for casual monitoring."
        case .medium:
            return "Balanced detection for typical doom scrolling patterns. Recommended for most users."
        case .high:
            return "Quick intervention at first signs of compulsive scrolling. Best for breaking strong habits."
        }
    }
}

// MARK: - Detection Configuration

/// Configuration struct containing all thresholds and parameters for scroll detection.
/// Use preset sensitivity levels or create custom configurations.
public struct DetectionConfig: Codable, Equatable {

    // MARK: - Session Duration Thresholds

    /// Minimum session duration (in seconds) before doom scrolling can be detected.
    /// Sessions shorter than this are considered normal browsing.
    public var minimumSessionDuration: TimeInterval

    /// Duration (in seconds) at which a session is considered "extended" and
    /// warrants stronger intervention consideration.
    public var extendedSessionDuration: TimeInterval

    /// Maximum session duration (in seconds) before forcing an intervention
    /// regardless of other metrics.
    public var maximumSessionDuration: TimeInterval

    // MARK: - Scroll Count Thresholds

    /// Minimum number of scroll gestures within the analysis window to trigger detection.
    public var minimumScrollCount: Int

    /// Scroll count threshold for "high activity" classification.
    public var highActivityScrollCount: Int

    // MARK: - Velocity Thresholds (points per second)

    /// Minimum average scroll velocity to be considered active scrolling.
    /// Velocities below this are treated as slow reading/browsing.
    public var minimumVelocity: Double

    /// Velocity threshold indicating rapid scrolling behavior.
    /// Scrolling above this speed suggests content is not being consumed meaningfully.
    public var rapidScrollVelocity: Double

    /// Maximum velocity to track (prevents outliers from skewing averages).
    public var velocityClampMax: Double

    // MARK: - Pattern Detection

    /// Time window (in seconds) for analyzing recent scroll patterns.
    /// Scroll events older than this are not considered in pattern analysis.
    public var analysisWindowDuration: TimeInterval

    /// Maximum pause duration (in seconds) between scrolls before resetting the pattern.
    /// If user pauses longer than this, they may be reading content.
    public var pauseBreakThreshold: TimeInterval

    /// Minimum ratio of downward scrolls to total scrolls for doom scroll classification.
    /// Value between 0.0 and 1.0. Doom scrolling typically has 0.8+ downward ratio.
    public var downwardScrollRatio: Double

    /// Number of direction changes per minute that indicates erratic/compulsive behavior.
    public var directionChangeRateThreshold: Double

    // MARK: - Intensity Scoring

    /// Intensity score threshold (0.0-1.0) at which to trigger a gentle reminder.
    public var gentleInterventionThreshold: Double

    /// Intensity score threshold (0.0-1.0) at which to trigger a firm intervention.
    public var firmInterventionThreshold: Double

    /// Intensity score threshold (0.0-1.0) at which to require a mandatory break.
    public var mandatoryBreakThreshold: Double

    // MARK: - Cooldown Periods

    /// Minimum time (in seconds) between gentle interventions.
    public var gentleCooldownPeriod: TimeInterval

    /// Minimum time (in seconds) between firm interventions.
    public var firmCooldownPeriod: TimeInterval

    /// Minimum time (in seconds) after a mandatory break before any intervention.
    public var postBreakCooldownPeriod: TimeInterval

    // MARK: - Smoothing Parameters

    /// Alpha value for exponential moving average (EMA) of velocity.
    /// Higher values (closer to 1.0) give more weight to recent measurements.
    /// Lower values provide more smoothing but slower response.
    public var velocityEMAAlpha: Double

    /// Number of recent scroll events to keep in the rolling window.
    public var rollingWindowSize: Int

    // MARK: - Battery Optimization

    /// Sample rate reduction factor when device is in Low Power Mode.
    /// Value of 2.0 means half the normal sample rate.
    public var lowPowerModeReductionFactor: Double

    /// Minimum interval (in seconds) between scroll event processing.
    /// Helps reduce CPU usage by batching rapid scroll events.
    public var minimumProcessingInterval: TimeInterval

    // MARK: - Initialization

    /// Creates a configuration with the specified sensitivity level preset.
    public init(sensitivity: SensitivityLevel) {
        switch sensitivity {
        case .low:
            self = DetectionConfig.lowSensitivity
        case .medium:
            self = DetectionConfig.mediumSensitivity
        case .high:
            self = DetectionConfig.highSensitivity
        }
    }

    /// Creates a fully custom configuration with all parameters specified.
    public init(
        minimumSessionDuration: TimeInterval,
        extendedSessionDuration: TimeInterval,
        maximumSessionDuration: TimeInterval,
        minimumScrollCount: Int,
        highActivityScrollCount: Int,
        minimumVelocity: Double,
        rapidScrollVelocity: Double,
        velocityClampMax: Double,
        analysisWindowDuration: TimeInterval,
        pauseBreakThreshold: TimeInterval,
        downwardScrollRatio: Double,
        directionChangeRateThreshold: Double,
        gentleInterventionThreshold: Double,
        firmInterventionThreshold: Double,
        mandatoryBreakThreshold: Double,
        gentleCooldownPeriod: TimeInterval,
        firmCooldownPeriod: TimeInterval,
        postBreakCooldownPeriod: TimeInterval,
        velocityEMAAlpha: Double,
        rollingWindowSize: Int,
        lowPowerModeReductionFactor: Double,
        minimumProcessingInterval: TimeInterval
    ) {
        self.minimumSessionDuration = minimumSessionDuration
        self.extendedSessionDuration = extendedSessionDuration
        self.maximumSessionDuration = maximumSessionDuration
        self.minimumScrollCount = minimumScrollCount
        self.highActivityScrollCount = highActivityScrollCount
        self.minimumVelocity = minimumVelocity
        self.rapidScrollVelocity = rapidScrollVelocity
        self.velocityClampMax = velocityClampMax
        self.analysisWindowDuration = analysisWindowDuration
        self.pauseBreakThreshold = pauseBreakThreshold
        self.downwardScrollRatio = downwardScrollRatio
        self.directionChangeRateThreshold = directionChangeRateThreshold
        self.gentleInterventionThreshold = gentleInterventionThreshold
        self.firmInterventionThreshold = firmInterventionThreshold
        self.mandatoryBreakThreshold = mandatoryBreakThreshold
        self.gentleCooldownPeriod = gentleCooldownPeriod
        self.firmCooldownPeriod = firmCooldownPeriod
        self.postBreakCooldownPeriod = postBreakCooldownPeriod
        self.velocityEMAAlpha = velocityEMAAlpha
        self.rollingWindowSize = rollingWindowSize
        self.lowPowerModeReductionFactor = lowPowerModeReductionFactor
        self.minimumProcessingInterval = minimumProcessingInterval
    }
}

// MARK: - Preset Configurations

extension DetectionConfig {

    /// Low sensitivity preset - intervenes only after extended scrolling.
    /// Best for users who want minimal interruption.
    public static let lowSensitivity = DetectionConfig(
        minimumSessionDuration: 420,           // 7 minutes before any detection
        extendedSessionDuration: 900,          // 15 minutes for extended session
        maximumSessionDuration: 1800,          // 30 minutes max before forced break
        minimumScrollCount: 80,                // 80 scrolls minimum
        highActivityScrollCount: 150,          // 150 for high activity
        minimumVelocity: 100,                  // 100 pts/s minimum
        rapidScrollVelocity: 1500,             // 1500 pts/s for rapid
        velocityClampMax: 5000,                // Clamp at 5000 pts/s
        analysisWindowDuration: 120,           // 2 minute analysis window
        pauseBreakThreshold: 15,               // 15 second pause resets pattern
        downwardScrollRatio: 0.85,             // 85% downward for doom scroll
        directionChangeRateThreshold: 30,      // 30 changes/min threshold
        gentleInterventionThreshold: 0.7,      // 70% intensity for gentle
        firmInterventionThreshold: 0.85,       // 85% for firm
        mandatoryBreakThreshold: 0.95,         // 95% for mandatory
        gentleCooldownPeriod: 600,             // 10 min between gentle
        firmCooldownPeriod: 900,               // 15 min between firm
        postBreakCooldownPeriod: 1200,         // 20 min after break
        velocityEMAAlpha: 0.2,                 // More smoothing
        rollingWindowSize: 100,                // 100 event window
        lowPowerModeReductionFactor: 3.0,      // Reduce 3x in low power
        minimumProcessingInterval: 0.1         // 100ms between processing
    )

    /// Medium sensitivity preset - balanced detection for typical users.
    /// Recommended default for most users.
    public static let mediumSensitivity = DetectionConfig(
        minimumSessionDuration: 300,           // 5 minutes before detection
        extendedSessionDuration: 600,          // 10 minutes for extended
        maximumSessionDuration: 1200,          // 20 minutes max
        minimumScrollCount: 50,                // 50 scrolls minimum
        highActivityScrollCount: 100,          // 100 for high activity
        minimumVelocity: 80,                   // 80 pts/s minimum
        rapidScrollVelocity: 1200,             // 1200 pts/s for rapid
        velocityClampMax: 4000,                // Clamp at 4000 pts/s
        analysisWindowDuration: 90,            // 90 second analysis window
        pauseBreakThreshold: 10,               // 10 second pause resets
        downwardScrollRatio: 0.75,             // 75% downward for doom scroll
        directionChangeRateThreshold: 25,      // 25 changes/min threshold
        gentleInterventionThreshold: 0.55,     // 55% intensity for gentle
        firmInterventionThreshold: 0.75,       // 75% for firm
        mandatoryBreakThreshold: 0.90,         // 90% for mandatory
        gentleCooldownPeriod: 300,             // 5 min between gentle
        firmCooldownPeriod: 600,               // 10 min between firm
        postBreakCooldownPeriod: 900,          // 15 min after break
        velocityEMAAlpha: 0.3,                 // Balanced smoothing
        rollingWindowSize: 75,                 // 75 event window
        lowPowerModeReductionFactor: 2.0,      // Reduce 2x in low power
        minimumProcessingInterval: 0.05        // 50ms between processing
    )

    /// High sensitivity preset - quick intervention at first signs of doom scrolling.
    /// Best for users trying to break strong habits.
    public static let highSensitivity = DetectionConfig(
        minimumSessionDuration: 180,           // 3 minutes before detection
        extendedSessionDuration: 300,          // 5 minutes for extended
        maximumSessionDuration: 600,           // 10 minutes max
        minimumScrollCount: 30,                // 30 scrolls minimum
        highActivityScrollCount: 60,           // 60 for high activity
        minimumVelocity: 50,                   // 50 pts/s minimum
        rapidScrollVelocity: 900,              // 900 pts/s for rapid
        velocityClampMax: 3000,                // Clamp at 3000 pts/s
        analysisWindowDuration: 60,            // 60 second analysis window
        pauseBreakThreshold: 8,                // 8 second pause resets
        downwardScrollRatio: 0.65,             // 65% downward for doom scroll
        directionChangeRateThreshold: 20,      // 20 changes/min threshold
        gentleInterventionThreshold: 0.4,      // 40% intensity for gentle
        firmInterventionThreshold: 0.6,        // 60% for firm
        mandatoryBreakThreshold: 0.8,          // 80% for mandatory
        gentleCooldownPeriod: 180,             // 3 min between gentle
        firmCooldownPeriod: 300,               // 5 min between firm
        postBreakCooldownPeriod: 600,          // 10 min after break
        velocityEMAAlpha: 0.4,                 // Less smoothing, faster response
        rollingWindowSize: 50,                 // 50 event window
        lowPowerModeReductionFactor: 1.5,      // Reduce 1.5x in low power
        minimumProcessingInterval: 0.033       // ~30fps processing
    )

    /// Default configuration (medium sensitivity)
    public static let `default` = mediumSensitivity
}

// MARK: - Validation

extension DetectionConfig {

    /// Validates the configuration and returns any issues found.
    public func validate() -> [String] {
        var issues: [String] = []

        // Duration validations
        if minimumSessionDuration <= 0 {
            issues.append("Minimum session duration must be positive")
        }
        if extendedSessionDuration <= minimumSessionDuration {
            issues.append("Extended session duration must be greater than minimum")
        }
        if maximumSessionDuration <= extendedSessionDuration {
            issues.append("Maximum session duration must be greater than extended")
        }

        // Scroll count validations
        if minimumScrollCount <= 0 {
            issues.append("Minimum scroll count must be positive")
        }
        if highActivityScrollCount <= minimumScrollCount {
            issues.append("High activity scroll count must be greater than minimum")
        }

        // Velocity validations
        if minimumVelocity < 0 {
            issues.append("Minimum velocity cannot be negative")
        }
        if rapidScrollVelocity <= minimumVelocity {
            issues.append("Rapid scroll velocity must be greater than minimum")
        }
        if velocityClampMax <= rapidScrollVelocity {
            issues.append("Velocity clamp max must be greater than rapid velocity")
        }

        // Ratio validations
        if downwardScrollRatio < 0 || downwardScrollRatio > 1 {
            issues.append("Downward scroll ratio must be between 0 and 1")
        }

        // Threshold validations
        if gentleInterventionThreshold < 0 || gentleInterventionThreshold > 1 {
            issues.append("Gentle intervention threshold must be between 0 and 1")
        }
        if firmInterventionThreshold <= gentleInterventionThreshold {
            issues.append("Firm intervention threshold must be greater than gentle")
        }
        if mandatoryBreakThreshold <= firmInterventionThreshold {
            issues.append("Mandatory break threshold must be greater than firm")
        }

        // EMA alpha validation
        if velocityEMAAlpha <= 0 || velocityEMAAlpha > 1 {
            issues.append("Velocity EMA alpha must be between 0 (exclusive) and 1")
        }

        // Window size validation
        if rollingWindowSize < 10 {
            issues.append("Rolling window size should be at least 10")
        }

        return issues
    }

    /// Returns true if the configuration is valid.
    public var isValid: Bool {
        validate().isEmpty
    }
}

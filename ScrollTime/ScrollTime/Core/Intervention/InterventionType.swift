//
//  InterventionType.swift
//  ScrollTime
//
//  Created by ScrollTime Team
//
//  Defines the types of interventions that can be triggered when doom scrolling
//  is detected. Each type is designed with behavioral psychology principles:
//  - Graduated intensity (whisper -> nudge -> pause -> checkpoint)
//  - Positive framing that supports rather than punishes
//  - Respect for user autonomy with clear override paths
//

import Foundation
import SwiftUI

// MARK: - Intervention Type

/// Represents different types of interventions, ordered from gentlest to firmest.
/// Each intervention is designed to interrupt automatic scrolling behavior while
/// maintaining user trust and autonomy.
public enum InterventionType: Int, CaseIterable, Codable, Identifiable, Sendable {
    /// A subtle, easily dismissable awareness prompt
    /// Behavioral principle: Simple awareness can disrupt automatic behavior
    case gentleReminder = 0

    /// A guided breathing exercise to engage the parasympathetic nervous system
    /// Behavioral principle: Physical interruption breaks the dopamine-seeking loop
    case breathingExercise = 1

    /// A mandatory pause with countdown timer
    /// Behavioral principle: Temporal friction creates space for reflection
    case timedPause = 2

    /// A friction dialog requiring deliberate action to continue
    /// Behavioral principle: Cognitive friction engages the prefrontal cortex
    case frictionDialog = 3

    public var id: Int { rawValue }

    // MARK: - Display Properties

    /// The title shown to users - always positive and supportive
    var title: String {
        switch self {
        case .gentleReminder:
            return "A Moment of Awareness"
        case .breathingExercise:
            return "Take a Breath"
        case .timedPause:
            return "Pause and Reflect"
        case .frictionDialog:
            return "Check In With Yourself"
        }
    }

    /// Supportive message that frames the intervention positively
    var message: String {
        switch self {
        case .gentleReminder:
            return "You've been scrolling for a while. How are you feeling?"
        case .breathingExercise:
            return "Let's take a moment together. A few deep breaths can help you reconnect with how you're really feeling."
        case .timedPause:
            return "Taking a short break can help you decide if you want to keep scrolling or do something else."
        case .frictionDialog:
            return "Before continuing, take a moment to consider: Is this how you want to spend your time right now?"
        }
    }

    /// SF Symbol icon name for visual representation
    var iconName: String {
        switch self {
        case .gentleReminder:
            return "leaf.fill"
        case .breathingExercise:
            return "wind"
        case .timedPause:
            return "clock.fill"
        case .frictionDialog:
            return "hand.raised.fill"
        }
    }

    /// Color theme for the intervention UI
    var themeColor: Color {
        switch self {
        case .gentleReminder:
            return Color(red: 0.4, green: 0.7, blue: 0.5) // Soft green - calm awareness
        case .breathingExercise:
            return Color(red: 0.4, green: 0.6, blue: 0.8) // Soft blue - tranquility
        case .timedPause:
            return Color(red: 0.6, green: 0.5, blue: 0.7) // Soft purple - reflection
        case .frictionDialog:
            return Color(red: 0.7, green: 0.5, blue: 0.4) // Warm amber - gentle attention
        }
    }

    // MARK: - Behavioral Properties

    /// Default duration for this intervention type (in seconds)
    var defaultDuration: TimeInterval {
        switch self {
        case .gentleReminder:
            return 3.0  // Quick acknowledgment
        case .breathingExercise:
            return 30.0 // One round of box breathing (4-4-4-4 x ~2 cycles)
        case .timedPause:
            return 15.0 // Brief mandatory pause
        case .frictionDialog:
            return 0    // No timer - requires deliberate action
        }
    }

    /// Whether the user can immediately dismiss this intervention
    var allowsQuickDismiss: Bool {
        switch self {
        case .gentleReminder:
            return true  // Tap anywhere to dismiss
        case .breathingExercise:
            return true  // Can skip, but we track this
        case .timedPause:
            return false // Must wait for timer
        case .frictionDialog:
            return false // Must complete friction action
        }
    }

    /// The intensity level (0-1) used for haptic feedback
    var hapticIntensity: CGFloat {
        switch self {
        case .gentleReminder:
            return 0.3  // Soft tap
        case .breathingExercise:
            return 0.5  // Gentle rhythm
        case .timedPause:
            return 0.6  // Noticeable but not jarring
        case .frictionDialog:
            return 0.7  // Firm but respectful
        }
    }

    /// Minimum time between interventions of this type (in seconds)
    var cooldownPeriod: TimeInterval {
        switch self {
        case .gentleReminder:
            return 60       // 1 minute - can remind frequently but gently
        case .breathingExercise:
            return 180      // 3 minutes - don't overdo breathing exercises
        case .timedPause:
            return 300      // 5 minutes - meaningful gaps between pauses
        case .frictionDialog:
            return 600      // 10 minutes - reserved for persistent scrolling
        }
    }

    /// The escalation level (higher = more intense intervention)
    var escalationLevel: Int {
        return rawValue
    }

    /// Whether this intervention should be logged for analytics
    var shouldTrackAnalytics: Bool {
        return true // All interventions are valuable data points
    }
}

// MARK: - Intervention Configuration

/// Configuration for a specific intervention instance
struct InterventionConfiguration: Codable, Equatable {
    let type: InterventionType
    let duration: TimeInterval
    let customMessage: String?
    let triggeredAt: Date
    let sessionScrollCount: Int
    let appContext: String? // Which app triggered this (if known)

    init(
        type: InterventionType,
        duration: TimeInterval? = nil,
        customMessage: String? = nil,
        sessionScrollCount: Int = 0,
        appContext: String? = nil
    ) {
        self.type = type
        self.duration = duration ?? type.defaultDuration
        self.customMessage = customMessage
        self.triggeredAt = Date()
        self.sessionScrollCount = sessionScrollCount
        self.appContext = appContext
    }

    /// The message to display (custom or default)
    var displayMessage: String {
        customMessage ?? type.message
    }
}

// MARK: - Intervention Result

/// Represents the outcome of an intervention
public enum InterventionResult: Codable, Equatable, Sendable {
    /// User completed the full intervention (breathing, timer, etc.)
    case completed

    /// User acknowledged and chose to take a break
    case tookBreak

    /// User skipped/dismissed the intervention
    case skipped

    /// User chose to continue scrolling after intervention
    case continuedScrolling

    /// Intervention timed out without user action
    case timedOut

    /// Whether this result indicates the user engaged positively
    public var wasPositiveEngagement: Bool {
        switch self {
        case .completed, .tookBreak:
            return true
        case .skipped, .continuedScrolling, .timedOut:
            return false
        }
    }

    /// Whether this result should reset the escalation level
    public var shouldResetEscalation: Bool {
        switch self {
        case .completed, .tookBreak:
            return true
        case .skipped, .continuedScrolling, .timedOut:
            return false
        }
    }
}

// MARK: - Intervention Record

/// A record of an intervention that occurred, used for history tracking
struct InterventionRecord: Codable, Identifiable {
    let id: UUID
    let configuration: InterventionConfiguration
    let result: InterventionResult
    let completedAt: Date
    let durationEngaged: TimeInterval // How long user spent in intervention

    init(
        configuration: InterventionConfiguration,
        result: InterventionResult,
        durationEngaged: TimeInterval
    ) {
        self.id = UUID()
        self.configuration = configuration
        self.result = result
        self.completedAt = Date()
        self.durationEngaged = durationEngaged
    }

    /// Time between trigger and completion
    var responseTime: TimeInterval {
        completedAt.timeIntervalSince(configuration.triggeredAt)
    }
}

// MARK: - Breathing Exercise Types

/// Different breathing patterns that can be used in breathing interventions
enum BreathingPattern: String, CaseIterable, Codable {
    /// Classic box breathing: 4 seconds each phase
    /// Research-backed for activating parasympathetic nervous system
    case boxBreathing = "box"

    /// 4-7-8 technique: Inhale 4, hold 7, exhale 8
    /// Developed by Dr. Andrew Weil, promotes relaxation
    case relaxing478 = "478"

    /// Physiological sigh: Double inhale, long exhale
    /// Fastest way to calm down (Stanford research)
    case physiologicalSigh = "sigh"

    var displayName: String {
        switch self {
        case .boxBreathing:
            return "Box Breathing"
        case .relaxing478:
            return "4-7-8 Relaxation"
        case .physiologicalSigh:
            return "Calming Sigh"
        }
    }

    var description: String {
        switch self {
        case .boxBreathing:
            return "Breathe in for 4, hold for 4, out for 4, hold for 4"
        case .relaxing478:
            return "Breathe in for 4, hold for 7, out slowly for 8"
        case .physiologicalSigh:
            return "Two quick inhales through nose, long exhale through mouth"
        }
    }

    /// Duration of one complete breath cycle in seconds
    var cycleDuration: TimeInterval {
        switch self {
        case .boxBreathing:
            return 16.0 // 4+4+4+4
        case .relaxing478:
            return 19.0 // 4+7+8
        case .physiologicalSigh:
            return 8.0  // 2+2+4 (approximate)
        }
    }

    /// The phases of this breathing pattern
    var phases: [BreathingPhase] {
        switch self {
        case .boxBreathing:
            return [
                BreathingPhase(action: .inhale, duration: 4),
                BreathingPhase(action: .hold, duration: 4),
                BreathingPhase(action: .exhale, duration: 4),
                BreathingPhase(action: .hold, duration: 4)
            ]
        case .relaxing478:
            return [
                BreathingPhase(action: .inhale, duration: 4),
                BreathingPhase(action: .hold, duration: 7),
                BreathingPhase(action: .exhale, duration: 8)
            ]
        case .physiologicalSigh:
            return [
                BreathingPhase(action: .inhale, duration: 2),
                BreathingPhase(action: .inhale, duration: 2), // Second inhale
                BreathingPhase(action: .exhale, duration: 4)
            ]
        }
    }
}

/// A single phase within a breathing pattern
struct BreathingPhase: Codable, Equatable {
    enum Action: String, Codable {
        case inhale
        case exhale
        case hold

        var instruction: String {
            switch self {
            case .inhale:
                return "Breathe In"
            case .exhale:
                return "Breathe Out"
            case .hold:
                return "Hold"
            }
        }
    }

    let action: Action
    let duration: TimeInterval
}

// MARK: - Friction Dialog Types

/// Different types of friction that require deliberate action
enum FrictionType: String, CaseIterable, Codable {
    /// Type a phrase to continue (engages prefrontal cortex)
    case typePhrase = "type"

    /// Answer a reflection question
    case reflectionQuestion = "reflect"

    /// Simple intention setting
    case setIntention = "intention"

    var instruction: String {
        switch self {
        case .typePhrase:
            return "Type the phrase below to continue"
        case .reflectionQuestion:
            return "Take a moment to reflect"
        case .setIntention:
            return "Set your intention"
        }
    }

    /// Sample prompts for this friction type
    var samplePrompts: [String] {
        switch self {
        case .typePhrase:
            return [
                "I choose to keep scrolling",
                "I am scrolling with intention",
                "This is how I want to spend my time"
            ]
        case .reflectionQuestion:
            return [
                "What were you hoping to find?",
                "How are you feeling right now?",
                "What else could you do with this time?"
            ]
        case .setIntention:
            return [
                "I will scroll for 5 more minutes",
                "I'm looking for something specific",
                "I'm taking a mental break"
            ]
        }
    }
}

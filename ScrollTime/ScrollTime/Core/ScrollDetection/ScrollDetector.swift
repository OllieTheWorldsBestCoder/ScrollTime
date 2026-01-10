//
//  ScrollDetector.swift
//  ScrollTime
//
//  Main detection engine for doom scrolling behavior.
//  Coordinates scroll session tracking, gesture analysis, and intervention triggering.
//  Uses Combine for reactive updates and is designed for battery efficiency.
//

import Foundation
import UIKit
import Combine

// MARK: - Detection Event

/// Events published by the ScrollDetector when significant patterns are detected.
public enum DetectionEvent {
    /// A new scroll session has started
    case sessionStarted(ScrollSession)

    /// A scroll session has ended
    case sessionEnded(ScrollSessionSummary)

    /// Doom scrolling pattern detected - gentle intervention recommended
    case gentleIntervention(ScrollIntensity, ScrollSession)

    /// Sustained doom scrolling - firm intervention recommended
    case firmIntervention(ScrollIntensity, ScrollSession)

    /// Excessive doom scrolling - mandatory break required
    case mandatoryBreak(ScrollIntensity, ScrollSession)

    /// Intensity score updated (published periodically during active scrolling)
    case intensityUpdated(ScrollIntensity)

    /// User took a meaningful pause (potential content engagement)
    case pauseDetected(TimeInterval)

    /// Session metrics updated
    case metricsUpdated(SessionMetrics)
}

// MARK: - Session Metrics

/// Aggregated metrics from the current or recent sessions.
public struct SessionMetrics: Codable {
    public let totalScrollsToday: Int
    public let totalSessionsToday: Int
    public let totalDoomScrollMinutesToday: TimeInterval
    public let averageIntensityToday: Double
    public let interventionsTodayCount: Int
    public let lastSessionDuration: TimeInterval?
    public let currentStreak: Int  // Days without excessive doom scrolling

    public static let empty = SessionMetrics(
        totalScrollsToday: 0,
        totalSessionsToday: 0,
        totalDoomScrollMinutesToday: 0,
        averageIntensityToday: 0,
        interventionsTodayCount: 0,
        lastSessionDuration: nil,
        currentStreak: 0
    )
}

// MARK: - Intervention State

/// Tracks intervention timing to enforce cooldown periods.
private struct InterventionState {
    var lastGentleIntervention: Date?
    var lastFirmIntervention: Date?
    var lastMandatoryBreak: Date?
    var interventionCount: Int = 0

    mutating func reset() {
        lastGentleIntervention = nil
        lastFirmIntervention = nil
        lastMandatoryBreak = nil
        interventionCount = 0
    }
}

// MARK: - Scroll Detector

/// Main detection engine that coordinates all scroll detection functionality.
/// This class is the primary interface for the scroll detection system.
///
/// Usage:
/// ```swift
/// let detector = ScrollDetector(config: .default)
///
/// // Subscribe to detection events
/// detector.eventPublisher
///     .sink { event in
///         switch event {
///         case .gentleIntervention(let intensity, _):
///             showGentleReminder()
///         case .firmIntervention(let intensity, _):
///             showFirmIntervention()
///         // ... handle other events
///         }
///     }
///     .store(in: &cancellables)
///
/// // Start monitoring
/// detector.startMonitoring(appBundleID: "com.instagram.Instagram")
///
/// // Feed scroll events from your gesture recognizer
/// detector.processScrollGesture(panGesture)
/// ```
public final class ScrollDetector: ObservableObject {

    // MARK: - Published State

    /// Whether the detector is currently monitoring for scrolls
    @Published public private(set) var isMonitoring: Bool = false

    /// The current active session, if any
    @Published public private(set) var currentSession: ScrollSession?

    /// Current scroll intensity score
    @Published public private(set) var currentIntensity: ScrollIntensity?

    /// Current aggregated metrics
    @Published public private(set) var metrics: SessionMetrics = .empty

    /// Whether doom scrolling is currently detected
    @Published public private(set) var isDoomScrollingDetected: Bool = false

    // MARK: - Configuration

    /// Detection configuration (thresholds, sensitivity, etc.)
    public var config: DetectionConfig {
        didSet {
            gestureAnalyzer.config = config
        }
    }

    // MARK: - Publishers

    /// Publisher for detection events
    public let eventPublisher = PassthroughSubject<DetectionEvent, Never>()

    /// Publisher for raw scroll events (for debugging/visualization)
    public let scrollEventPublisher = PassthroughSubject<ScrollEvent, Never>()

    // MARK: - Private Components

    /// Gesture analyzer for pattern recognition
    private let gestureAnalyzer: GestureAnalyzer

    /// History of completed sessions
    private var sessionHistory: [ScrollSessionSummary] = []

    /// Intervention timing state
    private var interventionState = InterventionState()

    /// Timer for periodic intensity analysis
    private var analysisTimer: Timer?

    /// Analysis interval in seconds
    private let analysisInterval: TimeInterval = 1.0

    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()

    /// Thread-safe lock
    private let lock = NSLock()

    /// Pause detection timer
    private var pauseTimer: Timer?

    /// Last scroll event timestamp
    private var lastScrollTime: Date?

    /// Bundle ID of app being monitored
    private var monitoredAppBundleID: String?

    // MARK: - Battery Optimization

    /// Whether the device is in low power mode
    private var isLowPowerMode: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    /// Adjusted analysis interval based on power mode
    private var adjustedAnalysisInterval: TimeInterval {
        if isLowPowerMode {
            return analysisInterval * config.lowPowerModeReductionFactor
        }
        return analysisInterval
    }

    // MARK: - Initialization

    /// Creates a new scroll detector with the specified configuration.
    ///
    /// - Parameter config: Detection configuration (defaults to medium sensitivity)
    public init(config: DetectionConfig = .default) {
        self.config = config
        self.gestureAnalyzer = GestureAnalyzer(config: config)

        setupObservers()
    }

    /// Sets up internal observers
    private func setupObservers() {
        // Observe low power mode changes
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                self?.handlePowerStateChange()
            }
            .store(in: &cancellables)

        // Forward gesture analyzer intensity updates
        gestureAnalyzer.$currentIntensity
            .compactMap { $0 }
            .sink { [weak self] intensity in
                self?.currentIntensity = intensity
            }
            .store(in: &cancellables)
    }

    // MARK: - Monitoring Control

    /// Starts monitoring for scroll behavior.
    ///
    /// - Parameter appBundleID: Optional bundle ID of the app being monitored
    public func startMonitoring(appBundleID: String? = nil) {
        lock.lock()
        defer { lock.unlock() }

        guard !isMonitoring else { return }

        monitoredAppBundleID = appBundleID

        // Create a new session
        let session = ScrollSession(
            appBundleID: appBundleID,
            windowSize: config.rollingWindowSize
        )
        currentSession = session
        isMonitoring = true

        // Publish session started event
        eventPublisher.send(.sessionStarted(session))

        // Start periodic analysis
        startAnalysisTimer()

        // Start pause detection
        startPauseDetection()
    }

    /// Stops monitoring and ends the current session.
    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        guard isMonitoring else { return }

        // Stop timers
        stopAnalysisTimer()
        stopPauseDetection()

        // End the current session
        if let session = currentSession {
            session.end()

            // Determine if this was a doom scrolling session
            let wasDoomScrolling = isDoomScrollingDetected

            // Create summary and store in history
            let summary = ScrollSessionSummary(from: session, wasDoomScrolling: wasDoomScrolling)
            sessionHistory.append(summary)

            // Trim history to prevent unbounded growth
            if sessionHistory.count > 100 {
                sessionHistory.removeFirst(sessionHistory.count - 100)
            }

            // Publish session ended event
            eventPublisher.send(.sessionEnded(summary))

            // Update metrics
            updateMetrics()
        }

        // Reset state
        currentSession = nil
        isMonitoring = false
        isDoomScrollingDetected = false
        gestureAnalyzer.reset()
    }

    /// Pauses monitoring temporarily (e.g., when app goes to background)
    public func pauseMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        currentSession?.pause()
        stopAnalysisTimer()
        stopPauseDetection()
    }

    /// Resumes monitoring after a pause
    public func resumeMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        guard isMonitoring, currentSession?.state == .paused else { return }

        startAnalysisTimer()
        startPauseDetection()
    }

    // MARK: - Gesture Processing

    /// Processes a pan gesture recognizer and records the scroll event.
    /// Call this from your UIGestureRecognizer callback.
    ///
    /// - Parameter recognizer: The pan gesture recognizer
    public func processScrollGesture(_ recognizer: UIPanGestureRecognizer) {
        guard isMonitoring, let session = currentSession else { return }

        if let event = gestureAnalyzer.processPanGesture(recognizer, session: session) {
            lastScrollTime = Date()
            scrollEventPublisher.send(event)
        }
    }

    /// Processes a raw scroll event with velocity and direction.
    /// Use this when you don't have access to a gesture recognizer.
    ///
    /// - Parameters:
    ///   - velocity: Scroll velocity in points per second
    ///   - direction: Direction of the scroll
    public func processScroll(velocity: Double, direction: ScrollDirection) {
        guard isMonitoring, let session = currentSession else { return }

        if let event = gestureAnalyzer.processScroll(
            velocity: velocity,
            direction: direction,
            session: session
        ) {
            lastScrollTime = Date()
            scrollEventPublisher.send(event)
        }
    }

    /// Processes a SwiftUI drag gesture.
    ///
    /// - Parameters:
    ///   - translation: Current translation from the drag gesture
    ///   - predictedEndTranslation: Predicted end translation
    public func processDragGesture(translation: CGSize, predictedEndTranslation: CGSize) {
        guard isMonitoring, let session = currentSession else { return }

        if let event = gestureAnalyzer.processDragGesture(
            translation: translation,
            predictedEndTranslation: predictedEndTranslation,
            session: session
        ) {
            lastScrollTime = Date()
            scrollEventPublisher.send(event)
        }
    }

    // MARK: - Analysis

    /// Performs intensity analysis and checks for intervention triggers.
    /// Called periodically by the analysis timer.
    private func performAnalysis() {
        guard let session = currentSession, session.state == .active else { return }

        // Calculate current intensity
        let intensity = gestureAnalyzer.analyzeSession(session)

        // Publish intensity update
        eventPublisher.send(.intensityUpdated(intensity))

        // Check for doom scrolling pattern
        let isDoomScrolling = gestureAnalyzer.isDoomScrollingPattern(in: session)
        if isDoomScrolling != isDoomScrollingDetected {
            isDoomScrollingDetected = isDoomScrolling
        }

        // Check for intervention triggers
        checkInterventionTriggers(intensity: intensity, session: session)

        // Update metrics
        updateMetrics()
    }

    /// Checks if an intervention should be triggered based on current intensity.
    private func checkInterventionTriggers(intensity: ScrollIntensity, session: ScrollSession) {
        let now = Date()

        // Check for mandatory break first (highest priority)
        if intensity.score >= config.mandatoryBreakThreshold {
            if canTriggerMandatoryBreak(at: now) {
                interventionState.lastMandatoryBreak = now
                interventionState.interventionCount += 1
                eventPublisher.send(.mandatoryBreak(intensity, session))
                return
            }
        }

        // Check for firm intervention
        if intensity.score >= config.firmInterventionThreshold {
            if canTriggerFirmIntervention(at: now) {
                interventionState.lastFirmIntervention = now
                interventionState.interventionCount += 1
                eventPublisher.send(.firmIntervention(intensity, session))
                return
            }
        }

        // Check for gentle intervention
        if intensity.score >= config.gentleInterventionThreshold {
            if canTriggerGentleIntervention(at: now) {
                interventionState.lastGentleIntervention = now
                interventionState.interventionCount += 1
                eventPublisher.send(.gentleIntervention(intensity, session))
            }
        }
    }

    /// Checks if a gentle intervention can be triggered (respecting cooldown)
    private func canTriggerGentleIntervention(at time: Date) -> Bool {
        // Check if we're in post-break cooldown
        if let lastBreak = interventionState.lastMandatoryBreak,
           time.timeIntervalSince(lastBreak) < config.postBreakCooldownPeriod {
            return false
        }

        // Check gentle cooldown
        if let lastGentle = interventionState.lastGentleIntervention,
           time.timeIntervalSince(lastGentle) < config.gentleCooldownPeriod {
            return false
        }

        return true
    }

    /// Checks if a firm intervention can be triggered (respecting cooldown)
    private func canTriggerFirmIntervention(at time: Date) -> Bool {
        // Check if we're in post-break cooldown
        if let lastBreak = interventionState.lastMandatoryBreak,
           time.timeIntervalSince(lastBreak) < config.postBreakCooldownPeriod {
            return false
        }

        // Check firm cooldown
        if let lastFirm = interventionState.lastFirmIntervention,
           time.timeIntervalSince(lastFirm) < config.firmCooldownPeriod {
            return false
        }

        return true
    }

    /// Checks if a mandatory break can be triggered (respecting cooldown)
    private func canTriggerMandatoryBreak(at time: Date) -> Bool {
        // Check post-break cooldown
        if let lastBreak = interventionState.lastMandatoryBreak,
           time.timeIntervalSince(lastBreak) < config.postBreakCooldownPeriod {
            return false
        }

        return true
    }

    // MARK: - Timers

    /// Starts the periodic analysis timer
    private func startAnalysisTimer() {
        stopAnalysisTimer()

        let interval = adjustedAnalysisInterval
        analysisTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            self?.performAnalysis()
        }

        // Allow timer to fire in common run loop modes (for smooth scrolling)
        if let timer = analysisTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    /// Stops the analysis timer
    private func stopAnalysisTimer() {
        analysisTimer?.invalidate()
        analysisTimer = nil
    }

    /// Starts pause detection timer
    private func startPauseDetection() {
        stopPauseDetection()

        // Check for pauses every second
        pauseTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            self?.checkForPause()
        }
    }

    /// Stops pause detection timer
    private func stopPauseDetection() {
        pauseTimer?.invalidate()
        pauseTimer = nil
    }

    /// Checks if the user has paused scrolling
    private func checkForPause() {
        guard let lastScroll = lastScrollTime else { return }

        let pauseDuration = Date().timeIntervalSince(lastScroll)

        if pauseDuration >= config.pauseBreakThreshold {
            // User has paused - they might be reading content
            eventPublisher.send(.pauseDetected(pauseDuration))

            // Reset pause detection (only fire once per pause)
            lastScrollTime = nil
        }
    }

    // MARK: - Power State

    /// Handles power state changes (low power mode)
    private func handlePowerStateChange() {
        if isMonitoring {
            // Restart timer with adjusted interval
            startAnalysisTimer()
        }
    }

    // MARK: - Metrics

    /// Updates aggregated metrics based on session history
    private func updateMetrics() {
        let today = Calendar.current.startOfDay(for: Date())

        // Filter today's sessions
        let todaySessions = sessionHistory.filter {
            Calendar.current.isDate($0.startTime, inSameDayAs: today)
        }

        // Calculate aggregates
        let totalScrolls = todaySessions.reduce(0) { $0 + $1.totalScrollCount }
        let totalSessions = todaySessions.count

        let doomScrollMinutes = todaySessions
            .filter { $0.wasDoomScrolling }
            .reduce(0.0) { $0 + $1.duration } / 60.0

        let avgIntensity: Double
        if !todaySessions.isEmpty {
            // Use current intensity for active session, otherwise use historical average
            if let current = currentIntensity {
                avgIntensity = current.score
            } else {
                avgIntensity = 0.5  // Default when no data available
            }
        } else {
            avgIntensity = 0
        }

        let lastDuration = currentSession?.duration ?? todaySessions.last?.duration

        // Calculate streak (simplified - would need persistent storage for real implementation)
        let streak = calculateStreak()

        metrics = SessionMetrics(
            totalScrollsToday: totalScrolls + (currentSession?.totalScrollCount ?? 0),
            totalSessionsToday: totalSessions + (currentSession != nil ? 1 : 0),
            totalDoomScrollMinutesToday: doomScrollMinutes,
            averageIntensityToday: avgIntensity,
            interventionsTodayCount: interventionState.interventionCount,
            lastSessionDuration: lastDuration,
            currentStreak: streak
        )

        eventPublisher.send(.metricsUpdated(metrics))
    }

    /// Calculates the current streak of days without excessive doom scrolling
    private func calculateStreak() -> Int {
        // Simplified implementation - returns 0 for now
        // A real implementation would check historical data from persistent storage
        return 0
    }

    // MARK: - Reset

    /// Resets all detector state
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        stopMonitoring()
        sessionHistory.removeAll()
        interventionState.reset()
        metrics = .empty
    }

    /// Resets only intervention cooldowns (allows interventions to fire again)
    public func resetCooldowns() {
        lock.lock()
        defer { lock.unlock() }

        interventionState.lastGentleIntervention = nil
        interventionState.lastFirmIntervention = nil
        // Note: Don't reset mandatory break cooldown as it's a stronger protection
    }
}

// MARK: - Debug Support

extension ScrollDetector {

    /// Debug description of current state
    public var debugDescription: String {
        """
        ScrollDetector State:
        - Monitoring: \(isMonitoring)
        - Session: \(currentSession?.id.uuidString ?? "none")
        - Session Duration: \(String(format: "%.1f", currentSession?.duration ?? 0))s
        - Total Scrolls: \(currentSession?.totalScrollCount ?? 0)
        - Intensity: \(String(format: "%.2f", currentIntensity?.score ?? 0))
        - Doom Scrolling: \(isDoomScrollingDetected)
        - Low Power Mode: \(isLowPowerMode)
        - Interventions Today: \(interventionState.interventionCount)
        """
    }

    /// Simulates a scroll event for testing purposes
    public func simulateScroll(velocity: Double = 500, direction: ScrollDirection = .down) {
        processScroll(velocity: velocity, direction: direction)
    }

    /// Simulates multiple rapid scrolls for testing doom scroll detection
    public func simulateDoomScrolling(count: Int = 50, interval: TimeInterval = 0.1) {
        if !isMonitoring {
            startMonitoring(appBundleID: "com.test.simulator")
        }

        // Dispatch rapid scroll events
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) { [weak self] in
                // Vary velocity slightly to simulate real scrolling
                let baseVelocity = 800.0
                let variance = Double.random(in: -200...200)
                self?.simulateScroll(velocity: baseVelocity + variance, direction: .down)
            }
        }
    }
}

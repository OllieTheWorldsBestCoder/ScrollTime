//
//  ScrollDetector.swift
//  ScrollTime
//
//  Main detection engine for doom scrolling behavior.
//  Coordinates scroll session tracking, gesture analysis, and intervention triggering.
//  Uses Combine for reactive updates and is designed for battery efficiency.
//
//  Battery Optimization Notes:
//  - Uses DispatchSourceTimer with generous leeway for system coalescing
//  - Consolidates multiple timers into a single analysis timer
//  - Integrates with PowerManager for adaptive behavior
//  - Pauses all timers when app is backgrounded or no scrolling detected
//  - Respects Low Power Mode and thermal state
//

import Foundation
import UIKit
import Combine
import os.log

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

    /// Monitoring state changed
    case monitoringStateChanged(isMonitoring: Bool, reason: String)
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
/// Battery Optimization Features:
/// - Uses DispatchSourceTimer with 30% leeway for system coalescing
/// - Consolidates analysis and pause detection into single timer
/// - Suspends timer when no active scrolling detected
/// - Integrates with PowerManager for adaptive intervals
/// - Responds to app lifecycle events (scenePhase)
/// - Respects Low Power Mode and thermal state
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

    /// Current power mode from PowerManager
    @Published public private(set) var currentPowerMode: PowerMode = .balanced

    // MARK: - Configuration

    /// Detection configuration (thresholds, sensitivity, etc.)
    public var config: DetectionConfig {
        didSet {
            gestureAnalyzer.config = config
            updateTimerConfiguration()
        }
    }

    // MARK: - Publishers

    /// Publisher for detection events
    public let eventPublisher = PassthroughSubject<DetectionEvent, Never>()

    /// Publisher for raw scroll events (for debugging/visualization)
    public let scrollEventPublisher = PassthroughSubject<ScrollEvent, Never>()

    // MARK: - Private Components

    private let logger = Logger(subsystem: "com.scrolltime", category: "ScrollDetector")

    /// Gesture analyzer for pattern recognition
    private let gestureAnalyzer: GestureAnalyzer

    /// History of completed sessions
    private var sessionHistory: [ScrollSessionSummary] = []

    /// Intervention timing state
    private var interventionState = InterventionState()

    /// Consolidated analysis timer (DispatchSourceTimer for battery efficiency)
    private var analysisTimer: DispatchSourceTimer?

    /// Queue for timer operations (background QoS for battery efficiency)
    private let timerQueue: DispatchQueue

    /// Base analysis interval in seconds (adjusted by power mode)
    private let baseAnalysisInterval: TimeInterval = 2.0

    /// Whether the analysis timer is currently active
    private var isTimerActive: Bool = false

    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()

    /// Thread-safe lock
    private let lock = NSLock()

    /// Last scroll event timestamp
    private var lastScrollTime: Date?

    /// Time since last scroll before suspending timer
    private let scrollIdleTimeout: TimeInterval = 10.0

    /// Bundle ID of app being monitored
    private var monitoredAppBundleID: String?

    /// Whether the app is currently in the foreground
    private var isAppActive: Bool = true

    // MARK: - Initialization

    /// Creates a new scroll detector with the specified configuration.
    ///
    /// - Parameter config: Detection configuration (defaults to medium sensitivity)
    public init(config: DetectionConfig = .default) {
        self.config = config
        self.gestureAnalyzer = GestureAnalyzer(config: config)

        // Create a dedicated queue for timer operations with background QoS
        // This allows the system to defer timer operations when under power pressure
        self.timerQueue = DispatchQueue(
            label: "com.scrolltime.scrolldetector.timer",
            qos: .utility  // Use .utility for battery-friendly background work
        )

        setupObservers()
        logger.info("ScrollDetector initialized with battery-optimized configuration")
    }

    deinit {
        stopAnalysisTimer()
    }

    /// Sets up internal observers for power state and intensity updates
    private func setupObservers() {
        // Observe power mode changes from PowerManager
        Task { @MainActor in
            PowerManager.shared.$currentMode
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newMode in
                    self?.handlePowerModeChange(newMode)
                }
                .store(in: &cancellables)
        }

        // Observe power mode change notifications (for non-Combine consumers)
        NotificationCenter.default.publisher(for: .powerModeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let newMode = notification.userInfo?["newMode"] as? PowerMode {
                    self?.handlePowerModeChange(newMode)
                }
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

        // Check if PowerManager allows monitoring
        Task { @MainActor in
            guard PowerManager.shared.shouldMonitor else {
                logger.info("Monitoring not started - power mode is suspended")
                eventPublisher.send(.monitoringStateChanged(isMonitoring: false, reason: "Power mode suspended"))
                return
            }
        }

        monitoredAppBundleID = appBundleID

        // Create a new session
        let session = ScrollSession(
            appBundleID: appBundleID,
            windowSize: config.rollingWindowSize
        )
        currentSession = session
        isMonitoring = true

        logger.info("Started monitoring for app: \(appBundleID ?? "unknown")")

        // Publish session started event
        eventPublisher.send(.sessionStarted(session))
        eventPublisher.send(.monitoringStateChanged(isMonitoring: true, reason: "User initiated"))

        // Timer will be started when first scroll event is received
        // This avoids unnecessary CPU wake-ups when user is not scrolling
    }

    /// Stops monitoring and ends the current session.
    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        guard isMonitoring else { return }

        logger.info("Stopping monitoring")

        // Stop timer
        stopAnalysisTimer()

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
        lastScrollTime = nil
        gestureAnalyzer.reset()

        eventPublisher.send(.monitoringStateChanged(isMonitoring: false, reason: "User stopped"))
    }

    /// Pauses monitoring temporarily (e.g., when app goes to background)
    /// This is critical for battery efficiency - timers are suspended.
    public func pauseMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        guard isMonitoring else { return }

        isAppActive = false
        currentSession?.pause()
        suspendAnalysisTimer()

        logger.info("Monitoring paused - app backgrounded")
        eventPublisher.send(.monitoringStateChanged(isMonitoring: true, reason: "Paused - app backgrounded"))
    }

    /// Resumes monitoring after a pause
    public func resumeMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        guard isMonitoring, currentSession?.state == .paused else { return }

        isAppActive = true

        // Only resume timer if we were recently scrolling
        // Otherwise wait for next scroll event
        if let lastScroll = lastScrollTime,
           Date().timeIntervalSince(lastScroll) < scrollIdleTimeout {
            resumeAnalysisTimer()
        }

        logger.info("Monitoring resumed")
        eventPublisher.send(.monitoringStateChanged(isMonitoring: true, reason: "Resumed - app foregrounded"))
    }

    /// Called when app scene phase changes
    /// - Parameter isActive: Whether the app is now active
    public func handleScenePhaseChange(isActive: Bool) {
        if isActive {
            resumeMonitoring()
        } else {
            pauseMonitoring()
        }
    }

    // MARK: - Gesture Processing

    /// Processes a pan gesture recognizer and records the scroll event.
    /// Call this from your UIGestureRecognizer callback.
    ///
    /// - Parameter recognizer: The pan gesture recognizer
    public func processScrollGesture(_ recognizer: UIPanGestureRecognizer) {
        guard isMonitoring, let session = currentSession else { return }

        if let event = gestureAnalyzer.processPanGesture(recognizer, session: session) {
            handleScrollEvent(event)
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
            handleScrollEvent(event)
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
            handleScrollEvent(event)
        }
    }

    /// Common handler for all scroll events
    private func handleScrollEvent(_ event: ScrollEvent) {
        lastScrollTime = Date()
        scrollEventPublisher.send(event)

        // Start or resume the analysis timer when we receive scroll events
        ensureAnalysisTimerRunning()
    }

    // MARK: - Timer Management (Battery Optimized)

    /// Creates and configures the analysis timer with power-aware settings
    private func createAnalysisTimer() {
        // Cancel any existing timer
        stopAnalysisTimer()

        // Use cached power mode to avoid deadlock (it's updated via subscription)
        let powerMode = currentPowerMode

        // Calculate interval based on power mode
        let interval = calculateAnalysisInterval(for: powerMode)
        let leeway = calculateTimerLeeway(for: interval)

        logger.debug("Creating analysis timer: interval=\(interval)s, leeway=\(leeway)s")

        // Create DispatchSourceTimer for better battery efficiency than Timer
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)

        // Schedule with generous leeway to allow system coalescing
        // This is CRITICAL for battery efficiency - allows system to batch timer firings
        timer.schedule(
            deadline: .now() + interval,
            repeating: interval,
            leeway: .milliseconds(Int(leeway * 1000))
        )

        timer.setEventHandler { [weak self] in
            self?.performConsolidatedAnalysis()
        }

        analysisTimer = timer
        timer.resume()
        isTimerActive = true
    }

    /// Calculates the analysis interval based on power mode
    private func calculateAnalysisInterval(for powerMode: PowerMode) -> TimeInterval {
        let baseInterval = baseAnalysisInterval

        switch powerMode {
        case .full:
            return baseInterval  // 2 seconds
        case .balanced:
            return baseInterval * 1.5  // 3 seconds
        case .reduced:
            return baseInterval * 2.5  // 5 seconds
        case .minimal:
            return baseInterval * 5.0  // 10 seconds
        case .suspended:
            return .infinity  // Don't run
        }
    }

    /// Calculates timer leeway (30% of interval for good coalescing)
    private func calculateTimerLeeway(for interval: TimeInterval) -> TimeInterval {
        // 30% leeway allows excellent system coalescing
        // This significantly reduces CPU wake-ups
        return interval * 0.3
    }

    /// Ensures the analysis timer is running (starts if needed)
    private func ensureAnalysisTimerRunning() {
        guard isMonitoring, isAppActive else { return }

        if analysisTimer == nil || !isTimerActive {
            createAnalysisTimer()
        }
    }

    /// Suspends the analysis timer (but keeps it configured)
    private func suspendAnalysisTimer() {
        guard let timer = analysisTimer, isTimerActive else { return }
        timer.suspend()
        isTimerActive = false
        logger.debug("Analysis timer suspended")
    }

    /// Resumes a suspended analysis timer
    private func resumeAnalysisTimer() {
        guard let timer = analysisTimer, !isTimerActive else {
            // Timer doesn't exist, create it
            createAnalysisTimer()
            return
        }
        timer.resume()
        isTimerActive = true
        logger.debug("Analysis timer resumed")
    }

    /// Stops and releases the analysis timer
    private func stopAnalysisTimer() {
        if let timer = analysisTimer {
            if !isTimerActive {
                // Must resume before cancelling a suspended timer
                timer.resume()
            }
            timer.cancel()
            analysisTimer = nil
            isTimerActive = false
            logger.debug("Analysis timer stopped")
        }
    }

    /// Updates timer configuration when power mode or config changes
    private func updateTimerConfiguration() {
        guard isMonitoring, isTimerActive else { return }

        // Recreate timer with new configuration
        createAnalysisTimer()
    }

    // MARK: - Analysis (Consolidated)

    /// Performs consolidated analysis including intensity calculation and pause detection.
    /// This replaces the separate analysis and pause timers for better battery efficiency.
    private func performConsolidatedAnalysis() {
        // Check if we should suspend due to scroll inactivity
        if let lastScroll = lastScrollTime {
            let idleTime = Date().timeIntervalSince(lastScroll)
            if idleTime >= scrollIdleTimeout {
                // User hasn't scrolled in a while - suspend timer to save battery
                DispatchQueue.main.async { [weak self] in
                    self?.suspendAnalysisTimer()
                    self?.logger.debug("Timer suspended due to scroll inactivity (\(idleTime)s)")
                }
                return
            }

            // Check for pause (user stopped scrolling but timer still active)
            if idleTime >= config.pauseBreakThreshold {
                DispatchQueue.main.async { [weak self] in
                    self?.eventPublisher.send(.pauseDetected(idleTime))
                }
            }
        }

        // Perform intensity analysis on main thread
        DispatchQueue.main.async { [weak self] in
            self?.performIntensityAnalysis()
        }
    }

    /// Performs intensity analysis and checks for intervention triggers.
    private func performIntensityAnalysis() {
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

    // MARK: - Power State Handling

    /// Handles power mode changes from PowerManager
    private func handlePowerModeChange(_ newMode: PowerMode) {
        let oldMode = currentPowerMode
        currentPowerMode = newMode

        logger.info("Power mode changed: \(oldMode.description) -> \(newMode.description)")

        // Handle suspended mode
        if newMode == .suspended {
            if isMonitoring {
                logger.info("Suspending monitoring due to power mode")
                suspendAnalysisTimer()
                eventPublisher.send(.monitoringStateChanged(
                    isMonitoring: true,
                    reason: "Paused - \(newMode.description) power mode"
                ))
            }
            return
        }

        // If transitioning from suspended, check if we should resume
        if oldMode == .suspended && isMonitoring && isAppActive {
            logger.info("Resuming monitoring after power mode change")
            if lastScrollTime != nil {
                resumeAnalysisTimer()
            }
        }

        // Update timer interval for new power mode
        if isMonitoring && isTimerActive {
            updateTimerConfiguration()
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

        logger.info("ScrollDetector reset")
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
        - Timer Active: \(isTimerActive)
        - Session: \(currentSession?.id.uuidString ?? "none")
        - Session Duration: \(String(format: "%.1f", currentSession?.duration ?? 0))s
        - Total Scrolls: \(currentSession?.totalScrollCount ?? 0)
        - Intensity: \(String(format: "%.2f", currentIntensity?.score ?? 0))
        - Doom Scrolling: \(isDoomScrollingDetected)
        - Power Mode: \(currentPowerMode.description)
        - Interventions Today: \(interventionState.interventionCount)
        - App Active: \(isAppActive)
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

    /// Returns battery efficiency diagnostics
    public var batteryDiagnostics: String {
        let interval = calculateAnalysisInterval(for: currentPowerMode)
        let leeway = calculateTimerLeeway(for: interval)

        return """
        Battery Efficiency Diagnostics:
        - Power Mode: \(currentPowerMode.description)
        - Analysis Interval: \(String(format: "%.1f", interval))s
        - Timer Leeway: \(String(format: "%.1f", leeway))s (allows coalescing)
        - Timer Active: \(isTimerActive)
        - Timer Type: DispatchSourceTimer (battery optimized)
        - Queue QoS: utility (battery friendly)
        - Idle Timeout: \(scrollIdleTimeout)s (suspends when inactive)
        """
    }
}

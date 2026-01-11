//
//  ScrollDetectionCoordinator.swift
//  ScrollTime
//
//  Coordinates the scroll detection system with the intervention system.
//  This is the main integration point that connects:
//  - ScrollDetector (detection engine)
//  - VelocityTracker (precise velocity measurements)
//  - DoomScrollingHeuristics (pattern analysis)
//  - InterventionManager (intervention triggering)
//
//  Use this coordinator as the single entry point for scroll monitoring
//  in your app. It handles all the wiring between components.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Scroll Detection Coordinator

/// Central coordinator that integrates scroll detection with the intervention system.
/// This is the recommended way to use the scroll detection system in production.
///
/// Usage:
/// ```swift
/// // In your app setup
/// let coordinator = ScrollDetectionCoordinator.shared
///
/// // Start monitoring when user enters a target app
/// coordinator.startMonitoring(appBundleID: "com.instagram.Instagram")
///
/// // Stop when they leave
/// coordinator.stopMonitoring()
///
/// // Subscribe to state changes
/// coordinator.$isDoomScrollingDetected
///     .sink { detected in
///         // Update UI
///     }
///     .store(in: &cancellables)
/// ```
@MainActor
public final class ScrollDetectionCoordinator: ObservableObject {

    // MARK: - Singleton

    public static let shared = ScrollDetectionCoordinator()

    // MARK: - Published State

    /// Whether the coordinator is currently monitoring
    @Published public private(set) var isMonitoring: Bool = false

    /// Whether doom scrolling is currently detected
    @Published public private(set) var isDoomScrollingDetected: Bool = false

    /// Current doom scroll score (0.0 - 1.0)
    @Published public private(set) var currentScore: DoomScrollScore = .empty

    /// Current scroll intensity
    @Published public private(set) var currentIntensity: ScrollIntensity?

    /// Current session duration in seconds
    @Published public private(set) var sessionDuration: TimeInterval = 0

    /// Total scroll count in current session
    @Published public private(set) var scrollCount: Int = 0

    /// Current velocity in points per second
    @Published public private(set) var currentVelocity: Double = 0

    // MARK: - Components

    /// The scroll detector instance
    public let scrollDetector: ScrollDetector

    /// The velocity tracker for precise measurements
    public let velocityTracker: VelocityTracker

    /// The heuristics engine for pattern analysis
    public let heuristics: DoomScrollingHeuristics

    /// The intervention manager (if available)
    private var interventionManager: InterventionManager?

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?

    // MARK: - Initialization

    private init() {
        self.scrollDetector = ScrollDetector(config: .default)
        self.velocityTracker = VelocityTracker(configuration: .default)
        self.heuristics = DoomScrollingHeuristics(configuration: .default)

        setupSubscriptions()
    }

    /// Creates a coordinator with custom configuration
    public init(
        detectionConfig: DetectionConfig,
        velocityConfig: VelocityTracker.Configuration,
        heuristicsConfig: HeuristicsConfiguration
    ) {
        self.scrollDetector = ScrollDetector(config: detectionConfig)
        self.velocityTracker = VelocityTracker(configuration: velocityConfig)
        self.heuristics = DoomScrollingHeuristics(configuration: heuristicsConfig)

        setupSubscriptions()
    }

    // MARK: - Setup

    private func setupSubscriptions() {
        // Subscribe to scroll detector state
        scrollDetector.$isMonitoring
            .receive(on: DispatchQueue.main)
            .sink { [weak self] monitoring in
                self?.isMonitoring = monitoring
            }
            .store(in: &cancellables)

        scrollDetector.$isDoomScrollingDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in
                self?.isDoomScrollingDetected = detected
            }
            .store(in: &cancellables)

        scrollDetector.$currentIntensity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] intensity in
                self?.currentIntensity = intensity
            }
            .store(in: &cancellables)

        // Subscribe to scroll events for velocity updates
        scrollDetector.scrollEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleScrollEvent(event)
            }
            .store(in: &cancellables)

        // Subscribe to detection events for intervention triggering
        scrollDetector.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleDetectionEvent(event)
            }
            .store(in: &cancellables)

        // Subscribe to heuristics score updates
        heuristics.$currentScore
            .receive(on: DispatchQueue.main)
            .sink { [weak self] score in
                self?.currentScore = score
            }
            .store(in: &cancellables)
    }

    // MARK: - Intervention Manager Integration

    /// Connects the coordinator to an intervention manager.
    /// Call this during app setup to enable automatic intervention triggering.
    func connectInterventionManager(_ manager: InterventionManager) {
        self.interventionManager = manager

        // Create a publisher that converts detection events to ScrollDetectionEvent
        let detectionPublisher = scrollDetector.eventPublisher
            .compactMap { [weak self] event -> ScrollDetectionEvent? in
                guard let self = self,
                      let session = self.scrollDetector.currentSession else {
                    return nil
                }

                switch event {
                case .gentleIntervention(let intensity, _),
                     .firmIntervention(let intensity, _),
                     .mandatoryBreak(let intensity, _):
                    return ScrollDetectionEvent(
                        timestamp: Date(),
                        scrollCount: session.totalScrollCount,
                        duration: session.duration,
                        appIdentifier: session.appBundleID,
                        confidence: intensity.score
                    )
                default:
                    return nil
                }
            }
            .eraseToAnyPublisher()

        manager.subscribeToDetectionEvents(detectionPublisher)
    }

    // MARK: - Public Methods

    /// Starts scroll monitoring for a specific app
    public func startMonitoring(appBundleID: String? = nil) {
        guard !isMonitoring else { return }

        scrollDetector.startMonitoring(appBundleID: appBundleID)
        velocityTracker.reset()
        heuristics.reset()
        startSessionTimer()
    }

    /// Stops scroll monitoring
    public func stopMonitoring() {
        guard isMonitoring else { return }

        scrollDetector.stopMonitoring()
        velocityTracker.reset()
        heuristics.reset()
        stopSessionTimer()
        sessionDuration = 0
        scrollCount = 0
        currentVelocity = 0
    }

    /// Pauses monitoring (e.g., when app goes to background)
    public func pauseMonitoring() {
        scrollDetector.pauseMonitoring()
        stopSessionTimer()
    }

    /// Resumes monitoring after a pause
    public func resumeMonitoring() {
        scrollDetector.resumeMonitoring()
        startSessionTimer()
    }

    /// Processes a pan gesture recognizer
    public func processGesture(_ recognizer: UIPanGestureRecognizer) {
        // Extract velocity from the gesture recognizer and record in VelocityTracker
        // This ensures VelocityTracker stays in sync with all gesture inputs
        let velocity = recognizer.velocity(in: recognizer.view)
        velocityTracker.recordVelocity(velocity: velocity)

        scrollDetector.processScrollGesture(recognizer)
    }

    /// Processes a SwiftUI drag gesture
    public func processDrag(translation: CGSize, predictedEnd: CGSize) {
        // Calculate velocity from drag
        let velocityX = (predictedEnd.width - translation.width) * 10
        let velocityY = (predictedEnd.height - translation.height) * 10

        // Record in velocity tracker
        velocityTracker.recordVelocity(velocity: CGPoint(x: velocityX, y: velocityY))

        // Process through scroll detector
        scrollDetector.processDragGesture(
            translation: translation,
            predictedEndTranslation: predictedEnd
        )
    }

    /// Processes a raw scroll event
    public func processScroll(velocity: Double, direction: ScrollDirection) {
        velocityTracker.recordVelocity(
            velocity: CGPoint(
                x: direction == .left ? -velocity : (direction == .right ? velocity : 0),
                y: direction == .down ? -velocity : (direction == .up ? velocity : 0)
            )
        )

        scrollDetector.processScroll(velocity: velocity, direction: direction)
    }

    /// Updates the detection sensitivity
    public func updateSensitivity(_ level: SensitivityLevel) {
        let config = DetectionConfig(sensitivity: level)
        scrollDetector.config = config

        // Also update heuristics configuration
        switch level {
        case .low:
            heuristics.configuration = .relaxed
        case .medium:
            heuristics.configuration = .default
        case .high:
            heuristics.configuration = .strict
        }
    }

    /// Resets all state
    public func reset() {
        stopMonitoring()
        scrollDetector.reset()
        velocityTracker.reset()
        heuristics.reset()
        currentScore = .empty
        currentIntensity = nil
        sessionDuration = 0
        scrollCount = 0
        currentVelocity = 0
    }

    // MARK: - Private Methods

    private func handleScrollEvent(_ event: ScrollEvent) {
        currentVelocity = event.velocity
        scrollCount = scrollDetector.currentSession?.totalScrollCount ?? 0

        // Update heuristics with fresh velocity stats
        if let session = scrollDetector.currentSession {
            let stats = velocityTracker.calculateStatistics(windowDuration: 30)
            _ = heuristics.calculateScore(session: session, velocityStats: stats)
        }
    }

    private func handleDetectionEvent(_ event: DetectionEvent) {
        switch event {
        case .sessionStarted:
            startSessionTimer()

        case .sessionEnded:
            stopSessionTimer()

        case .gentleIntervention(_, _):
            // Directly trigger intervention if manager is available
            // The Combine pipeline in connectInterventionManager also delivers these events,
            // but InterventionManager.shouldAllowIntervention() guards against duplicates
            interventionManager?.triggerIntervention(type: .gentleReminder)

        case .firmIntervention(_, _):
            interventionManager?.triggerIntervention(type: .breathingExercise)

        case .mandatoryBreak(_, _):
            interventionManager?.triggerIntervention(type: .timedPause)

        case .pauseDetected(let duration):
            // Record reading pause in heuristics
            if duration >= 3.0 {
                heuristics.recordReadingPause()
            }

        default:
            break
        }
    }

    private func startSessionTimer() {
        stopSessionTimer()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sessionDuration = self?.scrollDetector.currentSession?.duration ?? 0
            }
        }
    }

    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
}

// MARK: - SwiftUI Environment

private struct ScrollDetectionCoordinatorKey: EnvironmentKey {
    @MainActor static let defaultValue: ScrollDetectionCoordinator = ScrollDetectionCoordinator.shared
}

extension EnvironmentValues {
    public var scrollDetectionCoordinator: ScrollDetectionCoordinator {
        get { self[ScrollDetectionCoordinatorKey.self] }
        set { self[ScrollDetectionCoordinatorKey.self] = newValue }
    }
}

// MARK: - View Modifier for Easy Integration

/// A view modifier that automatically tracks scrolling in a view
public struct ScrollDetectionModifier: ViewModifier {
    @Environment(\.scrollDetectionCoordinator) private var coordinator

    let appBundleID: String?

    public func body(content: Content) -> some View {
        content
            .onAppear {
                coordinator.startMonitoring(appBundleID: appBundleID)
            }
            .onDisappear {
                coordinator.stopMonitoring()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        coordinator.processDrag(
                            translation: value.translation,
                            predictedEnd: value.predictedEndTranslation
                        )
                    }
            )
    }
}

extension View {
    /// Adds scroll detection to this view
    public func trackScrolling(appBundleID: String? = nil) -> some View {
        modifier(ScrollDetectionModifier(appBundleID: appBundleID))
    }
}

// MARK: - Debug Support

extension ScrollDetectionCoordinator {
    /// Debug description of current state
    public var debugDescription: String {
        """
        ScrollDetectionCoordinator State:
        - Monitoring: \(isMonitoring)
        - Doom Scrolling: \(isDoomScrollingDetected)
        - Score: \(String(format: "%.2f", currentScore.overallScore)) (\(currentScore.level.rawValue))
        - Velocity: \(String(format: "%.1f", currentVelocity)) pts/s
        - Duration: \(String(format: "%.0f", sessionDuration))s
        - Scroll Count: \(scrollCount)
        - Intensity: \(currentIntensity?.score.description ?? "N/A")

        Detector: \(scrollDetector.debugDescription)

        Heuristics: \(heuristics.debugDescription)
        """
    }
}

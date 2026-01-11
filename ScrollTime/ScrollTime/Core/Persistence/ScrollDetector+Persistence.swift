//
//  ScrollDetector+Persistence.swift
//  ScrollTime
//
//  Extension to integrate ScrollDetector with DataManager for automatic
//  session persistence and statistics tracking.
//

import Foundation
import Combine

// MARK: - ScrollDetector + Persistence

extension ScrollDetector {

    /// Connects the ScrollDetector to the DataManager for automatic session tracking.
    /// Call this once during app initialization to enable persistence.
    ///
    /// Usage:
    /// ```swift
    /// let detector = ScrollDetector()
    /// detector.enablePersistence()
    /// ```
    @MainActor
    public func enablePersistence() {
        let dataManager = DataManager.shared

        // Subscribe to detection events and persist accordingly
        eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task { @MainActor in
                    self?.handlePersistenceEvent(event, dataManager: dataManager)
                }
            }
            .store(in: &persistenceCancellables)
    }

    /// Handles detection events for persistence
    @MainActor
    private func handlePersistenceEvent(_ event: DetectionEvent, dataManager: DataManager) {
        switch event {
        case .sessionStarted(let session):
            // Start a new persisted session
            let appName = DataManager.appNameFromBundleId(session.appBundleID ?? "unknown")
            dataManager.startSession(
                appBundleId: session.appBundleID ?? "unknown",
                appName: appName
            )

        case .sessionEnded(let summary):
            // The session will be auto-ended when we call endSession
            // But we can update final metrics first if the DataManager has an active session
            if let activeSession = dataManager.activeSession {
                // Session ended, persist it
                dataManager.endSession(id: activeSession.id)
            }

        case .intensityUpdated(let intensity):
            // Update the active session's intensity
            if let activeSession = dataManager.activeSession {
                dataManager.updateSessionIntensity(
                    id: activeSession.id,
                    intensityScore: intensity.score
                )
            }

        case .gentleIntervention(let intensity, _),
             .firmIntervention(let intensity, _),
             .mandatoryBreak(let intensity, _):
            // Record that doom scrolling was detected and intervention triggered
            if let activeSession = dataManager.activeSession {
                // Mark doom scrolling
                dataManager.updateSession(
                    id: activeSession.id,
                    wasDoomScrolling: true
                )

                // Record the intervention
                let interventionType = interventionTypeForEvent(event)
                dataManager.recordIntervention(
                    id: activeSession.id,
                    interventionType: interventionType
                )
            }

        case .metricsUpdated:
            // Could trigger a stats refresh if needed
            break

        case .pauseDetected:
            // User paused scrolling - could track this as a positive signal
            break

        case .monitoringStateChanged:
            // Monitoring state changed - no persistence action needed
            break
        }
    }

    /// Maps detection events to intervention types
    private func interventionTypeForEvent(_ event: DetectionEvent) -> InterventionType {
        switch event {
        case .gentleIntervention:
            return .gentleReminder
        case .firmIntervention:
            return .breathingExercise
        case .mandatoryBreak:
            return .timedPause
        default:
            return .gentleReminder
        }
    }

    /// Records the result of an intervention shown to the user.
    /// Call this from your intervention UI when the user responds.
    ///
    /// - Parameter result: The result of the intervention
    @MainActor
    public func recordInterventionResult(_ result: InterventionResult) {
        let dataManager = DataManager.shared
        if let activeSession = dataManager.activeSession {
            dataManager.updateInterventionResult(
                id: activeSession.id,
                result: result
            )
        }
    }

    /// Storage for persistence subscriptions
    private var persistenceCancellables: Set<AnyCancellable> {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.cancellables) as? Set<AnyCancellable> ?? []
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.cancellables, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: - Associated Object Keys

private enum AssociatedKeys {
    static var cancellables = "persistenceCancellables"
}

// MARK: - Convenience Initializer

extension ScrollDetector {

    /// Creates a ScrollDetector with persistence automatically enabled.
    ///
    /// - Parameter config: Detection configuration
    /// - Returns: A configured ScrollDetector with persistence
    @MainActor
    public static func withPersistence(config: DetectionConfig = .default) -> ScrollDetector {
        let detector = ScrollDetector(config: config)
        detector.enablePersistence()
        return detector
    }
}

// MARK: - Manual Session Management

extension ScrollDetector {

    /// Manually starts a tracked session with the given app.
    /// Use this when you want explicit control over session boundaries.
    ///
    /// - Parameters:
    ///   - appBundleID: Bundle ID of the app
    ///   - appName: Optional display name
    /// - Returns: Session ID for tracking
    @MainActor
    @discardableResult
    public func startTrackedSession(appBundleID: String, appName: String? = nil) -> UUID {
        // Start monitoring in the detector
        startMonitoring(appBundleID: appBundleID)

        // Start in the data manager
        let dataManager = DataManager.shared
        let displayName = appName ?? DataManager.appNameFromBundleId(appBundleID)
        return dataManager.startSession(appBundleId: appBundleID, appName: displayName)
    }

    /// Manually ends the current tracked session.
    @MainActor
    public func endTrackedSession() {
        // Stop monitoring in the detector
        stopMonitoring()

        // End in the data manager
        let dataManager = DataManager.shared
        if let activeSession = dataManager.activeSession {
            dataManager.endSession(id: activeSession.id)
        }
    }
}

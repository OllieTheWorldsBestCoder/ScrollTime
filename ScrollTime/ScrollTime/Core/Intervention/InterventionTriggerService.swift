//
//  InterventionTriggerService.swift
//  ScrollTime
//
//  Created by ScrollTime Team
//
//  The bridge between scroll detection and intervention presentation.
//  This service subscribes to ScrollDetector events and coordinates with
//  InterventionManager to trigger appropriate interventions at the right time.
//
//  Design Philosophy:
//  - Single source of truth for intervention triggering decisions
//  - Maintains separation of concerns (detection vs. intervention)
//  - Provides testability through dependency injection
//  - Supports demo mode for development and testing
//

import Foundation
import Combine
import SwiftUI

// MARK: - Intervention Trigger Service

/// Coordinates scroll detection events with intervention presentation.
/// Acts as the bridge between the detection system and the intervention system.
@MainActor
final class InterventionTriggerService: ObservableObject {

    // MARK: - Published State

    /// Whether an intervention is currently being presented
    @Published  private(set) var isShowingIntervention: Bool = false

    /// The type of intervention currently being shown (if any)
    @Published  private(set) var currentInterventionType: InterventionType?

    /// Whether the service is actively listening for scroll events
    @Published  private(set) var isActive: Bool = false

    /// Stats about intervention triggers today
    @Published  private(set) var triggerStats: TriggerStatistics = .empty

    // MARK: - Dependencies

    /// The scroll detector providing detection events
    private let scrollDetector: ScrollDetector

    /// The intervention manager handling intervention logic and history
    private let interventionManager: InterventionManager

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let userDefaults: UserDefaults

    /// Tracks when the service started listening (for session stats)
    private var sessionStartTime: Date?

    /// Demo mode publisher for testing
    private let demoTriggerSubject = PassthroughSubject<InterventionType, Never>()

    // Storage keys
    private enum StorageKey {
        static let triggerStats = "scrolltime.trigger.stats"
        static let lastActiveDate = "scrolltime.trigger.lastActiveDate"
    }

    // MARK: - Initialization

    init(
        scrollDetector: ScrollDetector,
        interventionManager: InterventionManager,
        userDefaults: UserDefaults = .standard
    ) {
        self.scrollDetector = scrollDetector
        self.interventionManager = interventionManager
        self.userDefaults = userDefaults

        loadPersistedState()
        setupBindings()
    }

    /// Convenience initializer with default dependencies
     convenience init() {
        self.init(
            scrollDetector: ScrollDetector(),
            interventionManager: InterventionManager()
        )
    }

    // MARK: - Public Interface

    /// Starts listening for scroll detection events and triggering interventions
     func startListening() {
        guard !isActive else { return }

        isActive = true
        sessionStartTime = Date()

        // Reset daily stats if new day
        resetStatsIfNewDay()

        // Start the escalation session
        interventionManager.escalationEngine.startSession()
    }

    /// Stops listening for scroll detection events
     func stopListening() {
        guard isActive else { return }

        isActive = false
        sessionStartTime = nil

        // End the escalation session
        interventionManager.escalationEngine.endSession()
    }

    /// Manually triggers an intervention (for testing or user-requested intervention)
    /// - Parameter type: Optional specific type to trigger, defaults to escalation-based selection
     func triggerIntervention(type: InterventionType? = nil) {
        guard !isShowingIntervention else { return }

        let selectedType = type ?? interventionManager.escalationEngine.getNextInterventionType()
        presentIntervention(type: selectedType, source: .manual)
    }

    /// Called when the user completes or dismisses an intervention
     func handleInterventionResult(_ result: InterventionResult) {
        guard isShowingIntervention else { return }

        // Record the result in the intervention manager
        interventionManager.recordResult(result)

        // Update trigger stats
        updateTriggerStats(for: result)

        // Reset presentation state
        isShowingIntervention = false
        currentInterventionType = nil

        // Post notification for any external observers
        NotificationCenter.default.post(
            name: .interventionCompleted,
            object: self,
            userInfo: ["result": result]
        )
    }

    /// Provides access to the underlying intervention manager for settings/history
    var manager: InterventionManager {
        interventionManager
    }

    /// Provides access to the scroll detector for monitoring status
     var detector: ScrollDetector {
        scrollDetector
    }

    // MARK: - Demo Mode Support

    /// Triggers a demo intervention for testing purposes
     func triggerDemoIntervention(type: InterventionType) {
        demoTriggerSubject.send(type)
    }

    /// Simulates a complete scroll-to-intervention flow for demo purposes
     func simulateDoomScrollingSequence() {
        // Start monitoring if not already
        if !scrollDetector.isMonitoring {
            scrollDetector.startMonitoring(appBundleID: "com.demo.DoomScroll")
        }

        // Trigger doom scrolling simulation
        scrollDetector.simulateDoomScrolling(count: 30, interval: 0.15)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Subscribe to scroll detector events
        scrollDetector.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleScrollDetectionEvent(event)
            }
            .store(in: &cancellables)

        // Subscribe to intervention manager's active intervention state
        interventionManager.$isShowingIntervention
            .receive(on: DispatchQueue.main)
            .assign(to: &$isShowingIntervention)

        interventionManager.$activeIntervention
            .receive(on: DispatchQueue.main)
            .map { $0?.type }
            .assign(to: &$currentInterventionType)

        // Handle demo triggers
        demoTriggerSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] type in
                self?.presentIntervention(type: type, source: .demo)
            }
            .store(in: &cancellables)

        // Convert scroll detector events to ScrollDetectionEvent format for InterventionManager
        let scrollEventPublisher = scrollDetector.eventPublisher
            .compactMap { [weak self] event -> ScrollDetectionEvent? in
                self?.convertToScrollDetectionEvent(event)
            }
            .eraseToAnyPublisher()

        interventionManager.subscribeToDetectionEvents(scrollEventPublisher)
    }

    private func handleScrollDetectionEvent(_ event: DetectionEvent) {
        switch event {
        case .gentleIntervention(let intensity, let session):
            handleInterventionTrigger(
                intensity: intensity,
                session: session,
                suggestedType: .gentleReminder
            )

        case .firmIntervention(let intensity, let session):
            handleInterventionTrigger(
                intensity: intensity,
                session: session,
                suggestedType: .breathingExercise
            )

        case .mandatoryBreak(let intensity, let session):
            handleInterventionTrigger(
                intensity: intensity,
                session: session,
                suggestedType: .frictionDialog
            )

        case .sessionStarted:
            // Ensure escalation engine is tracking the session
            if !interventionManager.escalationEngine.isSessionActive {
                interventionManager.escalationEngine.startSession()
            }

        case .sessionEnded:
            // Session ended, may want to show summary
            break

        case .intensityUpdated, .pauseDetected, .metricsUpdated, .monitoringStateChanged:
            // These events don't directly trigger interventions
            break
        }
    }

    private func handleInterventionTrigger(
        intensity: ScrollIntensity,
        session: ScrollSession,
        suggestedType: InterventionType
    ) {
        guard isActive else { return }
        guard !isShowingIntervention else { return }

        // Let the escalation engine decide the actual intervention type
        let actualType = interventionManager.escalationEngine.getNextInterventionType()

        // Check if we should show this intervention
        guard shouldShowIntervention(type: actualType, intensity: intensity) else { return }

        presentIntervention(
            type: actualType,
            source: .scrollDetection,
            scrollCount: session.totalScrollCount,
            appContext: session.appBundleID
        )
    }

    private func shouldShowIntervention(type: InterventionType, intensity: ScrollIntensity) -> Bool {
        // Check intervention manager's conditions (cooldowns, quiet hours, etc.)
        // This is handled by the intervention manager itself when we call triggerIntervention

        // Additional check: ensure intensity meets threshold for this type
        switch type {
        case .gentleReminder:
            return intensity.score >= 0.3
        case .breathingExercise:
            return intensity.score >= 0.5
        case .timedPause:
            return intensity.score >= 0.6
        case .frictionDialog:
            return intensity.score >= 0.7
        }
    }

    private func presentIntervention(
        type: InterventionType,
        source: TriggerSource,
        scrollCount: Int = 0,
        appContext: String? = nil
    ) {
        // Use the intervention manager to present
        interventionManager.triggerIntervention(type: type)

        // Update local stats
        triggerStats.totalTriggers += 1
        triggerStats.lastTriggerTime = Date()
        triggerStats.triggersByType[type, default: 0] += 1
        triggerStats.triggersBySource[source, default: 0] += 1

        persistStats()
    }

    private func convertToScrollDetectionEvent(_ event: DetectionEvent) -> ScrollDetectionEvent? {
        switch event {
        case .gentleIntervention(let intensity, let session),
             .firmIntervention(let intensity, let session),
             .mandatoryBreak(let intensity, let session):
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

    private func updateTriggerStats(for result: InterventionResult) {
        switch result {
        case .completed:
            triggerStats.completedCount += 1
        case .tookBreak:
            triggerStats.tookBreakCount += 1
        case .skipped:
            triggerStats.skippedCount += 1
        case .continuedScrolling:
            triggerStats.continuedCount += 1
        case .timedOut:
            triggerStats.timedOutCount += 1
        }

        persistStats()
    }

    // MARK: - Persistence

    private func persistStats() {
        if let encoded = try? JSONEncoder().encode(triggerStats) {
            userDefaults.set(encoded, forKey: StorageKey.triggerStats)
        }
        userDefaults.set(Date().timeIntervalSince1970, forKey: StorageKey.lastActiveDate)
    }

    private func loadPersistedState() {
        // Load trigger stats
        if let data = userDefaults.data(forKey: StorageKey.triggerStats),
           let stats = try? JSONDecoder().decode(TriggerStatistics.self, from: data) {
            triggerStats = stats
        }
    }

    private func resetStatsIfNewDay() {
        let lastActiveTimestamp = userDefaults.double(forKey: StorageKey.lastActiveDate)
        guard lastActiveTimestamp > 0 else { return }

        let lastActive = Date(timeIntervalSince1970: lastActiveTimestamp)
        let calendar = Calendar.current

        if !calendar.isDateInToday(lastActive) {
            // New day - reset daily stats
            triggerStats = .empty
            persistStats()
        }
    }
}

// MARK: - Trigger Source

/// Source that initiated an intervention trigger
 enum TriggerSource: String, Codable, Hashable {
    case scrollDetection = "scroll_detection"
    case manual = "manual"
    case demo = "demo"
    case scheduled = "scheduled"
}

// MARK: - Trigger Statistics

/// Statistics about intervention triggers for the current day
 struct TriggerStatistics: Codable, Equatable {
     var totalTriggers: Int
     var completedCount: Int
     var tookBreakCount: Int
     var skippedCount: Int
     var continuedCount: Int
     var timedOutCount: Int
     var lastTriggerTime: Date?
     var triggersByType: [InterventionType: Int]
     var triggersBySource: [TriggerSource: Int]

     static let empty = TriggerStatistics(
        totalTriggers: 0,
        completedCount: 0,
        tookBreakCount: 0,
        skippedCount: 0,
        continuedCount: 0,
        timedOutCount: 0,
        lastTriggerTime: nil,
        triggersByType: [:],
        triggersBySource: [:]
    )

    /// Total positive outcomes (completed + took break)
     var positiveOutcomes: Int {
        completedCount + tookBreakCount
    }

    /// Positive outcome rate (0-1)
     var positiveOutcomeRate: Double {
        guard totalTriggers > 0 else { return 1.0 }
        return Double(positiveOutcomes) / Double(totalTriggers)
    }
}

// Note: ScrollIntensity is defined in GestureAnalyzer.swift and used throughout the detection system

// MARK: - SwiftUI Environment

/// Environment key for accessing the intervention trigger service
@MainActor
private struct InterventionTriggerServiceKey: EnvironmentKey {
    @MainActor static let defaultValue: InterventionTriggerService = InterventionTriggerService()
}

extension EnvironmentValues {
     var interventionTriggerService: InterventionTriggerService {
        get { self[InterventionTriggerServiceKey.self] }
        set { self[InterventionTriggerServiceKey.self] = newValue }
    }
}

// MARK: - Preview Support

#if DEBUG
extension InterventionTriggerService {
    /// Creates a service for previews with mock data
     static func preview() -> InterventionTriggerService {
        let service = InterventionTriggerService()
        service.triggerStats = TriggerStatistics(
            totalTriggers: 5,
            completedCount: 3,
            tookBreakCount: 1,
            skippedCount: 1,
            continuedCount: 0,
            timedOutCount: 0,
            lastTriggerTime: Date().addingTimeInterval(-300),
            triggersByType: [.gentleReminder: 2, .breathingExercise: 2, .timedPause: 1],
            triggersBySource: [.scrollDetection: 4, .manual: 1]
        )
        return service
    }

    /// Creates a service currently showing an intervention
     static func previewShowingIntervention(type: InterventionType) -> InterventionTriggerService {
        let service = preview()
        service.triggerIntervention(type: type)
        return service
    }
}
#endif

//
//  BackgroundTasks.swift
//  ScrollTime
//
//  BGTaskScheduler setup for battery-efficient background execution.
//  Designed to minimize CPU wake-ups and respect system power policies.
//

import Foundation
import BackgroundTasks
import os.log

// MARK: - Task Identifiers

/// Background task identifiers matching Info.plist configuration
public enum BackgroundTaskIdentifier: String, CaseIterable {
    /// Short refresh task for updating usage data (~30 seconds max)
    case refresh = "com.scrolltime.refresh"

    /// Long processing task for analysis and cleanup (requires power + WiFi)
    case processing = "com.scrolltime.processing"

    var identifier: String { rawValue }
}

// MARK: - Task Configuration

/// Configuration for background task scheduling
public struct BackgroundTaskConfig {
    /// Minimum time before task can run (allows system coalescing)
    public var earliestBeginDate: Date

    /// Whether task requires external power (processing tasks only)
    public var requiresExternalPower: Bool

    /// Whether task requires network connectivity
    public var requiresNetworkConnectivity: Bool

    public init(
        earliestBeginDate: Date = Date(timeIntervalSinceNow: 15 * 60), // 15 min default
        requiresExternalPower: Bool = false,
        requiresNetworkConnectivity: Bool = false
    ) {
        self.earliestBeginDate = earliestBeginDate
        self.requiresExternalPower = requiresExternalPower
        self.requiresNetworkConnectivity = requiresNetworkConnectivity
    }

    /// Configuration optimized for minimal battery impact
    public static var batteryOptimized: BackgroundTaskConfig {
        BackgroundTaskConfig(
            earliestBeginDate: Date(timeIntervalSinceNow: 30 * 60), // 30 minutes
            requiresExternalPower: false,
            requiresNetworkConnectivity: false
        )
    }

    /// Configuration for processing tasks (longer work, requires power)
    public static var processingOptimized: BackgroundTaskConfig {
        BackgroundTaskConfig(
            earliestBeginDate: Date(timeIntervalSinceNow: 60 * 60), // 1 hour
            requiresExternalPower: true, // Only when charging
            requiresNetworkConnectivity: false
        )
    }
}

// MARK: - Background Task Handler Protocol

/// Protocol for components that handle background task execution
public protocol BackgroundTaskHandler: AnyObject {
    /// Called when refresh task is executed. Complete quickly (< 30s).
    func handleRefreshTask() async -> Bool

    /// Called when processing task is executed. Can take longer.
    func handleProcessingTask() async -> Bool
}

// MARK: - Background Task Manager

/// Manages BGTaskScheduler registration and execution.
///
/// Battery Optimization Strategies:
/// 1. Set generous `earliestBeginDate` to allow system coalescing
/// 2. Require external power for processing tasks when possible
/// 3. Complete tasks as quickly as possible
/// 4. Always reschedule to maintain monitoring
/// 5. Respect power mode from PowerManager
@MainActor
public final class BackgroundTaskManager {

    // MARK: - Singleton

    public static let shared = BackgroundTaskManager()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.scrolltime", category: "BackgroundTasks")

    /// Delegate that handles actual task work
    public weak var handler: BackgroundTaskHandler?

    /// Track last successful execution times
    private var lastRefreshTime: Date?
    private var lastProcessingTime: Date?

    /// Whether tasks have been registered
    private var isRegistered = false

    // MARK: - Initialization

    private init() {}

    // MARK: - Registration

    /// Register all background tasks. Call from application(_:didFinishLaunchingWithOptions:)
    /// Must be called before app finishes launching.
    public func registerBackgroundTasks() {
        guard !isRegistered else {
            logger.warning("Background tasks already registered")
            return
        }

        // Register refresh task (BGAppRefreshTask)
        let refreshRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskIdentifier.refresh.identifier,
            using: nil // Use main queue
        ) { [weak self] task in
            self?.handleRefreshTaskExecution(task as! BGAppRefreshTask)
        }

        if refreshRegistered {
            logger.info("Registered refresh task: \(BackgroundTaskIdentifier.refresh.identifier)")
        } else {
            logger.error("Failed to register refresh task")
        }

        // Register processing task (BGProcessingTask)
        let processingRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskIdentifier.processing.identifier,
            using: nil
        ) { [weak self] task in
            self?.handleProcessingTaskExecution(task as! BGProcessingTask)
        }

        if processingRegistered {
            logger.info("Registered processing task: \(BackgroundTaskIdentifier.processing.identifier)")
        } else {
            logger.error("Failed to register processing task")
        }

        isRegistered = true
    }

    // MARK: - Scheduling

    /// Schedule a refresh task with power-aware configuration
    @discardableResult
    public func scheduleRefreshTask(config: BackgroundTaskConfig = .batteryOptimized) -> Bool {
        // Check power mode - don't schedule if suspended
        if !PowerManager.shared.shouldMonitor {
            logger.info("Skipping refresh task scheduling - monitoring suspended")
            return false
        }

        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskIdentifier.refresh.identifier)

        // Adjust earliest begin date based on power mode
        let adjustedDate = adjustedBeginDate(base: config.earliestBeginDate)
        request.earliestBeginDate = adjustedDate

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled refresh task for \(adjustedDate)")
            return true
        } catch BGTaskScheduler.Error.notPermitted {
            logger.error("Background refresh not permitted - check capabilities")
            return false
        } catch BGTaskScheduler.Error.tooManyPendingTaskRequests {
            logger.warning("Too many pending task requests - will retry later")
            return false
        } catch BGTaskScheduler.Error.unavailable {
            logger.error("Background tasks unavailable on this device")
            return false
        } catch {
            logger.error("Failed to schedule refresh task: \(error.localizedDescription)")
            return false
        }
    }

    /// Schedule a processing task for heavy analysis work
    @discardableResult
    public func scheduleProcessingTask(config: BackgroundTaskConfig = .processingOptimized) -> Bool {
        // Processing tasks are optional - skip in reduced power modes
        let powerMode = PowerManager.shared.currentMode
        if powerMode >= .reduced {
            logger.info("Skipping processing task - power mode is \(powerMode.description)")
            return false
        }

        let request = BGProcessingTaskRequest(identifier: BackgroundTaskIdentifier.processing.identifier)

        let adjustedDate = adjustedBeginDate(base: config.earliestBeginDate)
        request.earliestBeginDate = adjustedDate

        // CRITICAL: Require external power to avoid battery drain
        request.requiresExternalPower = config.requiresExternalPower
        request.requiresNetworkConnectivity = config.requiresNetworkConnectivity

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled processing task for \(adjustedDate), requiresPower=\(config.requiresExternalPower)")
            return true
        } catch BGTaskScheduler.Error.notPermitted {
            logger.error("Background processing not permitted")
            return false
        } catch BGTaskScheduler.Error.tooManyPendingTaskRequests {
            logger.warning("Too many pending processing requests")
            return false
        } catch {
            logger.error("Failed to schedule processing task: \(error.localizedDescription)")
            return false
        }
    }

    /// Cancel all pending background tasks
    public func cancelAllTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        logger.info("Cancelled all pending background tasks")
    }

    /// Cancel a specific task type
    public func cancelTask(_ taskType: BackgroundTaskIdentifier) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskType.identifier)
        logger.info("Cancelled task: \(taskType.identifier)")
    }

    // MARK: - Task Execution

    private func handleRefreshTaskExecution(_ task: BGAppRefreshTask) {
        logger.info("Executing refresh task")

        // Schedule next refresh immediately to ensure continuity
        scheduleRefreshTask()

        // Create a task to handle the work
        let workTask = Task {
            // Check power state before doing work
            guard PowerManager.shared.shouldMonitor else {
                logger.info("Refresh task skipped - monitoring suspended")
                return true
            }

            // Call handler if available
            if let handler = handler {
                return await handler.handleRefreshTask()
            } else {
                logger.warning("No handler registered for refresh task")
                return true
            }
        }

        // Set expiration handler - must complete work before this fires
        task.expirationHandler = {
            self.logger.warning("Refresh task expired - cancelling work")
            workTask.cancel()
        }

        // Execute and complete
        Task {
            let success = await workTask.value
            task.setTaskCompleted(success: success)
            lastRefreshTime = Date()
            logger.info("Refresh task completed, success=\(success)")
        }
    }

    private func handleProcessingTaskExecution(_ task: BGProcessingTask) {
        logger.info("Executing processing task")

        // Schedule next processing task
        scheduleProcessingTask()

        let workTask = Task {
            // Double-check power state - processing tasks are expensive
            guard PowerManager.shared.shouldPerformIntensiveOperations else {
                logger.info("Processing task skipped - power mode too restrictive")
                return true
            }

            if let handler = handler {
                return await handler.handleProcessingTask()
            } else {
                logger.warning("No handler registered for processing task")
                return true
            }
        }

        task.expirationHandler = {
            self.logger.warning("Processing task expired - cancelling work")
            workTask.cancel()
        }

        Task {
            let success = await workTask.value
            task.setTaskCompleted(success: success)
            lastProcessingTime = Date()
            logger.info("Processing task completed, success=\(success)")
        }
    }

    // MARK: - Power-Aware Scheduling

    /// Adjust begin date based on current power mode
    private func adjustedBeginDate(base: Date) -> Date {
        let powerMode = PowerManager.shared.currentMode

        // In lower power modes, delay tasks further to reduce wake-ups
        let multiplier: TimeInterval
        switch powerMode {
        case .full:
            multiplier = 1.0
        case .balanced:
            multiplier = 1.5
        case .reduced:
            multiplier = 2.0
        case .minimal:
            multiplier = 3.0
        case .suspended:
            multiplier = 4.0
        }

        let interval = base.timeIntervalSinceNow
        let adjustedInterval = interval * multiplier

        return Date(timeIntervalSinceNow: adjustedInterval)
    }

    // MARK: - Diagnostics

    /// Get pending task information for debugging
    public func getPendingTasksInfo() async -> [String: Date?] {
        // Note: iOS doesn't provide API to query pending tasks directly
        // This returns our last known scheduled times
        return [
            "lastRefresh": lastRefreshTime,
            "lastProcessing": lastProcessingTime
        ]
    }

    /// Debug helper: Trigger tasks immediately (only works in debugger)
    /// Use: e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.scrolltime.refresh"]
    public var debugInstructions: String {
        """
        To test background tasks in Xcode debugger:

        1. Set a breakpoint after scheduling
        2. In debugger console, run:
           e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.scrolltime.refresh"]

        Or for processing task:
           e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.scrolltime.processing"]
        """
    }
}

// MARK: - App Lifecycle Integration

public extension BackgroundTaskManager {

    /// Call when app enters background
    func handleAppDidEnterBackground() {
        logger.info("App entered background - ensuring tasks are scheduled")

        // Always ensure we have a refresh task scheduled
        scheduleRefreshTask()

        // Schedule processing if power allows
        if PowerManager.shared.shouldPerformIntensiveOperations {
            scheduleProcessingTask()
        }
    }

    /// Call when app becomes active
    func handleAppDidBecomeActive() {
        logger.info("App became active")
        // Tasks will be handled by the app directly when active
    }

    /// Call when app will terminate
    func handleAppWillTerminate() {
        logger.info("App will terminate - scheduling final tasks")
        // Ensure tasks are scheduled for next launch
        scheduleRefreshTask()
        scheduleProcessingTask()
    }
}

// MARK: - Coalesced Operations Helper

/// Helper for batching multiple operations into single execution windows
public final class CoalescedOperationQueue {

    private let queue: DispatchQueue
    private let logger = Logger(subsystem: "com.scrolltime", category: "CoalescedOps")
    private var pendingOperations: [() -> Void] = []
    private var flushWorkItem: DispatchWorkItem?

    /// Minimum delay before flushing operations (allows more to accumulate)
    public var coalesceInterval: TimeInterval = 5.0

    public init(label: String, qos: DispatchQoS = .utility) {
        self.queue = DispatchQueue(label: label, qos: qos)
    }

    /// Add an operation to be coalesced with others
    public func addOperation(_ operation: @escaping () -> Void) {
        queue.async { [weak self] in
            self?.pendingOperations.append(operation)
            self?.scheduleFlush()
        }
    }

    private func scheduleFlush() {
        flushWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.flushOperations()
        }
        flushWorkItem = workItem

        // Use generous leeway for coalescing
        queue.asyncAfter(
            deadline: .now() + coalesceInterval,
            execute: workItem
        )
    }

    private func flushOperations() {
        guard !pendingOperations.isEmpty else { return }

        let operations = pendingOperations
        pendingOperations = []

        logger.debug("Flushing \(operations.count) coalesced operations")

        for operation in operations {
            operation()
        }
    }

    /// Force immediate flush of pending operations
    public func flushNow() {
        queue.sync { [weak self] in
            self?.flushWorkItem?.cancel()
            self?.flushOperations()
        }
    }
}

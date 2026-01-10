//
//  AppDelegate.swift
//  ScrollTime
//
//  Application lifecycle handling with battery-efficient background task registration.
//  Integrates PowerManager for adaptive scheduling based on power state.
//

import UIKit
import BackgroundTasks
import os.log

/// AppDelegate handles background task registration and lifecycle events.
///
/// Background task registration MUST happen during app launch, before
/// application(_:didFinishLaunchingWithOptions:) returns.
class AppDelegate: NSObject, UIApplicationDelegate {

    private let logger = Logger(subsystem: "com.scrolltime", category: "AppDelegate")

    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        logger.info("Application launching")

        // CRITICAL: Register background tasks before launch completes
        // This must happen synchronously during launch
        BackgroundTaskManager.shared.registerBackgroundTasks()

        // Initialize PowerManager to start monitoring power state
        // This sets up battery/thermal state observers
        Task { @MainActor in
            _ = PowerManager.shared
        }

        // Set up background task handler
        BackgroundTaskManager.shared.handler = ScrollTimeBackgroundHandler.shared

        logger.info("Application launch complete")
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        logger.info("Application entered background")
        BackgroundTaskManager.shared.handleAppDidEnterBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        logger.info("Application will enter foreground")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        logger.info("Application became active")
        BackgroundTaskManager.shared.handleAppDidBecomeActive()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        logger.info("Application will terminate")
        BackgroundTaskManager.shared.handleAppWillTerminate()
    }
}

// MARK: - Background Task Handler Implementation

/// Handles background task execution for scroll time monitoring.
///
/// Battery Optimization Notes:
/// - Refresh tasks must complete in ~30 seconds
/// - Always check PowerManager.shared.shouldMonitor before doing work
/// - Keep operations minimal and batch when possible
/// - Use CoalescedOperationQueue for multiple small updates
final class ScrollTimeBackgroundHandler: BackgroundTaskHandler {

    static let shared = ScrollTimeBackgroundHandler()

    private let logger = Logger(subsystem: "com.scrolltime", category: "BackgroundHandler")

    /// Coalesced queue for batching small updates
    private let coalescedQueue = CoalescedOperationQueue(
        label: "com.scrolltime.coalesced",
        qos: .utility
    )

    private init() {}

    /// Handle refresh task - quick update of usage data.
    /// Must complete in ~30 seconds. Keep work minimal.
    func handleRefreshTask() async -> Bool {
        logger.info("Starting refresh task work")

        // Check power mode before doing work
        guard await PowerManager.shared.shouldMonitor else {
            logger.info("Refresh skipped - monitoring suspended")
            return true
        }

        // Minimal work only:
        // 1. Update today's usage statistics
        // 2. Check if any interventions are needed
        // 3. Update widget data if applicable

        // Note: Actual implementation would call into scroll detection
        // and usage tracking systems here. For now, this is a placeholder.

        // Example: Update today's scroll time data
        // await UsageDataStore.shared.updateTodayStats()

        logger.info("Refresh task completed successfully")
        return true
    }

    /// Handle processing task - longer analysis work.
    /// Can take several minutes but system requires power and/or WiFi.
    func handleProcessingTask() async -> Bool {
        logger.info("Starting processing task work")

        // Double-check power mode - processing tasks are expensive
        guard await PowerManager.shared.shouldPerformIntensiveOperations else {
            logger.info("Processing skipped - power mode too restrictive")
            return true
        }

        // More intensive work allowed here:
        // 1. Analyze weekly usage patterns
        // 2. Clean up old data
        // 3. Generate insights
        // 4. Sync with health data

        // Example: Perform weekly analysis
        // await AnalyticsEngine.shared.performWeeklyAnalysis()

        // Example: Clean up data older than 90 days
        // await UsageDataStore.shared.cleanupOldData(olderThan: .days(90))

        logger.info("Processing task completed successfully")
        return true
    }
}

// MARK: - Legacy Operation Classes (Deprecated)

/// Legacy refresh operation - use BackgroundTaskHandler instead
@available(*, deprecated, message: "Use BackgroundTaskHandler.handleRefreshTask instead")
class RefreshOperation: Operation {
    override func main() {
        guard !isCancelled else { return }
        // Refresh scroll detection state and check for any pending interventions
        // This runs in the background periodically
    }
}

/// Legacy processing operation - use BackgroundTaskHandler instead
@available(*, deprecated, message: "Use BackgroundTaskHandler.handleProcessingTask instead")
class ProcessingOperation: Operation {
    override func main() {
        guard !isCancelled else { return }
        // Process usage analytics and update statistics
        // This runs when the device is idle
    }
}

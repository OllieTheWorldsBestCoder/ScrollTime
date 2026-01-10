//
//  PowerManager.swift
//  ScrollTime
//
//  Battery-efficient power state monitoring and adaptive scheduling.
//  Designed for < 1% battery impact per hour.
//

import Foundation
import Combine
import os.log

// MARK: - Power State

/// Represents the current power efficiency mode based on system state
public enum PowerMode: Int, Comparable, CustomStringConvertible {
    /// Full monitoring - device is charging or battery is high
    case full = 0
    /// Balanced monitoring - normal battery operation
    case balanced = 1
    /// Reduced monitoring - battery below 30% or thermal pressure
    case reduced = 2
    /// Minimal monitoring - Low Power Mode enabled or critical thermal state
    case minimal = 3
    /// Suspended monitoring - critical battery or emergency thermal
    case suspended = 4

    public static func < (lhs: PowerMode, rhs: PowerMode) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        switch self {
        case .full: return "Full"
        case .balanced: return "Balanced"
        case .reduced: return "Reduced"
        case .minimal: return "Minimal"
        case .suspended: return "Suspended"
        }
    }

    /// Recommended minimum interval between monitoring operations (in seconds)
    public var monitoringInterval: TimeInterval {
        switch self {
        case .full: return 60          // 1 minute - aggressive but acceptable
        case .balanced: return 120     // 2 minutes - normal operation
        case .reduced: return 300      // 5 minutes - conserve battery
        case .minimal: return 600      // 10 minutes - bare minimum
        case .suspended: return .infinity
        }
    }

    /// Timer leeway to allow system coalescing (30% of interval)
    public var timerLeeway: DispatchTimeInterval {
        switch self {
        case .full: return .seconds(18)
        case .balanced: return .seconds(36)
        case .reduced: return .seconds(90)
        case .minimal: return .seconds(180)
        case .suspended: return .never
        }
    }

    /// Recommended QoS for background operations in this mode
    public var recommendedQoS: DispatchQoS {
        switch self {
        case .full: return .utility
        case .balanced: return .utility
        case .reduced: return .background
        case .minimal: return .background
        case .suspended: return .background
        }
    }
}

// MARK: - Power Manager

/// Manages battery-efficient scheduling and power state monitoring.
///
/// Key design principles:
/// - Minimize CPU wake-ups by using generous timer leeway
/// - Respect Low Power Mode unconditionally
/// - Respond proactively to thermal pressure
/// - Batch operations rather than frequent small tasks
/// - Use `.background` or `.utility` QoS for non-critical work
@MainActor
public final class PowerManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = PowerManager()

    // MARK: - Published State

    /// Current power mode based on all system factors
    @Published public private(set) var currentMode: PowerMode = .balanced

    /// Whether Low Power Mode is enabled on the device
    @Published public private(set) var isLowPowerModeEnabled: Bool = false

    /// Current thermal state of the device
    @Published public private(set) var thermalState: ProcessInfo.ThermalState = .nominal

    /// Battery level as percentage (0.0 - 1.0), nil if unavailable
    @Published public private(set) var batteryLevel: Float?

    /// Whether device is currently charging
    @Published public private(set) var isCharging: Bool = false

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.scrolltime", category: "PowerManager")
    private var cancellables = Set<AnyCancellable>()
    private var notificationObservers: [NSObjectProtocol] = []

    /// Debounce timer to avoid rapid mode changes
    private var modeUpdateWorkItem: DispatchWorkItem?

    // MARK: - Initialization

    private init() {
        setupInitialState()
        setupNotificationObservers()
        logger.info("PowerManager initialized with mode: \(self.currentMode.description)")
    }

    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Setup

    private func setupInitialState() {
        // Read initial Low Power Mode state
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

        // Read initial thermal state
        thermalState = ProcessInfo.processInfo.thermalState

        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel >= 0 ? UIDevice.current.batteryLevel : nil
        isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full

        // Calculate initial mode
        updatePowerMode()
    }

    private func setupNotificationObservers() {
        // Low Power Mode changes - CRITICAL for battery optimization
        let lowPowerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleLowPowerModeChange()
            }
        }
        notificationObservers.append(lowPowerObserver)

        // Thermal state changes - respond proactively to prevent throttling
        let thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleThermalStateChange()
            }
        }
        notificationObservers.append(thermalObserver)

        // Battery level changes
        let batteryLevelObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleBatteryLevelChange()
            }
        }
        notificationObservers.append(batteryLevelObserver)

        // Battery state changes (charging/unplugged)
        let batteryStateObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleBatteryStateChange()
            }
        }
        notificationObservers.append(batteryStateObserver)
    }

    // MARK: - Notification Handlers

    private func handleLowPowerModeChange() {
        let newValue = ProcessInfo.processInfo.isLowPowerModeEnabled
        guard newValue != isLowPowerModeEnabled else { return }

        isLowPowerModeEnabled = newValue
        logger.info("Low Power Mode changed: \(newValue)")

        // Immediate mode update - Low Power Mode is user's explicit request
        updatePowerMode()
    }

    private func handleThermalStateChange() {
        let newState = ProcessInfo.processInfo.thermalState
        guard newState != thermalState else { return }

        thermalState = newState
        logger.info("Thermal state changed: \(self.thermalStateDescription)")

        // Immediate update for thermal changes - these can escalate quickly
        updatePowerMode()
    }

    private func handleBatteryLevelChange() {
        let newLevel = UIDevice.current.batteryLevel
        guard newLevel >= 0 else { return }

        batteryLevel = newLevel

        // Debounce battery level updates (they can be frequent)
        scheduleDelayedModeUpdate()
    }

    private func handleBatteryStateChange() {
        let state = UIDevice.current.batteryState
        let newCharging = state == .charging || state == .full

        guard newCharging != isCharging else { return }

        isCharging = newCharging
        logger.info("Charging state changed: \(newCharging)")

        updatePowerMode()
    }

    // MARK: - Mode Calculation

    private func scheduleDelayedModeUpdate() {
        modeUpdateWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.updatePowerMode()
            }
        }
        modeUpdateWorkItem = workItem

        // Debounce by 2 seconds to avoid rapid recalculations
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    private func updatePowerMode() {
        let newMode = calculatePowerMode()

        guard newMode != currentMode else { return }

        let oldMode = currentMode
        currentMode = newMode

        logger.info("Power mode changed: \(oldMode.description) -> \(newMode.description)")

        // Post notification for components that don't use Combine
        NotificationCenter.default.post(
            name: .powerModeDidChange,
            object: self,
            userInfo: ["oldMode": oldMode, "newMode": newMode]
        )
    }

    private func calculatePowerMode() -> PowerMode {
        // Priority 1: Critical thermal state = suspend everything
        if thermalState == .critical {
            logger.warning("Critical thermal state - suspending monitoring")
            return .suspended
        }

        // Priority 2: Low Power Mode = user explicitly wants power savings
        if isLowPowerModeEnabled {
            // If also under thermal pressure, be even more aggressive
            if thermalState == .serious {
                return .suspended
            }
            return .minimal
        }

        // Priority 3: Serious thermal state = aggressive reduction
        if thermalState == .serious {
            return .reduced
        }

        // Priority 4: Charging = can be more aggressive
        if isCharging {
            return thermalState == .fair ? .balanced : .full
        }

        // Priority 5: Battery level based decisions
        guard let level = batteryLevel else {
            return .balanced // Unknown battery = assume balanced
        }

        if level < 0.10 {
            logger.info("Critical battery level (\(Int(level * 100))%) - suspending")
            return .suspended
        } else if level < 0.20 {
            return .minimal
        } else if level < 0.30 {
            return .reduced
        } else if level < 0.50 {
            // Fair thermal state + medium battery = reduce
            if thermalState == .fair {
                return .reduced
            }
            return .balanced
        } else {
            // Good battery level
            if thermalState == .fair {
                return .balanced
            }
            return .full
        }
    }

    // MARK: - Public API

    /// Check if intensive operations should be performed
    public var shouldPerformIntensiveOperations: Bool {
        currentMode <= .balanced && thermalState.rawValue < ProcessInfo.ThermalState.serious.rawValue
    }

    /// Check if any monitoring should occur
    public var shouldMonitor: Bool {
        currentMode != .suspended
    }

    /// Get a Combine publisher for power mode changes
    public var powerModePublisher: AnyPublisher<PowerMode, Never> {
        $currentMode.eraseToAnyPublisher()
    }

    /// Create a power-efficient timer that respects current power mode
    /// - Parameters:
    ///   - queue: Dispatch queue to run timer on (should be non-main for background work)
    ///   - handler: Closure called on each timer fire
    /// - Returns: Configured DispatchSourceTimer, or nil if monitoring is suspended
    public func createAdaptiveTimer(
        queue: DispatchQueue,
        handler: @escaping () -> Void
    ) -> DispatchSourceTimer? {
        guard shouldMonitor else {
            logger.info("Timer creation skipped - monitoring suspended")
            return nil
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)

        let interval = currentMode.monitoringInterval
        let leeway = currentMode.timerLeeway

        timer.schedule(
            deadline: .now() + interval,
            repeating: interval,
            leeway: leeway
        )

        timer.setEventHandler(handler: handler)

        logger.debug("Created adaptive timer: interval=\(interval)s, leeway=\(String(describing: leeway))")

        return timer
    }

    /// Update an existing timer to match current power mode
    public func updateTimer(_ timer: DispatchSourceTimer) {
        guard shouldMonitor else {
            timer.suspend()
            return
        }

        let interval = currentMode.monitoringInterval
        let leeway = currentMode.timerLeeway

        timer.schedule(
            deadline: .now() + interval,
            repeating: interval,
            leeway: leeway
        )
    }

    /// Execute work with appropriate QoS for current power mode
    public func executeWithAdaptiveQoS(_ work: @escaping () -> Void) {
        let qos = currentMode.recommendedQoS
        DispatchQueue.global(qos: qos.qosClass).async(execute: work)
    }

    // MARK: - Diagnostics

    private var thermalStateDescription: String {
        switch thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    /// Get a diagnostic summary of current power state
    public var diagnosticSummary: String {
        """
        Power Mode: \(currentMode.description)
        Low Power Mode: \(isLowPowerModeEnabled)
        Thermal State: \(thermalStateDescription)
        Battery Level: \(batteryLevel.map { "\(Int($0 * 100))%" } ?? "Unknown")
        Charging: \(isCharging)
        Monitoring Interval: \(currentMode.monitoringInterval)s
        """
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted when the power mode changes
    static let powerModeDidChange = Notification.Name("com.scrolltime.powerModeDidChange")
}

// MARK: - UIKit Import for Battery Monitoring

import UIKit

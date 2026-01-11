//
//  ScrollTimeApp.swift
//  ScrollTime
//
//  Main app entry point with battery-efficient lifecycle management.
//  Properly integrates with ScenePhase for power-aware monitoring.
//

import SwiftUI
import Combine

/// Main app entry point for ScrollTime
@main
struct ScrollTimeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.interventionService)
                .environment(\.interventionManager, appState.interventionService.manager)
                .environment(\.interventionTriggerService, appState.interventionService)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    appState.handleScenePhaseChange(from: oldPhase, to: newPhase)
                }
        }
    }
}

/// Root content view that handles splash, onboarding, and main app flow
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var interventionService: InterventionTriggerService
    @State private var showSplash = true
    @State private var showIntervention = false
    @State private var interventionType: InterventionType = .breathingExercise

    private var cancellables = Set<AnyCancellable>()

    var body: some View {
        ZStack {
            // Main content
            Group {
                if appState.hasCompletedOnboarding {
                    DashboardView()
                        .interventionPresenter(
                            isPresented: $showIntervention,
                            interventionType: $interventionType,
                            onComplete: handleInterventionResult
                        )
                } else {
                    OnboardingView {
                        withAnimation {
                            appState.completeOnboarding()
                        }
                    }
                }
            }
            .opacity(showSplash ? 0 : 1)

            // Splash screen overlay
            if showSplash {
                SplashScreenView {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .interventionTriggered)) { notification in
            handleInterventionTriggered(notification)
        }
        .onChange(of: interventionService.isShowingIntervention) { _, newValue in
            if newValue, let type = interventionService.currentInterventionType {
                interventionType = type
                showIntervention = true
            }
        }
    }

    private func handleInterventionTriggered(_ notification: Notification) {
        if let config = notification.userInfo?["configuration"] as? InterventionConfiguration {
            interventionType = config.type
            showIntervention = true
        }
    }

    private func handleInterventionResult(_ result: InterventionResult) {
        // Record the result through the intervention service
        interventionService.handleInterventionResult(result)

        // Update local state
        showIntervention = false

        // Log for debugging
        switch result {
        case .completed:
            print("[ScrollTime] User completed the intervention")
        case .tookBreak:
            print("[ScrollTime] User chose to take a break")
        case .continuedScrolling:
            print("[ScrollTime] User chose to continue scrolling")
        case .skipped:
            print("[ScrollTime] User skipped the intervention")
        case .timedOut:
            print("[ScrollTime] Intervention timed out")
        }
    }
}

/// Global app state management with battery-efficient lifecycle handling
@MainActor
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    @Published var isMonitoring: Bool
    @Published var preferences: UserPreferences

    /// Shared scroll detector instance for the app
    @Published private(set) var scrollDetector: ScrollDetector

    /// Intervention trigger service that bridges detection and interventions
    @Published private(set) var interventionService: InterventionTriggerService

    /// Track whether the app is currently active
    private var isAppActive: Bool = true

    /// Track the last scene phase for debugging
    private var lastScenePhase: ScenePhase = .active

    init() {
        // Load saved state first (non-dependent properties)
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let savedIsMonitoring = UserDefaults.standard.bool(forKey: "isMonitoring")
        self.isMonitoring = savedIsMonitoring

        // Load preferences into a local variable first
        let loadedPreferences: UserPreferences
        if let data = UserDefaults.standard.data(forKey: "preferences"),
           let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            loadedPreferences = prefs
        } else {
            loadedPreferences = .default
        }
        self.preferences = loadedPreferences

        // Initialize scroll detector with saved sensitivity
        // Convert detectionSensitivity (0.0-1.0) to SensitivityLevel
        let sensitivityLevel: SensitivityLevel
        if loadedPreferences.detectionSensitivity < 0.33 {
            sensitivityLevel = .low
        } else if loadedPreferences.detectionSensitivity < 0.66 {
            sensitivityLevel = .medium
        } else {
            sensitivityLevel = .high
        }
        let config = DetectionConfig(sensitivity: sensitivityLevel)
        let detector = ScrollDetector(config: config)
        self.scrollDetector = detector

        // Initialize intervention service with the scroll detector
        self.interventionService = InterventionTriggerService(
            scrollDetector: detector,
            interventionManager: InterventionManager()
        )

        // Start monitoring if it was enabled
        if savedIsMonitoring {
            detector.startMonitoring()
            interventionService.startListening()
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    /// Toggles monitoring state with proper lifecycle management
    func toggleMonitoring() {
        isMonitoring.toggle()
        UserDefaults.standard.set(isMonitoring, forKey: "isMonitoring")

        if isMonitoring {
            scrollDetector.startMonitoring()
            interventionService.startListening()
        } else {
            scrollDetector.stopMonitoring()
            interventionService.stopListening()
        }
    }

    /// Starts monitoring if not already active
    func startMonitoring() {
        guard !isMonitoring else { return }
        toggleMonitoring()
    }

    /// Stops monitoring if currently active
    func stopMonitoring() {
        guard isMonitoring else { return }
        toggleMonitoring()
    }

    func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "preferences")
        }

        // Update detector config if sensitivity changed
        // Convert detectionSensitivity (0.0-1.0) to SensitivityLevel
        let sensitivityLevel: SensitivityLevel
        if preferences.detectionSensitivity < 0.33 {
            sensitivityLevel = .low
        } else if preferences.detectionSensitivity < 0.66 {
            sensitivityLevel = .medium
        } else {
            sensitivityLevel = .high
        }
        let newConfig = DetectionConfig(sensitivity: sensitivityLevel)
        scrollDetector.config = newConfig
    }

    func resetAll() {
        hasCompletedOnboarding = false
        isMonitoring = false
        preferences = .default

        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "isMonitoring")
        UserDefaults.standard.removeObject(forKey: "preferences")

        scrollDetector.reset()
        interventionService.stopListening()
    }

    // MARK: - Scene Phase Handling (Battery Optimization)

    /// Handles scene phase changes for battery-efficient monitoring.
    /// This is CRITICAL for battery optimization - we pause all timers when backgrounded.
    ///
    /// - Parameters:
    ///   - oldPhase: The previous scene phase
    ///   - newPhase: The new scene phase
    func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        lastScenePhase = newPhase

        switch newPhase {
        case .active:
            // App is now active - resume monitoring if enabled
            isAppActive = true
            if isMonitoring {
                scrollDetector.handleScenePhaseChange(isActive: true)
            }
            print("[ScrollTime] App became active - monitoring \(isMonitoring ? "resumed" : "not enabled")")

        case .inactive:
            // App is transitioning (e.g., control center, notification)
            // Don't pause yet - might come right back
            print("[ScrollTime] App became inactive")

        case .background:
            // App is now in background - MUST pause monitoring to save battery
            isAppActive = false
            if isMonitoring {
                scrollDetector.handleScenePhaseChange(isActive: false)
            }
            print("[ScrollTime] App entered background - monitoring paused")

        @unknown default:
            break
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
}

import SwiftUI

/// Main app entry point for ScrollTime
@main
struct ScrollTimeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

/// Root content view that handles splash, onboarding, and main app flow
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true
    @State private var showIntervention = false
    @State private var interventionType: InterventionType = .breathingExercise

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
    }

    private func handleInterventionResult(_ result: InterventionResult) {
        switch result {
        case .completed:
            print("User completed the intervention")
        case .tookBreak:
            print("User chose to take a break")
        case .continuedScrolling:
            print("User chose to continue scrolling")
        case .skipped:
            print("User skipped the intervention")
        case .timedOut:
            print("Intervention timed out")
        }
    }
}

/// Global app state management
@MainActor
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    @Published var isMonitoring: Bool
    @Published var preferences: UserPreferences

    init() {
        // Load saved state
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.isMonitoring = UserDefaults.standard.bool(forKey: "isMonitoring")

        // Load preferences
        if let data = UserDefaults.standard.data(forKey: "preferences"),
           let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            self.preferences = prefs
        } else {
            self.preferences = .default
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func toggleMonitoring() {
        isMonitoring.toggle()
        UserDefaults.standard.set(isMonitoring, forKey: "isMonitoring")
    }

    func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "preferences")
        }
    }

    func resetAll() {
        hasCompletedOnboarding = false
        isMonitoring = false
        preferences = .default

        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "isMonitoring")
        UserDefaults.standard.removeObject(forKey: "preferences")
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
}

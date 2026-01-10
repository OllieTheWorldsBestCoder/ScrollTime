//
//  ScreenTimeManager.swift
//  ScrollTime
//
//  Manages FamilyControls authorization and provides the central
//  interface for Screen Time API integration. Handles graceful
//  degradation to demo mode when the entitlement is unavailable.
//

import Foundation
import Combine
import SwiftUI

// Conditional imports for Screen Time frameworks
// These may not be available on all platforms or without entitlements
#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

// MARK: - Authorization Status

/// Represents the current authorization state for Screen Time access
enum ScreenTimeAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case approved
    case unavailable  // FamilyControls entitlement not available

    var displayName: String {
        switch self {
        case .notDetermined:
            return "Not Requested"
        case .denied:
            return "Denied"
        case .approved:
            return "Approved"
        case .unavailable:
            return "Demo Mode"
        }
    }

    var isFullyFunctional: Bool {
        return self == .approved
    }
}

// MARK: - Screen Time Manager

/// Central manager for FamilyControls authorization and Screen Time integration.
/// Provides demo mode fallback when the FamilyControls entitlement is unavailable.
@MainActor
final class ScreenTimeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ScreenTimeManager()

    // MARK: - Published Properties

    /// Current authorization status
    @Published private(set) var authorizationStatus: ScreenTimeAuthorizationStatus = .notDetermined

    /// Whether Screen Time APIs are available on this device/configuration
    @Published private(set) var isScreenTimeAvailable: Bool = false

    /// Error message if authorization failed
    @Published private(set) var authorizationError: String?

    /// Whether the app is running in demo mode (without full Screen Time access)
    @Published private(set) var isDemoMode: Bool = true

    // MARK: - Private Properties

    #if canImport(FamilyControls)
    private var authorizationCancellable: AnyCancellable?
    #endif

    private let userDefaults = UserDefaults.standard
    private let hasRequestedAuthorizationKey = "ScreenTimeManager.hasRequestedAuthorization"

    // MARK: - Initialization

    private init() {
        checkScreenTimeAvailability()
        setupAuthorizationObserver()
        loadInitialStatus()
    }

    // MARK: - Public Methods

    /// Request FamilyControls authorization from the user.
    /// This presents a system dialog asking for Screen Time access.
    func requestAuthorization() async {
        #if canImport(FamilyControls)
        guard isScreenTimeAvailable else {
            authorizationStatus = .unavailable
            isDemoMode = true
            authorizationError = "Screen Time APIs are not available on this device or configuration."
            return
        }

        do {
            // Request authorization for individual (self) control
            // Use .child for parental control scenarios with Family Sharing
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)

            userDefaults.set(true, forKey: hasRequestedAuthorizationKey)
            authorizationError = nil

            // Status will be updated by the observer
            updateAuthorizationStatus()

        } catch let error as FamilyControlsError {
            handleFamilyControlsError(error)
        } catch {
            authorizationError = "Authorization failed: \(error.localizedDescription)"
            authorizationStatus = .denied
            isDemoMode = true
        }
        #else
        // FamilyControls not available at compile time
        authorizationStatus = .unavailable
        isDemoMode = true
        authorizationError = "FamilyControls framework not available."
        #endif
    }

    /// Revoke authorization (for testing or user-initiated reset).
    /// Note: This only clears local state. The user must revoke in Settings.
    func revokeAuthorization() async {
        #if canImport(FamilyControls)
        // Clear any managed settings
        let store = ManagedSettingsStore()
        store.clearAllSettings()

        // Note: There's no programmatic way to revoke FamilyControls authorization.
        // The user must go to Settings > Screen Time to revoke access.
        // We can only clear our local state.

        userDefaults.set(false, forKey: hasRequestedAuthorizationKey)
        updateAuthorizationStatus()
        #endif
    }

    /// Check if authorization has been previously requested
    var hasRequestedAuthorization: Bool {
        return userDefaults.bool(forKey: hasRequestedAuthorizationKey)
    }

    /// Force a refresh of the authorization status
    func refreshAuthorizationStatus() {
        updateAuthorizationStatus()
    }

    /// Enable demo mode explicitly (for testing without Screen Time)
    func enableDemoMode() {
        isDemoMode = true
        authorizationStatus = .unavailable
    }

    // MARK: - Private Methods

    /// Check if Screen Time APIs are available on this device
    private func checkScreenTimeAvailability() {
        #if canImport(FamilyControls)
        // Screen Time APIs require iOS 15+ and proper entitlements
        if #available(iOS 15.0, *) {
            // Check if we're on a physical device (Screen Time doesn't work on simulator)
            #if targetEnvironment(simulator)
            isScreenTimeAvailable = false
            isDemoMode = true
            authorizationError = "Screen Time APIs are not available in the simulator. Running in demo mode."
            #else
            // Assume available on device; actual check happens during authorization
            isScreenTimeAvailable = true
            #endif
        } else {
            isScreenTimeAvailable = false
            isDemoMode = true
            authorizationError = "Screen Time APIs require iOS 15 or later."
        }
        #else
        isScreenTimeAvailable = false
        isDemoMode = true
        #endif
    }

    /// Set up observer for authorization status changes
    private func setupAuthorizationObserver() {
        #if canImport(FamilyControls)
        guard #available(iOS 15.0, *) else { return }

        // Observe changes to authorization status
        // This fires when the user changes permissions in Settings
        authorizationCancellable = AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleAuthorizationStatusChange(status)
            }
        #endif
    }

    /// Load the initial authorization status
    private func loadInitialStatus() {
        updateAuthorizationStatus()
    }

    /// Update the current authorization status from the system
    private func updateAuthorizationStatus() {
        #if canImport(FamilyControls)
        guard #available(iOS 15.0, *), isScreenTimeAvailable else {
            authorizationStatus = .unavailable
            isDemoMode = true
            return
        }

        let status = AuthorizationCenter.shared.authorizationStatus
        handleAuthorizationStatusChange(status)
        #else
        authorizationStatus = .unavailable
        isDemoMode = true
        #endif
    }

    #if canImport(FamilyControls)
    /// Handle changes to the FamilyControls authorization status
    @available(iOS 16.0, *)
    private func handleAuthorizationStatusChange(_ status: AuthorizationStatus) {
        switch status {
        case .notDetermined:
            authorizationStatus = .notDetermined
            isDemoMode = true

        case .denied:
            authorizationStatus = .denied
            isDemoMode = true
            authorizationError = "Screen Time access was denied. Please enable in Settings > Screen Time."

        case .approved:
            authorizationStatus = .approved
            isDemoMode = false
            authorizationError = nil

        @unknown default:
            authorizationStatus = .notDetermined
            isDemoMode = true
        }
    }

    /// Handle specific FamilyControls errors
    private func handleFamilyControlsError(_ error: FamilyControlsError) {
        switch error {
        case .restricted:
            authorizationError = "Screen Time is restricted on this device."
            authorizationStatus = .denied

        case .unavailable:
            authorizationError = "Screen Time is unavailable. Please enable it in Settings."
            authorizationStatus = .unavailable
            isScreenTimeAvailable = false

        case .invalidAccountType:
            authorizationError = "Invalid account type for Screen Time access."
            authorizationStatus = .denied

        case .invalidArgument:
            authorizationError = "Invalid authorization request."
            authorizationStatus = .denied

        case .authorizationConflict:
            authorizationError = "Authorization conflict. Another app may be managing Screen Time."
            authorizationStatus = .denied

        case .authorizationCanceled:
            authorizationError = "Authorization was canceled by the user."
            authorizationStatus = .notDetermined

        case .networkError:
            authorizationError = "Network error during authorization. Please check your connection."
            authorizationStatus = .notDetermined

        @unknown default:
            authorizationError = "An unknown error occurred: \(error.localizedDescription)"
            authorizationStatus = .denied
        }

        isDemoMode = true
    }
    #endif
}

// MARK: - SwiftUI View Extension

extension ScreenTimeManager {

    /// A view that requests Screen Time authorization when it appears
    struct AuthorizationRequestView: View {
        @ObservedObject var manager: ScreenTimeManager
        let onComplete: (ScreenTimeAuthorizationStatus) -> Void

        var body: some View {
            VStack(spacing: 24) {
                Image(systemName: "hourglass.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                Text("Screen Time Access")
                    .font(.title)
                    .fontWeight(.bold)

                Text("ScrollTime needs Screen Time access to monitor your app usage and help you break doom scrolling habits.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                if let error = manager.authorizationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await manager.requestAuthorization()
                            onComplete(manager.authorizationStatus)
                        }
                    }) {
                        Text("Enable Screen Time Access")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        manager.enableDemoMode()
                        onComplete(.unavailable)
                    }) {
                        Text("Continue in Demo Mode")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}

// MARK: - Debug/Testing Helpers

#if DEBUG
extension ScreenTimeManager {

    /// Reset all Screen Time related state (for testing)
    func resetForTesting() {
        userDefaults.removeObject(forKey: hasRequestedAuthorizationKey)
        authorizationStatus = .notDetermined
        isDemoMode = true
        authorizationError = nil
    }

    /// Simulate a specific authorization status (for testing)
    func simulateStatus(_ status: ScreenTimeAuthorizationStatus) {
        authorizationStatus = status
        isDemoMode = status != .approved
    }
}
#endif

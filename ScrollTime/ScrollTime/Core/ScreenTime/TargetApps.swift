//
//  TargetApps.swift
//  ScrollTime
//
//  Manages the list of apps to monitor for doom scrolling.
//  Includes predefined social media apps and supports user customization
//  through FamilyActivitySelection.
//

import Foundation
import SwiftUI
import Combine

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

// MARK: - Predefined App Info

/// Information about a predefined target app
struct PredefinedApp: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let iconName: String  // SF Symbol name
    let category: AppCategory
    let defaultEnabled: Bool

    enum AppCategory: String, CaseIterable, Codable {
        case socialMedia = "Social Media"
        case video = "Video"
        case news = "News"
        case messaging = "Messaging"
        case other = "Other"

        var iconName: String {
            switch self {
            case .socialMedia: return "person.2.fill"
            case .video: return "play.rectangle.fill"
            case .news: return "newspaper.fill"
            case .messaging: return "message.fill"
            case .other: return "app.fill"
            }
        }
    }
}

// MARK: - Predefined Apps List

extension PredefinedApp {

    /// Predefined list of common doom scrolling apps
    static let allPredefined: [PredefinedApp] = [
        // Social Media
        PredefinedApp(
            id: "instagram",
            name: "Instagram",
            bundleIdentifier: "com.burbn.instagram",
            iconName: "camera.fill",
            category: .socialMedia,
            defaultEnabled: true
        ),
        PredefinedApp(
            id: "tiktok",
            name: "TikTok",
            bundleIdentifier: "com.zhiliaoapp.musically",
            iconName: "music.note",
            category: .video,
            defaultEnabled: true
        ),
        PredefinedApp(
            id: "twitter",
            name: "X (Twitter)",
            bundleIdentifier: "com.atebits.Tweetie2",
            iconName: "at",
            category: .socialMedia,
            defaultEnabled: true
        ),
        PredefinedApp(
            id: "reddit",
            name: "Reddit",
            bundleIdentifier: "com.reddit.Reddit",
            iconName: "bubble.left.and.bubble.right.fill",
            category: .socialMedia,
            defaultEnabled: true
        ),
        PredefinedApp(
            id: "facebook",
            name: "Facebook",
            bundleIdentifier: "com.facebook.Facebook",
            iconName: "hand.thumbsup.fill",
            category: .socialMedia,
            defaultEnabled: false
        ),
        PredefinedApp(
            id: "youtube",
            name: "YouTube",
            bundleIdentifier: "com.google.ios.youtube",
            iconName: "play.rectangle.fill",
            category: .video,
            defaultEnabled: true
        ),
        PredefinedApp(
            id: "snapchat",
            name: "Snapchat",
            bundleIdentifier: "com.toyopagroup.picaboo",
            iconName: "camera.viewfinder",
            category: .socialMedia,
            defaultEnabled: false
        ),
        PredefinedApp(
            id: "threads",
            name: "Threads",
            bundleIdentifier: "com.burbn.barcelona",
            iconName: "at.circle.fill",
            category: .socialMedia,
            defaultEnabled: false
        ),
        PredefinedApp(
            id: "linkedin",
            name: "LinkedIn",
            bundleIdentifier: "com.linkedin.LinkedIn",
            iconName: "briefcase.fill",
            category: .socialMedia,
            defaultEnabled: false
        ),
        PredefinedApp(
            id: "pinterest",
            name: "Pinterest",
            bundleIdentifier: "pinterest",
            iconName: "pin.fill",
            category: .socialMedia,
            defaultEnabled: false
        ),
        // News
        PredefinedApp(
            id: "news",
            name: "Apple News",
            bundleIdentifier: "com.apple.news",
            iconName: "newspaper.fill",
            category: .news,
            defaultEnabled: false
        ),
        // Video
        PredefinedApp(
            id: "netflix",
            name: "Netflix",
            bundleIdentifier: "com.netflix.Netflix",
            iconName: "tv.fill",
            category: .video,
            defaultEnabled: false
        ),
        PredefinedApp(
            id: "twitch",
            name: "Twitch",
            bundleIdentifier: "tv.twitch",
            iconName: "gamecontroller.fill",
            category: .video,
            defaultEnabled: false
        )
    ]

    /// Get predefined apps by category
    static func apps(in category: AppCategory) -> [PredefinedApp] {
        allPredefined.filter { $0.category == category }
    }

    /// Get apps that are enabled by default
    static var defaultEnabled: [PredefinedApp] {
        allPredefined.filter { $0.defaultEnabled }
    }
}

// MARK: - Target Apps Manager

/// Manages user's selection of apps to monitor.
/// Handles both predefined app selection (demo mode) and
/// FamilyActivitySelection (full Screen Time mode).
@MainActor
final class TargetAppsManager: ObservableObject {

    // MARK: - Singleton

    static let shared = TargetAppsManager()

    // MARK: - Published Properties

    /// IDs of enabled predefined apps (for demo mode or reference)
    @Published var enabledPredefinedAppIds: Set<String> = []

    /// The FamilyActivitySelection containing opaque tokens
    #if canImport(FamilyControls)
    @Published var familyActivitySelection: FamilyActivitySelection = FamilyActivitySelection()
    #endif

    /// Whether custom apps have been selected via FamilyActivityPicker
    @Published private(set) var hasCustomSelection: Bool = false

    /// Total count of selected apps/categories
    @Published private(set) var selectionCount: Int = 0

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let enabledAppsKey = "TargetApps.enabledPredefinedAppIds"
    private let customSelectionKey = "TargetApps.hasCustomSelection"

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadSavedSelection()
        setupObservers()
    }

    // MARK: - Computed Properties

    /// Get the current FamilyActivitySelection for monitoring
    #if canImport(FamilyControls)
    var currentSelection: FamilyActivitySelection {
        return familyActivitySelection
    }
    #else
    var currentSelection: Any {
        return enabledPredefinedAppIds
    }
    #endif

    /// Get the list of enabled predefined apps
    var enabledPredefinedApps: [PredefinedApp] {
        PredefinedApp.allPredefined.filter { enabledPredefinedAppIds.contains($0.id) }
    }

    /// Check if a predefined app is enabled
    func isEnabled(_ app: PredefinedApp) -> Bool {
        enabledPredefinedAppIds.contains(app.id)
    }

    /// Check if any apps are selected
    var hasAnySelection: Bool {
        #if canImport(FamilyControls)
        return !familyActivitySelection.applicationTokens.isEmpty ||
               !familyActivitySelection.categoryTokens.isEmpty ||
               !enabledPredefinedAppIds.isEmpty
        #else
        return !enabledPredefinedAppIds.isEmpty
        #endif
    }

    // MARK: - Public Methods

    /// Toggle a predefined app's enabled state
    func togglePredefinedApp(_ app: PredefinedApp) {
        if enabledPredefinedAppIds.contains(app.id) {
            enabledPredefinedAppIds.remove(app.id)
        } else {
            enabledPredefinedAppIds.insert(app.id)
        }
        saveSelection()
    }

    /// Enable a predefined app
    func enablePredefinedApp(_ app: PredefinedApp) {
        enabledPredefinedAppIds.insert(app.id)
        saveSelection()
    }

    /// Disable a predefined app
    func disablePredefinedApp(_ app: PredefinedApp) {
        enabledPredefinedAppIds.remove(app.id)
        saveSelection()
    }

    /// Enable all default apps
    func enableDefaults() {
        for app in PredefinedApp.defaultEnabled {
            enabledPredefinedAppIds.insert(app.id)
        }
        saveSelection()
    }

    /// Disable all apps
    func disableAll() {
        enabledPredefinedAppIds.removeAll()
        #if canImport(FamilyControls)
        familyActivitySelection = FamilyActivitySelection()
        #endif
        hasCustomSelection = false
        saveSelection()
    }

    /// Update selection from FamilyActivityPicker
    #if canImport(FamilyControls)
    func updateSelection(_ selection: FamilyActivitySelection) {
        familyActivitySelection = selection
        hasCustomSelection = !selection.applicationTokens.isEmpty ||
                            !selection.categoryTokens.isEmpty ||
                            !selection.webDomainTokens.isEmpty
        updateSelectionCount()
        saveSelection()
    }
    #endif

    /// Reset to default selection
    func resetToDefaults() {
        disableAll()
        enableDefaults()
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Observe changes to enabled apps
        $enabledPredefinedAppIds
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateSelectionCount()
            }
            .store(in: &cancellables)

        #if canImport(FamilyControls)
        $familyActivitySelection
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateSelectionCount()
            }
            .store(in: &cancellables)
        #endif
    }

    private func updateSelectionCount() {
        #if canImport(FamilyControls)
        selectionCount = familyActivitySelection.applicationTokens.count +
                        familyActivitySelection.categoryTokens.count +
                        enabledPredefinedAppIds.count
        #else
        selectionCount = enabledPredefinedAppIds.count
        #endif
    }

    private func saveSelection() {
        // Save predefined app IDs
        let idsArray = Array(enabledPredefinedAppIds)
        userDefaults.set(idsArray, forKey: enabledAppsKey)
        userDefaults.set(hasCustomSelection, forKey: customSelectionKey)

        // Save FamilyActivitySelection to App Groups for extension access
        #if canImport(FamilyControls)
        saveFamilyActivitySelection()
        #endif

        userDefaults.synchronize()
    }

    private func loadSavedSelection() {
        // Load predefined app IDs
        if let savedIds = userDefaults.array(forKey: enabledAppsKey) as? [String] {
            enabledPredefinedAppIds = Set(savedIds)
        } else {
            // First launch - enable defaults
            enableDefaults()
        }

        hasCustomSelection = userDefaults.bool(forKey: customSelectionKey)

        // Load FamilyActivitySelection from App Groups
        #if canImport(FamilyControls)
        loadFamilyActivitySelection()
        #endif

        updateSelectionCount()
    }

    #if canImport(FamilyControls)
    private func saveFamilyActivitySelection() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.scrolltime.shared") else {
            return
        }

        // FamilyActivitySelection is Codable
        let encoder = PropertyListEncoder()
        if let encoded = try? encoder.encode(familyActivitySelection) {
            sharedDefaults.set(encoded, forKey: "familyActivitySelection")
        }
    }

    private func loadFamilyActivitySelection() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.scrolltime.shared"),
              let data = sharedDefaults.data(forKey: "familyActivitySelection") else {
            return
        }

        let decoder = PropertyListDecoder()
        if let decoded = try? decoder.decode(FamilyActivitySelection.self, from: data) {
            familyActivitySelection = decoded
        }
    }
    #endif
}

// MARK: - SwiftUI Screen Time App Selection View

/// A view for selecting which apps to monitor using Screen Time APIs
struct ScreenTimeAppSelectionView: View {
    @ObservedObject var manager: TargetAppsManager
    @ObservedObject var screenTimeManager: ScreenTimeManager

    @State private var showingFamilyPicker = false

    var body: some View {
        List {
            // Screen Time Selection (when available)
            if screenTimeManager.authorizationStatus == .approved {
                Section {
                    #if canImport(FamilyControls)
                    familyPickerSection
                    #endif
                } header: {
                    Text("Screen Time Apps")
                } footer: {
                    Text("Select apps directly from your device using Screen Time.")
                }
            }

            // Predefined Apps by Category
            ForEach(PredefinedApp.AppCategory.allCases, id: \.self) { category in
                let appsInCategory = PredefinedApp.apps(in: category)
                if !appsInCategory.isEmpty {
                    Section {
                        ForEach(appsInCategory) { app in
                            predefinedAppRow(app)
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.iconName)
                    }
                }
            }

            // Actions
            Section {
                Button("Enable Recommended Apps") {
                    manager.enableDefaults()
                }

                Button("Disable All Apps", role: .destructive) {
                    manager.disableAll()
                }
            }
        }
        .navigationTitle("Apps to Monitor")
        #if canImport(FamilyControls)
        .familyActivityPicker(
            isPresented: $showingFamilyPicker,
            selection: $manager.familyActivitySelection
        )
        .onChange(of: manager.familyActivitySelection) { _, newValue in
            manager.updateSelection(newValue)
        }
        #endif
    }

    #if canImport(FamilyControls)
    @ViewBuilder
    private var familyPickerSection: some View {
        Button {
            showingFamilyPicker = true
        } label: {
            HStack {
                Image(systemName: "plus.app.fill")
                    .foregroundColor(.blue)
                Text("Select Apps from Screen Time")
                Spacer()
                if manager.hasCustomSelection {
                    Text("\(manager.familyActivitySelection.applicationTokens.count) apps")
                        .foregroundColor(.secondary)
                }
            }
        }

        if !manager.familyActivitySelection.applicationTokens.isEmpty {
            HStack {
                Text("Selected Applications")
                Spacer()
                Text("\(manager.familyActivitySelection.applicationTokens.count)")
                    .foregroundColor(.secondary)
            }
        }

        if !manager.familyActivitySelection.categoryTokens.isEmpty {
            HStack {
                Text("Selected Categories")
                Spacer()
                Text("\(manager.familyActivitySelection.categoryTokens.count)")
                    .foregroundColor(.secondary)
            }
        }
    }
    #endif

    private func predefinedAppRow(_ app: PredefinedApp) -> some View {
        Button {
            manager.togglePredefinedApp(app)
        } label: {
            HStack {
                Image(systemName: app.iconName)
                    .foregroundColor(.primary)
                    .frame(width: 24)

                Text(app.name)
                    .foregroundColor(.primary)

                Spacer()

                if manager.isEnabled(app) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ScreenTimeAppSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ScreenTimeAppSelectionView(
                manager: TargetAppsManager.shared,
                screenTimeManager: ScreenTimeManager.shared
            )
        }
    }
}
#endif

// MARK: - Compact Selection Summary View

/// A compact view showing the current app selection summary
struct AppSelectionSummaryView: View {
    @ObservedObject var manager: TargetAppsManager

    var body: some View {
        HStack {
            Image(systemName: "app.badge.checkmark.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Monitored Apps")
                    .font(.headline)

                if manager.selectionCount > 0 {
                    Text("\(manager.selectionCount) apps selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No apps selected")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            // Show icons for first few enabled apps
            HStack(spacing: -8) {
                ForEach(Array(manager.enabledPredefinedApps.prefix(4)), id: \.id) { app in
                    Image(systemName: app.iconName)
                        .font(.caption)
                        .padding(6)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

import SwiftUI

// MARK: - Redesigned Settings View
// Claude-inspired: warm, minimal, thoughtful

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var intentionManager = IntentionManager.shared
    @StateObject private var windDownManager = WindDownManager.shared
    @State private var showingResetConfirmation = false
    @State private var showWindDownSettings = false
    @AppStorage("morningCheckInEnabled") private var morningCheckInEnabled = true
    @AppStorage("eveningReflectionEnabled") private var eveningReflectionEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    var body: some View {
        NavigationStack {
            ZStack {
                STColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: STSpacing.xl) {
                        // Monitoring section
                        monitoringSection

                        // Intervention section
                        interventionSection

                        // Goals section
                        goalsSection

                        // Wellness section
                        wellnessSection

                        // About section
                        aboutSection

                        // Reset section
                        resetSection

                        Spacer(minLength: STSpacing.xxxl)
                    }
                    .padding(.horizontal, STSpacing.lg)
                    .padding(.top, STSpacing.md)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.save()
                        dismiss()
                    }
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.primary)
                }
            }
            .alert("Reset All Data?", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    viewModel.resetAllData()
                }
            } message: {
                Text("This will delete all your usage data and reset settings to default. This cannot be undone.")
            }
        }
    }

    // MARK: - Monitoring Section

    private var monitoringSection: some View {
        SettingsSection(title: "Monitoring") {
            VStack(spacing: 0) {
                // Enable toggle
                SettingsToggleRow(
                    icon: "eye",
                    title: "Enable Monitoring",
                    subtitle: "Track scroll patterns in selected apps",
                    isOn: $viewModel.isMonitoringEnabled
                )

                STDivider()
                    .padding(.leading, 52)

                // App selection
                NavigationLink {
                    AppSelectionView(selectedApps: $viewModel.monitoredApps)
                } label: {
                    SettingsNavigationRow(
                        icon: "app.badge",
                        title: "Apps to Monitor",
                        value: "\(viewModel.monitoredApps.count) apps"
                    )
                }

                STDivider()
                    .padding(.leading, 52)

                // Sensitivity
                NavigationLink {
                    SensitivityView(sensitivity: $viewModel.detectionSensitivity)
                } label: {
                    SettingsNavigationRow(
                        icon: "slider.horizontal.3",
                        title: "Detection Sensitivity",
                        value: viewModel.sensitivityLabel
                    )
                }
            }
        }
    }

    // MARK: - Intervention Section

    private var interventionSection: some View {
        SettingsSection(title: "Interventions") {
            VStack(spacing: 0) {
                // Intervention type
                VStack(alignment: .leading, spacing: STSpacing.sm) {
                    HStack(spacing: STSpacing.md) {
                        SettingsIcon(systemName: "hand.raised", color: STColors.primary)

                        Text("Intervention Type")
                            .font(STTypography.bodyMedium())
                            .foregroundColor(STColors.textPrimary)
                    }
                    .padding(.horizontal, STSpacing.md)
                    .padding(.top, STSpacing.md)

                    // Type picker
                    VStack(spacing: STSpacing.xs) {
                        ForEach(InterventionType.allCases) { type in
                            InterventionTypeRow(
                                type: type,
                                isSelected: viewModel.preferredIntervention == type
                            ) {
                                viewModel.preferredIntervention = type
                            }
                        }
                    }
                    .padding(.horizontal, STSpacing.sm)
                    .padding(.bottom, STSpacing.md)
                }

                STDivider()
                    .padding(.leading, 52)

                // Trigger time
                SettingsStepperRow(
                    icon: "timer",
                    title: "Trigger After",
                    value: $viewModel.scrollThresholdMinutes,
                    range: 1...30,
                    unit: "min"
                )

                STDivider()
                    .padding(.leading, 52)

                // Escalation
                SettingsToggleRow(
                    icon: "arrow.up.right",
                    title: "Escalate Interventions",
                    subtitle: "Increase intensity if scrolling continues",
                    isOn: $viewModel.escalationEnabled
                )
            }
        }
    }

    // MARK: - Goals Section

    private var goalsSection: some View {
        SettingsSection(title: "Daily Goal") {
            SettingsStepperRow(
                icon: "target",
                title: "Scroll Time Limit",
                value: $viewModel.dailyGoalMinutes,
                range: 15...180,
                step: 15,
                unit: "min"
            )
        }
    }

    // MARK: - Wellness Section

    private var wellnessSection: some View {
        SettingsSection(title: "Wellness") {
            VStack(spacing: 0) {
                // Morning check-in toggle
                SettingsToggleRow(
                    icon: "sun.horizon",
                    title: "Morning Check-in",
                    subtitle: "Set your daily intention each morning",
                    isOn: $morningCheckInEnabled
                )

                STDivider()
                    .padding(.leading, 52)

                // Evening reflection toggle
                SettingsToggleRow(
                    icon: "moon.stars",
                    title: "Evening Reflection",
                    subtitle: "Reflect on your day before bed",
                    isOn: $eveningReflectionEnabled
                )

                STDivider()
                    .padding(.leading, 52)

                // Wind-down mode navigation
                Button {
                    showWindDownSettings = true
                } label: {
                    SettingsNavigationRow(
                        icon: "moon.fill",
                        title: "Wind-Down Mode",
                        value: windDownStatusValue
                    )
                }

                STDivider()
                    .padding(.leading, 52)

                // Notifications toggle
                SettingsToggleRow(
                    icon: "bell",
                    title: "Notifications",
                    subtitle: "Receive wellness reminders",
                    isOn: $notificationsEnabled
                )
            }
        }
        .sheet(isPresented: $showWindDownSettings) {
            WindDownSettingsView()
        }
    }

    /// Computed property for wind-down status display value
    private var windDownStatusValue: String {
        if !windDownManager.settings.isEnabled {
            return "Off"
        }

        if windDownManager.isInWindDownMode {
            return "Active"
        }

        return windDownManager.settings.periodDescription
    }

    // MARK: - About Section

    private var aboutSection: some View {
        SettingsSection(title: "About") {
            VStack(spacing: 0) {
                SettingsInfoRow(icon: "info.circle", title: "Version", value: "1.0.0")

                STDivider()
                    .padding(.leading, 52)

                Link(destination: URL(string: "https://scrolltime.app/privacy")!) {
                    SettingsNavigationRow(
                        icon: "hand.raised.square",
                        title: "Privacy Policy",
                        value: ""
                    )
                }

                STDivider()
                    .padding(.leading, 52)

                Link(destination: URL(string: "https://scrolltime.app/terms")!) {
                    SettingsNavigationRow(
                        icon: "doc.text",
                        title: "Terms of Service",
                        value: ""
                    )
                }
            }
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        SettingsSection(title: "") {
            Button {
                showingResetConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Reset All Data")
                        .font(STTypography.bodyMedium())
                        .foregroundColor(Color(hex: "C44536"))
                    Spacer()
                }
                .padding(.vertical, STSpacing.md)
            }
        }
    }
}

// MARK: - Settings Section

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: STSpacing.sm) {
            if !title.isEmpty {
                Text(title)
                    .font(STTypography.label())
                    .foregroundColor(STColors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.leading, STSpacing.xxs)
            }

            STCard {
                content
            }
        }
    }
}

// MARK: - Settings Icon

private struct SettingsIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(color)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.12))
            )
    }
}

// MARK: - Settings Rows

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    init(icon: String, title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        HStack(spacing: STSpacing.md) {
            SettingsIcon(systemName: icon, color: STColors.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(STTypography.caption())
                        .foregroundColor(STColors.textTertiary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(STColors.primary)
                .labelsHidden()
        }
        .padding(.horizontal, STSpacing.md)
        .padding(.vertical, STSpacing.sm)
    }
}

private struct SettingsNavigationRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: STSpacing.md) {
            SettingsIcon(systemName: icon, color: STColors.primary)

            Text(title)
                .font(STTypography.bodyMedium())
                .foregroundColor(STColors.textPrimary)

            Spacer()

            if !value.isEmpty {
                Text(value)
                    .font(STTypography.bodySmall())
                    .foregroundColor(STColors.textTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(STColors.textTertiary)
        }
        .padding(.horizontal, STSpacing.md)
        .padding(.vertical, STSpacing.sm)
    }
}

private struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: STSpacing.md) {
            SettingsIcon(systemName: icon, color: STColors.primary)

            Text(title)
                .font(STTypography.bodyMedium())
                .foregroundColor(STColors.textPrimary)

            Spacer()

            Text(value)
                .font(STTypography.bodySmall())
                .foregroundColor(STColors.textTertiary)
        }
        .padding(.horizontal, STSpacing.md)
        .padding(.vertical, STSpacing.sm)
    }
}

private struct SettingsStepperRow: View {
    let icon: String
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    let unit: String

    var body: some View {
        HStack(spacing: STSpacing.md) {
            SettingsIcon(systemName: icon, color: STColors.primary)

            Text(title)
                .font(STTypography.bodyMedium())
                .foregroundColor(STColors.textPrimary)

            Spacer()

            HStack(spacing: STSpacing.sm) {
                Button {
                    if value > range.lowerBound {
                        value -= step
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(value > range.lowerBound ? STColors.primary : STColors.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(STColors.primaryLight)
                        )
                }

                Text("\(value) \(unit)")
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textPrimary)
                    .frame(minWidth: 60)

                Button {
                    if value < range.upperBound {
                        value += step
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(value < range.upperBound ? STColors.primary : STColors.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(STColors.primaryLight)
                        )
                }
            }
        }
        .padding(.horizontal, STSpacing.md)
        .padding(.vertical, STSpacing.sm)
    }
}

// MARK: - Intervention Type Row

private struct InterventionTypeRow: View {
    let type: InterventionType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: STSpacing.sm) {
                Image(systemName: type.iconName)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isSelected ? STColors.primary : STColors.textTertiary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(type.displayName)
                        .font(STTypography.bodySmall())
                        .foregroundColor(isSelected ? STColors.textPrimary : STColors.textSecondary)

                    Text(type.shortDescription)
                        .font(STTypography.caption())
                        .foregroundColor(STColors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(STColors.primary)
                }
            }
            .padding(.horizontal, STSpacing.sm)
            .padding(.vertical, STSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: STRadius.sm)
                    .fill(isSelected ? STColors.primaryLight : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Model

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var isMonitoringEnabled = true
    @Published var monitoredApps: [MonitoredApp] = []
    @Published var detectionSensitivity: Double = 0.5
    @Published var preferredIntervention: InterventionType = .breathingExercise
    @Published var scrollThresholdMinutes: Int = 5
    @Published var escalationEnabled = true
    @Published var dailyGoalMinutes: Int = 60

    var sensitivityLabel: String {
        switch detectionSensitivity {
        case 0..<0.33: return "Low"
        case 0.33..<0.66: return "Medium"
        default: return "High"
        }
    }

    init() {
        loadSettings()
    }

    func loadSettings() {
        // Sample apps for demo
        monitoredApps = [
            MonitoredApp(name: "Instagram", bundleId: "com.instagram.app", icon: "camera"),
            MonitoredApp(name: "TikTok", bundleId: "com.tiktok.app", icon: "music.note"),
            MonitoredApp(name: "Twitter", bundleId: "com.twitter.app", icon: "bird"),
            MonitoredApp(name: "Reddit", bundleId: "com.reddit.app", icon: "text.bubble")
        ]
    }

    func save() {
        // Save to UserDefaults in production
        print("Settings saved")
    }

    func resetAllData() {
        isMonitoringEnabled = false
        monitoredApps = []
        detectionSensitivity = 0.5
        preferredIntervention = .breathingExercise
        scrollThresholdMinutes = 5
        escalationEnabled = true
        dailyGoalMinutes = 60
    }
}

// MARK: - Monitored App Model

struct MonitoredApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleId: String
    let icon: String
}

// MARK: - Preview

#Preview {
    SettingsView()
}

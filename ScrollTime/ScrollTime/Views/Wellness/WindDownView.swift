//
//  WindDownView.swift
//  ScrollTime
//
//  Evening wind-down prompt view that helps users transition to rest.
//  This view appears when wind-down time approaches, showing today's
//  phone usage and encouraging the user to begin winding down.
//
//  Design Philosophy:
//  - Calm, soothing aesthetic appropriate for evening
//  - Non-judgmental presentation of usage data
//  - Clear but gentle call to action
//  - Always provide an opt-out (user agency)
//

import SwiftUI

// MARK: - Wind Down View

/// A calming prompt view that encourages users to begin their evening wind-down routine.
/// Shows today's phone usage summary and offers options to start wind-down mode or skip.
struct WindDownView: View {
    @Environment(\.windDownManager) private var windDownManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.statsProvider) private var statsProvider

    /// Optional callback when the view is dismissed
    var onDismiss: (() -> Void)?

    @State private var appeared = false
    @State private var moonScale: CGFloat = 0.8
    @State private var starsOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background gradient - evening sky
            backgroundGradient
                .ignoresSafeArea()

            // Decorative stars
            starsOverlay
                .opacity(starsOpacity)

            // Main content
            VStack(spacing: STSpacing.xxl) {
                Spacer()

                // Moon icon with gentle animation
                moonSection

                // Title
                titleSection

                // Usage summary card
                usageSummaryCard

                // Wind-down message
                messageSection

                Spacer()

                // Action buttons
                actionButtons

                // Skip option
                skipButton
            }
            .padding(.horizontal, STSpacing.xl)
            .padding(.bottom, STSpacing.xl)
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                moonScale = 0.85
            }
            withAnimation(.easeIn(duration: 1.5).delay(0.3)) {
                starsOpacity = 1
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: "1a1a2e"), // Deep navy
                Color(hex: "16213e"), // Midnight blue
                Color(hex: "0f3460")  // Dark blue
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var starsOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<15, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.3...0.7)))
                        .frame(width: CGFloat.random(in: 2...4))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height * 0.5)
                        )
                }
            }
        }
    }

    // MARK: - Moon Section

    private var moonSection: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "ffeaa7").opacity(0.3),
                            Color(hex: "ffeaa7").opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)

            // Moon emoji
            Text("moon.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "ffeaa7"),
                            Color(hex: "f5cd79")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(moonScale)

            // Using SF Symbol for better rendering
            Image(systemName: "moon.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "ffeaa7"),
                            Color(hex: "f5cd79")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(moonScale)
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: STSpacing.sm) {
            Text("Time to Wind Down")
                .font(STTypography.displayMedium())
                .foregroundColor(.white)

            Text("Let's ease into the evening")
                .font(STTypography.bodyLarge())
                .foregroundColor(.white.opacity(0.7))
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Usage Summary Card

    private var usageSummaryCard: some View {
        VStack(spacing: STSpacing.md) {
            Text("Today's Summary")
                .font(STTypography.label())
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(1.2)

            HStack(spacing: STSpacing.xl) {
                usageStatItem(
                    value: formattedScrollTime,
                    label: "Screen time"
                )

                divider

                usageStatItem(
                    value: "\(statsProvider.todayStats.scrollSessionCount)",
                    label: "Sessions"
                )

                divider

                usageStatItem(
                    value: "\(statsProvider.todayStats.interventionCount)",
                    label: "Pauses"
                )
            }
        }
        .padding(.vertical, STSpacing.lg)
        .padding(.horizontal, STSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: STRadius.lg)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: STRadius.lg)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func usageStatItem(value: String, label: String) -> some View {
        VStack(spacing: STSpacing.xxs) {
            Text(value)
                .font(STTypography.titleMedium())
                .foregroundColor(.white)

            Text(label)
                .font(STTypography.caption())
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 1, height: 40)
    }

    private var formattedScrollTime: String {
        let minutes = statsProvider.todayStats.totalScrollTimeMinutes
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }

    // MARK: - Message Section

    private var messageSection: some View {
        VStack(spacing: STSpacing.sm) {
            Text(windDownManager.settings.reminderMessage)
                .font(STTypography.bodyMedium())
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text(sensitivityDescription)
                .font(STTypography.bodySmall())
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, STSpacing.md)
    }

    private var sensitivityDescription: String {
        let boost = windDownManager.settings.sensitivityBoost
        let percentage = Int((1.0 - boost) * 100)
        return "Interventions will be \(percentage)% more sensitive"
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        Button {
            startWindDown()
        } label: {
            HStack(spacing: STSpacing.sm) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 18))

                Text("Start Wind-Down Mode")
                    .font(STTypography.bodyMedium())
                    .fontWeight(.medium)
            }
            .foregroundColor(Color(hex: "1a1a2e"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, STSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: STRadius.md)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "ffeaa7"),
                                Color(hex: "f5cd79")
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var skipButton: some View {
        Button {
            skipTonight()
        } label: {
            Text("Not tonight")
                .font(STTypography.bodyMedium())
                .foregroundColor(.white.opacity(0.6))
                .padding(.vertical, STSpacing.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func startWindDown() {
        windDownManager.startWindDown()
        dismissView()
    }

    private func skipTonight() {
        windDownManager.skipTonight()
        dismissView()
    }

    private func dismissView() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}

// MARK: - Wind Down Active View

/// A compact view shown when wind-down mode is currently active.
/// Can be embedded in other views to show wind-down status.
struct WindDownActiveIndicator: View {
    @Environment(\.windDownManager) private var windDownManager

    var body: some View {
        if windDownManager.isInWindDownMode {
            HStack(spacing: STSpacing.sm) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "ffeaa7"))

                Text("Wind-down active")
                    .font(STTypography.bodySmall())
                    .foregroundColor(STColors.textSecondary)

                Spacer()

                if windDownManager.isManuallyActive {
                    Button {
                        windDownManager.endWindDown()
                    } label: {
                        Text("End")
                            .font(STTypography.caption())
                            .fontWeight(.medium)
                            .foregroundColor(STColors.primary)
                    }
                }
            }
            .padding(.horizontal, STSpacing.md)
            .padding(.vertical, STSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: STRadius.sm)
                    .fill(Color(hex: "ffeaa7").opacity(0.1))
            )
        }
    }
}

// MARK: - Wind Down Settings Row

/// A row for displaying and toggling wind-down settings.
/// Use this in the settings view.
struct WindDownSettingsRow: View {
    @Environment(\.windDownManager) private var windDownManager
    @State private var showSettings = false

    var body: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: STSpacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: STRadius.sm)
                        .fill(Color(hex: "1a1a2e").opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: "moon.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "1a1a2e"))
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wind-Down Mode")
                        .font(STTypography.bodyMedium())
                        .foregroundColor(STColors.textPrimary)

                    Text(windDownManager.scheduleDescription)
                        .font(STTypography.bodySmall())
                        .foregroundColor(STColors.textTertiary)
                }

                Spacer()

                // Status badge
                if windDownManager.isInWindDownMode {
                    Text("Active")
                        .font(STTypography.caption())
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, STSpacing.sm)
                        .padding(.vertical, STSpacing.xxs)
                        .background(
                            Capsule()
                                .fill(Color(hex: "1a1a2e"))
                        )
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(STColors.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSettings) {
            WindDownSettingsView()
        }
    }
}

// MARK: - Wind Down Settings View

/// Full settings view for configuring wind-down mode.
struct WindDownSettingsView: View {
    @Environment(\.windDownManager) private var windDownManager
    @Environment(\.dismiss) private var dismiss

    @State private var isEnabled: Bool = false
    @State private var startTime: Date = WindDownSettings.defaultStartTime
    @State private var endTime: Date = WindDownSettings.defaultEndTime
    @State private var sensitivityBoost: Double = 0.7
    @State private var showReminder: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                STColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: STSpacing.xl) {
                        // Header explanation
                        headerSection

                        // Enable toggle
                        enableSection

                        if isEnabled {
                            // Time settings
                            timeSection

                            // Sensitivity slider
                            sensitivitySection

                            // Reminder toggle
                            reminderSection
                        }
                    }
                    .padding(.horizontal, STSpacing.lg)
                    .padding(.vertical, STSpacing.md)
                }
            }
            .navigationTitle("Wind-Down Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(STColors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .fontWeight(.medium)
                    .foregroundColor(STColors.primary)
                }
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: STSpacing.sm) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "1a1a2e"), Color(hex: "0f3460")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(WindDownSettings.explanation)
                .font(STTypography.bodyMedium())
                .foregroundColor(STColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.vertical, STSpacing.md)
    }

    private var enableSection: some View {
        STCard {
            Toggle(isOn: $isEnabled.animation()) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Wind-Down")
                        .font(STTypography.bodyMedium())
                        .foregroundColor(STColors.textPrimary)

                    Text("Automatically activate each evening")
                        .font(STTypography.bodySmall())
                        .foregroundColor(STColors.textTertiary)
                }
            }
            .tint(STColors.primary)
            .padding(STSpacing.md)
        }
    }

    private var timeSection: some View {
        STCard {
            VStack(spacing: STSpacing.md) {
                // Start time
                HStack {
                    Text("Start Time")
                        .font(STTypography.bodyMedium())
                        .foregroundColor(STColors.textPrimary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: $startTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                STDivider()

                // End time
                HStack {
                    Text("Wake Time")
                        .font(STTypography.bodyMedium())
                        .foregroundColor(STColors.textPrimary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: $endTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
            }
            .padding(STSpacing.md)
        }
    }

    private var sensitivitySection: some View {
        STCard {
            VStack(alignment: .leading, spacing: STSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sensitivity Boost")
                        .font(STTypography.bodyMedium())
                        .foregroundColor(STColors.textPrimary)

                    Text(sensitivityLabel)
                        .font(STTypography.bodySmall())
                        .foregroundColor(STColors.textTertiary)
                }

                Slider(
                    value: $sensitivityBoost,
                    in: 0.5...1.0,
                    step: 0.05
                )
                .tint(STColors.primary)

                HStack {
                    Text("50% stricter")
                        .font(STTypography.caption())
                        .foregroundColor(STColors.textTertiary)

                    Spacer()

                    Text("No change")
                        .font(STTypography.caption())
                        .foregroundColor(STColors.textTertiary)
                }
            }
            .padding(STSpacing.md)
        }
    }

    private var sensitivityLabel: String {
        let percentage = Int((1.0 - sensitivityBoost) * 100)
        if percentage == 0 {
            return "Interventions at normal sensitivity"
        }
        return "Interventions \(percentage)% more sensitive"
    }

    private var reminderSection: some View {
        STCard {
            Toggle(isOn: $showReminder) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Evening Reminder")
                        .font(STTypography.bodyMedium())
                        .foregroundColor(STColors.textPrimary)

                    Text("Show a notification when wind-down starts")
                        .font(STTypography.bodySmall())
                        .foregroundColor(STColors.textTertiary)
                }
            }
            .tint(STColors.primary)
            .padding(STSpacing.md)
        }
    }

    // MARK: - Actions

    private func loadCurrentSettings() {
        let settings = windDownManager.settings
        isEnabled = settings.isEnabled
        startTime = settings.startTime
        endTime = settings.endTime
        sensitivityBoost = settings.sensitivityBoost
        showReminder = settings.showReminder
    }

    private func saveSettings() {
        windDownManager.settings = WindDownSettings(
            isEnabled: isEnabled,
            startTime: startTime,
            endTime: endTime,
            sensitivityBoost: sensitivityBoost,
            showReminder: showReminder,
            reminderMessage: windDownManager.settings.reminderMessage
        )
        dismiss()
    }
}

// MARK: - Preview

#Preview("Wind Down Prompt") {
    WindDownView()
        .withStatsProvider()
}

#Preview("Active Indicator") {
    VStack {
        WindDownActiveIndicator()
            .padding()
    }
    .stBackground()
}

#Preview("Settings Row") {
    VStack {
        WindDownSettingsRow()
            .padding()
    }
    .stBackground()
}

#Preview("Settings View") {
    WindDownSettingsView()
}

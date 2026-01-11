//
//  EveningReflectionView.swift
//  ScrollTime
//
//  A reflective end-of-day check-in that helps users connect
//  their mood and intentions with their screen time habits.
//  The tone is supportive and never judgmental.
//

import SwiftUI

// MARK: - Evening Reflection View

/// Sheet-presented evening reflection for mindful end-of-day check-in.
/// Shows today's stats, morning intention (if set), mood selection, and optional notes.
struct EveningReflectionView: View {
    @Environment(\.dismiss) private var dismiss

    /// Callback when reflection is saved
    var onSave: ((EveningReflection) -> Void)?

    // MARK: - State

    @State private var selectedMood: MoodRating?
    @State private var noteText: String = ""
    @State private var intentionMet: Bool? = nil
    @State private var isSaving: Bool = false
    @State private var showSavedConfirmation: Bool = false

    // MARK: - Data

    @State private var todayStats: DailyStats = .empty
    @State private var todayIntention: DailyIntention?
    @State private var dailyGoalMinutes: Int = 60

    // MARK: - Computed Properties

    private var scrollTimeMinutes: Int {
        todayStats.totalScrollTimeMinutes
    }

    private var minutesFromGoal: Int {
        dailyGoalMinutes - scrollTimeMinutes
    }

    private var isUnderGoal: Bool {
        minutesFromGoal >= 0
    }

    private var formattedScrollTime: String {
        let hours = scrollTimeMinutes / 60
        let minutes = scrollTimeMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var formattedGoalDifference: String {
        let diff = abs(minutesFromGoal)
        let hours = diff / 60
        let minutes = diff % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var canSave: Bool {
        selectedMood != nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                STColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: STSpacing.xl) {
                        // Header
                        headerSection

                        // Today's stats
                        statsSection

                        // Morning intention (if set)
                        if todayIntention != nil {
                            intentionSection
                        }

                        // Mood selection
                        moodSection

                        // Divider
                        STDivider()
                            .padding(.horizontal, STSpacing.md)

                        // Optional notes
                        notesSection

                        // Save button
                        saveButton

                        // Bottom spacing
                        Spacer(minLength: STSpacing.xxl)
                    }
                    .padding(.horizontal, STSpacing.lg)
                    .padding(.top, STSpacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textSecondary)
                }
            }
        }
        .onAppear {
            loadData()
        }
        .overlay {
            if showSavedConfirmation {
                savedConfirmationOverlay
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: STSpacing.xs) {
            Text("How was today?")
                .font(STTypography.displayMedium())
                .foregroundColor(STColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: STSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: STSpacing.xs) {
                Text("You scrolled for")
                    .font(STTypography.bodyLarge())
                    .foregroundColor(STColors.textSecondary)

                Text(formattedScrollTime)
                    .font(STTypography.titleMedium())
                    .foregroundColor(STColors.textPrimary)
            }

            // Goal comparison
            HStack(spacing: STSpacing.xxs) {
                Text("(")
                    .foregroundColor(STColors.textTertiary)

                Text(formattedGoalDifference)
                    .fontWeight(.medium)
                    .foregroundColor(isUnderGoal ? STColors.success : STColors.primary)

                Text(isUnderGoal ? "under your goal)" : "over your goal)")
                    .foregroundColor(STColors.textTertiary)
            }
            .font(STTypography.bodyMedium())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Intention Section

    private var intentionSection: some View {
        VStack(alignment: .leading, spacing: STSpacing.md) {
            VStack(alignment: .leading, spacing: STSpacing.xs) {
                Text("This morning you wanted to:")
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textSecondary)

                HStack(spacing: STSpacing.xs) {
                    Text(todayIntention?.intention.emoji ?? "")
                    Text("\"\(todayIntention?.intention.rawValue ?? "")\"")
                        .font(STTypography.bodyLarge())
                        .fontWeight(.medium)
                        .foregroundColor(STColors.textPrimary)
                        .italic()
                }
            }

            // How did it go?
            VStack(alignment: .leading, spacing: STSpacing.sm) {
                Text("How did it go?")
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textSecondary)

                HStack(spacing: STSpacing.sm) {
                    IntentionResultButton(
                        title: "Met it",
                        isSelected: intentionMet == true
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            intentionMet = true
                        }
                    }

                    IntentionResultButton(
                        title: "Not quite",
                        isSelected: intentionMet == false
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            intentionMet = false
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(STSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: STRadius.md)
                .fill(STColors.primaryLight.opacity(0.5))
        )
    }

    // MARK: - Mood Section

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: STSpacing.lg) {
            // Supportive response based on mood
            if let mood = selectedMood {
                Text(mood.response)
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Mood buttons
            HStack(spacing: STSpacing.lg) {
                ForEach(MoodRating.allCases, id: \.rawValue) { mood in
                    MoodButton(
                        mood: mood,
                        isSelected: selectedMood == mood
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMood = mood
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: STSpacing.sm) {
            Text(selectedMood?.journalPrompt ?? "Any thoughts? (optional)")
                .font(STTypography.bodyMedium())
                .foregroundColor(STColors.textSecondary)

            TextField("", text: $noteText, axis: .vertical)
                .font(STTypography.bodyMedium())
                .foregroundColor(STColors.textPrimary)
                .lineLimit(3...6)
                .padding(STSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: STRadius.md)
                        .fill(STColors.surface)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: STRadius.md)
                        .stroke(STColors.subtle, lineWidth: 1)
                )
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveReflection()
        } label: {
            HStack(spacing: STSpacing.sm) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Save & Rest Well")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(STPrimaryButtonStyle())
        .disabled(!canSave || isSaving)
        .opacity(canSave ? 1 : 0.5)
    }

    // MARK: - Saved Confirmation Overlay

    private var savedConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: STSpacing.lg) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(STColors.primary)

                Text("Rest well")
                    .font(STTypography.titleLarge())
                    .foregroundColor(STColors.textPrimary)

                Text("See you tomorrow")
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textSecondary)
            }
            .padding(STSpacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: STRadius.xl)
                    .fill(STColors.surface)
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 8)
            )
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        // Load today's stats from StatsProvider
        let statsProvider = StatsProvider.shared
        todayStats = statsProvider.todayStats
        dailyGoalMinutes = statsProvider.dailyGoalMinutes

        // Load today's intention if set
        todayIntention = loadTodayIntention()
    }

    private func loadTodayIntention() -> DailyIntention? {
        let key = "com.scrolltime.dailyIntention"
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }

        do {
            let intention = try JSONDecoder().decode(DailyIntention.self, from: data)
            // Only return if it's for today
            return intention.isActiveToday ? intention : nil
        } catch {
            return nil
        }
    }

    // MARK: - Save Logic

    private func saveReflection() {
        guard let mood = selectedMood else { return }

        isSaving = true

        // Create the reflection
        let reflection = EveningReflection(
            mood: mood,
            note: noteText.isEmpty ? nil : noteText.trimmingCharacters(in: .whitespacesAndNewlines),
            scrollTimeMinutes: scrollTimeMinutes,
            goalMinutes: dailyGoalMinutes,
            intentionMet: intentionMet
        )

        // Save to UserDefaults
        saveReflectionToStorage(reflection)

        // Show confirmation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isSaving = false
            showSavedConfirmation = true
        }

        // Callback
        onSave?(reflection)

        // Dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }

    private func saveReflectionToStorage(_ reflection: EveningReflection) {
        let key = "com.scrolltime.eveningReflections"
        var reflections = loadAllReflections()

        // Remove any existing reflection for today
        let todayStart = Calendar.current.startOfDay(for: Date())
        reflections.removeAll { Calendar.current.isDate($0.date, inSameDayAs: todayStart) }

        // Add new reflection
        reflections.append(reflection)

        // Keep only last 90 days of reflections
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        reflections = reflections.filter { $0.date >= cutoff }

        // Sort by date
        reflections.sort { $0.date > $1.date }

        // Save
        do {
            let data = try JSONEncoder().encode(reflections)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("EveningReflectionView: Failed to save reflection: \(error)")
        }
    }

    private func loadAllReflections() -> [EveningReflection] {
        let key = "com.scrolltime.eveningReflections"
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }

        do {
            return try JSONDecoder().decode([EveningReflection].self, from: data)
        } catch {
            return []
        }
    }
}

// MARK: - Mood Button

private struct MoodButton: View {
    let mood: MoodRating
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: STSpacing.sm) {
                Text(mood.emoji)
                    .font(.system(size: 36))
                    .scaleEffect(isSelected ? 1.15 : 1.0)

                Text(mood.label)
                    .font(STTypography.bodySmall())
                    .foregroundColor(isSelected ? STColors.primary : STColors.textSecondary)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: STRadius.lg)
                    .fill(isSelected ? STColors.primaryLight : STColors.surface)
                    .shadow(
                        color: isSelected ? STColors.primary.opacity(0.2) : Color.black.opacity(0.04),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: STRadius.lg)
                    .stroke(isSelected ? STColors.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mood.label) mood")
        .accessibilityHint("Select if today felt \(mood.label.lowercased())")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Intention Result Button

private struct IntentionResultButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: STSpacing.xs) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(STTypography.bodySmall())
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : STColors.textSecondary)
            .padding(.horizontal, STSpacing.md)
            .padding(.vertical, STSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: STRadius.full)
                    .fill(isSelected ? STColors.primary : STColors.surface)
                    .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: STRadius.full)
                    .stroke(isSelected ? Color.clear : STColors.subtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview("Default") {
    EveningReflectionView()
}

#Preview("With Intention") {
    EveningReflectionView()
        .onAppear {
            // Set up preview data with intention
            let intention = DailyIntention(intention: .focusOnWork)
            if let data = try? JSONEncoder().encode(intention) {
                UserDefaults.standard.set(data, forKey: "com.scrolltime.dailyIntention")
            }
        }
}

#Preview("Mood Selected") {
    struct PreviewWrapper: View {
        var body: some View {
            EveningReflectionViewWithMood()
        }
    }

    return PreviewWrapper()
}

// Helper view for preview with pre-selected mood
private struct EveningReflectionViewWithMood: View {
    @State private var selectedMood: MoodRating? = .okay

    var body: some View {
        NavigationStack {
            ZStack {
                STColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: STSpacing.xl) {
                        // Header
                        VStack(alignment: .leading, spacing: STSpacing.xs) {
                            Text("How was today?")
                                .font(STTypography.displayMedium())
                                .foregroundColor(STColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Stats
                        VStack(alignment: .leading, spacing: STSpacing.sm) {
                            HStack(alignment: .firstTextBaseline, spacing: STSpacing.xs) {
                                Text("You scrolled for")
                                    .font(STTypography.bodyLarge())
                                    .foregroundColor(STColors.textSecondary)

                                Text("1h 12m")
                                    .font(STTypography.titleMedium())
                                    .foregroundColor(STColors.textPrimary)
                            }

                            HStack(spacing: STSpacing.xxs) {
                                Text("(")
                                    .foregroundColor(STColors.textTertiary)

                                Text("32m")
                                    .fontWeight(.medium)
                                    .foregroundColor(STColors.success)

                                Text("under your goal)")
                                    .foregroundColor(STColors.textTertiary)
                            }
                            .font(STTypography.bodyMedium())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Intention
                        VStack(alignment: .leading, spacing: STSpacing.md) {
                            VStack(alignment: .leading, spacing: STSpacing.xs) {
                                Text("This morning you wanted to:")
                                    .font(STTypography.bodyMedium())
                                    .foregroundColor(STColors.textSecondary)

                                HStack(spacing: STSpacing.xs) {
                                    Text(IntentionType.focusOnWork.emoji)
                                    Text("\"Focus on work\"")
                                        .font(STTypography.bodyLarge())
                                        .fontWeight(.medium)
                                        .foregroundColor(STColors.textPrimary)
                                        .italic()
                                }
                            }

                            VStack(alignment: .leading, spacing: STSpacing.sm) {
                                Text("How did it go?")
                                    .font(STTypography.bodyMedium())
                                    .foregroundColor(STColors.textSecondary)

                                HStack(spacing: STSpacing.sm) {
                                    IntentionResultButton(title: "Met it", isSelected: true) {}
                                    IntentionResultButton(title: "Not quite", isSelected: false) {}
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(STSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: STRadius.md)
                                .fill(STColors.primaryLight.opacity(0.5))
                        )

                        // Mood
                        VStack(alignment: .leading, spacing: STSpacing.lg) {
                            if let mood = selectedMood {
                                Text(mood.response)
                                    .font(STTypography.bodyMedium())
                                    .foregroundColor(STColors.textSecondary)
                                    .multilineTextAlignment(.leading)
                            }

                            HStack(spacing: STSpacing.lg) {
                                ForEach(MoodRating.allCases, id: \.rawValue) { mood in
                                    MoodButton(
                                        mood: mood,
                                        isSelected: selectedMood == mood
                                    ) {
                                        selectedMood = mood
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }

                        STDivider()
                            .padding(.horizontal, STSpacing.md)

                        // Notes
                        VStack(alignment: .leading, spacing: STSpacing.sm) {
                            Text("Anything on your mind?")
                                .font(STTypography.bodyMedium())
                                .foregroundColor(STColors.textSecondary)

                            TextField("", text: .constant(""), axis: .vertical)
                                .font(STTypography.bodyMedium())
                                .foregroundColor(STColors.textPrimary)
                                .lineLimit(3...6)
                                .padding(STSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: STRadius.md)
                                        .fill(STColors.surface)
                                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: STRadius.md)
                                        .stroke(STColors.subtle, lineWidth: 1)
                                )
                        }

                        // Save button
                        Button {} label: {
                            Text("Save & Rest Well")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(STPrimaryButtonStyle())

                        Spacer(minLength: STSpacing.xxl)
                    }
                    .padding(.horizontal, STSpacing.lg)
                    .padding(.top, STSpacing.lg)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {}
                        .font(STTypography.bodyMedium())
                        .foregroundColor(STColors.textSecondary)
                }
            }
        }
    }
}

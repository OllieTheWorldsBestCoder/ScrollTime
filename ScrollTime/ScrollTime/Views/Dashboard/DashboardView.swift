import SwiftUI

// MARK: - Redesigned Dashboard View
// Claude-inspired: warm, minimal, thoughtful
// Integrates: Milestones, Insights, Intentions, Wind-Down, Weekly Report

struct DashboardView: View {
    @EnvironmentObject var interventionService: InterventionTriggerService
    @StateObject private var viewModel = DashboardViewModel()

    // Feature managers
    @State private var milestoneTracker = MilestoneTracker.shared
    @StateObject private var patternAnalyzer = PatternAnalyzer.shared
    @StateObject private var intentionManager = IntentionManager.shared
    @StateObject private var windDownManager = WindDownManager.shared

    // Navigation state
    @State private var showSettings = false
    @State private var showDemo = false
    @State private var showSessionHistory = false
    @State private var showWeeklyReport = false
    @State private var showEveningReflection = false
    @State private var showMorningIntention = false

    // Milestone celebration state
    @State private var celebratingMilestone: Milestone?

    // Appearance animation
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                STColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: STSpacing.xl) {
                        // Header greeting with weekly report button
                        headerSection
                            .padding(.top, STSpacing.md)

                        // Streak badge (if streak > 0)
                        if milestoneTracker.currentStreak.currentStreak > 0 {
                            streakBadge
                        }

                        // Wind-down active indicator
                        if windDownManager.isInWindDownMode {
                            WindDownActiveIndicator()
                                .padding(.horizontal, -STSpacing.lg)
                        }

                        // Today's focus card
                        todayCard

                        // Insights carousel (only if insights exist)
                        if !patternAnalyzer.currentInsights.isEmpty {
                            insightsSection
                        }

                        // Quick stats
                        statsSection

                        // Time reclaimed card
                        if milestoneTracker.totalHoursReclaimed > 0 {
                            timeReclaimedCard
                        }

                        // Recent activity
                        activitySection

                        // Demo mode section
                        demoSection

                        // Bottom spacing
                        Spacer(minLength: STSpacing.xxxl)
                    }
                    .padding(.horizontal, STSpacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showWeeklyReport = true
                    } label: {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(STColors.textSecondary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(STColors.textSecondary)
                    }
                }
            }
            // Settings sheet
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            // Weekly report sheet
            .sheet(isPresented: $showWeeklyReport) {
                WeeklyReportView()
            }
            // Morning intention sheet
            .sheet(isPresented: $showMorningIntention) {
                MorningIntentionSheet(intentionManager: intentionManager)
            }
            // Wind-down prompt sheet
            .sheet(isPresented: $windDownManager.showWindDownPrompt) {
                WindDownView()
            }
            // Evening reflection sheet
            .sheet(isPresented: $showEveningReflection) {
                EveningReflectionSheet()
            }
            // Navigation destinations
            .navigationDestination(isPresented: $showDemo) {
                DemoScrollView()
            }
            .navigationDestination(isPresented: $showSessionHistory) {
                SessionHistoryView()
            }
        }
        // Milestone celebration overlay
        .milestoneCelebration(milestone: $celebratingMilestone) {
            // Mark the milestone as celebrated when dismissed
            if let milestone = celebratingMilestone {
                milestoneTracker.markCelebrated(milestone)
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
            viewModel.refresh()

            // Check for pending milestone celebrations
            checkPendingCelebration()
        }
        .onChange(of: milestoneTracker.pendingCelebration?.id) { _, _ in
            if celebratingMilestone == nil {
                celebratingMilestone = milestoneTracker.pendingCelebration
            }
        }
        .onChange(of: intentionManager.showMorningPrompt) { _, shouldShow in
            if shouldShow {
                showMorningIntention = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Check prompts when app becomes active
            if intentionManager.showMorningPrompt && !showMorningIntention {
                showMorningIntention = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: STSpacing.xs) {
                Text(greeting)
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textTertiary)

                Text("Your mindful\nmoments today")
                    .font(STTypography.displayMedium())
                    .foregroundColor(STColors.textPrimary)
                    .lineSpacing(2)
            }

            Spacer()

            // Today's intention badge (if set)
            if let intention = intentionManager.todaysIntention {
                intentionBadge(intention)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    private func intentionBadge(_ intention: DailyIntention) -> some View {
        VStack(spacing: STSpacing.xxs) {
            Text(intention.intention.emoji)
                .font(.system(size: 20))

            Text(intention.intention.rawValue)
                .font(STTypography.caption())
                .foregroundColor(STColors.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, STSpacing.sm)
        .padding(.vertical, STSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: STRadius.md)
                .fill(STColors.primaryLight.opacity(0.5))
        )
    }

    // MARK: - Streak Badge

    private var streakBadge: some View {
        HStack(spacing: STSpacing.sm) {
            Image(systemName: milestoneTracker.currentStreak.symbolName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(STColors.success)

            Text(milestoneTracker.currentStreak.celebrationText)
                .font(STTypography.bodyMedium())
                .fontWeight(.medium)
                .foregroundColor(STColors.textPrimary)

            Spacer()

            if milestoneTracker.currentStreak.isPersonalBest {
                Text("Personal best!")
                    .font(STTypography.caption())
                    .foregroundColor(STColors.success)
                    .padding(.horizontal, STSpacing.xs)
                    .padding(.vertical, STSpacing.xxxs)
                    .background(
                        Capsule()
                            .fill(STColors.success.opacity(0.12))
                    )
            }
        }
        .padding(.horizontal, STSpacing.md)
        .padding(.vertical, STSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: STRadius.md)
                .fill(STColors.success.opacity(0.08))
        )
    }

    // MARK: - Today Card

    private var todayCard: some View {
        STCard {
            VStack(spacing: STSpacing.lg) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(STColors.subtle, lineWidth: 8)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: viewModel.goalProgress)
                        .stroke(
                            STColors.primary,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: viewModel.goalProgress)

                    VStack(spacing: 2) {
                        Text("\(Int(viewModel.goalProgress * 100))%")
                            .font(STTypography.titleLarge())
                            .foregroundColor(STColors.textPrimary)

                        Text("of goal")
                            .font(STTypography.caption())
                            .foregroundColor(STColors.textTertiary)
                    }
                }

                // Status message
                VStack(spacing: STSpacing.xxs) {
                    Text(viewModel.statusMessage)
                        .font(STTypography.bodyLarge())
                        .foregroundColor(STColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(viewModel.statusDetail)
                        .font(STTypography.bodySmall())
                        .foregroundColor(STColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(STSpacing.xl)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        InsightCarouselView(insights: patternAnalyzer.currentInsights) { insight in
            // Handle insight tap - could navigate to detail or show action
            if insight.actionSuggestion != nil {
                // For now, just log the tap
                // Future: Show insight detail sheet
            }
        }
        .padding(.horizontal, -STSpacing.lg) // Compensate for parent padding
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: STSpacing.md) {
            Text("Today's insights")
                .font(STTypography.titleSmall())
                .foregroundColor(STColors.textPrimary)

            HStack(spacing: STSpacing.sm) {
                StatCard(
                    value: "\(viewModel.todayStats.scrollSessionCount)",
                    label: "Sessions",
                    icon: "arrow.up.arrow.down"
                )

                StatCard(
                    value: viewModel.formattedScrollTime,
                    label: "Scroll time",
                    icon: "clock"
                )

                StatCard(
                    value: "\(viewModel.todayStats.interventionCount)",
                    label: "Pauses",
                    icon: "pause.circle"
                )
            }
        }
    }

    // MARK: - Time Reclaimed Card

    private var timeReclaimedCard: some View {
        VStack(alignment: .leading, spacing: STSpacing.md) {
            Text("Time reclaimed")
                .font(STTypography.titleSmall())
                .foregroundColor(STColors.textPrimary)

            STCard {
                HStack(spacing: STSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(STColors.success.opacity(0.12))
                            .frame(width: 48, height: 48)

                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(STColors.success)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(milestoneTracker.formattedHoursReclaimed)
                            .font(STTypography.titleMedium())
                            .foregroundColor(STColors.textPrimary)

                        Text("saved from mindless scrolling")
                            .font(STTypography.bodySmall())
                            .foregroundColor(STColors.textTertiary)
                    }

                    Spacer()
                }
                .padding(STSpacing.md)
            }
        }
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: STSpacing.md) {
            HStack {
                Text("Recent activity")
                    .font(STTypography.titleSmall())
                    .foregroundColor(STColors.textPrimary)

                Spacer()

                if !viewModel.recentSessions.isEmpty {
                    Button("See all") {
                        showSessionHistory = true
                    }
                    .font(STTypography.bodySmall())
                    .foregroundColor(STColors.primary)
                }
            }

            if viewModel.recentSessions.isEmpty {
                emptyActivityState
            } else {
                STCard {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.recentSessions.prefix(3).enumerated()), id: \.element.id) { index, session in
                            ActivityRow(session: session)

                            if index < min(2, viewModel.recentSessions.count - 1) {
                                STDivider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                    .padding(.vertical, STSpacing.xs)
                }
            }
        }
    }

    private var emptyActivityState: some View {
        STCard {
            VStack(spacing: STSpacing.md) {
                Image(systemName: "leaf")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(STColors.textTertiary)

                Text("No activity yet today")
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textSecondary)

                Text("We'll track your scroll sessions\nand help you stay mindful")
                    .font(STTypography.bodySmall())
                    .foregroundColor(STColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(STSpacing.xl)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Demo Section

    private var demoSection: some View {
        VStack(alignment: .leading, spacing: STSpacing.md) {
            Text("Try it out")
                .font(STTypography.titleSmall())
                .foregroundColor(STColors.textPrimary)

            STCard {
                VStack(spacing: STSpacing.md) {
                    HStack(spacing: STSpacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: STRadius.sm)
                                .fill(STColors.primaryLight)
                                .frame(width: 48, height: 48)

                            Image(systemName: "hand.draw")
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(STColors.primary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Demo Mode")
                                .font(STTypography.bodyMedium())
                                .fontWeight(.medium)
                                .foregroundColor(STColors.textPrimary)

                            Text("Experience scroll detection in action")
                                .font(STTypography.bodySmall())
                                .foregroundColor(STColors.textTertiary)
                        }

                        Spacer()
                    }

                    Button {
                        showDemo = true
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                            Text("Try Demo")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(STPrimaryButtonStyle())
                }
                .padding(STSpacing.md)
            }
        }
    }

    // MARK: - Helper Methods

    private func checkPendingCelebration() {
        // Check for pending milestone celebration after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let pending = milestoneTracker.pendingCelebration {
                celebratingMilestone = pending
            }
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        STCard {
            VStack(spacing: STSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(STColors.primary)

                Text(value)
                    .font(STTypography.titleMedium())
                    .foregroundColor(STColors.textPrimary)

                Text(label)
                    .font(STTypography.caption())
                    .foregroundColor(STColors.textTertiary)
            }
            .padding(.vertical, STSpacing.md)
            .padding(.horizontal, STSpacing.sm)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let session: ScrollSessionSummary

    var body: some View {
        HStack(spacing: STSpacing.md) {
            // App icon placeholder
            ZStack {
                RoundedRectangle(cornerRadius: STRadius.sm)
                    .fill(STColors.primaryLight)
                    .frame(width: 40, height: 40)

                Text(session.appName.prefix(1))
                    .font(STTypography.bodyMedium())
                    .fontWeight(.medium)
                    .foregroundColor(STColors.primary)
            }

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(session.appName)
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textPrimary)

                Text(session.formattedDuration)
                    .font(STTypography.bodySmall())
                    .foregroundColor(STColors.textTertiary)
            }

            Spacer()

            // Status indicator
            if session.interventionTriggered {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(STColors.primary)
            }
        }
        .padding(.horizontal, STSpacing.md)
        .padding(.vertical, STSpacing.sm)
    }
}

// MARK: - View Model

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var todayStats: DailyStats = .sample
    @Published var recentSessions: [ScrollSessionSummary] = []
    @Published var goalProgress: Double = 0

    var formattedScrollTime: String {
        let minutes = todayStats.totalScrollTimeSeconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }

    var statusMessage: String {
        if goalProgress >= 1.0 {
            return "Goal reached!"
        } else if goalProgress >= 0.8 {
            return "Almost there"
        } else if goalProgress >= 0.5 {
            return "Making progress"
        } else {
            return "Just getting started"
        }
    }

    var statusDetail: String {
        let remaining = max(0, 60 - (todayStats.totalScrollTimeSeconds / 60))
        if remaining == 0 {
            return "You've been wonderfully mindful today"
        } else {
            return "\(remaining) minutes until your daily goal"
        }
    }

    func refresh() {
        // Load real data from StatsProvider
        let statsProvider = StatsProvider.shared
        todayStats = statsProvider.todayStats

        // Calculate progress (inverted - less scroll time = more progress)
        let goalMinutes = Double(statsProvider.dailyGoalMinutes)
        let usedMinutes = Double(todayStats.totalScrollTimeSeconds) / 60.0
        goalProgress = min(1.0, max(0, 1.0 - (usedMinutes / goalMinutes)))

        // Convert persisted sessions to summaries for display
        recentSessions = statsProvider.recentSessions.prefix(5).map { session in
            ScrollSessionSummary(
                appBundleID: session.appBundleId,
                startTime: session.startTime,
                endTime: session.endTime,
                totalScrollCount: session.scrollCount,
                wasDoomScrolling: session.wasDoomScrolling
            )
        }

        // If no real data yet, show empty state (no fake sample data)
        if todayStats.scrollSessionCount == 0 && recentSessions.isEmpty {
            // Keep empty - will show "No activity yet" UI
        }

        // Trigger pattern analysis
        Task {
            await PatternAnalyzer.shared.analyzePatterns()
        }

        // Check milestones
        MilestoneTracker.shared.checkMilestones()

        // Check morning prompt
        IntentionManager.shared.checkMorningPrompt()
    }

    /// Trigger the evening reflection prompt
    func showEveningReflection() -> Bool {
        // Check if it's evening (after 8 PM)
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 20 || hour < 2
    }
}

// MARK: - Morning Intention Sheet

/// Sheet wrapper for morning intention view
private struct MorningIntentionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var intentionManager: IntentionManager

    @State private var appeared = false
    @State private var selectedIntention: IntentionType?
    @State private var showingConfirmation = false
    @State private var confirmationScale: CGFloat = 0.8

    var body: some View {
        ZStack {
            STColors.background.ignoresSafeArea()

            if showingConfirmation, let selected = selectedIntention {
                confirmationOverlay(for: selected)
            } else {
                mainContent
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: STSpacing.xxxl)

            // Greeting
            Text(greeting)
                .font(STTypography.displayMedium())
                .foregroundColor(STColors.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.1), value: appeared)

            Spacer()
                .frame(height: STSpacing.xxl)

            // Question
            Text("What would make today\nfeel meaningful?")
                .font(STTypography.titleLarge())
                .foregroundColor(STColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: appeared)

            Spacer()
                .frame(height: STSpacing.xl)

            // Intention cards
            VStack(spacing: STSpacing.sm) {
                ForEach(Array(IntentionType.allCases.enumerated()), id: \.element) { index, intention in
                    IntentionCardButton(intention: intention) {
                        selectIntention(intention)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.8)
                        .delay(0.2 + Double(index) * 0.05),
                        value: appeared
                    )
                }
            }

            Spacer()

            // Skip button
            Button {
                skipForToday()
            } label: {
                Text("Skip for today")
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textTertiary)
                    .padding(.vertical, STSpacing.md)
                    .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)

            Spacer()
                .frame(height: STSpacing.xl)
        }
        .padding(.horizontal, STSpacing.lg)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Hello"
        }
    }

    private func confirmationOverlay(for intention: IntentionType) -> some View {
        VStack(spacing: STSpacing.xl) {
            Text(intention.emoji)
                .font(.system(size: 72))
                .scaleEffect(confirmationScale)

            Text(intention.encouragement)
                .font(STTypography.titleMedium())
                .foregroundColor(STColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, STSpacing.xl)
                .opacity(confirmationScale == 1 ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                confirmationScale = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeOut(duration: 0.3)) {
                    appeared = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
        }
    }

    private func selectIntention(_ intention: IntentionType) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        selectedIntention = intention
        intentionManager.setIntention(intention)

        withAnimation(.easeInOut(duration: 0.3)) {
            showingConfirmation = true
        }
    }

    private func skipForToday() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        intentionManager.dismissMorningPrompt()

        withAnimation(.easeOut(duration: 0.3)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

// MARK: - Intention Card Button

private struct IntentionCardButton: View {
    let intention: IntentionType
    let onSelect: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: STSpacing.md) {
                Text(intention.emoji)
                    .font(.system(size: 24))

                Text(intention.rawValue)
                    .font(STTypography.bodyLarge())
                    .foregroundColor(STColors.textPrimary)

                Spacer()
            }
            .padding(.horizontal, STSpacing.lg)
            .padding(.vertical, STSpacing.md + STSpacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: STRadius.lg)
                    .fill(STColors.surface)
                    .shadow(
                        color: Color.black.opacity(isPressed ? 0.02 : 0.04),
                        radius: isPressed ? 4 : 8,
                        x: 0,
                        y: isPressed ? 1 : 2
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Evening Reflection Sheet

/// Sheet wrapper for evening reflection view
private struct EveningReflectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMood: MoodRating?
    @State private var noteText: String = ""
    @State private var intentionMet: Bool? = nil
    @State private var isSaving: Bool = false
    @State private var showSavedConfirmation: Bool = false
    @State private var todayStats: DailyStats = .empty
    @State private var todayIntention: DailyIntention?
    @State private var dailyGoalMinutes: Int = 60

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

    var body: some View {
        NavigationStack {
            ZStack {
                STColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: STSpacing.xl) {
                        headerSection
                        statsSection

                        if todayIntention != nil {
                            intentionSection
                        }

                        moodSection

                        STDivider()
                            .padding(.horizontal, STSpacing.md)

                        notesSection
                        saveButton

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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: STSpacing.xs) {
            Text("How was today?")
                .font(STTypography.displayMedium())
                .foregroundColor(STColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

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

            VStack(alignment: .leading, spacing: STSpacing.sm) {
                Text("How did it go?")
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textSecondary)

                HStack(spacing: STSpacing.sm) {
                    ReflectionResultButton(title: "Met it", isSelected: intentionMet == true) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            intentionMet = true
                        }
                    }

                    ReflectionResultButton(title: "Not quite", isSelected: intentionMet == false) {
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

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: STSpacing.lg) {
            if let mood = selectedMood {
                Text(mood.response)
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: STSpacing.lg) {
                ForEach(MoodRating.allCases, id: \.rawValue) { mood in
                    ReflectionMoodButton(mood: mood, isSelected: selectedMood == mood) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMood = mood
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

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

    private func loadData() {
        let statsProvider = StatsProvider.shared
        todayStats = statsProvider.todayStats
        dailyGoalMinutes = statsProvider.dailyGoalMinutes
        todayIntention = IntentionManager.shared.todaysIntention
    }

    private func saveReflection() {
        guard let mood = selectedMood else { return }

        isSaving = true

        let reflection = EveningReflection(
            mood: mood,
            note: noteText.isEmpty ? nil : noteText.trimmingCharacters(in: .whitespacesAndNewlines),
            scrollTimeMinutes: scrollTimeMinutes,
            goalMinutes: dailyGoalMinutes,
            intentionMet: intentionMet
        )

        saveReflectionToStorage(reflection)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isSaving = false
            showSavedConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }

    private func saveReflectionToStorage(_ reflection: EveningReflection) {
        let key = "com.scrolltime.eveningReflections"
        var reflections = loadAllReflections()

        let todayStart = Calendar.current.startOfDay(for: Date())
        reflections.removeAll { Calendar.current.isDate($0.date, inSameDayAs: todayStart) }
        reflections.append(reflection)

        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        reflections = reflections.filter { $0.date >= cutoff }
        reflections.sort { $0.date > $1.date }

        if let data = try? JSONEncoder().encode(reflections) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadAllReflections() -> [EveningReflection] {
        let key = "com.scrolltime.eveningReflections"
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([EveningReflection].self, from: data)) ?? []
    }
}

// MARK: - Reflection Mood Button

private struct ReflectionMoodButton: View {
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Reflection Result Button

private struct ReflectionResultButton: View {
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

#Preview {
    DashboardView()
        .environmentObject(InterventionTriggerService())
}

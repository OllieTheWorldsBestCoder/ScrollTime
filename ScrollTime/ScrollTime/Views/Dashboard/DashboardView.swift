import SwiftUI

// MARK: - Redesigned Dashboard View
// Claude-inspired: warm, minimal, thoughtful

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showSettings = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                STColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: STSpacing.xl) {
                        // Header greeting
                        headerSection
                            .padding(.top, STSpacing.md)

                        // Today's focus card
                        todayCard

                        // Quick stats
                        statsSection

                        // Recent activity
                        activitySection

                        // Bottom spacing
                        Spacer(minLength: STSpacing.xxxl)
                    }
                    .padding(.horizontal, STSpacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
            viewModel.refresh()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: STSpacing.xs) {
            Text(greeting)
                .font(STTypography.bodyMedium())
                .foregroundColor(STColors.textTertiary)

            Text("Your mindful\nmoments today")
                .font(STTypography.displayMedium())
                .foregroundColor(STColors.textPrimary)
                .lineSpacing(2)
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
                        // Navigate to full history
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
        // Load real data in production
        todayStats = DailyStats.sample

        // Calculate progress (inverted - less scroll time = more progress)
        let goalMinutes = 60.0
        let usedMinutes = Double(todayStats.totalScrollTimeSeconds) / 60.0
        goalProgress = min(1.0, max(0, 1.0 - (usedMinutes / goalMinutes)))

        // Sample sessions
        recentSessions = [
            ScrollSessionSummary(
                appBundleID: "com.instagram.Instagram",
                startTime: Date().addingTimeInterval(-600),
                endTime: Date().addingTimeInterval(-300),
                totalScrollCount: 45,
                wasDoomScrolling: true
            ),
            ScrollSessionSummary(
                appBundleID: "com.twitter.Twitter",
                startTime: Date().addingTimeInterval(-1800),
                endTime: Date().addingTimeInterval(-1500),
                totalScrollCount: 30,
                wasDoomScrolling: false
            )
        ]
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
}

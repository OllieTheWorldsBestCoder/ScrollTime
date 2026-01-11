//
//  SessionHistoryView.swift
//  ScrollTime
//
//  Displays all scroll sessions grouped by day with pull-to-refresh.
//  Follows the Claude-inspired minimal aesthetic.
//

import SwiftUI

// MARK: - Session History View

/// Shows all scroll sessions grouped by day (Today, Yesterday, etc.)
struct SessionHistoryView: View {
    @State private var sessions: [PersistedScrollSession] = []
    @State private var isLoading = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            STColors.background.ignoresSafeArea()

            if sessions.isEmpty && !isLoading {
                emptyState
            } else {
                sessionList
            }
        }
        .navigationTitle("Session History")
        .navigationBarTitleDisplayMode(.large)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
            loadSessions()
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: STSpacing.lg, pinnedViews: .sectionHeaders) {
                ForEach(groupedSessions.keys.sorted(by: >), id: \.self) { dateKey in
                    Section {
                        sessionGroup(for: dateKey)
                    } header: {
                        sectionHeader(for: dateKey)
                    }
                }

                // Bottom padding
                Spacer(minLength: STSpacing.xxxl)
            }
            .padding(.horizontal, STSpacing.lg)
            .padding(.top, STSpacing.md)
        }
        .refreshable {
            await refreshSessions()
        }
    }

    // MARK: - Section Header

    private func sectionHeader(for date: Date) -> some View {
        HStack {
            Text(formatSectionTitle(for: date))
                .font(STTypography.titleSmall())
                .foregroundColor(STColors.textPrimary)

            Spacer()

            Text(sessionCountText(for: date))
                .font(STTypography.caption())
                .foregroundColor(STColors.textTertiary)
        }
        .padding(.vertical, STSpacing.xs)
        .padding(.horizontal, STSpacing.xxs)
        .background(STColors.background)
    }

    // MARK: - Session Group

    private func sessionGroup(for dateKey: Date) -> some View {
        STCard {
            VStack(spacing: 0) {
                let daySessions = groupedSessions[dateKey] ?? []
                ForEach(Array(daySessions.enumerated()), id: \.element.id) { index, session in
                    SessionRowView(session: session)

                    if index < daySessions.count - 1 {
                        STDivider()
                            .padding(.leading, 68)
                    }
                }
            }
            .padding(.vertical, STSpacing.xs)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: STSpacing.lg) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundColor(STColors.textTertiary)

            VStack(spacing: STSpacing.xs) {
                Text("No sessions yet")
                    .font(STTypography.titleMedium())
                    .foregroundColor(STColors.textPrimary)

                Text("Your scroll sessions will appear here\nas you use your apps")
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(STSpacing.xl)
    }

    // MARK: - Grouped Sessions

    private var groupedSessions: [Date: [PersistedScrollSession]] {
        Dictionary(grouping: sessions) { session in
            Calendar.current.startOfDay(for: session.startTime)
        }
    }

    // MARK: - Section Title Formatting

    private func formatSectionTitle(for date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if isDateInCurrentWeek(date) {
            // Day name for this week (Monday, Tuesday, etc.)
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else if isDateInLastWeek(date) {
            return "Last week"
        } else {
            // Full date for older sessions
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    private func sessionCountText(for date: Date) -> String {
        let count = groupedSessions[date]?.count ?? 0
        return count == 1 ? "1 session" : "\(count) sessions"
    }

    private func isDateInCurrentWeek(_ date: Date) -> Bool {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return false
        }
        return date >= weekStart
    }

    private func isDateInLastWeek(_ date: Date) -> Bool {
        let calendar = Calendar.current
        guard let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())),
              let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) else {
            return false
        }
        return date >= lastWeekStart && date < thisWeekStart
    }

    // MARK: - Data Loading

    private func loadSessions() {
        isLoading = true
        sessions = StatsProvider.shared.recentSessions
        isLoading = false
    }

    private func refreshSessions() async {
        await StatsProvider.shared.refreshAll()
        sessions = StatsProvider.shared.recentSessions
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionHistoryView()
    }
}

// MARK: - Preview with Sample Data

#Preview("With Sessions") {
    NavigationStack {
        SessionHistoryViewPreview()
    }
}

/// A preview wrapper that injects sample data
private struct SessionHistoryViewPreview: View {
    @State private var sessions: [PersistedScrollSession] = PersistedScrollSession.sampleDay + createOlderSessions()

    var body: some View {
        SessionHistoryViewWithData(sessions: sessions)
    }

    private static func createOlderSessions() -> [PersistedScrollSession] {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        return [
            PersistedScrollSession(
                appBundleId: "com.instagram.app",
                appName: "Instagram",
                startTime: yesterday.addingTimeInterval(-7200),
                endTime: yesterday.addingTimeInterval(-5400),
                scrollCount: 180,
                wasDoomScrolling: true,
                interventionShown: true,
                interventionType: .gentleReminder,
                interventionResult: .tookBreak
            ),
            PersistedScrollSession(
                appBundleId: "com.reddit.app",
                appName: "Reddit",
                startTime: yesterday.addingTimeInterval(-3600),
                endTime: yesterday.addingTimeInterval(-2700),
                scrollCount: 95,
                wasDoomScrolling: false
            )
        ]
    }
}

/// Version of SessionHistoryView that accepts sessions directly for previews
private struct SessionHistoryViewWithData: View {
    let sessions: [PersistedScrollSession]

    var body: some View {
        ZStack {
            STColors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: STSpacing.lg, pinnedViews: .sectionHeaders) {
                    ForEach(groupedSessions.keys.sorted(by: >), id: \.self) { dateKey in
                        Section {
                            sessionGroup(for: dateKey)
                        } header: {
                            sectionHeader(for: dateKey)
                        }
                    }

                    Spacer(minLength: STSpacing.xxxl)
                }
                .padding(.horizontal, STSpacing.lg)
                .padding(.top, STSpacing.md)
            }
        }
        .navigationTitle("Session History")
        .navigationBarTitleDisplayMode(.large)
    }

    private var groupedSessions: [Date: [PersistedScrollSession]] {
        Dictionary(grouping: sessions) { session in
            Calendar.current.startOfDay(for: session.startTime)
        }
    }

    private func sectionHeader(for date: Date) -> some View {
        HStack {
            Text(formatSectionTitle(for: date))
                .font(STTypography.titleSmall())
                .foregroundColor(STColors.textPrimary)

            Spacer()

            let count = groupedSessions[date]?.count ?? 0
            Text(count == 1 ? "1 session" : "\(count) sessions")
                .font(STTypography.caption())
                .foregroundColor(STColors.textTertiary)
        }
        .padding(.vertical, STSpacing.xs)
        .padding(.horizontal, STSpacing.xxs)
        .background(STColors.background)
    }

    private func sessionGroup(for dateKey: Date) -> some View {
        STCard {
            VStack(spacing: 0) {
                let daySessions = groupedSessions[dateKey] ?? []
                ForEach(Array(daySessions.enumerated()), id: \.element.id) { index, session in
                    SessionRowView(session: session)

                    if index < daySessions.count - 1 {
                        STDivider()
                            .padding(.leading, 68)
                    }
                }
            }
            .padding(.vertical, STSpacing.xs)
        }
    }

    private func formatSectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
    }
}

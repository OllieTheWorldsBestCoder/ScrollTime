//
//  WeeklyReportView.swift
//  ScrollTime
//
//  A comprehensive weekly insights view showing scroll patterns,
//  interventions, and usage trends in a warm, encouraging format.
//

import SwiftUI

// MARK: - Weekly Report View

/// Displays a comprehensive weekly report with scroll time, daily breakdown,
/// intervention metrics, and usage patterns.
struct WeeklyReportView: View {
    @StateObject private var viewModel = WeeklyReportViewModel()
    @State private var appeared = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                STColors.background.ignoresSafeArea()

                if viewModel.isLoading {
                    loadingState
                } else if let report = viewModel.report {
                    reportContent(report)
                } else {
                    emptyState
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.primary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.report != nil {
                        ShareLink(
                            item: viewModel.shareText,
                            subject: Text("My Weekly ScrollTime Report"),
                            message: Text(viewModel.shareText)
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(STColors.textSecondary)
                        }
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
            viewModel.loadReport()
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: STSpacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(STColors.primary)

            Text("Generating your report...")
                .font(STTypography.bodyMedium())
                .foregroundColor(STColors.textSecondary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: STSpacing.lg) {
            Spacer()

            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundColor(STColors.textTertiary)

            VStack(spacing: STSpacing.xs) {
                Text("No data yet")
                    .font(STTypography.titleMedium())
                    .foregroundColor(STColors.textPrimary)

                Text("Use ScrollTime for a week\nto see your insights")
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(STSpacing.xl)
    }

    // MARK: - Report Content

    private func reportContent(_ report: WeeklyReport) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: STSpacing.xl) {
                // Header with week date range
                headerSection(report)
                    .padding(.top, STSpacing.md)

                // Hero card with total time
                heroCard(report)

                // Daily breakdown chart
                dailyBreakdownSection(report)

                // Best day celebration
                bestDaySection(report)

                // Time reclaimed section
                timeReclaimedSection(report)

                // Top apps list
                topAppsSection(report)

                // Peak usage pattern
                patternSection(report)

                // Bottom spacing
                Spacer(minLength: STSpacing.xxxl)
            }
            .padding(.horizontal, STSpacing.lg)
        }
    }

    // MARK: - Header Section

    private func headerSection(_ report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: STSpacing.xs) {
            Text("Your Week in Review")
                .font(STTypography.bodyMedium())
                .foregroundColor(STColors.textTertiary)

            Text(formatWeekRange(report))
                .font(STTypography.displayMedium())
                .foregroundColor(STColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatWeekRange(_ report: WeeklyReport) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: report.weekStartDate)
        let end = formatter.string(from: report.weekEndDate)
        return "\(start) - \(end)"
    }

    // MARK: - Hero Card

    private func heroCard(_ report: WeeklyReport) -> some View {
        STCard {
            VStack(spacing: STSpacing.lg) {
                // Total time display
                VStack(spacing: STSpacing.xxs) {
                    Text(report.formattedTotalTime)
                        .font(.system(size: 56, weight: .light, design: .serif))
                        .foregroundColor(STColors.textPrimary)

                    Text("total scroll time")
                        .font(STTypography.bodyMedium())
                        .foregroundColor(STColors.textTertiary)
                }

                // Comparison badge
                comparisonBadge(report)

                // Summary message
                Text(report.summaryMessage)
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(STSpacing.xl)
            .frame(maxWidth: .infinity)
        }
    }

    private func comparisonBadge(_ report: WeeklyReport) -> some View {
        HStack(spacing: STSpacing.xs) {
            Image(systemName: report.isImproving ? "arrow.down.right" : "arrow.up.right")
                .font(.system(size: 12, weight: .medium))

            Text(report.formattedScrollTimeChange)
                .font(STTypography.bodySmall())
                .fontWeight(.medium)
        }
        .foregroundColor(report.isImproving ? STColors.success : STColors.warning)
        .padding(.horizontal, STSpacing.sm)
        .padding(.vertical, STSpacing.xs)
        .background(
            Capsule()
                .fill((report.isImproving ? STColors.success : STColors.warning).opacity(0.12))
        )
    }

    // MARK: - Daily Breakdown Section

    private func dailyBreakdownSection(_ report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: STSpacing.md) {
            Text("Daily breakdown")
                .font(STTypography.titleSmall())
                .foregroundColor(STColors.textPrimary)

            STCard {
                DailyBreakdownChart(dailyData: report.dailyBreakdown)
                    .padding(STSpacing.md)
            }
        }
    }

    // MARK: - Best Day Section

    private func bestDaySection(_ report: WeeklyReport) -> some View {
        STCard {
            HStack(spacing: STSpacing.md) {
                ZStack {
                    Circle()
                        .fill(STColors.success.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: "star.fill")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(STColors.success)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Best day: \(formatDayName(report.bestDay))")
                        .font(STTypography.bodyMedium())
                        .fontWeight(.medium)
                        .foregroundColor(STColors.textPrimary)

                    Text("Only \(formatDuration(report.bestDayDuration)) of scrolling")
                        .font(STTypography.bodySmall())
                        .foregroundColor(STColors.textTertiary)
                }

                Spacer()
            }
            .padding(STSpacing.md)
        }
    }

    private func formatDayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Time Reclaimed Section

    private func timeReclaimedSection(_ report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: STSpacing.md) {
            Text("Time reclaimed")
                .font(STTypography.titleSmall())
                .foregroundColor(STColors.textPrimary)

            HStack(spacing: STSpacing.sm) {
                timeReclaimedCard(
                    value: "\(report.interventionsCompleted)",
                    label: "Pauses taken",
                    icon: "pause.circle"
                )

                timeReclaimedCard(
                    value: estimatedHoursSaved(report),
                    label: "Hours saved",
                    icon: "clock.badge.checkmark"
                )
            }
        }
    }

    private func timeReclaimedCard(value: String, label: String, icon: String) -> some View {
        STCard {
            VStack(spacing: STSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(STColors.primary)

                Text(value)
                    .font(STTypography.titleLarge())
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

    private func estimatedHoursSaved(_ report: WeeklyReport) -> String {
        // Estimate 10 minutes saved per completed intervention
        let minutesSaved = report.interventionsCompleted * 10
        if minutesSaved >= 60 {
            let hours = minutesSaved / 60
            let mins = minutesSaved % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(minutesSaved)m"
    }

    // MARK: - Top Apps Section

    private func topAppsSection(_ report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: STSpacing.md) {
            Text("Top apps")
                .font(STTypography.titleSmall())
                .foregroundColor(STColors.textPrimary)

            STCard {
                VStack(spacing: 0) {
                    ForEach(Array(report.topApps.prefix(4).enumerated()), id: \.element.id) { index, app in
                        AppUsageRow(app: app, rank: index + 1)

                        if index < min(3, report.topApps.count - 1) {
                            STDivider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .padding(.vertical, STSpacing.xs)
            }
        }
    }

    // MARK: - Pattern Section

    private func patternSection(_ report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: STSpacing.md) {
            Text("Your pattern")
                .font(STTypography.titleSmall())
                .foregroundColor(STColors.textPrimary)

            STCard {
                VStack(alignment: .leading, spacing: STSpacing.md) {
                    HStack(spacing: STSpacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: STRadius.sm)
                                .fill(STColors.primaryLight)
                                .frame(width: 48, height: 48)

                            Image(systemName: "clock")
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(STColors.primary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Peak usage at \(report.formattedPeakHour)")
                                .font(STTypography.bodyMedium())
                                .fontWeight(.medium)
                                .foregroundColor(STColors.textPrimary)

                            Text("This is when you scroll most")
                                .font(STTypography.bodySmall())
                                .foregroundColor(STColors.textTertiary)
                        }

                        Spacer()
                    }

                    // Tip based on peak hour
                    tipView(for: report.peakScrollHour)
                }
                .padding(STSpacing.md)
            }
        }
    }

    private func tipView(for hour: Int) -> some View {
        let tip = tipForHour(hour)

        return HStack(alignment: .top, spacing: STSpacing.sm) {
            Image(systemName: "lightbulb")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(STColors.warning)

            Text(tip)
                .font(STTypography.bodySmall())
                .foregroundColor(STColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(STSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: STRadius.sm)
                .fill(STColors.warning.opacity(0.08))
        )
    }

    private func tipForHour(_ hour: Int) -> String {
        switch hour {
        case 6..<9:
            return "Try a morning routine without your phone for the first 30 minutes"
        case 9..<12:
            return "Consider a focused work block during these hours"
        case 12..<14:
            return "Try mindful eating without screens during lunch"
        case 14..<18:
            return "Set an afternoon focus timer to stay on track"
        case 18..<21:
            return "Wind down with a book or conversation instead"
        case 21..<24:
            return "Evening scrolling can affect sleep. Try a wind-down routine"
        default:
            return "Late-night scrolling disrupts sleep. Consider a bedtime boundary"
        }
    }
}

// MARK: - Daily Breakdown Chart

private struct DailyBreakdownChart: View {
    let dailyData: [DailyScrollData]

    private var maxDuration: TimeInterval {
        dailyData.map { $0.totalDuration }.max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: STSpacing.sm) {
            ForEach(dailyData) { day in
                DayBarView(
                    day: day,
                    maxDuration: maxDuration
                )
            }
        }
        .frame(height: 140)
    }
}

private struct DayBarView: View {
    let day: DailyScrollData
    let maxDuration: TimeInterval

    @State private var animatedHeight: CGFloat = 0

    private var barHeight: CGFloat {
        guard maxDuration > 0 else { return 0 }
        let ratio = day.totalDuration / maxDuration
        return CGFloat(ratio) * 80 // Max bar height
    }

    private var dayInitial: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE" // Single letter day
        return formatter.string(from: day.date)
    }

    var body: some View {
        VStack(spacing: STSpacing.xs) {
            // Duration label
            Text(day.formattedDuration)
                .font(STTypography.caption())
                .foregroundColor(STColors.textTertiary)
                .frame(height: 16)

            // Bar
            RoundedRectangle(cornerRadius: STRadius.sm)
                .fill(day.isLowActivity ? STColors.success : STColors.primary)
                .frame(height: animatedHeight)
                .frame(maxWidth: .infinity)

            // Day label
            Text(dayInitial)
                .font(STTypography.label())
                .foregroundColor(STColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                animatedHeight = max(barHeight, 4) // Minimum visible height
            }
        }
    }
}

// MARK: - App Usage Row

private struct AppUsageRow: View {
    let app: AppUsageSummary
    let rank: Int

    var body: some View {
        HStack(spacing: STSpacing.md) {
            // Rank badge
            ZStack {
                RoundedRectangle(cornerRadius: STRadius.sm)
                    .fill(rankColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                Text("\(rank)")
                    .font(STTypography.bodyMedium())
                    .fontWeight(.semibold)
                    .foregroundColor(rankColor)
            }

            // App name
            VStack(alignment: .leading, spacing: 2) {
                Text(app.appName)
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textPrimary)

                Text(app.formattedDuration)
                    .font(STTypography.bodySmall())
                    .foregroundColor(STColors.textTertiary)
            }

            Spacer()

            // Progress bar
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(STColors.subtle)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(rankColor)
                            .frame(width: barWidth(for: geometry.size.width))
                    }
            }
            .frame(width: 60, height: 4)
        }
        .padding(.horizontal, STSpacing.md)
        .padding(.vertical, STSpacing.sm)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return STColors.primary
        case 2: return STColors.warning
        case 3: return STColors.success
        default: return STColors.textTertiary
        }
    }

    private func barWidth(for totalWidth: CGFloat) -> CGFloat {
        // First app is always 100%, others scale proportionally
        let maxRatio = 1.0 - (Double(rank - 1) * 0.2)
        return totalWidth * CGFloat(max(0.2, maxRatio))
    }
}

// MARK: - View Model

@MainActor
class WeeklyReportViewModel: ObservableObject {
    @Published var report: WeeklyReport?
    @Published var isLoading = false

    private let reportGenerator: ReportGenerator

    init(reportGenerator: ReportGenerator = .shared) {
        self.reportGenerator = reportGenerator
    }

    var shareText: String {
        guard let report = report else { return "" }

        return """
        My ScrollTime Weekly Report
        \(formatWeekRange(report))

        Total scroll time: \(report.formattedTotalTime)
        \(report.formattedScrollTimeChange) vs last week

        Pauses taken: \(report.interventionsCompleted)
        Best day: \(formatDayName(report.bestDay))

        \(report.summaryMessage)

        #ScrollTime #DigitalWellness
        """
    }

    func loadReport() {
        isLoading = true

        Task {
            // Generate fresh report from actual tracked data
            await reportGenerator.generateReports()

            // Get the current week's report
            let generatedReport = reportGenerator.currentWeekReport

            // Only show report if there's meaningful data (at least one session)
            // Otherwise, leave report as nil to show empty state
            if let generated = generatedReport, generated.dailyBreakdown.contains(where: { $0.sessionCount > 0 }) {
                self.report = generated
            } else {
                self.report = nil
            }

            self.isLoading = false
        }
    }

    private func formatWeekRange(_ report: WeeklyReport) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: report.weekStartDate)
        let end = formatter.string(from: report.weekEndDate)
        return "\(start) - \(end)"
    }

    private func formatDayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Previews

#Preview("Weekly Report") {
    WeeklyReportView()
}

#Preview("Loading State") {
    WeeklyReportViewPreview(showLoading: true)
}

#Preview("Empty State") {
    WeeklyReportViewPreview(showEmpty: true)
}

/// Preview wrapper for different states
private struct WeeklyReportViewPreview: View {
    let showLoading: Bool
    let showEmpty: Bool

    init(showLoading: Bool = false, showEmpty: Bool = false) {
        self.showLoading = showLoading
        self.showEmpty = showEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                STColors.background.ignoresSafeArea()

                if showLoading {
                    loadingState
                } else if showEmpty {
                    emptyState
                } else {
                    reportContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { }
                        .font(STTypography.bodyMedium())
                        .foregroundColor(STColors.primary)
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: STSpacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(STColors.primary)

            Text("Generating your report...")
                .font(STTypography.bodyMedium())
                .foregroundColor(STColors.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: STSpacing.lg) {
            Spacer()

            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundColor(STColors.textTertiary)

            VStack(spacing: STSpacing.xs) {
                Text("No data yet")
                    .font(STTypography.titleMedium())
                    .foregroundColor(STColors.textPrimary)

                Text("Use ScrollTime for a week\nto see your insights")
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(STSpacing.xl)
    }

    private var reportContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: STSpacing.xl) {
                Text("Report content preview")
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textSecondary)
            }
            .padding(STSpacing.lg)
        }
    }
}

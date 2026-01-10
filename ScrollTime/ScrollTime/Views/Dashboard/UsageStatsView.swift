import SwiftUI

/// Detailed usage statistics view with daily/weekly data and trend visualization
struct UsageStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = UsageStatsViewModel()
    @State private var selectedTimeRange: TimeRange = .week

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Range Picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Trend Chart
                    TrendChartView(
                        data: viewModel.chartData(for: selectedTimeRange),
                        timeRange: selectedTimeRange
                    )
                    .frame(height: 200)
                    .padding(.horizontal)

                    // Summary Stats
                    SummaryStatsSection(viewModel: viewModel, timeRange: selectedTimeRange)

                    // Intervention Success
                    InterventionSuccessCard(
                        successRate: viewModel.overallSuccessRate,
                        totalInterventions: viewModel.totalInterventions
                    )

                    // App Breakdown
                    AppBreakdownSection(appUsage: viewModel.appUsage)

                    // Daily Breakdown (for week view)
                    if selectedTimeRange == .week {
                        DailyBreakdownSection(dailyStats: viewModel.weeklyStats)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Usage Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Time Range

enum TimeRange: String, CaseIterable, Identifiable {
    case today
    case week
    case month

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}

// MARK: - Trend Chart View

private struct TrendChartView: View {
    let data: [ChartDataPoint]
    let timeRange: TimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scroll Time Trend")
                .font(.headline)

            GeometryReader { geometry in
                if data.isEmpty {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.line.downtrend.xyaxis",
                        description: Text("Start monitoring to see your trends")
                    )
                } else {
                    ChartContent(data: data, size: geometry.size)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct ChartContent: View {
    let data: [ChartDataPoint]
    let size: CGSize

    private var maxValue: Double {
        data.map(\.value).max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(data) { point in
                VStack(spacing: 4) {
                    Spacer()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor(for: point.value))
                        .frame(height: barHeight(for: point.value, maxHeight: size.height - 30))

                    Text(point.label)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barHeight(for value: Double, maxHeight: CGFloat) -> CGFloat {
        guard maxValue > 0 else { return 0 }
        return max(CGFloat(value / maxValue) * maxHeight, 4)
    }

    private func barColor(for value: Double) -> Color {
        let ratio = value / maxValue
        if ratio > 0.8 {
            return .red
        } else if ratio > 0.5 {
            return .orange
        }
        return .accentColor
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

// MARK: - Summary Stats Section

private struct SummaryStatsSection: View {
    let viewModel: UsageStatsViewModel
    let timeRange: TimeRange

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "Total Time",
                value: viewModel.totalTimeFormatted,
                icon: "clock.fill",
                color: .blue
            )

            StatCard(
                title: "Sessions",
                value: "\(viewModel.totalSessions)",
                icon: "arrow.up.arrow.down",
                color: .purple
            )

            StatCard(
                title: "Avg/Day",
                value: viewModel.averagePerDayFormatted,
                icon: "chart.bar.fill",
                color: .green
            )
        }
        .padding(.horizontal)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Intervention Success Card

private struct InterventionSuccessCard: View {
    let successRate: Double
    let totalInterventions: Int

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Intervention Success")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 24) {
                // Success Rate Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: successRate)
                        .stroke(
                            successRate > 0.5 ? Color.green : Color.orange,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8), value: successRate)

                    VStack(spacing: 2) {
                        Text("\(Int(successRate * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Success")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 12) {
                    InterventionStatRow(
                        label: "Total Interventions",
                        value: "\(totalInterventions)",
                        color: .blue
                    )

                    InterventionStatRow(
                        label: "You Stopped",
                        value: "\(Int(Double(totalInterventions) * successRate))",
                        color: .green
                    )

                    InterventionStatRow(
                        label: "You Continued",
                        value: "\(Int(Double(totalInterventions) * (1 - successRate)))",
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

private struct InterventionStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - App Breakdown Section

private struct AppBreakdownSection: View {
    let appUsage: [AppUsageRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Breakdown")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(appUsage) { usage in
                    AppUsageRow(usage: usage, maxTime: appUsage.first?.scrollTimeSeconds ?? 1)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}

private struct AppUsageRow: View {
    let usage: AppUsageRecord
    let maxTime: Int

    private var progress: Double {
        guard maxTime > 0 else { return 0 }
        return Double(usage.scrollTimeSeconds) / Double(maxTime)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(usage.appName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(usage.formattedTime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Daily Breakdown Section

private struct DailyBreakdownSection: View {
    let dailyStats: [DailyStats]

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Breakdown")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(dailyStats) { stats in
                    VStack(spacing: 0) {
                        HStack {
                            Text(dayFormatter.string(from: stats.date))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 40, alignment: .leading)

                            Text(stats.formattedTotalTime)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "hand.raised")
                                    .font(.caption2)
                                Text("\(stats.interventionCount)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12)

                        if stats.id != dailyStats.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}

// MARK: - Usage Stats ViewModel

@MainActor
class UsageStatsViewModel: ObservableObject {
    @Published var weeklyStats: [DailyStats] = []
    @Published var appUsage: [AppUsageRecord] = []

    var totalTimeFormatted: String {
        let totalSeconds = weeklyStats.reduce(0) { $0 + $1.totalScrollTimeSeconds }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var totalSessions: Int {
        weeklyStats.reduce(0) { $0 + $1.scrollSessionCount }
    }

    var averagePerDayFormatted: String {
        guard !weeklyStats.isEmpty else { return "0m" }
        let totalSeconds = weeklyStats.reduce(0) { $0 + $1.totalScrollTimeSeconds }
        let avgSeconds = totalSeconds / weeklyStats.count
        let minutes = avgSeconds / 60
        return "\(minutes)m"
    }

    var overallSuccessRate: Double {
        let totalInterventions = weeklyStats.reduce(0) { $0 + $1.interventionCount }
        let successfulInterventions = weeklyStats.reduce(0) { $0 + $1.successfulInterventions }
        guard totalInterventions > 0 else { return 0 }
        return Double(successfulInterventions) / Double(totalInterventions)
    }

    var totalInterventions: Int {
        weeklyStats.reduce(0) { $0 + $1.interventionCount }
    }

    init() {
        loadSampleData()
    }

    func chartData(for timeRange: TimeRange) -> [ChartDataPoint] {
        switch timeRange {
        case .today:
            return (0..<24).map { hour in
                ChartDataPoint(label: "\(hour)", value: Double.random(in: 0...30))
            }
        case .week:
            let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            return days.enumerated().map { index, day in
                ChartDataPoint(
                    label: day,
                    value: Double(weeklyStats[safe: index]?.totalScrollTimeSeconds ?? 0) / 60
                )
            }
        case .month:
            return (1...4).map { week in
                ChartDataPoint(label: "W\(week)", value: Double.random(in: 100...500))
            }
        }
    }

    private func loadSampleData() {
        let calendar = Calendar.current
        weeklyStats = (0..<7).map { daysAgo in
            DailyStats(
                date: calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date(),
                totalScrollTimeSeconds: Int.random(in: 1800...7200),
                scrollSessionCount: Int.random(in: 5...20),
                interventionCount: Int.random(in: 2...8),
                successfulInterventions: Int.random(in: 1...5),
                appUsage: []
            )
        }.reversed()

        appUsage = [
            AppUsageRecord(appName: "Instagram", bundleId: "com.instagram.app", scrollTimeSeconds: 5400),
            AppUsageRecord(appName: "TikTok", bundleId: "com.tiktok.app", scrollTimeSeconds: 4200),
            AppUsageRecord(appName: "Twitter", bundleId: "com.twitter.app", scrollTimeSeconds: 2700),
            AppUsageRecord(appName: "Reddit", bundleId: "com.reddit.app", scrollTimeSeconds: 1800)
        ]
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    UsageStatsView()
}

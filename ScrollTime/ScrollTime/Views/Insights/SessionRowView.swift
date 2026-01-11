//
//  SessionRowView.swift
//  ScrollTime
//
//  A reusable row component for displaying scroll session information.
//  Follows the Claude-inspired minimal aesthetic with warm colors.
//

import SwiftUI

// MARK: - Session Row View

/// A reusable row component for displaying a single scroll session.
/// Shows app name, time, duration, and intervention outcome.
struct SessionRowView: View {
    let session: PersistedScrollSession

    var body: some View {
        HStack(spacing: STSpacing.md) {
            // App icon - first letter
            appIcon

            // Session details
            VStack(alignment: .leading, spacing: STSpacing.xxxs) {
                Text(session.appName)
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textPrimary)

                HStack(spacing: STSpacing.xs) {
                    Text(formattedTime)
                        .font(STTypography.bodySmall())
                        .foregroundColor(STColors.textTertiary)

                    Text("·")
                        .font(STTypography.bodySmall())
                        .foregroundColor(STColors.textTertiary)

                    Text(session.formattedDuration)
                        .font(STTypography.bodySmall())
                        .foregroundColor(STColors.textTertiary)
                }
            }

            Spacer()

            // Intervention outcome indicator
            outcomeIndicator
        }
        .padding(.horizontal, STSpacing.md)
        .padding(.vertical, STSpacing.sm)
    }

    // MARK: - App Icon

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: STRadius.sm)
                .fill(STColors.primaryLight)
                .frame(width: 40, height: 40)

            Text(session.appName.prefix(1).uppercased())
                .font(STTypography.bodyMedium())
                .fontWeight(.medium)
                .foregroundColor(STColors.primary)
        }
    }

    // MARK: - Time Formatting

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: session.startTime)
    }

    // MARK: - Outcome Indicator

    @ViewBuilder
    private var outcomeIndicator: some View {
        if session.interventionShown {
            HStack(spacing: STSpacing.xxs) {
                outcomeIcon
                    .font(.system(size: 14))
                    .foregroundColor(outcomeColor)

                Text(outcomeText)
                    .font(STTypography.caption())
                    .foregroundColor(outcomeColor)
            }
            .padding(.horizontal, STSpacing.xs)
            .padding(.vertical, STSpacing.xxs)
            .background(
                Capsule()
                    .fill(outcomeColor.opacity(0.12))
            )
        } else if session.wasDoomScrolling {
            // Doom scrolling detected but no intervention (unusual case)
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 14))
                .foregroundColor(STColors.textTertiary)
        }
        // No indicator for normal sessions without interventions
    }

    private var outcomeIcon: Image {
        guard let result = session.interventionResult else {
            return Image(systemName: "questionmark.circle")
        }

        switch result {
        case .completed, .tookBreak:
            return Image(systemName: "checkmark.circle.fill")
        case .skipped:
            return Image(systemName: "forward.fill")
        case .continuedScrolling:
            return Image(systemName: "arrow.uturn.forward")
        case .timedOut:
            return Image(systemName: "clock")
        }
    }

    private var outcomeColor: Color {
        guard let result = session.interventionResult else {
            return STColors.textTertiary
        }

        switch result {
        case .completed, .tookBreak:
            return STColors.success
        case .skipped, .continuedScrolling, .timedOut:
            return STColors.textSecondary
        }
    }

    private var outcomeText: String {
        guard let result = session.interventionResult else {
            return "Pending"
        }

        switch result {
        case .completed:
            return "Completed"
        case .tookBreak:
            return "Took break"
        case .skipped:
            return "Skipped"
        case .continuedScrolling:
            return "Continued"
        case .timedOut:
            return "Timed out"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        SessionRowView(session: .sample)

        STDivider()
            .padding(.leading, 68)

        SessionRowView(session: PersistedScrollSession(
            appBundleId: "com.tiktok.app",
            appName: "TikTok",
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date().addingTimeInterval(-2400),
            scrollCount: 200,
            wasDoomScrolling: true,
            interventionShown: true,
            interventionType: .breathingExercise,
            interventionResult: .skipped
        ))

        STDivider()
            .padding(.leading, 68)

        SessionRowView(session: PersistedScrollSession(
            appBundleId: "com.twitter.app",
            appName: "Twitter",
            startTime: Date().addingTimeInterval(-7200),
            endTime: Date().addingTimeInterval(-6600),
            scrollCount: 80,
            wasDoomScrolling: false
        ))
    }
    .background(STColors.surface)
}

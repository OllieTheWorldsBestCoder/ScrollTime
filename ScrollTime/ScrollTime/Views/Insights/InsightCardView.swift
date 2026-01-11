//
//  InsightCardView.swift
//  ScrollTime
//
//  A compact card component for displaying pattern-based insights in
//  a horizontal carousel. Follows the Claude-inspired warm, minimal aesthetic.
//

import SwiftUI

// MARK: - Insight Card View

/// A compact card displaying a single insight for the Dashboard carousel.
/// Designed to show 2-3 cards per screen width with warm, inviting styling.
struct InsightCardView: View {
    let insight: Insight
    var onTap: (() -> Void)? = nil

    // Animation state for tap interaction
    @State private var isPressed = false

    var body: some View {
        Button {
            onTap?()
        } label: {
            cardContent
        }
        .buttonStyle(InsightCardButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(insight.actionSuggestion != nil ? "Double tap for suggestion" : "")
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: STSpacing.sm) {
            // Emoji header
            emojiHeader

            // Title
            Text(insight.title)
                .font(STTypography.bodyMedium())
                .fontWeight(.medium)
                .foregroundColor(STColors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Message
            Text(insight.message)
                .font(STTypography.bodySmall())
                .foregroundColor(STColors.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: STSpacing.xs)

            // Action suggestion (if present)
            if let suggestion = insight.actionSuggestion {
                actionSuggestionView(suggestion)
            }
        }
        .padding(STSpacing.md)
        .frame(width: 180, alignment: .topLeading)
        .frame(minHeight: 180)
        .background(
            RoundedRectangle(cornerRadius: STRadius.lg)
                .fill(cardBackgroundColor)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: STRadius.lg)
                .strokeBorder(cardBorderColor, lineWidth: 1)
        )
    }

    // MARK: - Emoji Header

    private var emojiHeader: some View {
        ZStack {
            Circle()
                .fill(emojiBackgroundColor)
                .frame(width: 44, height: 44)

            Text(emojiCharacter)
                .font(.system(size: 22))
        }
    }

    /// Converts insight emoji description to actual emoji character
    private var emojiCharacter: String {
        // Map emoji descriptions to actual characters
        let emojiMap: [String: String] = [
            "party popper": "\u{1F389}",
            "star": "\u{2B50}",
            "chart with downwards trend": "\u{1F4C9}",
            "chart with upwards trend": "\u{1F4C8}",
            "chart increasing": "\u{1F4C8}",
            "person in lotus position": "\u{1F9D8}",
            "beach with umbrella": "\u{1F3D6}",
            "sunrise over mountains": "\u{1F304}",
            "owl": "\u{1F989}",
            "thought balloon": "\u{1F4AD}",
            "waving hand": "\u{1F44B}",
            "clock face 9 oclock": "\u{1F558}",
            "clock face 8 oclock": "\u{1F557}",
            "clock face 10 oclock": "\u{1F559}",
            "clock face 11 oclock": "\u{1F55A}",
            "clock face 12 oclock": "\u{1F55B}",
            "clock face 1 oclock": "\u{1F550}",
            "clock face 2 oclock": "\u{1F551}",
            "clock face 3 oclock": "\u{1F552}",
            "clock face 4 oclock": "\u{1F553}",
            "clock face 5 oclock": "\u{1F554}",
            "clock face 6 oclock": "\u{1F555}",
            "clock face 7 oclock": "\u{1F556}"
        ]

        // Try to find a match, otherwise use a default or the raw string
        if let emoji = emojiMap[insight.emoji.lowercased()] {
            return emoji
        }

        // Check for clock face patterns with different formats
        if insight.emoji.lowercased().contains("clock") {
            return "\u{1F550}" // Default clock
        }

        // If it's already an emoji character, return it
        if insight.emoji.count <= 2 {
            return insight.emoji
        }

        // Default fallback based on insight type positivity
        return insight.isPositive ? "\u{2728}" : "\u{1F4A1}" // Sparkles or lightbulb
    }

    // MARK: - Action Suggestion

    private func actionSuggestionView(_ suggestion: String) -> some View {
        HStack(spacing: STSpacing.xxs) {
            Image(systemName: "lightbulb.min")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(STColors.primary)

            Text("Tip")
                .font(STTypography.caption())
                .fontWeight(.medium)
                .foregroundColor(STColors.primary)
        }
        .padding(.horizontal, STSpacing.xs)
        .padding(.vertical, STSpacing.xxxs)
        .background(
            Capsule()
                .fill(STColors.primaryLight)
        )
    }

    // MARK: - Colors

    private var cardBackgroundColor: Color {
        insight.isPositive ? STColors.surface : STColors.surface
    }

    private var cardBorderColor: Color {
        insight.isPositive ? STColors.subtle.opacity(0.5) : STColors.warning.opacity(0.2)
    }

    private var emojiBackgroundColor: Color {
        insight.isPositive ? STColors.primaryLight : STColors.primaryLight.opacity(0.8)
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var description = "\(insight.title). \(insight.message)"
        if let suggestion = insight.actionSuggestion {
            description += " Suggestion: \(suggestion)"
        }
        return description
    }
}

// MARK: - Insight Card Button Style

/// Custom button style for insight cards with subtle press animation
private struct InsightCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Insight Carousel View

/// A horizontal scrolling carousel of insight cards for the Dashboard.
/// Displays pattern-based insights in a compact, swipeable format.
struct InsightCarouselView: View {
    let insights: [Insight]
    var onInsightTap: ((Insight) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: STSpacing.md) {
            // Section header
            headerView

            // Carousel
            if insights.isEmpty {
                emptyState
            } else {
                carouselContent
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Insights")
                .font(STTypography.titleSmall())
                .foregroundColor(STColors.textPrimary)

            Spacer()

            if !insights.isEmpty {
                Text("\(insights.count) patterns found")
                    .font(STTypography.caption())
                    .foregroundColor(STColors.textTertiary)
            }
        }
        .padding(.horizontal, STSpacing.lg)
    }

    // MARK: - Carousel Content

    private var carouselContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: STSpacing.md) {
                ForEach(sortedInsights) { insight in
                    InsightCardView(insight: insight) {
                        onInsightTap?(insight)
                    }
                }
            }
            .padding(.horizontal, STSpacing.lg)
            .padding(.vertical, STSpacing.xxs) // Extra padding for shadow
        }
    }

    /// Insights sorted by priority (highest first)
    private var sortedInsights: [Insight] {
        insights.sorted { $0.priority > $1.priority }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        STCard {
            VStack(spacing: STSpacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(STColors.textTertiary)

                Text("Gathering insights")
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textSecondary)

                Text("We'll discover patterns in your\nscrolling habits over the next few days")
                    .font(STTypography.bodySmall())
                    .foregroundColor(STColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(STSpacing.xl)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, STSpacing.lg)
    }
}

// MARK: - Previews

#Preview("Single Insight Card") {
    ZStack {
        STColors.background.ignoresSafeArea()

        InsightCardView(insight: .sampleImprovement) {
            print("Tapped improvement insight")
        }
        .padding()
    }
}

#Preview("Insight Card - With Action") {
    ZStack {
        STColors.background.ignoresSafeArea()

        InsightCardView(insight: .nightOwl()) {
            print("Tapped night owl insight")
        }
        .padding()
    }
}

#Preview("Insight Card - Attention Needed") {
    ZStack {
        STColors.background.ignoresSafeArea()

        InsightCardView(insight: .attentionNeeded(percentIncrease: 25)) {
            print("Tapped attention insight")
        }
        .padding()
    }
}

#Preview("Insight Carousel") {
    ZStack {
        STColors.background.ignoresSafeArea()

        VStack {
            InsightCarouselView(insights: Insight.sampleCollection) { insight in
                print("Tapped: \(insight.title)")
            }

            Spacer()
        }
        .padding(.top, STSpacing.xl)
    }
}

#Preview("Empty Carousel") {
    ZStack {
        STColors.background.ignoresSafeArea()

        VStack {
            InsightCarouselView(insights: [])

            Spacer()
        }
        .padding(.top, STSpacing.xl)
    }
}

#Preview("Carousel in Context") {
    NavigationStack {
        ZStack {
            STColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: STSpacing.xl) {
                    // Simulated header
                    VStack(alignment: .leading, spacing: STSpacing.xs) {
                        Text("Good afternoon")
                            .font(STTypography.bodyMedium())
                            .foregroundColor(STColors.textTertiary)

                        Text("Your mindful\nmoments today")
                            .font(STTypography.displayMedium())
                            .foregroundColor(STColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, STSpacing.lg)

                    // Insight carousel
                    InsightCarouselView(insights: Insight.sampleCollection)

                    Spacer()
                }
                .padding(.top, STSpacing.md)
            }
        }
    }
}

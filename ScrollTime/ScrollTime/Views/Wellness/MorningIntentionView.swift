//
//  MorningIntentionView.swift
//  ScrollTime
//
//  A warm, inviting morning intention setting view.
//  Presented as a full-screen sheet to help users start their day
//  with mindful awareness of their screen time goals.
//

import SwiftUI

// MARK: - Morning Intention View

struct MorningIntentionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var intentionManager: IntentionManager

    @State private var appeared = false
    @State private var selectedIntention: IntentionType?
    @State private var showingConfirmation = false
    @State private var confirmationScale: CGFloat = 0.8

    // Staggered animation delays for cards
    private let cardAnimationDelays: [Double] = [0.1, 0.15, 0.2, 0.25, 0.3]

    var body: some View {
        ZStack {
            // Background
            STColors.background
                .ignoresSafeArea()

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

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: STSpacing.xxxl)

            // Greeting
            greetingSection
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.1), value: appeared)

            Spacer()
                .frame(height: STSpacing.xxl)

            // Question
            questionSection
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: appeared)

            Spacer()
                .frame(height: STSpacing.xl)

            // Intention cards
            intentionCardsSection

            Spacer()

            // Skip button
            skipButton
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)

            Spacer()
                .frame(height: STSpacing.xl)
        }
        .padding(.horizontal, STSpacing.lg)
    }

    // MARK: - Greeting Section

    private var greetingSection: some View {
        Text(greeting)
            .font(STTypography.displayMedium())
            .foregroundColor(STColors.textPrimary)
            .multilineTextAlignment(.center)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<21:
            return "Good evening"
        default:
            return "Hello"
        }
    }

    // MARK: - Question Section

    private var questionSection: some View {
        Text("What would make today\nfeel meaningful?")
            .font(STTypography.titleLarge())
            .foregroundColor(STColors.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
    }

    // MARK: - Intention Cards Section

    private var intentionCardsSection: some View {
        VStack(spacing: STSpacing.sm) {
            ForEach(Array(IntentionType.allCases.enumerated()), id: \.element) { index, intention in
                IntentionCard(intention: intention) {
                    selectIntention(intention)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8)
                    .delay(cardAnimationDelays[safe: index] ?? 0.3),
                    value: appeared
                )
            }
        }
    }

    // MARK: - Skip Button

    private var skipButton: some View {
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
    }

    // MARK: - Confirmation Overlay

    private func confirmationOverlay(for intention: IntentionType) -> some View {
        VStack(spacing: STSpacing.xl) {
            // Emoji
            Text(intention.emoji)
                .font(.system(size: 72))
                .scaleEffect(confirmationScale)

            // Encouragement message
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

            // Dismiss after showing confirmation
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

    // MARK: - Actions

    private func selectIntention(_ intention: IntentionType) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        selectedIntention = intention
        intentionManager.setIntention(intention)

        withAnimation(.easeInOut(duration: 0.3)) {
            showingConfirmation = true
        }
    }

    private func skipForToday() {
        // Light haptic
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        intentionManager.skipIntention()

        withAnimation(.easeOut(duration: 0.3)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

// MARK: - Intention Card

private struct IntentionCard: View {
    let intention: IntentionType
    let onSelect: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: STSpacing.md) {
                // Emoji
                Text(intention.emoji)
                    .font(.system(size: 24))

                // Intention name
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

// MARK: - Array Safe Subscript Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview("Morning Intention") {
    MorningIntentionView(intentionManager: .previewWithPrompt)
}

#Preview("Afternoon") {
    // Simulate afternoon greeting
    MorningIntentionView(intentionManager: .previewWithPrompt)
}

#Preview("Dark Mode") {
    MorningIntentionView(intentionManager: .previewWithPrompt)
        .preferredColorScheme(.dark)
}

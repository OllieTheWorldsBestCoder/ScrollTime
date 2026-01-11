//
//  MilestoneCelebrationView.swift
//  ScrollTime
//
//  A gentle, warm celebration overlay for milestones.
//  Designed to feel like a moment of quiet acknowledgment,
//  not an aggressive achievement popup.
//

import SwiftUI

// MARK: - Milestone Celebration View

/// A subtle modal overlay that celebrates user milestones with warmth
/// Appears as a gentle acknowledgment, not a blocking achievement popup
struct MilestoneCelebrationView: View {
    let milestone: Milestone
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3

    // Encouraging messages that rotate based on milestone type
    private var encouragingMessage: String {
        switch milestone.type {
        case .firstMindfulDay:
            return "Every journey begins with a single step."
        case .streakDays(let days):
            if days >= 30 {
                return "Your consistency is inspiring."
            } else if days >= 7 {
                return "You're building something real."
            } else {
                return "Keep nurturing this habit."
            }
        case .hoursReclaimed:
            return "Time well saved is time well spent."
        case .breathingExercises:
            return "Each breath brings you closer to calm."
        case .interventionsMastered:
            return "Mindfulness is becoming second nature."
        case .totalMindfulDays:
            return "Progress, not perfection."
        case .firstImprovingWeek:
            return "You're heading in the right direction."
        }
    }

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black
                .opacity(appeared ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWithAnimation()
                }

            // Celebration card
            VStack(spacing: STSpacing.lg) {
                // Warm glow behind emoji
                ZStack {
                    // Outer glow ring - subtle pulse
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    STColors.primary.opacity(0.3),
                                    STColors.primary.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseScale)
                        .opacity(glowOpacity)

                    // Inner warm circle
                    Circle()
                        .fill(STColors.primaryLight)
                        .frame(width: 100, height: 100)

                    // Milestone symbol
                    Image(systemName: milestone.symbolName)
                        .font(.system(size: 44))
                        .foregroundStyle(STColors.primary)
                        .scaleEffect(pulseScale * 0.95)
                }
                .padding(.top, STSpacing.md)

                // Title and description
                VStack(spacing: STSpacing.sm) {
                    Text(milestone.title)
                        .font(STTypography.titleMedium())
                        .foregroundStyle(STColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(milestone.description)
                        .font(STTypography.bodyMedium())
                        .foregroundStyle(STColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, STSpacing.sm)
                }

                // Divider
                STDivider()
                    .padding(.horizontal, STSpacing.lg)

                // Encouraging closing message
                Text(encouragingMessage)
                    .font(STTypography.bodySmall())
                    .italic()
                    .foregroundStyle(STColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, STSpacing.md)

                // Subtle dismiss hint
                Text("Tap anywhere to continue")
                    .font(STTypography.caption())
                    .foregroundStyle(STColors.textTertiary.opacity(0.7))
                    .padding(.top, STSpacing.xs)
                    .padding(.bottom, STSpacing.md)
            }
            .padding(STSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: STRadius.xl)
                    .fill(STColors.surface)
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, STSpacing.xl)
            .scaleEffect(appeared ? 1.0 : 0.8)
            .opacity(appeared ? 1.0 : 0)
            .onTapGesture {
                dismissWithAnimation()
            }
        }
        .onAppear {
            // Fade in background and scale up card
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }

            // Start subtle pulse animation on emoji
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.08
                glowOpacity = 0.5
            }
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.easeOut(duration: 0.25)) {
            appeared = false
        }

        // Call dismiss after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}

// MARK: - View Modifier

/// A view modifier for easily presenting milestone celebrations
struct MilestoneCelebrationModifier: ViewModifier {
    @Binding var milestone: Milestone?
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        ZStack {
            content

            if let milestone = milestone {
                MilestoneCelebrationView(milestone: milestone) {
                    self.milestone = nil
                    onDismiss()
                }
                .transition(.opacity)
                .zIndex(1000) // Ensure it appears above other content
            }
        }
    }
}

extension View {
    /// Presents a milestone celebration overlay when a milestone is provided
    /// - Parameters:
    ///   - milestone: Binding to the milestone to celebrate (nil hides the view)
    ///   - onDismiss: Closure called when the celebration is dismissed
    /// - Returns: The modified view with milestone celebration capability
    func milestoneCelebration(
        milestone: Binding<Milestone?>,
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        modifier(MilestoneCelebrationModifier(milestone: milestone, onDismiss: onDismiss))
    }
}

// MARK: - Previews

#Preview("First Mindful Day") {
    ZStack {
        STColors.background
            .ignoresSafeArea()

        VStack {
            Text("Dashboard Content")
                .font(STTypography.titleLarge())
        }
    }
    .overlay {
        MilestoneCelebrationView(
            milestone: Milestone.sampleFirstDay
        ) {
            print("Dismissed")
        }
    }
}

#Preview("Week Streak") {
    ZStack {
        STColors.background
            .ignoresSafeArea()

        VStack {
            Text("Dashboard Content")
                .font(STTypography.titleLarge())
        }
    }
    .overlay {
        MilestoneCelebrationView(
            milestone: Milestone.sampleStreak
        ) {
            print("Dismissed")
        }
    }
}

#Preview("Hours Reclaimed") {
    ZStack {
        STColors.background
            .ignoresSafeArea()

        VStack {
            Text("Dashboard Content")
                .font(STTypography.titleLarge())
        }
    }
    .overlay {
        MilestoneCelebrationView(
            milestone: Milestone.sampleHours
        ) {
            print("Dismissed")
        }
    }
}

#Preview("Breathing Exercises") {
    ZStack {
        STColors.background
            .ignoresSafeArea()

        VStack {
            Text("Dashboard Content")
                .font(STTypography.titleLarge())
        }
    }
    .overlay {
        MilestoneCelebrationView(
            milestone: Milestone.sampleBreathing
        ) {
            print("Dismissed")
        }
    }
}

#Preview("First Improving Week") {
    ZStack {
        STColors.background
            .ignoresSafeArea()

        VStack {
            Text("Dashboard Content")
                .font(STTypography.titleLarge())
        }
    }
    .overlay {
        MilestoneCelebrationView(
            milestone: Milestone(type: .firstImprovingWeek)
        ) {
            print("Dismissed")
        }
    }
}

#Preview("Interventions Mastered") {
    ZStack {
        STColors.background
            .ignoresSafeArea()

        VStack {
            Text("Dashboard Content")
                .font(STTypography.titleLarge())
        }
    }
    .overlay {
        MilestoneCelebrationView(
            milestone: Milestone(type: .interventionsMastered)
        ) {
            print("Dismissed")
        }
    }
}

#Preview("Long Streak (30 days)") {
    ZStack {
        STColors.background
            .ignoresSafeArea()

        VStack {
            Text("Dashboard Content")
                .font(STTypography.titleLarge())
        }
    }
    .overlay {
        MilestoneCelebrationView(
            milestone: Milestone(type: .streakDays(30))
        ) {
            print("Dismissed")
        }
    }
}

#Preview("View Modifier Usage") {
    struct PreviewContainer: View {
        @State private var milestone: Milestone? = Milestone.sampleStreak

        var body: some View {
            ZStack {
                STColors.background
                    .ignoresSafeArea()

                VStack(spacing: STSpacing.lg) {
                    Text("Main App Content")
                        .font(STTypography.titleLarge())

                    Button("Show Milestone") {
                        milestone = Milestone.sampleBreathing
                    }
                    .buttonStyle(STPrimaryButtonStyle())
                }
            }
            .milestoneCelebration(milestone: $milestone) {
                print("Milestone celebrated and dismissed")
            }
        }
    }

    return PreviewContainer()
}

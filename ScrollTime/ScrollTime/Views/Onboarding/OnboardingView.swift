import SwiftUI

// MARK: - Redesigned Onboarding View
// Claude-inspired: warm, minimal, thoughtful

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var appeared = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Reclaim your\nattention",
            subtitle: "ScrollTime gently notices when you're lost in endless scrolling, and offers a moment to pause.",
            illustration: "hand.raised"
        ),
        OnboardingPage(
            title: "A gentle\nreminder",
            subtitle: "No judgment, no guilt. Just a calm invitation to check in with yourself and decide what you really want.",
            illustration: "leaf"
        ),
        OnboardingPage(
            title: "Breathe.\nReset.",
            subtitle: "When you're ready, we'll guide you through a brief moment of mindfulness to break the scroll cycle.",
            illustration: "wind"
        )
    ]

    var body: some View {
        ZStack {
            // Warm background
            STColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                currentPage = pages.count - 1
                            }
                        }
                        .font(STTypography.bodySmall())
                        .foregroundColor(STColors.textTertiary)
                    }
                }
                .padding(.horizontal, STSpacing.lg)
                .padding(.top, STSpacing.md)
                .frame(height: 44)

                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Spacer()

                // Bottom section
                VStack(spacing: STSpacing.lg) {
                    // Page indicators
                    HStack(spacing: STSpacing.xs) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? STColors.primary : STColors.subtle)
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
                        }
                    }

                    // Action button
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentPage += 1
                            }
                        } else {
                            onComplete()
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(STPrimaryButtonStyle())
                    .padding(.horizontal, STSpacing.lg)
                }
                .padding(.bottom, STSpacing.xxl)
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }
}

// MARK: - Page Model

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let illustration: String
}

// MARK: - Page View

private struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var appeared = false

    var body: some View {
        VStack(spacing: STSpacing.xxl) {
            // Illustration
            ZStack {
                Circle()
                    .fill(STColors.primaryLight)
                    .frame(width: 160, height: 160)

                Image(systemName: page.illustration)
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(STColors.primary)
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)

            // Text content
            VStack(spacing: STSpacing.md) {
                Text(page.title)
                    .font(STTypography.displayMedium())
                    .foregroundColor(STColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text(page.subtitle)
                    .font(STTypography.bodyLarge())
                    .foregroundColor(STColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, STSpacing.xl)
            }
            .offset(y: appeared ? 0 : 20)
            .opacity(appeared ? 1 : 0)
        }
        .padding(.horizontal, STSpacing.lg)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
        .onDisappear {
            appeared = false
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
}

import SwiftUI

/// A subtle, easily dismissable awareness prompt
/// The gentlest form of intervention - just a moment of awareness
struct GentleReminderView: View {
    let onComplete: (InterventionResult) -> Void

    @State private var hasAppeared = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Gentle pulsing icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale)

                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 12) {
                Text("A Moment of Awareness")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("You've been scrolling for a while.\nHow are you feeling?")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Quick action buttons
            VStack(spacing: 16) {
                Button {
                    onComplete(.tookBreak)
                } label: {
                    HStack {
                        Image(systemName: "figure.walk")
                        Text("I'll Take a Break")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    onComplete(.continuedScrolling)
                } label: {
                    Text("Keep Scrolling")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .padding()
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.8)
            .ignoresSafeArea()

        GentleReminderView { result in
            print("Result: \(result)")
        }
    }
}

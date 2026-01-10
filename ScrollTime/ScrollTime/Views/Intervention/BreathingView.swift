import SwiftUI

/// Animated breathing exercise intervention
/// Guides user through inhale/hold/exhale cycles with visual feedback
struct BreathingView: View {
    let onComplete: (InterventionResult) -> Void

    @State private var breathPhase: BreathPhase = .ready
    @State private var currentCycle = 0
    @State private var circleScale: CGFloat = 0.5
    @State private var innerRingOpacity: Double = 0.3

    private let totalCycles = 3
    private let inhaleDuration: Double = 4.0
    private let holdDuration: Double = 4.0
    private let exhaleDuration: Double = 6.0

    var body: some View {
        VStack(spacing: 40) {
            // Breathing circle visualization
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                    .frame(width: 220, height: 220)

                // Animated breathing ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 8
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(circleScale)
                    .opacity(innerRingOpacity)

                // Inner circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.blue.opacity(0.6),
                                Color.blue.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(circleScale)

                // Phase text
                VStack(spacing: 8) {
                    Text(breathPhase.instruction)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    if breathPhase != .ready && breathPhase != .complete {
                        Text("\(currentCycle + 1) of \(totalCycles)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }

            // Progress dots
            if breathPhase != .ready && breathPhase != .complete {
                HStack(spacing: 12) {
                    ForEach(0..<totalCycles, id: \.self) { index in
                        Circle()
                            .fill(index <= currentCycle ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }

            // Action buttons
            VStack(spacing: 16) {
                if breathPhase == .ready {
                    Button {
                        startBreathing()
                    } label: {
                        Text("Begin Breathing")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                } else if breathPhase == .complete {
                    VStack(spacing: 12) {
                        Button {
                            onComplete(.tookBreak)
                        } label: {
                            Text("I'm Done Scrolling")
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
                            Text("Continue Scrolling")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private func startBreathing() {
        breathPhase = .inhale
        runBreathCycle()
    }

    private func runBreathCycle() {
        // Inhale phase
        withAnimation(.easeInOut(duration: inhaleDuration)) {
            circleScale = 1.0
            innerRingOpacity = 1.0
        }

        // Hold phase
        DispatchQueue.main.asyncAfter(deadline: .now() + inhaleDuration) {
            breathPhase = .hold
        }

        // Exhale phase
        DispatchQueue.main.asyncAfter(deadline: .now() + inhaleDuration + holdDuration) {
            breathPhase = .exhale
            withAnimation(.easeInOut(duration: exhaleDuration)) {
                circleScale = 0.5
                innerRingOpacity = 0.3
            }
        }

        // Next cycle or complete
        let cycleDuration = inhaleDuration + holdDuration + exhaleDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + cycleDuration) {
            if currentCycle < totalCycles - 1 {
                currentCycle += 1
                breathPhase = .inhale
                runBreathCycle()
            } else {
                withAnimation {
                    breathPhase = .complete
                }
                onComplete(.completed)
            }
        }
    }
}

// MARK: - Breath Phase

private enum BreathPhase {
    case ready
    case inhale
    case hold
    case exhale
    case complete

    var instruction: String {
        switch self {
        case .ready: return "Ready?"
        case .inhale: return "Breathe In"
        case .hold: return "Hold"
        case .exhale: return "Breathe Out"
        case .complete: return "Well Done"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.8)
            .ignoresSafeArea()

        BreathingView { result in
            print("Result: \(result)")
        }
    }
}

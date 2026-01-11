import SwiftUI

/// Wait timer intervention with countdown
/// Enforces a pause before allowing user to continue scrolling
struct TimerView: View {
    let onComplete: (InterventionResult) -> Void

    @State private var timeRemaining: Int = 30
    @State private var isRunning = false
    @State private var isComplete = false
    @State private var timer: Timer?

    private let totalTime = 30

    private var progress: Double {
        1.0 - (Double(timeRemaining) / Double(totalTime))
    }

    var body: some View {
        VStack(spacing: 40) {
            // Timer ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 200, height: 200)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // Inner content
                VStack(spacing: 8) {
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("\(timeRemaining)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())

                        Text("seconds")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }

            // Status text
            Text(statusText)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            // Action buttons
            VStack(spacing: 16) {
                if !isRunning && !isComplete {
                    Button {
                        startTimer()
                    } label: {
                        Text("Start Timer")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                } else if isComplete {
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
        .onDisappear {
            stopTimer()
        }
    }

    private var statusText: String {
        if !isRunning && !isComplete {
            return "Take 30 seconds to pause\nand consider your intention"
        } else if isRunning {
            return "Pausing..."
        } else {
            return "Great job taking a moment\nto be intentional!"
        }
    }

    private func startTimer() {
        isRunning = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            if timeRemaining > 0 {
                withAnimation {
                    timeRemaining -= 1
                }
            } else {
                timer?.invalidate()
                timer = nil
                withAnimation(.spring(response: 0.5)) {
                    isRunning = false
                    isComplete = true
                }
                // Note: Do NOT auto-call onComplete here - let user choose their action
                // The user will tap either "I'm Done Scrolling" or "Continue Scrolling"
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.8)
            .ignoresSafeArea()

        TimerView { result in
            print("Result: \(result)")
        }
    }
}

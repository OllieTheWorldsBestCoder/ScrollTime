import SwiftUI

// MARK: - Redesigned Intervention View
// Claude-inspired: calm, warm, inviting

struct InterventionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var interventionType: InterventionType
    let onComplete: (InterventionResult) -> Void

    @State private var appeared = false
    @State private var canSkip = false

    var body: some View {
        ZStack {
            // Warm, calming background
            LinearGradient(
                colors: [
                    STColors.background,
                    STColors.primaryLight.opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -20)

                Spacer()

                // Main content
                Group {
                    switch interventionType {
                    case .gentleReminder:
                        GentleReminderContent { result in
                            handleCompletion(result: result)
                        }
                    case .breathingExercise:
                        BreathingContent { result in
                            handleCompletion(result: result)
                        }
                    case .timedPause:
                        TimedPauseContent { result in
                            handleCompletion(result: result)
                        }
                    case .frictionDialog:
                        FrictionContent { result in
                            handleCompletion(result: result)
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.95)

                Spacer()

                // Skip option
                skipButton
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
            }
            .padding(.horizontal, STSpacing.lg)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
            // Enable skip after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    canSkip = true
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: STSpacing.sm) {
            ZStack {
                Circle()
                    .fill(STColors.primaryLight)
                    .frame(width: 64, height: 64)

                Image(systemName: interventionType.iconName)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(STColors.primary)
            }

            Text(interventionType.title)
                .font(STTypography.titleMedium())
                .foregroundColor(STColors.textPrimary)

            Text(interventionType.message)
                .font(STTypography.bodySmall())
                .foregroundColor(STColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, STSpacing.xxl)
    }

    // MARK: - Skip Button

    private var skipButton: some View {
        Button {
            handleCompletion(result: .skipped)
        } label: {
            Text(canSkip ? "Skip this time" : "Skip available soon...")
                .font(STTypography.bodySmall())
                .foregroundColor(canSkip ? STColors.textSecondary : STColors.textTertiary)
        }
        .disabled(!canSkip)
        .padding(.bottom, STSpacing.xxl)
    }

    // MARK: - Completion Handler

    private func handleCompletion(result: InterventionResult) {
        withAnimation(.easeOut(duration: 0.3)) {
            appeared = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete(result)
            dismiss()
        }
    }
}

// MARK: - Gentle Reminder Content

private struct GentleReminderContent: View {
    let onComplete: (InterventionResult) -> Void
    @State private var selectedMood: String?

    private let moods = [
        ("Good", "face.smiling", Color(hex: "4A9B6E")),
        ("Okay", "face.smiling.inverse", Color(hex: "E0A33D")),
        ("Need a break", "moon.zzz", Color(hex: "6B8EBF"))
    ]

    var body: some View {
        VStack(spacing: STSpacing.xl) {
            Text("How are you feeling\nright now?")
                .font(STTypography.titleLarge())
                .foregroundColor(STColors.textPrimary)
                .multilineTextAlignment(.center)

            VStack(spacing: STSpacing.sm) {
                ForEach(moods, id: \.0) { mood, icon, color in
                    Button {
                        selectedMood = mood
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            switch mood {
                            case "Good": onComplete(.continuedScrolling)
                            case "Okay": onComplete(.tookBreak)
                            default: onComplete(.completed)
                            }
                        }
                    } label: {
                        HStack(spacing: STSpacing.md) {
                            Image(systemName: icon)
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(color)
                                .frame(width: 32)

                            Text(mood)
                                .font(STTypography.bodyLarge())
                                .foregroundColor(STColors.textPrimary)

                            Spacer()

                            if selectedMood == mood {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(STColors.primary)
                            }
                        }
                        .padding(.horizontal, STSpacing.lg)
                        .padding(.vertical, STSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: STRadius.md)
                                .fill(STColors.surface)
                                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, STSpacing.md)
        }
    }
}

// MARK: - Breathing Content

private struct BreathingContent: View {
    let onComplete: (InterventionResult) -> Void

    @State private var phase: BreathPhase = .ready
    @State private var breathScale: CGFloat = 0.6
    @State private var cycleCount = 0
    private let totalCycles = 3

    enum BreathPhase: String {
        case ready = "Ready?"
        case inhale = "Breathe in..."
        case hold = "Hold..."
        case exhale = "Breathe out..."
        case complete = "Well done"
    }

    var body: some View {
        VStack(spacing: STSpacing.xl) {
            // Breathing circle
            ZStack {
                // Outer ring
                Circle()
                    .stroke(STColors.subtle, lineWidth: 2)
                    .frame(width: 200, height: 200)

                // Animated circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [STColors.primary.opacity(0.3), STColors.primary.opacity(0.1)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(breathScale)
                    .animation(.easeInOut(duration: phaseDuration), value: breathScale)

                // Phase text
                Text(phase.rawValue)
                    .font(STTypography.bodyLarge())
                    .foregroundColor(STColors.textPrimary)
            }

            // Progress
            if phase != .ready && phase != .complete {
                HStack(spacing: STSpacing.xs) {
                    ForEach(0..<totalCycles, id: \.self) { index in
                        Circle()
                            .fill(index < cycleCount ? STColors.primary : STColors.subtle)
                            .frame(width: 8, height: 8)
                    }
                }
            }

            // Action button
            if phase == .ready {
                Button("Begin") {
                    startBreathing()
                }
                .buttonStyle(STPrimaryButtonStyle())
            } else if phase == .complete {
                Button("Continue") {
                    onComplete(.completed)
                }
                .buttonStyle(STPrimaryButtonStyle())
            }
        }
    }

    private var phaseDuration: Double {
        switch phase {
        case .inhale: return 4.0
        case .hold: return 4.0
        case .exhale: return 6.0
        default: return 0.5
        }
    }

    private func startBreathing() {
        cycleCount = 0
        runCycle()
    }

    private func runCycle() {
        // Inhale
        phase = .inhale
        withAnimation { breathScale = 1.0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            // Hold
            phase = .hold

            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                // Exhale
                phase = .exhale
                withAnimation { breathScale = 0.6 }

                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    cycleCount += 1
                    if cycleCount < totalCycles {
                        runCycle()
                    } else {
                        phase = .complete
                    }
                }
            }
        }
    }
}

// MARK: - Timed Pause Content

private struct TimedPauseContent: View {
    let onComplete: (InterventionResult) -> Void

    @State private var timeRemaining = 30
    @State private var isRunning = false
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: STSpacing.xl) {
            // Timer display
            ZStack {
                Circle()
                    .stroke(STColors.subtle, lineWidth: 4)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: CGFloat(timeRemaining) / 30.0)
                    .stroke(STColors.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timeRemaining)

                VStack(spacing: STSpacing.xxs) {
                    Text("\(timeRemaining)")
                        .font(.system(size: 48, weight: .light, design: .serif))
                        .foregroundColor(STColors.textPrimary)

                    Text("seconds")
                        .font(STTypography.bodySmall())
                        .foregroundColor(STColors.textTertiary)
                }
            }

            // Message
            Text(isRunning ? "Take a moment to pause\nand breathe" : "A brief pause to\nreset your mind")
                .font(STTypography.bodyLarge())
                .foregroundColor(STColors.textSecondary)
                .multilineTextAlignment(.center)

            // Action
            if !isRunning {
                Button("Start Pause") {
                    startTimer()
                }
                .buttonStyle(STPrimaryButtonStyle())
            }
        }
    }

    private func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
                onComplete(.completed)
            }
        }
    }
}

// MARK: - Friction Content

private struct FrictionContent: View {
    let onComplete: (InterventionResult) -> Void

    @State private var userInput = ""
    @FocusState private var isFocused: Bool

    private let phrase = "I choose to continue"

    var body: some View {
        VStack(spacing: STSpacing.xl) {
            // Prompt
            VStack(spacing: STSpacing.md) {
                Text("To continue scrolling,\ntype the phrase below")
                    .font(STTypography.titleLarge())
                    .foregroundColor(STColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("This small friction helps you\nmake a conscious choice")
                    .font(STTypography.bodySmall())
                    .foregroundColor(STColors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            // Phrase to type
            Text("\"\(phrase)\"")
                .font(STTypography.bodyLarge())
                .foregroundColor(STColors.primary)
                .padding(.vertical, STSpacing.sm)

            // Input field
            TextField("Type here...", text: $userInput)
                .font(STTypography.bodyMedium())
                .foregroundColor(STColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(STSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: STRadius.md)
                        .fill(STColors.surface)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                )
                .focused($isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            // Continue button
            if userInput.lowercased() == phrase.lowercased() {
                Button("Continue Scrolling") {
                    onComplete(.continuedScrolling)
                }
                .buttonStyle(STSecondaryButtonStyle())
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Alternative - take a break
            Button("Take a break instead") {
                onComplete(.tookBreak)
            }
            .font(STTypography.bodySmall())
            .foregroundColor(STColors.textSecondary)
        }
        .padding(.horizontal, STSpacing.md)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: userInput)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
    }
}

// MARK: - Intervention Presenter

struct InterventionPresenter: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var interventionType: InterventionType
    let onComplete: (InterventionResult) -> Void

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                InterventionView(
                    interventionType: $interventionType,
                    onComplete: onComplete
                )
            }
    }
}

extension View {
    func interventionPresenter(
        isPresented: Binding<Bool>,
        interventionType: Binding<InterventionType>,
        onComplete: @escaping (InterventionResult) -> Void
    ) -> some View {
        modifier(InterventionPresenter(
            isPresented: isPresented,
            interventionType: interventionType,
            onComplete: onComplete
        ))
    }
}

// MARK: - Previews

#Preview("Gentle Reminder") {
    InterventionView(interventionType: .constant(.gentleReminder)) { _ in }
}

#Preview("Breathing") {
    InterventionView(interventionType: .constant(.breathingExercise)) { _ in }
}

#Preview("Timed Pause") {
    InterventionView(interventionType: .constant(.timedPause)) { _ in }
}

#Preview("Friction") {
    InterventionView(interventionType: .constant(.frictionDialog)) { _ in }
}

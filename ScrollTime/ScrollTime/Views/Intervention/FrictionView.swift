import SwiftUI

/// Deliberate friction UI intervention
/// Requires intentional confirmation before allowing continued scrolling
struct FrictionView: View {
    let onComplete: (InterventionResult) -> Void

    @State private var typedText = ""
    @State private var showConfirmation = false
    @State private var shakeOffset: CGFloat = 0

    private let confirmationPhrase = "I choose to continue"

    private var isTextCorrect: Bool {
        typedText.lowercased().trimmingCharacters(in: .whitespaces) ==
        confirmationPhrase.lowercased()
    }

    var body: some View {
        VStack(spacing: 32) {
            // Icon and message
            VStack(spacing: 16) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text("Mindful Moment")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("You've been scrolling for a while.\nIf you want to continue, please type:")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            // Confirmation phrase to type
            VStack(spacing: 16) {
                Text("\"\(confirmationPhrase)\"")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Text input field
                TextField("", text: $typedText, prompt: Text("Type here...").foregroundColor(.white.opacity(0.3)))
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: 2)
                    )
                    .offset(x: shakeOffset)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal)

            // Action buttons
            VStack(spacing: 16) {
                // Stop scrolling button (always available)
                Button {
                    onComplete(.tookBreak)
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("I'm Done Scrolling")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Continue button (only enabled when text matches)
                Button {
                    if isTextCorrect {
                        onComplete(.continuedScrolling)
                    } else {
                        triggerShake()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Continue Scrolling")
                    }
                    .font(.headline)
                    .foregroundStyle(isTextCorrect ? .white : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isTextCorrect ? Color.orange : Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal)

            // Helper text
            if !typedText.isEmpty && !isTextCorrect {
                Text("Please type the phrase exactly as shown")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
    }

    private var borderColor: Color {
        if typedText.isEmpty {
            return Color.white.opacity(0.2)
        } else if isTextCorrect {
            return Color.green
        } else {
            return Color.orange
        }
    }

    private func triggerShake() {
        withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
                shakeOffset = -10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
                shakeOffset = 0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.8)
            .ignoresSafeArea()

        FrictionView { result in
            print("Result: \(result)")
        }
    }
}

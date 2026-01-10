import SwiftUI

/// View for adjusting scroll detection sensitivity
struct SensitivityView: View {
    @Binding var sensitivity: Double
    @State private var tempSensitivity: Double = 0.5

    var body: some View {
        List {
            // Sensitivity Slider Section
            Section {
                VStack(spacing: 24) {
                    // Visual indicator
                    SensitivityIndicator(sensitivity: tempSensitivity)
                        .frame(height: 120)
                        .padding(.top, 8)

                    // Slider
                    VStack(spacing: 8) {
                        Slider(value: $tempSensitivity, in: 0...1, step: 0.01)
                            .tint(sensitivityColor)

                        HStack {
                            Text("Less Sensitive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("More Sensitive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Detection Sensitivity")
            }

            // Sensitivity Level Description
            Section {
                HStack(spacing: 16) {
                    Image(systemName: sensitivityIcon)
                        .font(.title)
                        .foregroundStyle(sensitivityColor)
                        .frame(width: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(sensitivityLabel)
                            .font(.headline)

                        Text(sensitivityDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Current Level: \(sensitivityLabel)")
            }

            // What sensitivity affects
            Section {
                SensitivityDetailRow(
                    icon: "clock",
                    title: "Detection Time",
                    lowValue: "Longer",
                    highValue: "Shorter",
                    currentValue: tempSensitivity
                )

                SensitivityDetailRow(
                    icon: "arrow.up.arrow.down",
                    title: "Scroll Threshold",
                    lowValue: "More scrolls needed",
                    highValue: "Fewer scrolls needed",
                    currentValue: tempSensitivity
                )

                SensitivityDetailRow(
                    icon: "hand.raised",
                    title: "Intervention Frequency",
                    lowValue: "Less frequent",
                    highValue: "More frequent",
                    currentValue: tempSensitivity
                )
            } header: {
                Text("What This Affects")
            } footer: {
                Text("Higher sensitivity means ScrollTime will intervene more quickly. Lower sensitivity allows more scrolling before triggering an intervention.")
            }

            Section {
                presetButtons
            } header: {
                Text("Quick Presets")
            }
        }
        .navigationTitle("Sensitivity")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            tempSensitivity = sensitivity
        }
        .onDisappear {
            sensitivity = tempSensitivity
        }
    }

    @ViewBuilder
    private var presetButtons: some View {
        ForEach(SensitivityPreset.allCases, id: \.self) { preset in
            Button {
                withAnimation(.spring(response: 0.4)) {
                    tempSensitivity = preset.value
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.name)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Text(preset.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if abs(tempSensitivity - preset.value) < 0.05 {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
    }

    private var sensitivityLabel: String {
        switch tempSensitivity {
        case 0..<0.25: return "Very Low"
        case 0.25..<0.45: return "Low"
        case 0.45..<0.55: return "Medium"
        case 0.55..<0.75: return "High"
        default: return "Very High"
        }
    }

    private var sensitivityDescription: String {
        switch tempSensitivity {
        case 0..<0.25:
            return "ScrollTime will only intervene after extended scrolling sessions. Best for occasional use."
        case 0.25..<0.45:
            return "A relaxed approach that allows moderate scrolling before intervention."
        case 0.45..<0.55:
            return "A balanced setting suitable for most users. Interventions at reasonable intervals."
        case 0.55..<0.75:
            return "More proactive monitoring. Good for building better habits."
        default:
            return "Maximum sensitivity. Interventions will trigger quickly to help break the scroll habit."
        }
    }

    private var sensitivityIcon: String {
        switch tempSensitivity {
        case 0..<0.33: return "tortoise"
        case 0.33..<0.66: return "figure.walk"
        default: return "hare"
        }
    }

    private var sensitivityColor: Color {
        switch tempSensitivity {
        case 0..<0.33: return .green
        case 0.33..<0.66: return .orange
        default: return .red
        }
    }
}

// MARK: - Sensitivity Indicator

private struct SensitivityIndicator: View {
    let sensitivity: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .rotationEffect(.degrees(90))

                // Colored arc
                Circle()
                    .trim(from: 0.15, to: 0.15 + (0.7 * sensitivity))
                    .stroke(
                        AngularGradient(
                            colors: [.green, .yellow, .orange, .red],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .animation(.spring(response: 0.4), value: sensitivity)

                // Needle indicator
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 4, height: geometry.size.width * 0.35)
                    .offset(y: -geometry.size.width * 0.15)
                    .rotationEffect(.degrees(-126 + (252 * sensitivity)))
                    .animation(.spring(response: 0.4), value: sensitivity)

                // Center circle
                Circle()
                    .fill(Color.primary)
                    .frame(width: 16, height: 16)

                // Percentage label
                VStack {
                    Spacer()
                    Text("\(Int(sensitivity * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }
        }
    }
}

// MARK: - Sensitivity Detail Row

private struct SensitivityDetailRow: View {
    let icon: String
    let title: String
    let lowValue: String
    let highValue: String
    let currentValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.green, .yellow, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * currentValue, height: 8)

                    // Indicator
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 2)
                        .offset(x: (geometry.size.width - 16) * currentValue)
                }
            }
            .frame(height: 16)

            HStack {
                Text(lowValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(highValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sensitivity Preset

enum SensitivityPreset: String, CaseIterable, Identifiable {
    case relaxed
    case balanced
    case focused
    case strict

    var id: String { rawValue }

    var name: String {
        switch self {
        case .relaxed: return "Relaxed"
        case .balanced: return "Balanced"
        case .focused: return "Focused"
        case .strict: return "Strict"
        }
    }

    var description: String {
        switch self {
        case .relaxed: return "Minimal interventions for casual monitoring"
        case .balanced: return "Recommended for most users"
        case .focused: return "More frequent check-ins to build awareness"
        case .strict: return "Maximum help breaking the scroll habit"
        }
    }

    var value: Double {
        switch self {
        case .relaxed: return 0.25
        case .balanced: return 0.5
        case .focused: return 0.75
        case .strict: return 0.95
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SensitivityView(sensitivity: .constant(0.5))
    }
}

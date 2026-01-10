import SwiftUI

// MARK: - Animated Splash Screen
// Scrolling dots that melt away - representing breaking free from doom scrolling

struct SplashScreenView: View {
    let onComplete: () -> Void

    @State private var dots: [MeltingDot] = []
    @State private var phase: SplashPhase = .scrolling
    @State private var logoOpacity: Double = 0
    @State private var logoScale: Double = 0.8
    @State private var textOpacity: Double = 0

    private let dotCount = 12
    private let columns = 3

    enum SplashPhase {
        case scrolling
        case melting
        case revealing
        case complete
    }

    var body: some View {
        ZStack {
            // Warm background
            STColors.background.ignoresSafeArea()

            // Melting dots
            ForEach(dots) { dot in
                MeltingDotView(dot: dot, phase: phase)
            }

            // Logo reveal
            VStack(spacing: STSpacing.md) {
                // App icon representation
                ZStack {
                    // Outer circle
                    Circle()
                        .fill(STColors.primaryLight)
                        .frame(width: 120, height: 120)

                    // Inner design - abstract "break free" symbol
                    ZStack {
                        // Broken scroll line
                        BrokenScrollSymbol()
                            .stroke(STColors.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 50, height: 60)
                    }
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // App name
                VStack(spacing: STSpacing.xxs) {
                    Text("ScrollTime")
                        .font(.system(size: 28, weight: .regular, design: .serif))
                        .foregroundColor(STColors.textPrimary)

                    Text("reclaim your attention")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundColor(STColors.textTertiary)
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            initializeDots()
            startAnimation()
        }
    }

    private func initializeDots() {
        dots = (0..<dotCount).map { index in
            let column = index % columns
            let row = index / columns
            let xOffset = CGFloat(column - 1) * 40
            let yOffset = CGFloat(row) * 35 - 70

            return MeltingDot(
                id: index,
                initialX: xOffset,
                initialY: yOffset,
                delay: Double(index) * 0.05
            )
        }
    }

    private func startAnimation() {
        // Phase 1: Dots scroll up
        withAnimation(.easeInOut(duration: 0.8)) {
            phase = .scrolling
        }

        // Phase 2: Dots melt away
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                phase = .melting
            }
        }

        // Phase 3: Logo reveals
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                phase = .revealing
                logoOpacity = 1
                logoScale = 1
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                textOpacity = 1
            }
        }

        // Phase 4: Complete and transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            phase = .complete
            onComplete()
        }
    }
}

// MARK: - Melting Dot Model

struct MeltingDot: Identifiable {
    let id: Int
    let initialX: CGFloat
    let initialY: CGFloat
    let delay: Double
}

// MARK: - Melting Dot View

struct MeltingDotView: View {
    let dot: MeltingDot
    let phase: SplashScreenView.SplashPhase

    @State private var scrollOffset: CGFloat = 100
    @State private var meltOffset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 1
    @State private var blur: CGFloat = 0

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [STColors.primary, STColors.primary.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 24, height: 24)
            .scaleEffect(scale)
            .blur(radius: blur)
            .opacity(opacity)
            .offset(x: dot.initialX, y: dot.initialY + scrollOffset + meltOffset)
            .onChange(of: phase) { _, newPhase in
                animateForPhase(newPhase)
            }
            .onAppear {
                // Initial scroll animation
                withAnimation(.easeInOut(duration: 0.6).delay(dot.delay)) {
                    scrollOffset = 0
                }
            }
    }

    private func animateForPhase(_ phase: SplashScreenView.SplashPhase) {
        switch phase {
        case .scrolling:
            // Continue scrolling motion
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(dot.delay)) {
                scrollOffset = -10
            }

        case .melting:
            // Melt away effect - dots drip and fade
            let meltDelay = Double(dot.id) * 0.06

            withAnimation(.easeIn(duration: 0.5).delay(meltDelay)) {
                meltOffset = CGFloat.random(in: 80...150)
                scale = CGFloat.random(in: 0.3...0.6)
                blur = 8
            }

            withAnimation(.easeOut(duration: 0.4).delay(meltDelay + 0.3)) {
                opacity = 0
            }

        case .revealing, .complete:
            break
        }
    }
}

// MARK: - Broken Scroll Symbol

struct BrokenScrollSymbol: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let midX = rect.midX
        let midY = rect.midY

        // Top part of broken scroll line
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX, y: midY - 8))

        // Break symbol - curves outward
        path.move(to: CGPoint(x: midX - 12, y: midY - 4))
        path.addQuadCurve(
            to: CGPoint(x: midX - 12, y: midY + 4),
            control: CGPoint(x: midX - 20, y: midY)
        )

        path.move(to: CGPoint(x: midX + 12, y: midY - 4))
        path.addQuadCurve(
            to: CGPoint(x: midX + 12, y: midY + 4),
            control: CGPoint(x: midX + 20, y: midY)
        )

        // Bottom part of broken scroll line
        path.move(to: CGPoint(x: midX, y: midY + 8))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY))

        // Small dots at ends
        path.addEllipse(in: CGRect(x: midX - 3, y: rect.minY - 3, width: 6, height: 6))
        path.addEllipse(in: CGRect(x: midX - 3, y: rect.maxY - 3, width: 6, height: 6))

        return path
    }
}

// MARK: - App Icon View (for export reference)

struct AppIconView: View {
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "FAF8F5"),
                            Color(hex: "FEF3EC")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Melting dots pattern
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Circle().fill(STColors.primary).frame(width: 16, height: 16)
                    Circle().fill(STColors.primary.opacity(0.7)).frame(width: 16, height: 16)
                    Circle().fill(STColors.primary.opacity(0.4)).frame(width: 16, height: 16)
                }
                HStack(spacing: 8) {
                    Circle().fill(STColors.primary.opacity(0.8)).frame(width: 16, height: 16)
                    Circle().fill(STColors.primary.opacity(0.5)).frame(width: 16, height: 16)
                    Circle().fill(STColors.primary.opacity(0.2)).frame(width: 16, height: 16)
                }
                HStack(spacing: 8) {
                    MeltingDropShape()
                        .fill(STColors.primary.opacity(0.6))
                        .frame(width: 16, height: 24)
                    MeltingDropShape()
                        .fill(STColors.primary.opacity(0.3))
                        .frame(width: 16, height: 20)
                    MeltingDropShape()
                        .fill(STColors.primary.opacity(0.1))
                        .frame(width: 16, height: 16)
                }
            }
            .offset(y: -5)
        }
        .frame(width: 120, height: 120)
    }
}

// MARK: - Melting Drop Shape

struct MeltingDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Circle at top that drips down
        let circleRadius = rect.width / 2
        let circleCenter = CGPoint(x: rect.midX, y: circleRadius)

        path.addArc(
            center: circleCenter,
            radius: circleRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: true
        )

        // Drip
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.midY + circleRadius)
        )

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: circleRadius),
            control: CGPoint(x: rect.maxX, y: rect.midY + circleRadius)
        )

        return path
    }
}

// MARK: - Preview

#Preview("Splash Screen") {
    SplashScreenView(onComplete: {})
}

#Preview("App Icon") {
    AppIconView()
        .padding(50)
        .background(Color.gray.opacity(0.2))
}

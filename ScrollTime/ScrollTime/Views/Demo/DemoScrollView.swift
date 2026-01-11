//
//  DemoScrollView.swift
//  ScrollTime
//
//  A demo view that simulates a social media-style infinite scroll feed
//  to test doom scroll detection without FamilyControls entitlement.
//  Users can experience the scroll detection and interventions within the app.
//

import SwiftUI
import Combine

// MARK: - Demo Scroll View

struct DemoScrollView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DemoScrollViewModel()

    @State private var showIntervention = false
    @State private var interventionType: InterventionType = .gentleReminder

    var body: some View {
        ZStack {
            // Background
            STColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Stats header
                statsHeader

                // Scrollable feed
                demoFeed
            }

            // Detection status overlay
            if viewModel.isDoomScrollingDetected {
                doomScrollingAlert
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    viewModel.stopMonitoring()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(STColors.textSecondary)
                }
            }

            ToolbarItem(placement: .principal) {
                Text("Demo Feed")
                    .font(STTypography.titleSmall())
                    .foregroundColor(STColors.textPrimary)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.resetSession()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(STColors.textSecondary)
                }
            }
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
        .interventionPresenter(
            isPresented: $showIntervention,
            interventionType: $interventionType,
            onComplete: { result in
                viewModel.handleInterventionResult(result)
            }
        )
        .onChange(of: showIntervention) { _, isShowing in
            // Pause/resume processing based on intervention state
            if isShowing {
                viewModel.pauseProcessing()
            }
        }
        .onReceive(viewModel.$pendingIntervention) { intervention in
            if let type = intervention {
                interventionType = type
                // Small delay to ensure state is stable before presenting
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showIntervention = true
                }
                viewModel.clearPendingIntervention()
            }
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        VStack(spacing: STSpacing.sm) {
            // Primary stats row - session time and intensity
            HStack(spacing: STSpacing.xl) {
                StatBadge(
                    icon: "clock",
                    value: viewModel.formattedDuration,
                    label: "Session"
                )

                StatBadge(
                    icon: "gauge.with.needle",
                    value: viewModel.formattedIntensity,
                    label: "Intensity",
                    valueColor: colorForLevel(viewModel.doomScrollLevel)
                )
            }

            // Doom scroll score bar with better visual
            VStack(spacing: STSpacing.xxs) {
                HStack {
                    Text("Detection Level")
                        .font(STTypography.caption())
                        .foregroundColor(STColors.textTertiary)

                    Spacer()

                    Text(viewModel.doomScrollLevel.rawValue)
                        .font(STTypography.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(colorForLevel(viewModel.doomScrollLevel))
                        .animation(.easeInOut(duration: 0.2), value: viewModel.doomScrollLevel)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(STColors.subtle)

                        // Filled portion
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [colorForLevel(viewModel.doomScrollLevel).opacity(0.8), colorForLevel(viewModel.doomScrollLevel)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * viewModel.doomScrollScore))
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.doomScrollScore)

                        // Threshold markers
                        ForEach([0.35, 0.55, 0.75], id: \.self) { threshold in
                            Rectangle()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 1)
                                .offset(x: geo.size.width * threshold)
                        }
                    }
                }
                .frame(height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Status message with pulsing indicator
            HStack(spacing: STSpacing.xs) {
                Circle()
                    .fill(viewModel.statusColor)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(viewModel.statusColor.opacity(0.5), lineWidth: 2)
                            .scaleEffect(viewModel.isDoomScrollingDetected ? 1.5 : 1.0)
                            .opacity(viewModel.isDoomScrollingDetected ? 0 : 1)
                            .animation(
                                viewModel.isDoomScrollingDetected
                                    ? .easeOut(duration: 1).repeatForever(autoreverses: false)
                                    : .default,
                                value: viewModel.isDoomScrollingDetected
                            )
                    )

                Text(viewModel.statusMessage)
                    .font(STTypography.caption())
                    .foregroundColor(STColors.textSecondary)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.statusMessage)

                Spacer()
            }
        }
        .padding(.horizontal, STSpacing.lg)
        .padding(.vertical, STSpacing.md)
        .background(
            STColors.surface
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private func colorForLevel(_ level: DoomScrollLevel) -> Color {
        switch level {
        case .none: return STColors.success
        case .mild: return Color.yellow
        case .moderate: return Color.orange
        case .elevated: return STColors.primary
        case .severe: return Color.red
        }
    }

    // MARK: - Demo Feed

    private var demoFeed: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: STSpacing.md) {
                // Welcome hint card
                if viewModel.scrollCount < 5 {
                    welcomeHint
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                ForEach(viewModel.posts) { post in
                    DemoPostCard(post: post)
                        .onAppear {
                            // Track scroll events when posts appear
                            viewModel.recordScrollEvent()

                            // Load more posts when near the end
                            if post.id == viewModel.posts.last?.id {
                                viewModel.loadMorePosts()
                            }
                        }
                }

                // Loading indicator at bottom
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: STColors.primary))
                    .padding(.vertical, STSpacing.xl)
            }
            .padding(.horizontal, STSpacing.md)
            .padding(.top, STSpacing.md)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scroll")).origin.y)
                }
            )
            .animation(.easeInOut(duration: 0.3), value: viewModel.scrollCount < 5)
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            viewModel.processScrollOffset(offset)
        }
    }

    // MARK: - Welcome Hint

    private var welcomeHint: some View {
        HStack(spacing: STSpacing.md) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 24))
                .foregroundColor(STColors.primary)

            VStack(alignment: .leading, spacing: STSpacing.xxs) {
                Text("Try scrolling!")
                    .font(STTypography.bodyMedium())
                    .fontWeight(.medium)
                    .foregroundColor(STColors.textPrimary)

                Text("Scroll through this feed to see how ScrollTime detects doom scrolling patterns.")
                    .font(STTypography.caption())
                    .foregroundColor(STColors.textSecondary)
            }
        }
        .padding(STSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: STRadius.lg)
                .fill(STColors.primaryLight.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: STRadius.lg)
                        .stroke(STColors.primary.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Doom Scrolling Alert

    private var doomScrollingAlert: some View {
        VStack {
            Spacer()

            HStack(spacing: STSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)

                Text("Doom scrolling detected")
                    .font(STTypography.bodySmall())
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, STSpacing.lg)
            .padding(.vertical, STSpacing.sm)
            .background(
                Capsule()
                    .fill(STColors.primary)
            )
            .padding(.bottom, STSpacing.xl)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.isDoomScrollingDetected)
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    var valueColor: Color? = nil

    var body: some View {
        VStack(spacing: STSpacing.xxs) {
            HStack(spacing: STSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(valueColor ?? STColors.primary)

                Text(value)
                    .font(STTypography.titleSmall())
                    .fontWeight(.semibold)
                    .foregroundColor(valueColor ?? STColors.textPrimary)
                    .contentTransition(.numericText())
            }
            .animation(.spring(response: 0.3), value: value)

            Text(label)
                .font(STTypography.caption())
                .foregroundColor(STColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Demo Post Card

private struct DemoPostCard: View {
    let post: DemoPost

    @State private var isLiked = false

    var body: some View {
        STCard {
            VStack(alignment: .leading, spacing: STSpacing.sm) {
                // Header
                HStack(spacing: STSpacing.sm) {
                    // Avatar
                    Circle()
                        .fill(post.avatarColor)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(post.authorInitial)
                                .font(STTypography.bodyMedium())
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.authorName)
                            .font(STTypography.bodyMedium())
                            .fontWeight(.medium)
                            .foregroundColor(STColors.textPrimary)

                        Text(post.timeAgo)
                            .font(STTypography.caption())
                            .foregroundColor(STColors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "ellipsis")
                        .foregroundColor(STColors.textTertiary)
                }

                // Content
                Text(post.content)
                    .font(STTypography.bodyMedium())
                    .foregroundColor(STColors.textPrimary)
                    .lineSpacing(4)

                // Image placeholder (if applicable)
                if post.hasImage {
                    RoundedRectangle(cornerRadius: STRadius.md)
                        .fill(
                            LinearGradient(
                                colors: [post.imageGradientStart, post.imageGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: post.imageIcon)
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(.white.opacity(0.6))
                        )
                }

                // Actions
                HStack(spacing: STSpacing.xl) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isLiked.toggle()
                        }
                    } label: {
                        HStack(spacing: STSpacing.xxs) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundColor(isLiked ? STColors.primary : STColors.textTertiary)
                            Text("\(post.likes + (isLiked ? 1 : 0))")
                                .font(STTypography.caption())
                                .foregroundColor(STColors.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: STSpacing.xxs) {
                        Image(systemName: "bubble.left")
                            .foregroundColor(STColors.textTertiary)
                        Text("\(post.comments)")
                            .font(STTypography.caption())
                            .foregroundColor(STColors.textTertiary)
                    }

                    HStack(spacing: STSpacing.xxs) {
                        Image(systemName: "arrow.2.squarepath")
                            .foregroundColor(STColors.textTertiary)
                        Text("\(post.shares)")
                            .font(STTypography.caption())
                            .foregroundColor(STColors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "bookmark")
                        .foregroundColor(STColors.textTertiary)
                }
                .font(.system(size: 14))
            }
            .padding(STSpacing.md)
        }
    }
}

// MARK: - Demo Post Model

struct DemoPost: Identifiable {
    let id: UUID
    let authorName: String
    let authorInitial: String
    let avatarColor: Color
    let content: String
    let timeAgo: String
    let likes: Int
    let comments: Int
    let shares: Int
    let hasImage: Bool
    let imageGradientStart: Color
    let imageGradientEnd: Color
    let imageIcon: String

    static func random(index: Int) -> DemoPost {
        let authors = [
            ("Alex Chen", "A", Color(hex: "6B8EBF")),
            ("Jordan Taylor", "J", Color(hex: "E07A3D")),
            ("Sam Rivera", "S", Color(hex: "4A9B6E")),
            ("Morgan Lee", "M", Color(hex: "9B6B9B")),
            ("Casey Kim", "C", Color(hex: "BF6B8E")),
            ("Riley Park", "R", Color(hex: "8EBF6B")),
            ("Drew Johnson", "D", Color(hex: "6B9BBF")),
            ("Quinn Adams", "Q", Color(hex: "BF8E6B"))
        ]

        let contents = [
            "Just discovered an amazing coffee shop downtown. The atmosphere is perfect for getting work done!",
            "Anyone else thinking about trying that new mindfulness app? I've heard great things about it.",
            "Beautiful sunset today. Sometimes you just need to stop and appreciate the little things.",
            "Finally finished reading that book everyone's been talking about. Highly recommend!",
            "Working on a new project that I'm really excited about. Can't wait to share more soon!",
            "Had the best workout this morning. Starting the day right makes all the difference.",
            "Exploring new hiking trails this weekend. Nature is the best therapy.",
            "Just made the most amazing homemade pasta. Cooking is such a great stress reliever.",
            "Grateful for the little moments that make life special. What are you thankful for today?",
            "Learning a new skill is so rewarding. Never stop growing!",
            "Quality time with friends is priceless. Who's your go-to person?",
            "Sometimes the best plan is no plan at all. Spontaneous adventures are the best.",
            "Meditation has been a game changer for my mental health. Anyone else practice regularly?",
            "Just finished a digital detox weekend. It's incredible how refreshing it can be.",
            "New week, new goals. What are you working towards?"
        ]

        let timeAgos = ["2m", "5m", "12m", "28m", "1h", "2h", "3h", "5h"]

        let imageIcons = ["photo", "mountain.2", "leaf", "cup.and.saucer", "book", "figure.run", "sun.max", "heart"]

        let gradients: [(Color, Color)] = [
            (Color(hex: "667eea"), Color(hex: "764ba2")),
            (Color(hex: "f093fb"), Color(hex: "f5576c")),
            (Color(hex: "4facfe"), Color(hex: "00f2fe")),
            (Color(hex: "43e97b"), Color(hex: "38f9d7")),
            (Color(hex: "fa709a"), Color(hex: "fee140")),
            (Color(hex: "a8edea"), Color(hex: "fed6e3")),
            (Color(hex: "ff9a9e"), Color(hex: "fecfef")),
            (Color(hex: "ffecd2"), Color(hex: "fcb69f"))
        ]

        let author = authors[index % authors.count]
        let gradient = gradients[index % gradients.count]
        let hasImage = index % 3 != 0 // 2/3 of posts have images

        return DemoPost(
            id: UUID(),
            authorName: author.0,
            authorInitial: author.1,
            avatarColor: author.2,
            content: contents[index % contents.count],
            timeAgo: timeAgos[index % timeAgos.count],
            likes: Int.random(in: 5...500),
            comments: Int.random(in: 0...50),
            shares: Int.random(in: 0...20),
            hasImage: hasImage,
            imageGradientStart: gradient.0,
            imageGradientEnd: gradient.1,
            imageIcon: imageIcons[index % imageIcons.count]
        )
    }
}

// MARK: - Demo Scroll View Model

@MainActor
class DemoScrollViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var posts: [DemoPost] = []
    @Published private(set) var scrollCount: Int = 0
    @Published private(set) var sessionDuration: TimeInterval = 0
    @Published private(set) var currentIntensity: Double = 0
    @Published private(set) var isDoomScrollingDetected: Bool = false
    @Published private(set) var statusMessage: String = "Ready to monitor"
    @Published var pendingIntervention: InterventionType? = nil

    // Detailed metrics for display
    @Published private(set) var currentVelocity: Double = 0
    @Published private(set) var doomScrollScore: Double = 0
    @Published private(set) var doomScrollLevel: DoomScrollLevel = .none
    @Published private(set) var downwardRatio: Double = 0

    // MARK: - Private State

    private var scrollDetector: ScrollDetector?
    private var velocityTracker: VelocityTracker?
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private var postIndex: Int = 0
    private var isInitialized = false

    // Scroll tracking state
    private var lastScrollOffset: CGFloat = 0
    private var lastScrollTime: Date = Date()
    private var isProcessingPaused: Bool = false
    private var isLoadingMorePosts: Bool = false

    // MARK: - Computed Properties

    var formattedDuration: String {
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedIntensity: String {
        String(format: "%.0f%%", currentIntensity * 100)
    }

    var statusColor: Color {
        if isDoomScrollingDetected {
            return STColors.primary
        } else if currentIntensity > 0.5 {
            return Color(hex: "E0A33D") // Warning amber
        } else if scrollDetector?.isMonitoring == true {
            return STColors.success
        } else {
            return STColors.textTertiary
        }
    }

    // MARK: - Initialization

    init() {
        loadInitialPosts()
    }

    deinit {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    // MARK: - Setup

    private func loadInitialPosts() {
        posts = (0..<20).map { DemoPost.random(index: $0) }
        postIndex = 20
    }

    private func initializeDetection() {
        guard !isInitialized else { return }
        isInitialized = true

        // Initialize components lazily to avoid crashes during view construction
        scrollDetector = ScrollDetector(config: .demoMode)
        velocityTracker = VelocityTracker(configuration: .default)

        setupSubscriptions()
    }

    private func setupSubscriptions() {
        guard let scrollDetector = scrollDetector else { return }

        // Subscribe to scroll detector events
        scrollDetector.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleDetectionEvent(event)
            }
            .store(in: &cancellables)

        // Subscribe to intensity updates - this is the single source of truth
        scrollDetector.$currentIntensity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] intensity in
                guard let self = self, let intensity = intensity else { return }
                // Update all intensity-related UI from ScrollDetector
                self.currentIntensity = intensity.score
                self.doomScrollScore = intensity.score
                self.doomScrollLevel = self.mapIntensityLevel(intensity.level)
            }
            .store(in: &cancellables)

        // Subscribe to doom scrolling detection
        scrollDetector.$isDoomScrollingDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in
                self?.isDoomScrollingDetected = detected
            }
            .store(in: &cancellables)

        // Subscribe to session changes - update scroll count AND downward ratio
        scrollDetector.$currentSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                guard let self = self, let session = session else { return }
                self.scrollCount = session.totalScrollCount
                self.downwardRatio = session.downwardScrollRatio
            }
            .store(in: &cancellables)
    }

    /// Maps ScrollDetector's IntensityLevel to DoomScrollLevel for UI display
    private func mapIntensityLevel(_ level: ScrollIntensity.IntensityLevel) -> DoomScrollLevel {
        switch level {
        case .low: return .none
        case .moderate: return .mild
        case .elevated: return .moderate
        case .high: return .elevated
        case .critical: return .severe
        }
    }

    // MARK: - Public Methods

    func startMonitoring() {
        initializeDetection()
        isProcessingPaused = false
        lastScrollOffset = 0
        lastScrollTime = Date()
        scrollDetector?.startMonitoring(appBundleID: "com.scrolltime.demo")
        startSessionTimer()
        statusMessage = "Detecting scrolling..."
    }

    func stopMonitoring() {
        scrollDetector?.stopMonitoring()
        stopSessionTimer()
        isProcessingPaused = true
        statusMessage = "Monitoring stopped"
    }

    func pauseProcessing() {
        isProcessingPaused = true
        stopSessionTimer()
    }

    func resumeProcessing() {
        isProcessingPaused = false
        // Reset scroll tracking to avoid velocity spikes
        lastScrollOffset = 0
        lastScrollTime = Date()
        startSessionTimer()
    }

    func resetSession() {
        stopSessionTimer()
        scrollDetector?.reset()
        velocityTracker?.reset()
        sessionDuration = 0
        scrollCount = 0
        currentIntensity = 0
        currentVelocity = 0
        doomScrollScore = 0
        doomScrollLevel = .none
        downwardRatio = 0
        isDoomScrollingDetected = false
        lastScrollOffset = 0
        lastScrollTime = Date()
        isProcessingPaused = false
        posts = []
        postIndex = 0
        loadInitialPosts()
        startMonitoring()
        statusMessage = "Ready to scroll!"
    }

    func loadMorePosts() {
        // Prevent multiple concurrent loads
        guard !isLoadingMorePosts else { return }
        isLoadingMorePosts = true

        let newPosts = (postIndex..<postIndex + 10).map { DemoPost.random(index: $0) }
        posts.append(contentsOf: newPosts)
        postIndex += 10

        isLoadingMorePosts = false
    }

    func handleInterventionResult(_ result: InterventionResult) {
        // Resume processing after intervention
        resumeProcessing()

        // Reset cooldowns after intervention is handled
        if result.wasPositiveEngagement {
            scrollDetector?.resetCooldowns()
            statusMessage = "Great job taking a break!"
        } else {
            statusMessage = "Continuing to monitor..."
        }
    }

    func clearPendingIntervention() {
        pendingIntervention = nil
    }

    // MARK: - Scroll Tracking (Simplified)

    /// Records a scroll event when a post appears (user scrolled to it)
    /// This is a lightweight method - just increments scroll count
    func recordScrollEvent() {
        guard !isProcessingPaused else { return }
        guard let detector = scrollDetector else { return }

        // Just record a simple scroll - don't do heavy analysis here
        detector.processScroll(velocity: 300, direction: .down)
    }

    /// Processes scroll offset changes to calculate velocity
    /// Throttled to avoid excessive CPU usage
    func processScrollOffset(_ offset: CGFloat) {
        // Skip if paused (during intervention)
        guard !isProcessingPaused else { return }

        // Safely unwrap required components
        guard let detector = scrollDetector,
              let tracker = velocityTracker else {
            return
        }

        let now = Date()
        let timeDelta = now.timeIntervalSince(lastScrollTime)

        // Throttle: minimum 50ms between updates (20 FPS max)
        guard timeDelta > 0.05 else { return }

        let offsetDelta = offset - lastScrollOffset

        // Skip tiny movements
        guard abs(offsetDelta) > 2 else { return }

        // Calculate velocity safely
        let velocity = min(abs(offsetDelta / CGFloat(timeDelta)), 5000)

        // Update velocity display
        currentVelocity = Double(velocity)

        // Record velocity in tracker (for ScrollDetector's internal use)
        tracker.recordVelocity(velocity: CGPoint(x: 0, y: offsetDelta))

        // Determine direction
        let direction: ScrollDirection = offsetDelta < 0 ? .down : .up

        // Process scroll event - this will update ScrollDetector's internal state
        // and trigger subscription updates for intensity, scroll count, etc.
        if abs(offsetDelta) > 5 {
            detector.processScroll(velocity: Double(velocity), direction: direction)
        }

        // Update tracking state
        lastScrollOffset = offset
        lastScrollTime = now
    }

    // MARK: - Private Methods

    private func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.isProcessingPaused else { return }
                self.sessionDuration += 1
            }
        }
    }

    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    private func handleDetectionEvent(_ event: DetectionEvent) {
        // Don't process events if paused
        guard !isProcessingPaused else { return }

        switch event {
        case .sessionStarted(_):
            statusMessage = "Monitoring started"

        case .sessionEnded(_):
            statusMessage = "Session complete"

        case .gentleIntervention(_, _):
            // Pause processing before showing intervention
            pauseProcessing()
            statusMessage = "Time for a check-in"
            pendingIntervention = .gentleReminder

        case .firmIntervention(_, _):
            pauseProcessing()
            statusMessage = "Let's take a breath"
            pendingIntervention = .breathingExercise

        case .mandatoryBreak(_, _):
            pauseProcessing()
            statusMessage = "Break time"
            pendingIntervention = .timedPause

        case .intensityUpdated(let intensity):
            updateStatusForIntensity(intensity.score)

        case .pauseDetected(_):
            statusMessage = "Nice pause!"

        case .metricsUpdated(_):
            break // Handled by other publishers

        case .monitoringStateChanged(_, _):
            break // Handled by isMonitoring state
        }
    }

    private func updateStatusForIntensity(_ score: Double) {
        if score < 0.2 {
            statusMessage = "Just browsing..."
        } else if score < 0.35 {
            statusMessage = "Scrolling detected"
        } else if score < 0.55 {
            statusMessage = "Getting into a scroll..."
        } else if score < 0.75 {
            statusMessage = "Scroll intensity rising"
        } else {
            statusMessage = "Doom scroll detected!"
        }
    }
}

// MARK: - Demo Mode Configuration

extension DetectionConfig {
    /// A configuration optimized for demo purposes - balanced to feel natural
    static let demoMode = DetectionConfig(
        minimumSessionDuration: 20,           // 20 seconds before detection starts
        extendedSessionDuration: 45,          // 45 seconds for extended
        maximumSessionDuration: 180,          // 3 minutes max
        minimumScrollCount: 15,               // 15 scrolls minimum before detection
        highActivityScrollCount: 35,          // 35 for high activity
        minimumVelocity: 50,                  // Moderate velocity threshold
        rapidScrollVelocity: 800,             // Higher rapid threshold
        velocityClampMax: 2000,               // Clamp at 2000 pts/s
        analysisWindowDuration: 30,           // 30 second analysis window
        pauseBreakThreshold: 3,               // 3 second pause resets intensity
        downwardScrollRatio: 0.65,            // 65% downward for doom scroll
        directionChangeRateThreshold: 10,     // Direction change threshold
        gentleInterventionThreshold: 0.45,    // 45% intensity for gentle (was 35%)
        firmInterventionThreshold: 0.65,      // 65% for firm (was 55%)
        mandatoryBreakThreshold: 0.85,        // 85% for mandatory (was 75%)
        gentleCooldownPeriod: 30,             // 30 sec between gentle
        firmCooldownPeriod: 60,               // 60 sec between firm
        postBreakCooldownPeriod: 90,          // 90 sec after break
        velocityEMAAlpha: 0.3,                // Smoother response
        rollingWindowSize: 25,                // Moderate window
        lowPowerModeReductionFactor: 1.0,     // No reduction in demo
        minimumProcessingInterval: 0.03       // Balanced processing
    )
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DemoScrollView()
    }
}

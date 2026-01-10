import Foundation

/// A simplified view model representation of a scroll session for UI display.
/// The full ScrollSession with detailed event tracking is in Core/ScrollDetection.
/// Note: A more detailed ScrollSessionSummary is in Core/ScrollDetection/ScrollSession.swift
struct UIScrollSessionSummary: Codable, Identifiable {
    let id: UUID

    /// When the session started
    let startTime: Date

    /// When the session ended (nil if ongoing)
    var endTime: Date?

    /// The app being used during this session
    let appBundleId: String
    let appName: String

    /// Number of detected scroll events
    var scrollEventCount: Int

    /// Whether an intervention was triggered
    var interventionTriggered: Bool

    /// Whether the user stopped after intervention
    var stoppedAfterIntervention: Bool

    /// Session duration in seconds
    var durationSeconds: Int {
        let end = endTime ?? Date()
        return Int(end.timeIntervalSince(startTime))
    }

    /// Whether the session is currently active
    var isActive: Bool {
        endTime == nil
    }

    /// Formatted duration string
    var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        appBundleId: String,
        appName: String,
        scrollEventCount: Int = 0,
        interventionTriggered: Bool = false,
        stoppedAfterIntervention: Bool = false
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.appBundleId = appBundleId
        self.appName = appName
        self.scrollEventCount = scrollEventCount
        self.interventionTriggered = interventionTriggered
        self.stoppedAfterIntervention = stoppedAfterIntervention
    }

    /// End the session
    mutating func end() {
        endTime = Date()
    }

    /// Record a scroll event
    mutating func recordScrollEvent() {
        scrollEventCount += 1
    }

    /// Sample session for previews
    static var sample: UIScrollSessionSummary {
        UIScrollSessionSummary(
            startTime: Date().addingTimeInterval(-300),
            appBundleId: "com.instagram.app",
            appName: "Instagram",
            scrollEventCount: 45
        )
    }
}

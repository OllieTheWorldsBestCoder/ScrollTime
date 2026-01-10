# ScrollTime - Feature Implementation Plan

## Design Philosophy
- **Tone**: Gentle celebration - acknowledge wins without pressure
- **No guilt**: Never say "streak broken" - just fresh starts
- **Warm & encouraging**: Claude-inspired voice throughout

---

## Feature Set 1: Insights & Reports

### 1.1 Weekly Insights Report
A beautiful, digestible summary of the user's week.

**Screen: `WeeklyReportView.swift`**

```
┌─────────────────────────────────────┐
│  Your Week in Review                │
│  Jan 6 - Jan 12                     │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │   2h 34m                    │   │
│  │   total scroll time         │   │
│  │   ↓ 45min from last week    │   │
│  └─────────────────────────────┘   │
│                                     │
│  Daily Breakdown                    │
│  M  T  W  T  F  S  S               │
│  ▁  ▃  ▂  ▅  ▂  ▇  ▄               │
│                                     │
│  Your Best Day: Wednesday          │
│  "Only 18 minutes - nice work!"    │
│                                     │
├─────────────────────────────────────┤
│  Time Reclaimed                     │
│                                     │
│  You took 12 mindful pauses        │
│  and reclaimed ~1.5 hours          │
│                                     │
│  That's enough time to:            │
│  ☕ Have coffee with a friend      │
│  📖 Read 3 chapters of a book      │
│                                     │
├─────────────────────────────────────┤
│  Top Apps                           │
│  1. TikTok      52min              │
│  2. Instagram   48min              │
│  3. Twitter     34min              │
│                                     │
├─────────────────────────────────────┤
│  Pattern Spotted                    │
│  📍 Most scrolling happens         │
│     between 9-11pm                 │
│                                     │
│  💡 Tip: Try setting a wind-down   │
│     reminder at 9pm                │
│                                     │
└─────────────────────────────────────┘
```

**Data Model: `WeeklyReport.swift`**
```swift
struct WeeklyReport {
    let weekStartDate: Date
    let totalScrollTime: TimeInterval
    let previousWeekScrollTime: TimeInterval
    let dailyBreakdown: [DailyScrollData]
    let topApps: [(appName: String, duration: TimeInterval)]
    let interventionsTaken: Int
    let interventionsCompleted: Int
    let peakScrollHour: Int // 0-23
    let bestDay: Date
    let bestDayDuration: TimeInterval
}

struct DailyScrollData: Identifiable {
    let id = UUID()
    let date: Date
    let totalDuration: TimeInterval
    let sessionCount: Int
    let interventionCount: Int
}
```

**Generation**: Run every Sunday night, push notification Monday morning

---

### 1.2 Session History View
Detailed log of all scroll sessions.

**Screen: `SessionHistoryView.swift`**

```
┌─────────────────────────────────────┐
│  ← Session History                  │
├─────────────────────────────────────┤
│  Today                              │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🎵 TikTok                   │   │
│  │ 10:34 AM · 8 minutes        │   │
│  │ ✓ Took a breathing break    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📸 Instagram                │   │
│  │ 9:12 AM · 4 minutes         │   │
│  │ Under threshold - no pause  │   │
│  └─────────────────────────────┘   │
│                                     │
│  Yesterday                          │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🐦 Twitter                  │   │
│  │ 11:45 PM · 22 minutes       │   │
│  │ ⚡ Continued after reminder │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📸 Instagram                │   │
│  │ 8:30 PM · 6 minutes         │   │
│  │ ✓ Ended session naturally   │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**Data tracked per session:**
- App name & icon
- Start time, duration
- Intervention triggered? Which type?
- Outcome: completed, skipped, continued scrolling

---

### 1.3 Pattern Insights
Intelligent observations about user behavior.

**Insights Engine: `PatternAnalyzer.swift`**
```swift
enum InsightType {
    case peakUsageTime(hour: Int)
    case bestDay(dayOfWeek: Int)
    case appTrend(app: String, direction: TrendDirection)
    case streakCelebration(days: Int)
    case improvementNotice(percentDecrease: Double)
    case consistentPauser // takes breaks regularly
}

struct Insight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let message: String
    let emoji: String
    let actionSuggestion: String?
    let generatedAt: Date
}
```

**Example Insights:**
- "You scroll most between 9-11pm. Wind-down mode could help!"
- "Wednesdays are your calmest day. What's different?"
- "You've reduced TikTok time by 30% this month"
- "You complete breathing exercises 80% of the time - that's wonderful"

---

## Feature Set 2: Positive Reinforcement (Gentle)

### 2.1 Streaks (No Guilt Version)

**Model: `MindfulStreak.swift`**
```swift
struct MindfulStreak {
    let currentStreak: Int // days under goal
    let longestStreak: Int
    let lastUnderGoalDate: Date?

    // Never shows "broken" - just current state
    var message: String {
        if currentStreak == 0 {
            return "Today is a fresh start"
        } else if currentStreak == 1 {
            return "One mindful day"
        } else {
            return "\(currentStreak) mindful days"
        }
    }
}
```

**UI: Small, non-intrusive badge on Dashboard**
```
┌──────────────────┐
│  🌱 4 days       │
│  under goal      │
└──────────────────┘
```

**Key principle**: When streak "breaks", don't announce it. Just show "Today is a fresh start" with a seedling emoji. New beginnings, not failures.

---

### 2.2 Milestones

**Milestone Types:**
```swift
enum Milestone {
    case firstMindfulDay
    case threeDayStreak
    case oneWeekStreak
    case twoWeekStreak
    case oneMonthStreak
    case hourReclaimed(hours: Int) // 1, 5, 10, 24, 50, 100
    case breathingExercisesCompleted(count: Int) // 10, 25, 50, 100
    case interventionsMastered // completed 90%+ for a week
}
```

**Celebration Screen: `MilestoneCelebrationView.swift`**
- Appears as subtle modal, not blocking
- Warm animation (confetti feels too aggressive - maybe gentle glow/pulse)
- "You've reclaimed 10 hours this month" with encouraging message
- Dismiss with tap anywhere

---

### 2.3 Time Reclaimed Counter

**Dashboard Widget:**
```
┌─────────────────────────────────┐
│  Time Reclaimed                 │
│                                 │
│  4h 32m                         │
│  this month                     │
│                                 │
│  That's a movie marathon       │
│  or a long lunch with friends  │
└─────────────────────────────────┘
```

**Calculation**: Sum of (intervention duration + estimated "would have scrolled" time based on typical session length)

---

## Feature Set 3: Proactive Wellness

### 3.1 Morning Intention

**Trigger**: Configurable time (default 8am), gentle notification

**Screen: `MorningIntentionView.swift`**
```
┌─────────────────────────────────────┐
│                                     │
│  Good morning                       │
│                                     │
│  What would make today              │
│  feel meaningful?                   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Focus on work               │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ Connect with friends        │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ Take it easy                │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ Skip for today              │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**Effect**: Selection influences intervention sensitivity
- "Focus on work" → stricter during work hours
- "Take it easy" → gentler thresholds
- Shown in evening reflection

---

### 3.2 Evening Wind-Down

**Trigger**: User-set time (default 9pm)

**Flow:**
1. Gentle notification: "Time to start winding down"
2. If opened, shows Wind-Down screen:

```
┌─────────────────────────────────────┐
│                                     │
│  Wind-Down Time                     │
│                                     │
│  🌙                                 │
│                                     │
│  You've used your phone for         │
│  3h 24m today                       │
│                                     │
│  As bedtime approaches,             │
│  ScrollTime will gently             │
│  encourage you to rest.             │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Start Wind-Down Mode        │   │
│  └─────────────────────────────┘   │
│                                     │
│  Not tonight                        │
│                                     │
└─────────────────────────────────────┘
```

**Wind-Down Mode Effects:**
- Intervention thresholds reduced (triggers sooner)
- Softer intervention messages ("Rest is calling")
- Optional: Display dimming reminder
- Ends at wake time or manually

---

### 3.3 Evening Reflection

**Trigger**: 30min before typical bedtime

**Screen: `EveningReflectionView.swift`**
```
┌─────────────────────────────────────┐
│                                     │
│  How was today?                     │
│                                     │
│  You scrolled for 1h 12m           │
│  (32min under your goal)           │
│                                     │
│  This morning you wanted to:        │
│  "Focus on work"                    │
│                                     │
│  How did it go?                     │
│                                     │
│  😊        😐        😔            │
│  Great    Okay     Tough           │
│                                     │
│  ──────────────────────────────    │
│                                     │
│  Any thoughts? (optional)           │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  [Save & Rest Well]                │
│                                     │
└─────────────────────────────────────┘
```

**Data stored**: Mood + optional note → feeds into pattern analysis

---

## Implementation Plan

### Files to Create

**Models:**
- `Models/WeeklyReport.swift`
- `Models/MindfulStreak.swift`
- `Models/Milestone.swift`
- `Models/Insight.swift`
- `Models/DailyIntention.swift`
- `Models/EveningReflection.swift`

**Services:**
- `Core/Analytics/PatternAnalyzer.swift`
- `Core/Analytics/ReportGenerator.swift`
- `Core/Analytics/MilestoneTracker.swift`
- `Core/Wellness/IntentionManager.swift`
- `Core/Wellness/WindDownManager.swift`

**Views:**
- `Views/Insights/WeeklyReportView.swift`
- `Views/Insights/SessionHistoryView.swift`
- `Views/Insights/InsightCardView.swift`
- `Views/Celebration/MilestoneCelebrationView.swift`
- `Views/Wellness/MorningIntentionView.swift`
- `Views/Wellness/WindDownView.swift`
- `Views/Wellness/EveningReflectionView.swift`

**Dashboard Updates:**
- Add streak badge
- Add "Time Reclaimed" widget
- Add "View Report" button
- Add insight cards carousel

---

## Build Order

### Phase 1: Foundation
1. Data models for tracking
2. Session history storage
3. Basic session history view

### Phase 2: Insights
4. Weekly report data aggregation
5. Weekly report view
6. Pattern analyzer basics

### Phase 3: Reinforcement
7. Streak tracking
8. Milestone system
9. Time reclaimed calculator
10. Celebration view

### Phase 4: Wellness
11. Morning intention flow
12. Evening reflection flow
13. Wind-down mode
14. Notification scheduling

### Phase 5: Polish
15. Dashboard integration
16. Insight cards on dashboard
17. Settings for all new features
18. Animation refinements

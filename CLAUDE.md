# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ScrollTime** is an iOS app that detects endless scrolling behavior (doom scrolling) and intervenes to break the habit. Unlike traditional screen time apps that only track duration, ScrollTime detects the *action* of repeated scrolling and provides real-time interventions.

### Core Features
- Detect rapid, repeated scrolling patterns on apps like Instagram, TikTok, Twitter, Reddit
- Trigger interventions (breathing exercises, timers, friction dialogs) when doom scrolling is detected
- Track usage patterns with Screen Time API integration
- Battery-efficient background monitoring

### Technical Approach
- **Screen Time API (FamilyControls/DeviceActivity)** - Track when user opens target apps
- **Scroll Detection Heuristics** - Infer scrolling from usage patterns, session duration, gesture analysis
- **Native SwiftUI** - Modern iOS UI framework
- **Demo Mode** - Works without FamilyControls entitlement for initial testing

## Build Commands

```bash
# Build for device (release)
xcodebuild -project ScrollTime.xcodeproj -scheme ScrollTime -sdk iphoneos -configuration Release build

# Build for simulator (debug)
xcodebuild -project ScrollTime.xcodeproj -scheme ScrollTime -sdk iphonesimulator -configuration Debug build

# Run tests
xcodebuild -project ScrollTime.xcodeproj -scheme ScrollTime -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' test

# Clean build
xcodebuild -project ScrollTime.xcodeproj -scheme ScrollTime clean

# List available simulators
xcrun simctl list devices available

# Install on connected device (requires signing)
xcodebuild -project ScrollTime.xcodeproj -scheme ScrollTime -sdk iphoneos -configuration Debug -destination 'generic/platform=iOS' build
```

## Architecture

```
ScrollTime/
├── ScrollTime.xcodeproj
├── ScrollTime/
│   ├── App/
│   │   ├── ScrollTimeApp.swift           # App entry point, FamilyControls auth
│   │   └── AppDelegate.swift             # Background task registration
│   │
│   ├── Core/
│   │   ├── ScrollDetection/
│   │   │   ├── ScrollDetector.swift      # Main detection engine
│   │   │   ├── GestureAnalyzer.swift     # Scroll pattern recognition
│   │   │   ├── ScrollSession.swift       # Track individual scroll sessions
│   │   │   └── DetectionConfig.swift     # Sensitivity thresholds
│   │   │
│   │   ├── ScreenTime/
│   │   │   ├── ScreenTimeManager.swift   # FamilyControls integration
│   │   │   ├── AppMonitor.swift          # DeviceActivity monitoring
│   │   │   └── TargetApps.swift          # Apps to monitor (IG, TikTok, etc)
│   │   │
│   │   ├── Battery/
│   │   │   ├── PowerManager.swift        # Battery-efficient scheduling
│   │   │   └── BackgroundTasks.swift     # BGTaskScheduler setup
│   │   │
│   │   └── Intervention/
│   │       ├── InterventionManager.swift # When/how to intervene
│   │       ├── InterventionType.swift    # Types of interventions
│   │       └── EscalationEngine.swift    # Gentle → firm progression
│   │
│   ├── Views/
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift       # Main app screen
│   │   │   └── UsageStatsView.swift      # Usage statistics
│   │   │
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift        # App configuration
│   │   │   ├── AppSelectionView.swift    # Choose apps to monitor
│   │   │   └── SensitivityView.swift     # Detection sensitivity
│   │   │
│   │   ├── Intervention/
│   │   │   ├── InterventionView.swift    # Base intervention container
│   │   │   ├── BreathingView.swift       # Breathing exercise
│   │   │   ├── TimerView.swift           # Wait timer
│   │   │   └── FrictionView.swift        # Deliberate friction UI
│   │   │
│   │   └── Onboarding/
│   │       └── OnboardingView.swift      # First-time setup
│   │
│   ├── Models/
│   │   ├── ScrollSession.swift           # Scroll session data
│   │   ├── DailyStats.swift              # Daily usage statistics
│   │   └── UserPreferences.swift         # User settings
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist
│
├── ScrollTimeMonitor/                     # DeviceActivity Monitor Extension
│   ├── ScrollTimeMonitor.swift
│   └── Info.plist
│
└── ScrollTimeShield/                      # Shield Configuration Extension
    ├── ShieldConfiguration.swift
    └── Info.plist
```

## Specialized Sub-Agents

This project uses specialized agents for parallel development. Invoke them via the Task tool:

| Agent | Use For |
|-------|---------|
| `ios-scroll-detection` | Gesture recognition, scroll pattern analysis, detection algorithms |
| `ios-battery` | Background execution, power efficiency, BGTaskScheduler |
| `ios-habit-intervention` | Intervention UX, breathing exercises, behavioral psychology |
| `ios-screentime-api` | FamilyControls, DeviceActivity, Shield configuration |
| `ios-swiftui` | Views, navigation, state management, animations |

### When to Use Each Agent

- **Building detection logic** → `ios-scroll-detection`
- **Optimizing background tasks** → `ios-battery`
- **Designing intervention UI** → `ios-habit-intervention`
- **Screen Time integration** → `ios-screentime-api`
- **Any SwiftUI view work** → `ios-swiftui`

## Key Technical Decisions

### Scroll Detection Strategy
1. **In-app gesture tracking** - When our app is in focus, use gesture recognizers
2. **Usage pattern heuristics** - Long sessions + no app switches = likely scrolling
3. **Time-based thresholds** - Configurable triggers (e.g., 5 min continuous use)
4. **Future: ML enhancement** - On-device model for improved accuracy

### Battery Optimization
- Use `BGTaskScheduler` for periodic checks, not timers
- Coalesce operations to minimize wake-ups
- Respect Low Power Mode via `ProcessInfo.processInfo.isLowPowerModeEnabled`
- Target < 1% battery impact per hour of monitoring

### Intervention Philosophy
- **Graduated escalation**: Gentle reminder → Firm pause → Required break
- **User agency**: Always allow override, but with friction
- **Positive framing**: "Take a breath" not "You're addicted"
- **Build trust**: Don't be annoying, be helpful

## Development Workflow

### Iterative Build Loop
```bash
# Watch for changes and rebuild
while true; do
  xcodebuild -project ScrollTime.xcodeproj -scheme ScrollTime -sdk iphonesimulator -configuration Debug build 2>&1 | tail -20
  echo "Build complete. Press enter to rebuild, Ctrl+C to exit"
  read
done
```

### Testing on Physical Device
1. Connect iPhone via USB
2. Enable Developer Mode on device (Settings → Privacy & Security → Developer Mode)
3. Open Xcode, select your device as destination
4. Build and run (Cmd+R in Xcode, or use xcodebuild)

### FamilyControls Entitlement
- Required for full Screen Time integration
- Request at: https://developer.apple.com/contact/request/family-controls-distribution
- App works in "demo mode" without it (manual app selection, in-app detection only)

## Info.plist Required Entries

```xml
<!-- Background processing -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.scrolltime.refresh</string>
    <string>com.scrolltime.processing</string>
</array>

<!-- Background modes -->
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
    <string>fetch</string>
</array>

<!-- Usage descriptions -->
<key>NSFamilyControlsUsageDescription</key>
<string>ScrollTime monitors app usage to detect doom scrolling patterns.</string>
```

## Entitlements Required

```xml
<!-- ScrollTime.entitlements -->
<key>com.apple.developer.family-controls</key>
<true/>
```

## Testing Checklist

- [ ] App launches without crash
- [ ] FamilyControls authorization flow works (or graceful degradation in demo mode)
- [ ] Scroll detection triggers after configured threshold
- [ ] Intervention view appears and is dismissable
- [ ] Breathing exercise animation is smooth
- [ ] Background refresh works
- [ ] Battery usage is acceptable (< 1% per hour)
- [ ] App works after device restart
- [ ] Settings persist across launches

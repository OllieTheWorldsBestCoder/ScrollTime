import SwiftUI

/// View for selecting which apps to monitor for doom scrolling
struct AppSelectionView: View {
    @Binding var selectedApps: [MonitoredApp]
    @State private var searchText = ""

    // Common social media apps that support endless scrolling
    private let availableApps: [MonitoredApp] = [
        MonitoredApp(name: "Instagram", bundleId: "com.instagram.app", icon: "camera"),
        MonitoredApp(name: "TikTok", bundleId: "com.tiktok.app", icon: "music.note"),
        MonitoredApp(name: "Twitter / X", bundleId: "com.twitter.app", icon: "bird"),
        MonitoredApp(name: "Reddit", bundleId: "com.reddit.app", icon: "text.bubble"),
        MonitoredApp(name: "Facebook", bundleId: "com.facebook.app", icon: "person.2"),
        MonitoredApp(name: "YouTube", bundleId: "com.google.youtube", icon: "play.rectangle"),
        MonitoredApp(name: "Snapchat", bundleId: "com.snapchat.app", icon: "camera.viewfinder"),
        MonitoredApp(name: "Pinterest", bundleId: "com.pinterest.app", icon: "pin"),
        MonitoredApp(name: "LinkedIn", bundleId: "com.linkedin.app", icon: "briefcase"),
        MonitoredApp(name: "Tumblr", bundleId: "com.tumblr.app", icon: "t.square"),
        MonitoredApp(name: "Discord", bundleId: "com.discord.app", icon: "bubble.left.and.bubble.right"),
        MonitoredApp(name: "Threads", bundleId: "com.instagram.threads", icon: "at"),
        MonitoredApp(name: "BeReal", bundleId: "com.bereal.app", icon: "eye"),
        MonitoredApp(name: "Mastodon", bundleId: "org.joinmastodon.app", icon: "elephant")
    ]

    private var filteredApps: [MonitoredApp] {
        if searchText.isEmpty {
            return availableApps
        }
        return availableApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            // Selected apps section
            if !selectedApps.isEmpty {
                Section {
                    ForEach(selectedApps) { app in
                        AppRow(app: app, isSelected: true) {
                            withAnimation {
                                selectedApps.removeAll { $0.bundleId == app.bundleId }
                            }
                        }
                    }
                } header: {
                    Text("Monitoring (\(selectedApps.count))")
                } footer: {
                    Text("Tap to remove an app from monitoring.")
                }
            }

            // Available apps section
            Section {
                ForEach(filteredApps) { app in
                    let isSelected = selectedApps.contains { $0.bundleId == app.bundleId }

                    if !isSelected {
                        AppRow(app: app, isSelected: false) {
                            withAnimation {
                                selectedApps.append(app)
                            }
                        }
                    }
                }
            } header: {
                Text("Available Apps")
            } footer: {
                Text("Select apps that you want ScrollTime to monitor for endless scrolling patterns.")
            }

            // Note about FamilyControls
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Screen Time Integration")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("For full monitoring capabilities, ScrollTime uses Apple's Screen Time API. Some features may require additional permissions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .searchable(text: $searchText, prompt: "Search apps")
        .navigationTitle("Select Apps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        withAnimation {
                            selectedApps = availableApps
                        }
                    } label: {
                        Label("Select All", systemImage: "checkmark.circle")
                    }

                    Button {
                        withAnimation {
                            selectedApps = []
                        }
                    } label: {
                        Label("Deselect All", systemImage: "circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

// MARK: - App Row

private struct AppRow: View {
    let app: MonitoredApp
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // App icon placeholder
                Image(systemName: app.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(iconGradient)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(app.bundleId)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .green : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var iconGradient: LinearGradient {
        LinearGradient(
            colors: iconColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconColors: [Color] {
        switch app.name.lowercased() {
        case let name where name.contains("instagram"):
            return [.purple, .pink, .orange]
        case let name where name.contains("tiktok"):
            return [.black, .pink]
        case let name where name.contains("twitter") || name.contains("x"):
            return [.blue, .cyan]
        case let name where name.contains("reddit"):
            return [.orange, .red]
        case let name where name.contains("facebook"):
            return [.blue, .indigo]
        case let name where name.contains("youtube"):
            return [.red, .pink]
        case let name where name.contains("snapchat"):
            return [.yellow, .orange]
        case let name where name.contains("pinterest"):
            return [.red, .pink]
        case let name where name.contains("linkedin"):
            return [.blue, .cyan]
        case let name where name.contains("discord"):
            return [.indigo, .purple]
        default:
            return [.gray, .secondary]
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AppSelectionView(selectedApps: .constant([
            MonitoredApp(name: "Instagram", bundleId: "com.instagram.app", icon: "camera"),
            MonitoredApp(name: "TikTok", bundleId: "com.tiktok.app", icon: "music.note")
        ]))
    }
}

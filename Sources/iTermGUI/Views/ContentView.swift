import SwiftUI

struct ContentView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } content: {
            ProfileListView()
                .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 560)
        } detail: {
            if let profile = profileManager.selectedProfile {
                ProfileDetailView(profile: profile)
            } else {
                EmptyStateView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var profileManager: ProfileManager

    private var profileCount: Int { profileManager.profiles.count }
    private var favoriteCount: Int { profileManager.profiles.filter(\.isFavorite).count }
    private var recentCount: Int { profileManager.profiles.filter { $0.lastUsed != nil }.count }

    var body: some View {
        ZStack {
            backgroundDecoration

            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 24)

                    EmptyHero()

                    EmptyStatsRow(
                        profileCount: profileCount,
                        favoriteCount: favoriteCount,
                        recentCount: recentCount
                    )

                    EmptyStateActions()
                        .environmentObject(profileManager)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: 580)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var backgroundDecoration: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.06),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }
}

private struct EmptyHero: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.accentColor.opacity(0.22), .accentColor.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 88, height: 88)

                Circle()
                    .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
                    .frame(width: 88, height: 88)

                Image(systemName: "terminal.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.tint)
            }

            VStack(spacing: 4) {
                Text("Welcome to iTermGUI")
                    .font(.title2.weight(.semibold))

                Text("Manage SSH profiles and launch sessions in iTerm2")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct EmptyStatsRow: View {
    let profileCount: Int
    let favoriteCount: Int
    let recentCount: Int

    var body: some View {
        HStack(spacing: 10) {
            StatTile(value: profileCount, label: "Profiles", systemImage: "square.stack.3d.up.fill", tint: .accentColor)
            StatTile(value: favoriteCount, label: "Favorites", systemImage: "star.fill", tint: .yellow)
            StatTile(value: recentCount, label: "Recent", systemImage: "clock.fill", tint: .blue)
        }
    }
}

private struct StatTile: View {
    let value: Int
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.background.opacity(0.6))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.separator.opacity(0.6), lineWidth: 0.5)
                }
        }
    }
}

private struct EmptyStateActions: View {
    @EnvironmentObject var profileManager: ProfileManager

    var body: some View {
        VStack(spacing: 14) {
            Button {
                profileManager.createNewProfile()
            } label: {
                Label("New Profile", systemImage: "plus")
                    .font(.body.weight(.medium))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("n", modifiers: .command)

            secondaryRow
        }
    }

    @ViewBuilder
    private var secondaryRow: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 10) {
                secondaryButtons
            }
        } else {
            secondaryButtons
        }
    }

    @ViewBuilder
    private var secondaryButtons: some View {
        HStack(spacing: 10) {
            QuickActionTile(title: "Localhost", systemImage: "terminal", tint: .green) {
                ITerm2Service().openLocalhost()
            }
            QuickActionTile(title: "Import", systemImage: "square.and.arrow.down", tint: .blue) {
                profileManager.importFromSSHConfig()
            }
            QuickActionTile(title: "SFTP", systemImage: "folder.fill", tint: .orange) {
                profileManager.openSFTPWindow()
            }

            if #available(macOS 14.0, *) {
                SettingsLink {
                    QuickActionLabel(title: "Settings", systemImage: "gearshape.fill", tint: .secondary)
                }
                .buttonStyle(.plain)
            } else {
                QuickActionTile(title: "Settings", systemImage: "gearshape.fill", tint: .gray) {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
            }
        }
    }
}

private struct QuickActionTile: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            QuickActionLabel(title: title, systemImage: systemImage, tint: tint)
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct QuickActionLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.background.opacity(0.6))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.separator.opacity(0.6), lineWidth: 0.5)
                }
        }
    }
}

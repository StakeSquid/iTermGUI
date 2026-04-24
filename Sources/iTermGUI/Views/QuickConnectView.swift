import SwiftUI

struct QuickConnectView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredProfiles: [SSHProfile] {
        if searchText.isEmpty {
            return profileManager.profiles
                .filter { $0.isFavorite || $0.lastUsed != nil }
                .sorted(by: defaultSort)
                .prefix(10)
                .map { $0 }
        }
        return profileManager.profiles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.host.localizedCaseInsensitiveContains(searchText)
            || $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func defaultSort(_ a: SSHProfile, _ b: SSHProfile) -> Bool {
        if a.isFavorite != b.isFavorite { return a.isFavorite }
        return (a.lastUsed ?? .distantPast) > (b.lastUsed ?? .distantPast)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchHeader

            Divider()

            if filteredProfiles.isEmpty {
                EmptyResultsView(searchText: searchText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        if searchText.isEmpty {
                            QuickConnectSectionHeader(title: "Quick Access")
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                        }
                        ForEach(filteredProfiles) { profile in
                            QuickConnectRow(profile: profile) {
                                profileManager.connectToProfile(profile)
                                NSApp.keyWindow?.close()
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(width: 360, height: 460)
        .onAppear { isSearchFocused = true }
    }

    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)

            TextField("Quick connect…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isSearchFocused)
                .onSubmit {
                    if let first = filteredProfiles.first {
                        profileManager.connectToProfile(first)
                        NSApp.keyWindow?.close()
                    }
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct QuickConnectSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.bottom, 2)
    }
}

private struct EmptyResultsView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "star" : "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "No favorites or recent profiles yet" : "No profiles match \u{201C}\(searchText)\u{201D}")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct QuickConnectRow: View {
    let profile: SSHProfile
    let onConnect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.tint.opacity(isHovered ? 0.18 : 0.10))
                        .frame(width: 30, height: 30)
                    Image(systemName: profile.isFavorite ? "star.fill" : "server.rack")
                        .font(.caption)
                        .foregroundStyle(profile.isFavorite ? Color.yellow : Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(profile.connectionString)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isHovered ? Color.accentColor : Color.secondary.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .modifier(QuickConnectHoverBackground(isHovered: isHovered))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

private struct QuickConnectHoverBackground: ViewModifier {
    let isHovered: Bool

    func body(content: Content) -> some View {
        if isHovered {
            content.glassBackground(tinted: .accentColor, in: .rect(cornerRadius: 8), fallback: .ultraThinMaterial)
        } else {
            content
        }
    }
}

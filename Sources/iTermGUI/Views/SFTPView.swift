import SwiftUI
import AppKit

// MARK: - Sort helper

private extension RemoteFile {
    var modifiedSortKey: Date { modifiedDate ?? .distantPast }
}

// MARK: - Pane state

private struct PaneState: Equatable {
    var location: FileLocation = .localhost
    var path: String
    var files: [RemoteFile] = []
    var selection: Set<RemoteFile.ID> = []
    var sortOrder: [KeyPathComparator<RemoteFile>] = [
        KeyPathComparator(\RemoteFile.name)
    ]
    var isLoading: Bool = false

    var sortedFiles: [RemoteFile] {
        let sorted = files.sorted(using: sortOrder)
        return sorted.filter(\.isDirectory) + sorted.filter { !$0.isDirectory }
    }

    var selectedFiles: [RemoteFile] {
        files.filter { selection.contains($0.id) }
    }

    var selectionSize: Int64 {
        selectedFiles.reduce(0) { $0 + ($1.isDirectory ? 0 : $1.size) }
    }

    var isAtRoot: Bool { path == "/" || path == "~" }
}

private enum PaneSide: String { case left, right }

private struct PendingDelete: Identifiable {
    let id = UUID()
    let side: PaneSide
    let location: FileLocation
    let files: [RemoteFile]
}

// MARK: - Transfer intent / conflict batch

private struct TransferIntent: Identifiable, Hashable {
    let id = UUID()
    let sourcePath: String
    let sourceLocation: FileLocation
    let destPath: String
    let destLocation: FileLocation
    let isDirectory: Bool
    let name: String
}

private struct PendingConflictBatch {
    var conflicts: [TransferIntent]
    let refresh: () -> Void
}

private enum ConflictDecision {
    case replace, skip, stop
}

// MARK: - Main view

struct SFTPView: View {
    @EnvironmentObject private var profileManager: ProfileManager
    @StateObject private var sftpService = SFTPService()

    let initialProfile: SSHProfile?

    @State private var leftPane = PaneState(path: NSHomeDirectory())
    @State private var rightPane = PaneState(path: NSHomeDirectory())

    @State private var errorMessage: String?
    @State private var pendingDelete: PendingDelete?
    @State private var queueExpanded = false
    @State private var pendingConflicts: PendingConflictBatch?
    @State private var applyToAllConflicts = false

    init(profile: SSHProfile? = nil) {
        self.initialProfile = profile
    }

    var body: some View {
        ZStack(alignment: .top) {
            SFTPBackdrop(leftLocation: leftPane.location, rightLocation: rightPane.location)

            VStack(spacing: 0) {
                Color.clear.frame(height: 28)

                HSplitView {
                    FilePane(
                        side: .left,
                        state: $leftPane,
                        profiles: profileManager.profiles,
                        counterpartLocation: rightPane.location,
                        onReload: reloadLeft,
                        onDelete: { files in
                            pendingDelete = PendingDelete(side: .left, location: leftPane.location, files: files)
                        },
                        onTransferToOther: transferLeftToRight,
                        onDrop: { items in handleDrop(into: .left, items: items) }
                    )
                    .frame(minWidth: 360, idealWidth: 560)

                    FilePane(
                        side: .right,
                        state: $rightPane,
                        profiles: profileManager.profiles,
                        counterpartLocation: leftPane.location,
                        onReload: reloadRight,
                        onDelete: { files in
                            pendingDelete = PendingDelete(side: .right, location: rightPane.location, files: files)
                        },
                        onTransferToOther: transferRightToLeft,
                        onDrop: { items in handleDrop(into: .right, items: items) }
                    )
                    .frame(minWidth: 360, idealWidth: 560)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                SFTPStatusBar(
                    leftPane: leftPane,
                    rightPane: rightPane,
                    transfers: sftpService.transfers,
                    queueExpanded: $queueExpanded,
                    onTransferRight: { transferLeftToRight(leftPane.selectedFiles) },
                    onTransferLeft: { transferRightToLeft(rightPane.selectedFiles) }
                )

                if queueVisible {
                    TransferQueueView(
                        transfers: sftpService.transfers,
                        onCancel: { sftpService.cancelTransfer($0) },
                        onCancelAll: cancelAllActive
                    )
                    .frame(height: 200)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(minWidth: 900, idealWidth: 1200, maxWidth: .infinity,
               minHeight: 560, idealHeight: 760, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: queueVisible)
        .onAppear(perform: setupInitialState)
        .alert(
            "Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(
            deleteAlertTitle,
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) { performDelete() }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: Binding(
            get: { pendingConflicts != nil },
            set: { if !$0 { pendingConflicts = nil } }
        )) {
            if let batch = pendingConflicts, let head = batch.conflicts.first {
                ConflictResolutionSheet(
                    intent: head,
                    remaining: batch.conflicts.count,
                    applyToAll: $applyToAllConflicts,
                    onResolve: resolveConflict
                )
            }
        }
        .onExitCommand { NSApp.keyWindow?.close() }
    }

    private var queueVisible: Bool {
        queueExpanded && !sftpService.transfers.isEmpty
    }

    private var deleteAlertTitle: String {
        let count = pendingDelete?.files.count ?? 0
        return count == 1 ? "Delete 1 item?" : "Delete \(count) items?"
    }

    // MARK: - Lifecycle

    private func setupInitialState() {
        if let profile = initialProfile {
            rightPane.location = .server(profile)
            rightPane.path = "~"
        }
        reloadLeft()
        reloadRight()
    }

    // MARK: - Reload

    private func reloadLeft() { reload(side: .left) }
    private func reloadRight() { reload(side: .right) }

    private func reload(side: PaneSide) {
        let snapshot = (side == .left) ? leftPane : rightPane
        switch side {
        case .left:  leftPane.isLoading = true
        case .right: rightPane.isLoading = true
        }

        sftpService.listFiles(at: snapshot.path, location: snapshot.location) { result in
            switch result {
            case .success(let files):
                switch side {
                case .left:
                    leftPane.files = files
                    leftPane.selection.removeAll()
                    leftPane.isLoading = false
                case .right:
                    rightPane.files = files
                    rightPane.selection.removeAll()
                    rightPane.isLoading = false
                }
            case .failure(let error):
                switch side {
                case .left:  leftPane.isLoading = false
                case .right: rightPane.isLoading = false
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Transfer

    private func transferLeftToRight(_ files: [RemoteFile]) {
        transfer(files, sourcePath: leftPane.path, sourceLocation: leftPane.location,
                 destPath: rightPane.path, destLocation: rightPane.location,
                 refresh: reloadRight)
    }

    private func transferRightToLeft(_ files: [RemoteFile]) {
        transfer(files, sourcePath: rightPane.path, sourceLocation: rightPane.location,
                 destPath: leftPane.path, destLocation: leftPane.location,
                 refresh: reloadLeft)
    }

    private func transfer(_ files: [RemoteFile],
                          sourcePath: String, sourceLocation: FileLocation,
                          destPath: String, destLocation: FileLocation,
                          refresh: @escaping () -> Void) {
        guard !files.isEmpty else { return }
        let intents = files.map { file in
            TransferIntent(
                sourcePath: file.path,
                sourceLocation: sourceLocation,
                destPath: joinPath(destPath, file.name),
                destLocation: destLocation,
                isDirectory: file.isDirectory,
                name: file.name
            )
        }
        beginBatch(intents, refresh: refresh)
    }

    // MARK: - Drop

    private func handleDrop(into destSide: PaneSide, items: [RemoteFileDragItem]) {
        let foreign = items.filter { $0.originSide != destSide.rawValue }
        guard !foreign.isEmpty else { return }

        let sourceSide: PaneSide = (destSide == .left) ? .right : .left
        let sourceLocation = (sourceSide == .left) ? leftPane.location : rightPane.location
        let destPane = (destSide == .left) ? leftPane : rightPane
        let refresh: () -> Void = (destSide == .left) ? reloadLeft : reloadRight

        let intents = foreign.map { item in
            TransferIntent(
                sourcePath: item.path,
                sourceLocation: sourceLocation,
                destPath: joinPath(destPane.path, item.name),
                destLocation: destPane.location,
                isDirectory: item.isDirectory,
                name: item.name
            )
        }
        beginBatch(intents, refresh: refresh)
    }

    // MARK: - Batch with conflict check

    private func beginBatch(_ intents: [TransferIntent], refresh: @escaping () -> Void) {
        guard let destLocation = intents.first?.destLocation else { return }

        sftpService.fileExistsBatch(paths: intents.map(\.destPath), location: destLocation) { existence in
            var clean: [TransferIntent] = []
            var conflicts: [TransferIntent] = []
            for intent in intents {
                if existence[intent.destPath] == true {
                    conflicts.append(intent)
                } else {
                    clean.append(intent)
                }
            }

            for intent in clean { enqueueTransfer(intent) }

            if conflicts.isEmpty {
                if !clean.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: refresh)
                }
            } else {
                applyToAllConflicts = false
                pendingConflicts = PendingConflictBatch(conflicts: conflicts, refresh: refresh)
            }
        }
    }

    private func enqueueTransfer(_ intent: TransferIntent) {
        sftpService.transferFile(
            from: intent.sourcePath,
            sourceLocation: intent.sourceLocation,
            to: intent.destPath,
            destinationLocation: intent.destLocation,
            isDirectory: intent.isDirectory
        )
    }

    private func resolveConflict(_ decision: ConflictDecision) {
        guard var batch = pendingConflicts else { return }

        if decision == .stop {
            pendingConflicts = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: batch.refresh)
            return
        }

        let useAll = applyToAllConflicts
        let toResolve: [TransferIntent]
        if useAll {
            toResolve = batch.conflicts
            batch.conflicts.removeAll()
        } else {
            toResolve = [batch.conflicts.removeFirst()]
        }

        for intent in toResolve {
            switch decision {
            case .replace:
                sftpService.deleteFile(at: intent.destPath, location: intent.destLocation) { _ in
                    DispatchQueue.main.async {
                        enqueueTransfer(intent)
                    }
                }
            case .skip:
                break
            case .stop:
                break
            }
        }

        if batch.conflicts.isEmpty {
            pendingConflicts = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: batch.refresh)
        } else {
            pendingConflicts = batch
        }
    }

    // MARK: - Cancel

    private func cancelAllActive() {
        let active = sftpService.transfers
            .filter { $0.status == .transferring || $0.status == .pending }
            .map(\.id)
        for id in active {
            sftpService.cancelTransfer(id)
        }
    }

    // MARK: - Delete

    private func performDelete() {
        guard let pending = pendingDelete else { return }
        let group = DispatchGroup()
        var failures: [String] = []

        for file in pending.files {
            group.enter()
            sftpService.deleteFile(at: file.path, location: pending.location) { ok in
                if !ok { failures.append(file.name) }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !failures.isEmpty {
                errorMessage = "Failed to delete: \(failures.joined(separator: ", "))"
            }
            switch pending.side {
            case .left: reloadLeft()
            case .right: reloadRight()
            }
            pendingDelete = nil
        }
    }
}

// MARK: - File pane

private struct FilePane: View {
    let side: PaneSide
    @Binding var state: PaneState
    let profiles: [SSHProfile]
    let counterpartLocation: FileLocation
    let onReload: () -> Void
    let onDelete: ([RemoteFile]) -> Void
    let onTransferToOther: ([RemoteFile]) -> Void
    let onDrop: ([RemoteFileDragItem]) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            paneHeader
            tableContent
        }
        .background(Color.clear)
    }

    // MARK: header

    private var paneHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            LocationMenu(location: state.location, profiles: profiles) { newLocation in
                state.location = newLocation
                state.path = (newLocation == .localhost) ? NSHomeDirectory() : "~"
                state.selection.removeAll()
                onReload()
            }

            pathBar
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 0.5)
                }
        }
    }

    private var pathBar: some View {
        HStack(spacing: 2) {
            SFTPIconButton(systemName: "arrow.up", help: "Up one directory", disabled: state.isAtRoot, action: navigateUp)
            SFTPIconButton(systemName: "house", help: "Home", action: navigateHome)

            TextField("Path", text: $state.path)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .onSubmit(onReload)

            SFTPIconButton(systemName: "arrow.clockwise", help: "Refresh", action: onReload)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(Color.primary.opacity(0.05))
        }
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    // MARK: table

    private var tableContent: some View {
        Table(state.sortedFiles, selection: $state.selection, sortOrder: $state.sortOrder) {
            TableColumn("Name", value: \.name) { file in
                HStack(spacing: 6) {
                    Image(systemName: file.isDirectory ? "folder.fill" : "doc")
                        .foregroundStyle(file.isDirectory ? Color.accentColor : Color.secondary)
                    Text(file.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .draggable(containerItemID: file.id)
            }
            .width(min: 160, ideal: 260)

            TableColumn("Size", value: \.size) { file in
                Text(file.sizeString)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 60, ideal: 80, max: 140)

            TableColumn("Permissions") { file in
                Text(file.permissions)
                    .foregroundStyle(.secondary)
                    .font(.system(.caption, design: .monospaced))
            }
            .width(min: 80, ideal: 100, max: 140)

            TableColumn("Modified", value: \.modifiedSortKey) { file in
                Text(file.dateString)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 160, max: 220)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .scrollContentBackground(.hidden)
        .contextMenu(forSelectionType: RemoteFile.ID.self) { ids in
            let files = state.files.filter { ids.contains($0.id) }
            if !files.isEmpty {
                Button {
                    onTransferToOther(files)
                } label: {
                    Label("Send to \(counterpartLocation.displayName)",
                          systemImage: "arrow.right.arrow.left")
                }
                Divider()
            }
            Button("Refresh", action: onReload)
            if !files.isEmpty {
                Divider()
                Button(role: .destructive) {
                    onDelete(files)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } primaryAction: { ids in
            guard let id = ids.first,
                  let file = state.files.first(where: { $0.id == id }),
                  file.isDirectory else { return }
            navigate(into: file)
        }
        .dragContainer(for: RemoteFileDragItem.self, itemID: \.id) { (ids: [UUID]) in
            state.files
                .filter { ids.contains($0.id) }
                .map { file in
                    RemoteFileDragItem(
                        id: file.id,
                        path: file.path,
                        name: file.name,
                        isDirectory: file.isDirectory,
                        originSide: side.rawValue
                    )
                }
        }
        .dragContainerSelection(Array(state.selection))
        .dropDestination(for: RemoteFileDragItem.self) { items, _ in
            let foreign = items.filter { $0.originSide != side.rawValue }
            guard !foreign.isEmpty else { return false }
            onDrop(foreign)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted {
                ZStack {
                    Color.accentColor.opacity(0.08)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            Color.accentColor,
                            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                        )
                        .padding(6)
                }
                .allowsHitTesting(false)
            }
        }
        .overlay {
            if state.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .padding(24)
                    .glassBackground(in: .rect(cornerRadius: 14), fallback: .regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    }
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isDropTargeted)
    }

    // MARK: navigation

    private func navigateUp() {
        let parent = parentPath(of: state.path)
        guard parent != state.path else { return }
        state.path = parent
        state.selection.removeAll()
        onReload()
    }

    private func navigateHome() {
        state.path = (state.location == .localhost) ? NSHomeDirectory() : "~"
        state.selection.removeAll()
        onReload()
    }

    private func navigate(into file: RemoteFile) {
        state.path = file.path
        state.selection.removeAll()
        onReload()
    }

    private func parentPath(of path: String) -> String {
        if path == "/" || path == "~" { return path }
        if path.hasPrefix("~/") {
            let comps = path.dropFirst(2).split(separator: "/")
            return comps.count <= 1 ? "~" : "~/" + comps.dropLast().joined(separator: "/")
        }
        let comps = path.split(separator: "/", omittingEmptySubsequences: true)
        if comps.isEmpty { return "/" }
        let dropped = comps.dropLast()
        return dropped.isEmpty ? "/" : "/" + dropped.joined(separator: "/")
    }
}

// MARK: - Location menu

private struct LocationMenu: View {
    let location: FileLocation
    let profiles: [SSHProfile]
    let onChange: (FileLocation) -> Void

    private var accent: Color {
        location == .localhost ? .green : .accentColor
    }

    var body: some View {
        Menu {
            Button {
                onChange(.localhost)
            } label: {
                Label("Localhost", systemImage: "laptopcomputer")
            }
            if !profiles.isEmpty {
                Divider()
                Section("Servers") {
                    ForEach(profiles) { profile in
                        Button {
                            onChange(.server(profile))
                        } label: {
                            Label(profile.name, systemImage: "server.rack")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 22, height: 22)
                    Image(systemName: location == .localhost ? "laptopcomputer" : "server.rack")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent)
                }
                Text(location.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 4)
            .padding(.trailing, 12)
            .padding(.vertical, 4)
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .glassBackground(in: .capsule, fallback: .thinMaterial)
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .fixedSize()
    }
}

// MARK: - Status bar

private struct SFTPStatusBar: View {
    let leftPane: PaneState
    let rightPane: PaneState
    let transfers: [FileTransfer]
    @Binding var queueExpanded: Bool
    let onTransferRight: () -> Void
    let onTransferLeft: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            paneSummary(leftPane)
                .frame(maxWidth: .infinity, alignment: .leading)

            transferControls

            paneSummary(rightPane)
                .frame(maxWidth: .infinity, alignment: .trailing)

            transferStatusButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 0.5)
                }
        }
        .font(.callout)
    }

    private var transferControls: some View {
        let cluster = HStack(spacing: 6) {
            TransferArrowButton(
                systemName: "arrow.left",
                help: "Send selection to left (⌘⇧←)",
                disabled: rightPane.selection.isEmpty,
                action: onTransferLeft
            )
            .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])

            TransferArrowButton(
                systemName: "arrow.right",
                help: "Send selection to right (⌘⇧→)",
                disabled: leftPane.selection.isEmpty,
                action: onTransferRight
            )
            .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
        }

        return Group {
            if #available(macOS 26, *) {
                GlassEffectContainer(spacing: 6) { cluster }
            } else {
                cluster
            }
        }
    }

    private func paneSummary(_ pane: PaneState) -> some View {
        let total = pane.files.count
        let sel = pane.selection.count
        let summary: String
        if sel == 0 {
            summary = "\(total) item\(total == 1 ? "" : "s")"
        } else {
            let size = ByteCountFormatter.string(fromByteCount: pane.selectionSize, countStyle: .file)
            summary = "\(sel) selected · \(size)"
        }
        return HStack(spacing: 6) {
            Text(pane.location.displayName)
                .font(.system(size: 12, weight: .semibold))
            Text("·")
                .foregroundStyle(.tertiary)
            Text(summary)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .lineLimit(1)
        .truncationMode(.middle)
    }

    private var transferStatusButton: some View {
        let active = transfers.filter { $0.status == .transferring }.count
        let failed = transfers.filter { $0.status == .failed }.count
        let total = transfers.count

        return Button {
            queueExpanded.toggle()
        } label: {
            HStack(spacing: 6) {
                if active > 0 {
                    ProgressView().controlSize(.small)
                    Text("\(active) active")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                } else if total > 0 {
                    Image(systemName: failed > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(failed > 0 ? Color.yellow : Color.green)
                    Text("\(total) transfer\(total == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                } else {
                    Image(systemName: "tray")
                        .foregroundStyle(.tertiary)
                    Text("No transfers")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                Image(systemName: queueExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassBackground(in: .capsule, fallback: .thinMaterial)
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .disabled(transfers.isEmpty)
        .opacity(transfers.isEmpty ? 0.6 : 1)
    }
}

private struct TransferArrowButton: View {
    let systemName: String
    let help: String
    let disabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(disabled ? Color.secondary : Color.white)
                .frame(width: 32, height: 26)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .modifier(TransferArrowBackground(disabled: disabled, isHovered: isHovered))
        .help(help)
        .disabled(disabled)
        .onHover { isHovered = $0 }
    }
}

private struct TransferArrowBackground: ViewModifier {
    let disabled: Bool
    let isHovered: Bool

    func body(content: Content) -> some View {
        if disabled {
            content
                .background {
                    Capsule().fill(Color.primary.opacity(0.06))
                }
                .overlay {
                    Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
        } else if #available(macOS 26, *) {
            content
                .glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)
        } else {
            content
                .background(Capsule().fill(Color.accentColor))
        }
    }
}

// MARK: - Transfer queue

private struct TransferQueueView: View {
    let transfers: [FileTransfer]
    let onCancel: (UUID) -> Void
    let onCancelAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            queueHeader

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(transfers) { transfer in
                        TransferRow(transfer: transfer, onCancel: onCancel)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .scrollContentBackground(.hidden)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 0.5)
                }
        }
    }

    private var queueHeader: some View {
        let active = transfers.filter { $0.status == .transferring || $0.status == .pending }.count
        let completed = transfers.filter { $0.status == .completed }.count
        let failed = transfers.filter { $0.status == .failed }.count
        let cancelled = transfers.filter { $0.status == .cancelled }.count

        return HStack(spacing: 10) {
            Text("Transfers")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 6) {
                if active > 0 {
                    StatusChip(count: active, systemImage: "arrow.right.circle.fill", tint: .blue)
                }
                if completed > 0 {
                    StatusChip(count: completed, systemImage: "checkmark.circle.fill", tint: .green)
                }
                if failed > 0 {
                    StatusChip(count: failed, systemImage: "xmark.circle.fill", tint: .red)
                }
                if cancelled > 0 {
                    StatusChip(count: cancelled, systemImage: "stop.circle.fill", tint: .secondary)
                }
            }

            if active > 0 {
                Button(role: .destructive, action: onCancelAll) {
                    Label("Cancel All", systemImage: "stop.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 0.5)
        }
    }
}

private struct StatusChip: View {
    let count: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background {
            Capsule().fill(tint.opacity(0.14))
        }
    }
}

private struct TransferRow: View {
    let transfer: FileTransfer
    let onCancel: (UUID) -> Void
    @State private var showingError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.18))
                        .frame(width: 24, height: 24)
                    Image(systemName: statusIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(URL(fileURLWithPath: transfer.sourcePath).lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.system(size: 12, weight: .medium))
                    HStack(spacing: 6) {
                        Text("\(transfer.sourceLocation.displayName) → \(transfer.destinationLocation.displayName)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        if transfer.status == .transferring {
                            Text(transfer.progressString)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.blue)
                                .monospacedDigit()
                        }
                    }
                }

                Spacer()

                if transfer.status == .transferring || transfer.status == .pending {
                    if transfer.status == .transferring {
                        ProgressView(value: transfer.progress)
                            .progressViewStyle(.linear)
                            .frame(width: 100)
                    }
                    Button {
                        onCancel(transfer.id)
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel transfer")
                } else if transfer.status == .failed && transfer.error != nil {
                    Button {
                        showingError.toggle()
                    } label: {
                        Image(systemName: showingError ? "chevron.up.circle.fill" : "info.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            if showingError, transfer.status == .failed, let error = transfer.error {
                VStack(alignment: .leading, spacing: 4) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 0.5)
                        .padding(.vertical, 2)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("From: \(transfer.sourcePath)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text("To: \(transfer.destinationPath)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.leading, 34)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }

    private var statusIcon: String {
        switch transfer.status {
        case .pending:      return "clock"
        case .transferring: return "arrow.right.circle"
        case .completed:    return "checkmark.circle.fill"
        case .failed:       return "xmark.circle.fill"
        case .cancelled:    return "stop.circle"
        }
    }

    private var statusColor: Color {
        switch transfer.status {
        case .pending:      return .gray
        case .transferring: return .blue
        case .completed:    return .green
        case .failed:       return .red
        case .cancelled:    return .gray
        }
    }
}

// MARK: - Conflict resolution sheet

private struct ConflictResolutionSheet: View {
    let intent: TransferIntent
    let remaining: Int
    @Binding var applyToAll: Bool
    let onResolve: (ConflictDecision) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.22))
                        .frame(width: 44, height: 44)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.yellow)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(intent.isDirectory ? "A folder" : "A file") named \u{201C}\(intent.name)\u{201D} already exists.")
                        .font(.system(size: 15, weight: .semibold))

                    Text(intent.destPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        }

                    Text("Replacing will delete the existing item before transferring.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }

            if remaining > 1 {
                Toggle(isOn: $applyToAll) {
                    Text("Apply to remaining \(remaining - 1) conflict\(remaining - 1 == 1 ? "" : "s")")
                        .font(.callout)
                }
                .toggleStyle(.checkbox)
            }

            HStack(spacing: 8) {
                Button("Stop", role: .cancel) {
                    onResolve(.stop)
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Skip") {
                    onResolve(.skip)
                }

                Button("Replace") {
                    onResolve(.replace)
                }
                .keyboardShortcut(.defaultAction)
                .glassProminentButton()
            }
        }
        .padding(22)
        .frame(minWidth: 480, idealWidth: 520)
    }
}

// MARK: - Path helpers

private func joinPath(_ base: String, _ name: String) -> String {
    base.hasSuffix("/") ? "\(base)\(name)" : "\(base)/\(name)"
}

// MARK: - Glass chrome helpers

private struct SFTPIconButton: View {
    let systemName: String
    let help: String
    var disabled: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 24, height: 22)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            if isHovered && !disabled {
                Capsule().fill(Color.primary.opacity(0.08))
            }
        }
        .help(help)
        .disabled(disabled)
        .onHover { isHovered = $0 }
    }

    private var foreground: Color {
        if disabled { return Color.secondary.opacity(0.5) }
        return isHovered ? .primary : .secondary
    }
}

private struct SFTPBackdrop: View {
    let leftLocation: FileLocation
    let rightLocation: FileLocation

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    tint(for: leftLocation).opacity(0.10),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )

            LinearGradient(
                colors: [
                    tint(for: rightLocation).opacity(0.10),
                    Color.clear
                ],
                startPoint: .topTrailing,
                endPoint: .center
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private func tint(for location: FileLocation) -> Color {
        switch location {
        case .localhost:
            return .green
        case .server(let profile):
            return ProfileAvatar.color(for: profile)
        }
    }
}

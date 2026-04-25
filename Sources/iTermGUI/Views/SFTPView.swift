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
        VStack(spacing: 0) {
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

            Divider()

            SFTPStatusBar(
                leftPane: leftPane,
                rightPane: rightPane,
                transfers: sftpService.transfers,
                queueExpanded: $queueExpanded,
                onTransferRight: { transferLeftToRight(leftPane.selectedFiles) },
                onTransferLeft: { transferRightToLeft(rightPane.selectedFiles) }
            )

            if queueVisible {
                Divider()
                TransferQueueView(
                    transfers: sftpService.transfers,
                    onCancel: { sftpService.cancelTransfer($0) },
                    onCancelAll: cancelAllActive
                )
                .frame(height: 180)
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
            Divider()
            tableContent
        }
    }

    // MARK: header

    private var paneHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            LocationMenu(location: state.location, profiles: profiles) { newLocation in
                state.location = newLocation
                state.path = (newLocation == .localhost) ? NSHomeDirectory() : "~"
                state.selection.removeAll()
                onReload()
            }

            HStack(spacing: 4) {
                Button(action: navigateUp) {
                    Image(systemName: "arrow.up")
                }
                .help("Up one directory")
                .disabled(state.isAtRoot)

                Button(action: navigateHome) {
                    Image(systemName: "house")
                }
                .help("Home")

                TextField("Path", text: $state.path)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(onReload)

                Button(action: onReload) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            .buttonStyle(.borderless)
            .controlSize(.regular)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
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
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .padding(2)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if state.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .padding(20)
                    .background(.regularMaterial, in: .rect(cornerRadius: 10))
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
            HStack(spacing: 6) {
                Image(systemName: location == .localhost ? "laptopcomputer" : "server.rack")
                    .foregroundStyle(.secondary)
                Text(location.displayName)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
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

            Divider().frame(height: 14)

            transferStatusButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .font(.callout)
    }

    private var transferControls: some View {
        HStack(spacing: 6) {
            Button(action: onTransferLeft) {
                Image(systemName: "arrow.left")
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
            .help("Send selection to left (⌘⇧←)")
            .disabled(rightPane.selection.isEmpty)

            Button(action: onTransferRight) {
                Image(systemName: "arrow.right")
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
            .help("Send selection to right (⌘⇧→)")
            .disabled(leftPane.selection.isEmpty)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
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
                .fontWeight(.medium)
            Text("·")
                .foregroundStyle(.tertiary)
            Text(summary)
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
                    Text("\(active) active").monospacedDigit()
                } else if total > 0 {
                    Image(systemName: failed > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(failed > 0 ? Color.yellow : Color.green)
                    Text("\(total) transfer\(total == 1 ? "" : "s")")
                        .monospacedDigit()
                } else {
                    Image(systemName: "tray")
                        .foregroundStyle(.secondary)
                    Text("No transfers").foregroundStyle(.secondary)
                }
                Image(systemName: queueExpanded ? "chevron.down" : "chevron.up")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.borderless)
        .disabled(transfers.isEmpty)
    }
}

// MARK: - Transfer queue

private struct TransferQueueView: View {
    let transfers: [FileTransfer]
    let onCancel: (UUID) -> Void
    let onCancelAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("Transfers")
                    .font(.headline)
                Spacer()

                let active = transfers.filter { $0.status == .transferring || $0.status == .pending }.count
                let completed = transfers.filter { $0.status == .completed }.count
                let failed = transfers.filter { $0.status == .failed }.count
                let cancelled = transfers.filter { $0.status == .cancelled }.count

                if active > 0 {
                    Label("\(active)", systemImage: "arrow.right.circle")
                        .foregroundStyle(.blue)
                }
                if completed > 0 {
                    Label("\(completed)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if failed > 0 {
                    Label("\(failed)", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                if cancelled > 0 {
                    Label("\(cancelled)", systemImage: "stop.circle")
                        .foregroundStyle(.secondary)
                }

                if active > 0 {
                    Button(role: .destructive, action: onCancelAll) {
                        Label("Cancel All", systemImage: "stop.fill")
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(transfers) { transfer in
                        TransferRow(transfer: transfer, onCancel: onCancel)
                    }
                }
                .padding(8)
            }
        }
        .background(.regularMaterial)
    }
}

private struct TransferRow: View {
    let transfer: FileTransfer
    let onCancel: (UUID) -> Void
    @State private var showingError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(URL(fileURLWithPath: transfer.sourcePath).lastPathComponent)
                        .lineLimit(1)
                        .fontWeight(.medium)
                    HStack(spacing: 6) {
                        Text("\(transfer.sourceLocation.displayName) → \(transfer.destinationLocation.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if transfer.status == .transferring {
                            Text(transfer.progressString)
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .monospacedDigit()
                        }
                    }
                }

                Spacer()

                if transfer.status == .transferring || transfer.status == .pending {
                    if transfer.status == .transferring {
                        ProgressView(value: transfer.progress)
                            .frame(width: 80)
                    }
                    Button {
                        onCancel(transfer.id)
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel transfer")
                } else if transfer.status == .failed && transfer.error != nil {
                    Button {
                        showingError.toggle()
                    } label: {
                        Image(systemName: showingError ? "chevron.up.circle" : "info.circle")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            if showingError, transfer.status == .failed, let error = transfer.error {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("From: \(transfer.sourcePath)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text("To: \(transfer.destinationPath)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.background.opacity(0.5), in: .rect(cornerRadius: 6))
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(intent.isDirectory ? "A folder" : "A file") named \u{201C}\(intent.name)\u{201D} already exists at the destination.")
                        .font(.headline)

                    Text(intent.destPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

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
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 480, idealWidth: 520)
    }
}

// MARK: - Path helpers

private func joinPath(_ base: String, _ name: String) -> String {
    base.hasSuffix("/") ? "\(base)\(name)" : "\(base)/\(name)"
}

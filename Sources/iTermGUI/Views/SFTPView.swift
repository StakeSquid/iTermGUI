import SwiftUI
import AppKit

// MARK: - Models / Enums

enum FileSortOption: String, CaseIterable {
    case name = "Name"
    case size = "Size"
    case date = "Date Modified"
    case type = "Type"
}

struct ColumnWidths: Equatable {
    var name: CGFloat = 200
    var size: CGFloat = 80
    var permissions: CGFloat = 90
    var date: CGFloat = 120
}

// Which column is being resized
enum ColumnKey { case name, size, permissions }

// Resizing phases used by header and grip (internal so all types here can use it)
enum ResizePhase { case start, change(CGFloat), end }

// MARK: - Main View

struct SFTPView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileManager: ProfileManager
    @StateObject private var sftpService = SFTPService()
    
    @State private var leftLocation: FileLocation = .localhost
    @State private var rightLocation: FileLocation = .localhost
    
    @State private var leftPath: String = NSHomeDirectory()
    @State private var rightPath: String = NSHomeDirectory()
    
    @State private var leftFiles: [RemoteFile] = []
    @State private var rightFiles: [RemoteFile] = []
    
    @State private var leftSelection: Set<RemoteFile> = []
    @State private var rightSelection: Set<RemoteFile> = []
    
    @State private var leftSortOption: FileSortOption = .name
    @State private var leftSortAscending = true
    @State private var rightSortOption: FileSortOption = .name
    @State private var rightSortAscending = true
    
    @State private var leftColumnWidths = ColumnWidths()
    @State private var rightColumnWidths = ColumnWidths()
    
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var filesToDelete: [(file: RemoteFile, location: FileLocation, isLeft: Bool)] = []
    
    let initialProfile: SSHProfile?
    
    init(profile: SSHProfile? = nil) {
        self.initialProfile = profile
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SFTP File Transfer")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !sftpService.transfers.isEmpty {
                    Text("\(sftpService.transfers.filter { $0.status == .transferring }.count) active transfers")
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    if let window = NSApp.keyWindow { window.close() }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close SFTP Window")
            }
            .padding()
            
            Divider()
            
            // Main content
            HStack(spacing: 0) {
                // Left pane
                VStack(spacing: 0) {
                    FilePaneHeader(
                        location: $leftLocation,
                        path: $leftPath,
                        profiles: profileManager.profiles,
                        onLocationChange: { loadLeftPane() },
                        onPathChange: { loadLeftPane() }
                    )
                    
                    Divider()
                    
                    FilePaneContent(
                        files: $leftFiles,
                        selection: $leftSelection,
                        currentPath: $leftPath,
                        location: leftLocation,
                        sortOption: $leftSortOption,
                        sortAscending: $leftSortAscending,
                        columnWidths: $leftColumnWidths,
                        isLoading: isLoading,
                        onNavigate: { path in
                            leftPath = path
                            loadLeftPane()
                        },
                        onRefresh: { loadLeftPane() },
                        onDelete: { files in
                            filesToDelete = files.map { ($0, leftLocation, true) }
                            showDeleteConfirmation = true
                        },
                        onTransfer: { files in
                            transferFromLeftPane(files)
                        }
                    )
                }
                .frame(minWidth: 400)
                
                Divider()
                
                // Transfer buttons
                VStack(spacing: 20) {
                    Button(action: transferLeftToRight) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title)
                    }
                    .disabled(leftSelection.isEmpty)
                    .help("Transfer selected files to right")
                    
                    Button(action: transferRightToLeft) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.title)
                    }
                    .disabled(rightSelection.isEmpty)
                    .help("Transfer selected files to left")
                }
                .padding()
                .frame(width: 80)
                
                Divider()
                
                // Right pane
                VStack(spacing: 0) {
                    FilePaneHeader(
                        location: $rightLocation,
                        path: $rightPath,
                        profiles: profileManager.profiles,
                        onLocationChange: { loadRightPane() },
                        onPathChange: { loadRightPane() }
                    )
                    
                    Divider()
                    
                    FilePaneContent(
                        files: $rightFiles,
                        selection: $rightSelection,
                        currentPath: $rightPath,
                        location: rightLocation,
                        sortOption: $rightSortOption,
                        sortAscending: $rightSortAscending,
                        columnWidths: $rightColumnWidths,
                        isLoading: isLoading,
                        onNavigate: { path in
                            rightPath = path
                            loadRightPane()
                        },
                        onRefresh: { loadRightPane() },
                        onDelete: { files in
                            filesToDelete = files.map { ($0, rightLocation, false) }
                            showDeleteConfirmation = true
                        },
                        onTransfer: { files in
                            transferFromRightPane(files)
                        }
                    )
                }
                .frame(minWidth: 400)
            }
            
            Divider()
            
            // Transfer queue
            if !sftpService.transfers.isEmpty {
                TransferQueueView(transfers: sftpService.transfers)
                    .frame(height: 150)
            }
        }
        .frame(minWidth: 900, idealWidth: 1200, maxWidth: .infinity,
               minHeight: 600, idealHeight: 800, maxHeight: .infinity)
        .onAppear { setupInitialState() }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: { Text(errorMessage) }
        .alert("Delete Files", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                performDelete()
            }
        } message: {
            Text("Are you sure you want to delete \(filesToDelete.count) selected item(s)? This action cannot be undone.")
        }
        .onExitCommand {
            if let window = NSApp.keyWindow { window.close() }
        }
    }
    
    private func setupInitialState() {
        if let profile = initialProfile {
            rightLocation = .server(profile)
            rightPath = "~"
        }
        loadLeftPane()
        loadRightPane()
    }
    
    private func loadLeftPane() {
        isLoading = true
        sftpService.listFiles(at: leftPath, location: leftLocation) { result in
            isLoading = false
            switch result {
            case .success(let files):
                leftFiles = files
                leftSelection.removeAll()
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func loadRightPane() {
        isLoading = true
        sftpService.listFiles(at: rightPath, location: rightLocation) { result in
            isLoading = false
            switch result {
            case .success(let files):
                rightFiles = files
                rightSelection.removeAll()
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func transferLeftToRight() {
        for file in leftSelection {
            let destPath = rightPath.hasSuffix("/") ?
                "\(rightPath)\(file.name)" : "\(rightPath)/\(file.name)"
            
            sftpService.transferFile(
                from: file.path,
                sourceLocation: leftLocation,
                to: destPath,
                destinationLocation: rightLocation,
                isDirectory: file.isDirectory
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { loadRightPane() }
    }
    
    private func transferRightToLeft() {
        for file in rightSelection {
            let destPath = leftPath.hasSuffix("/") ?
                "\(leftPath)\(file.name)" : "\(leftPath)/\(file.name)"
            
            sftpService.transferFile(
                from: file.path,
                sourceLocation: rightLocation,
                to: destPath,
                destinationLocation: leftLocation,
                isDirectory: file.isDirectory
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { loadLeftPane() }
    }
    
    private func transferFromLeftPane(_ files: [RemoteFile]) {
        // Transfer from left pane to right pane
        for file in files {
            let destPath = rightPath.hasSuffix("/") ?
                "\(rightPath)\(file.name)" : "\(rightPath)/\(file.name)"
            
            sftpService.transferFile(
                from: file.path,
                sourceLocation: leftLocation,
                to: destPath,
                destinationLocation: rightLocation,
                isDirectory: file.isDirectory
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { loadRightPane() }
    }
    
    private func transferFromRightPane(_ files: [RemoteFile]) {
        // Transfer from right pane to left pane
        for file in files {
            let destPath = leftPath.hasSuffix("/") ?
                "\(leftPath)\(file.name)" : "\(leftPath)/\(file.name)"
            
            sftpService.transferFile(
                from: file.path,
                sourceLocation: rightLocation,
                to: destPath,
                destinationLocation: leftLocation,
                isDirectory: file.isDirectory
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { loadLeftPane() }
    }
    
    private func performDelete() {
        let group = DispatchGroup()
        
        for item in filesToDelete {
            group.enter()
            sftpService.deleteFile(at: item.file.path, location: item.location) { success in
                if !success {
                    self.errorMessage = "Failed to delete \(item.file.name)"
                    self.showError = true
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Refresh the appropriate panes after all deletions complete
            let needsLeftRefresh = self.filesToDelete.contains(where: { $0.isLeft })
            let needsRightRefresh = self.filesToDelete.contains(where: { !$0.isLeft })
            
            if needsLeftRefresh {
                self.loadLeftPane()
            }
            if needsRightRefresh {
                self.loadRightPane()
            }
            
            self.filesToDelete.removeAll()
        }
    }
}

// MARK: - Header (Path + Location)

struct FilePaneHeader: View {
    @Binding var location: FileLocation
    @Binding var path: String
    let profiles: [SSHProfile]
    let onLocationChange: () -> Void
    let onPathChange: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Location selector
            HStack {
                Menu {
                    Button("Localhost") {
                        location = .localhost
                        path = NSHomeDirectory()
                        onLocationChange()
                    }
                    
                    Divider()
                    
                    ForEach(profiles) { profile in
                        Button(profile.name) {
                            location = .server(profile)
                            path = "~"
                            onLocationChange()
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: location.displayName == "Localhost" ? "laptopcomputer" : "server.rack")
                        Text(location.displayName)
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(5)
                }
                .menuStyle(.borderlessButton)
                
                Spacer()
            }
            
            // Path input
            HStack(spacing: 6) {
                TextField("Path", text: $path, onCommit: onPathChange)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: onPathChange) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(10)
    }
}

// MARK: - File Pane Content (Table)

struct FilePaneContent: View {
    @Binding var files: [RemoteFile]
    @Binding var selection: Set<RemoteFile>
    @Binding var currentPath: String
    let location: FileLocation
    @Binding var sortOption: FileSortOption
    @Binding var sortAscending: Bool
    @Binding var columnWidths: ColumnWidths
    let isLoading: Bool
    let onNavigate: (String) -> Void
    let onRefresh: () -> Void
    let onDelete: ([RemoteFile]) -> Void
    let onTransfer: ([RemoteFile]) -> Void
    
    // Layout constants
    private let iconWidth: CGFloat = 28
    private let gripWidth: CGFloat = 8
    private let rowHeight: CGFloat = 24
    private let headerHeight: CGFloat = 30
    
    // Resize ranges
    private let nameRange: ClosedRange<CGFloat> = 120...600
    private let sizeRange: ClosedRange<CGFloat> = 60...160
    private let permRange: ClosedRange<CGFloat> = 70...180
    private let dateRange: ClosedRange<CGFloat> = 110...260 // no resizer for date, kept for consistency
    
    // Transient drag state to prevent flicker (commit only on .end)
    @State private var activeDrag: (key: ColumnKey, start: CGFloat, delta: CGFloat)?
    // Live guideline position during resize (in content coordinates).
    @State private var guideX: CGFloat?
    
    private var totalContentWidth: CGFloat {
        // icon + name + grip + size + grip + permissions + grip + date
        iconWidth
        + columnWidths.name + gripWidth
        + columnWidths.size + gripWidth
        + columnWidths.permissions + gripWidth
        + columnWidths.date
    }
    
    var sortedFiles: [RemoteFile] {
        files.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory } // dirs first
            
            let asc: Bool
            switch sortOption {
            case .name:
                asc = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .size:
                asc = a.size < b.size
            case .date:
                let d1 = a.modifiedDate ?? .distantPast
                let d2 = b.modifiedDate ?? .distantPast
                asc = d1 < d2
            case .type:
                let e1 = URL(fileURLWithPath: a.name).pathExtension
                let e2 = URL(fileURLWithPath: b.name).pathExtension
                if e1 == e2 {
                    asc = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                } else {
                    asc = e1.localizedCaseInsensitiveCompare(e2) == .orderedAscending
                }
            }
            return sortAscending ? asc : !asc
        }
    }
    
    var body: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            }
        } else {
            // Horizontal scroll if columns exceed pane width
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Header
                    FileListHeader(
                        sortOption: $sortOption,
                        sortAscending: $sortAscending,
                        columnWidths: columnWidths,
                        iconWidth: iconWidth,
                        gripWidth: gripWidth,
                        height: headerHeight,
                        onResizePhase: handleResizePhase // callback for drag events
                    )
                    .frame(width: totalContentWidth, height: headerHeight)
                    .background(Color(NSColor.controlBackgroundColor))
                    .transaction { $0.disablesAnimations = true }
                    
                    Divider()
                    
                    // Rows
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            // Parent directory entry (no need to fabricate a RemoteFile)
                            // Show parent for all paths except root (/) and home (~)
                            if currentPath != "/" && currentPath != "~" {
                                FileRow(
                                    iconWidth: iconWidth,
                                    heights: rowHeight,
                                    nameWidth: columnWidths.name,
                                    sizeWidth: columnWidths.size,
                                    permWidth: columnWidths.permissions,
                                    dateWidth: columnWidths.date,
                                    file: nil,
                                    isParentRow: true,
                                    isSelected: false,
                                    onDoubleClick: {
                                        let parentPath = getParentPath(from: currentPath)
                                        onNavigate(parentPath)
                                    }
                                )
                            }
                            
                            ForEach(sortedFiles) { file in
                                FileRow(
                                    iconWidth: iconWidth,
                                    heights: rowHeight,
                                    nameWidth: columnWidths.name,
                                    sizeWidth: columnWidths.size,
                                    permWidth: columnWidths.permissions,
                                    dateWidth: columnWidths.date,
                                    file: file,
                                    isParentRow: false,
                                    isSelected: selection.contains(file),
                                    onDoubleClick: {
                                        if file.isDirectory { onNavigate(file.path) }
                                    }
                                )
                                .background(selection.contains(file) ? Color.accentColor.opacity(0.18) : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if NSEvent.modifierFlags.contains(.command) {
                                        if selection.contains(file) { selection.remove(file) } else { selection.insert(file) }
                                    } else {
                                        selection = [file]
                                    }
                                }
                                .transaction { $0.disablesAnimations = true }
                            }
                        }
                        .frame(width: totalContentWidth)
                    }
                    .scrollDisabled(activeDrag != nil) // smoother drags
                    .transaction { $0.disablesAnimations = true }
                }
                // Draw a live vertical guideline instead of live-resizing columns -> no flicker.
                .overlay(alignment: .topLeading) {
                    if let x = guideX {
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.9))
                                .frame(width: 2, height: proxy.size.height)
                                .offset(x: x)
                        }
                        .allowsHitTesting(false)
                    }
                }
                .frame(minWidth: totalContentWidth, alignment: .leading)
            }
            .contextMenu {
                if !selection.isEmpty {
                    Button(action: {
                        onTransfer(Array(selection))
                    }) {
                        Label("Transfer", systemImage: "arrow.right.arrow.left")
                    }
                    Divider()
                }
                Button("Refresh") { onRefresh() }
                Divider()
                Button("New Folder") {
                    // TODO: Implement new folder creation
                }
                if !selection.isEmpty {
                    Divider()
                    Button("Delete", role: .destructive) {
                        onDelete(Array(selection))
                    }
                }
            }
            .animation(nil, value: activeDrag?.delta) // ensure no implicit animations while dragging
        }
    }
    
    // Get parent path handling both local and remote paths properly
    private func getParentPath(from path: String) -> String {
        // Handle special cases
        if path == "/" || path == "~" {
            return path  // Can't go up from root or home
        }
        
        // For home-relative paths
        if path.hasPrefix("~/") {
            let withoutTilde = String(path.dropFirst(2))
            if !withoutTilde.contains("/") {
                // Direct child of home, go back to home
                return "~"
            }
            // Remove last component
            let components = withoutTilde.split(separator: "/")
            if components.count > 1 {
                let parentComponents = components.dropLast()
                return "~/" + parentComponents.joined(separator: "/")
            }
            return "~"
        }
        
        // For absolute paths
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        if components.isEmpty {
            return "/"
        }
        
        let parentComponents = components.dropLast()
        if parentComponents.isEmpty {
            return "/"
        }
        
        return "/" + parentComponents.joined(separator: "/")
    }
    
    // Handle header resize events; show guideline during drag and only commit on end
    private func handleResizePhase(_ key: ColumnKey, _ phase: ResizePhase) {
        switch phase {
        case .start:
            let startWidth: CGFloat
            switch key {
            case .name: startWidth = columnWidths.name
            case .size: startWidth = columnWidths.size
            case .permissions: startWidth = columnWidths.permissions
            }
            activeDrag = (key: key, start: startWidth, delta: 0)
            // Initialize guideline at current divider
            guideX = dividerX(for: key, proposed: startWidth)
            
        case .change(let dx):
            if var drag = activeDrag {
                drag.delta = dx
                activeDrag = drag
                // Move guideline with clamped proposed width
                let proposed: CGFloat
                switch drag.key {
                case .name: proposed = (drag.start + dx).clamped(to: nameRange)
                case .size: proposed = (drag.start + dx).clamped(to: sizeRange)
                case .permissions: proposed = (drag.start + dx).clamped(to: permRange)
                }
                guideX = dividerX(for: drag.key, proposed: proposed)
            }
            
        case .end:
            guard let drag = activeDrag else { return }
            var committed = columnWidths
            switch drag.key {
            case .name:
                committed.name = (drag.start + drag.delta).clamped(to: nameRange)
            case .size:
                committed.size = (drag.start + drag.delta).clamped(to: sizeRange)
            case .permissions:
                committed.permissions = (drag.start + drag.delta).clamped(to: permRange)
            }
            columnWidths = committed // single commit -> no flicker
            activeDrag = nil
            guideX = nil
        }
    }

    // Compute divider X position within content for a given column and proposed width.
    private func dividerX(for key: ColumnKey, proposed: CGFloat) -> CGFloat {
        switch key {
        case .name:
            return iconWidth + proposed
        case .size:
            return iconWidth + columnWidths.name + gripWidth + proposed
        case .permissions:
            return iconWidth + columnWidths.name + gripWidth + columnWidths.size + gripWidth + proposed
        }
    }
}

// MARK: - Header Row with Resizers

struct FileListHeader: View {
    @Binding var sortOption: FileSortOption
    @Binding var sortAscending: Bool
    
    // NOTE: For flicker-free behavior, this is a value (snapshot),
    // not a binding. The parent computes an "effective" width while dragging.
    let columnWidths: ColumnWidths
    
    let iconWidth: CGFloat
    let gripWidth: CGFloat
    let height: CGFloat
    
    // Callback to parent with which column is being resized
    let onResizePhase: (ColumnKey, ResizePhase) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Icon placeholder
            Color.clear.frame(width: iconWidth, height: height)
            
            // Name
            headerButton(title: "Name", isActive: sortOption == .name) {
                if sortOption == .name { sortAscending.toggle() } else { sortOption = .name; sortAscending = true }
            }
            .frame(width: columnWidths.name, height: height, alignment: .leading)
            resizer(gripWidth: gripWidth) { phase in
                onResizePhase(.name, phase)
            }
            
            // Size
            headerButton(title: "Size", isActive: sortOption == .size) {
                if sortOption == .size { sortAscending.toggle() } else { sortOption = .size; sortAscending = true }
            }
            .frame(width: columnWidths.size, height: height, alignment: .trailing)
            resizer(gripWidth: gripWidth) { phase in
                onResizePhase(.size, phase)
            }
            
            // Permissions (non-sortable label)
            Text("Permissions")
                .fontWeight(.regular)
                .padding(.horizontal, 4)
                .frame(width: columnWidths.permissions, height: height, alignment: .center)
            resizer(gripWidth: gripWidth) { phase in
                onResizePhase(.permissions, phase)
            }
            
            // Date (no resizer for last column to keep edge clean)
            headerButton(title: "Modified", isActive: sortOption == .date) {
                if sortOption == .date { sortAscending.toggle() } else { sortOption = .date; sortAscending = true }
            }
            .frame(width: columnWidths.date, height: height, alignment: .trailing)
        }
        .transaction { $0.disablesAnimations = true }
    }
    
    // Sortable header button
    @ViewBuilder
    private func headerButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if title == "Name" {
                    Text(title).fontWeight(isActive ? .semibold : .regular)
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    Text(title).fontWeight(isActive ? .semibold : .regular)
                }
                if isActive {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // Resizer Grip
    @ViewBuilder
    private func resizer(gripWidth: CGFloat, onPhase: @escaping (ResizePhase) -> Void) -> some View {
        ResizerGrip(width: gripWidth, onPhase: onPhase)
    }
}

private struct ResizerGrip: View {
    let width: CGFloat
    let onPhase: (ResizePhase) -> Void
    
    @State private var hovering = false
    @State private var dragging = false
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: width)
            .overlay(
                Rectangle()
                    .frame(width: 2)
                    .foregroundColor((hovering || dragging) ? .accentColor.opacity(0.9) : .gray.opacity(0.35))
            )
            .contentShape(Rectangle())
            .onHover { isHovering in
                hovering = isHovering
                if isHovering { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !dragging {
                            dragging = true
                            onPhase(.start)
                        }
                        onPhase(.change(value.translation.width))
                    }
                    .onEnded { _ in
                        dragging = false
                        onPhase(.end)
                    }
            )
            .transaction { $0.disablesAnimations = true }
    }
}

// MARK: - File Row

struct FileRow: View {
    let iconWidth: CGFloat
    let heights: CGFloat
    let nameWidth: CGFloat
    let sizeWidth: CGFloat
    let permWidth: CGFloat
    let dateWidth: CGFloat
    
    // file is optional to allow rendering the parent ("..") row without fabricating a RemoteFile
    let file: RemoteFile?
    let isParentRow: Bool
    let isSelected: Bool
    let onDoubleClick: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Icon
            Image(systemName: (isParentRow || (file?.isDirectory ?? false)) ? "folder.fill" : "doc.fill")
                .foregroundColor((isParentRow || (file?.isDirectory ?? false)) ? .blue : .gray)
                .frame(width: iconWidth, height: heights, alignment: .center)
            
            // Name
            Text(isParentRow ? ".." : (file?.name ?? ""))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 4)
                .frame(width: nameWidth, height: heights, alignment: .leading)
            
            // Vertical grip placeholder line (keeps alignment with header’s grip)
            Spacer().frame(width: 8).fixedSize()
            
            // Size
            Text(isParentRow ? "" : (file?.sizeString ?? ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .frame(width: sizeWidth, height: heights, alignment: .trailing)
            
            Spacer().frame(width: 8).fixedSize()
            
            // Permissions
            Text(isParentRow ? "" : (file?.permissions ?? ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .frame(width: permWidth, height: heights, alignment: .center)
            
            Spacer().frame(width: 8).fixedSize()
            
            // Date
            Text(isParentRow ? "" : (file?.dateString ?? ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .frame(width: dateWidth, height: heights, alignment: .trailing)
        }
        .frame(height: heights)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onDoubleClick)
        .transaction { $0.disablesAnimations = true }
    }
}

// MARK: - Transfer Queue

struct TransferQueueView: View {
    let transfers: [FileTransfer]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Transfer Queue")
                    .font(.headline)
                
                Spacer()
                
                // Show counts
                let activeCount = transfers.filter { $0.status == .transferring }.count
                let failedCount = transfers.filter { $0.status == .failed }.count
                let completedCount = transfers.filter { $0.status == .completed }.count
                
                if activeCount > 0 {
                    Label("\(activeCount)", systemImage: "arrow.right.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                
                if completedCount > 0 {
                    Label("\(completedCount)", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                if failedCount > 0 {
                    Label("\(failedCount)", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 5)
            
            Divider()
            
            if transfers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.right.arrow.left.circle")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary)
                    Text("No transfers in queue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(transfers) { transfer in
                            TransferRow(transfer: transfer)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct TransferRow: View {
    let transfer: FileTransfer
    @State private var showingError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(URL(fileURLWithPath: transfer.sourcePath).lastPathComponent)
                        .lineLimit(1)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("\(transfer.sourceLocation.displayName) → \(transfer.destinationLocation.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if transfer.status == .transferring {
                            Text(transfer.progressString)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Show error message for failed transfers
                    if transfer.status == .failed, let error = transfer.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(showingError ? nil : 1)
                            .truncationMode(.tail)
                    }
                }
                
                Spacer()
                
                if transfer.status == .transferring {
                    ProgressView(value: transfer.progress)
                        .frame(width: 100)
                } else if transfer.status == .failed && transfer.error != nil {
                    Button(action: { showingError.toggle() }) {
                        Image(systemName: showingError ? "chevron.up.circle" : "info.circle")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help(showingError ? "Hide error details" : "Show error details")
                }
            }
            
            // Expanded error details
            if showingError, transfer.status == .failed, let error = transfer.error {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    Text("Error Details:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 4) {
                        Text("From:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(transfer.sourcePath)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    
                    HStack(spacing: 4) {
                        Text("To:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(transfer.destinationPath)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(5)
    }
    
    private var statusIcon: String {
        switch transfer.status {
        case .pending: return "clock"
        case .transferring: return "arrow.right.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch transfer.status {
        case .pending: return .gray
        case .transferring: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Utilities

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
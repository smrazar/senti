import AppKit
import SwiftUI

/// Recording settings, plus the handful of files most recently written.
struct RecordingSettingsView: View {

    @ObservedObject var preferences: Preferences
    @State private var recent: [Recording] = []

    struct Recording: Identifiable, Hashable {
        let url: URL
        let modified: Date
        let bytes: Int64
        var id: URL { url }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.section) {
            settings
            recentGroup
        }
        .task { reloadRecent() }
        .onChange(of: preferences.recordingFolderPath) { _, _ in reloadRecent() }
    }

    // MARK: Settings

    private var settings: some View {
        SettingsGroup(title: "Recording", symbol: Sym.paneRecording) {
            SettingsRow(label: "Record every session",
                        description: "Each mirror session is written to a video file as it plays.") {
                SentiToggle(isOn: $preferences.recordingEnabled)
            }
            RowDivider()
            SettingsRow(label: "Format",
                        description: "mp4 opens anywhere. mkv survives a session that ends badly.") {
                InlinePicker(selection: $preferences.recordingFormat,
                             options: [("mp4", "mp4"), ("mkv", "mkv")])
            }
            RowDivider()
            SettingsRow(label: "Save to",
                        description: preferences.recordingFolderPath.replacingOccurrences(
                            of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")) {
                HStack(spacing: Theme.Space.s8) {
                    SecondaryButton(title: "Show", symbol: Sym.reveal) { revealFolder() }
                    SecondaryButton(title: "Change…") { chooseFolder() }
                }
            }
        }
    }

    // MARK: Recent files

    private var recentGroup: some View {
        SettingsGroup(title: "Recent recordings", symbol: "film") {
            if recent.isEmpty {
                EmptyState(symbol: "film",
                           title: "Nothing recorded yet",
                           message: "Turn recording on and mirror a phone — the files land in the folder above.")
            } else {
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { RowDivider() }
                    SettingsRow(label: item.url.lastPathComponent,
                                description: "\(Self.sizeFormatter.string(fromByteCount: item.bytes)) · \(Self.dateFormatter.string(from: item.modified))",
                                symbol: "film") {
                        HStack(spacing: Theme.Space.s8) {
                            SecondaryButton(title: "Show") {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            }
                            SecondaryButton(title: "Open") {
                                NSWorkspace.shared.open(item.url)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func revealFolder() {
        let folder = preferences.recordingFolder
        // The folder is created lazily at the first recording, so it may not exist yet — asking
        // Finder to reveal nothing does nothing at all, which reads as a dead button.
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = preferences.recordingFolder
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        preferences.recordingFolderPath = url.path
    }

    private func reloadRecent() {
        let folder = preferences.recordingFolder
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: folder,
                                                                  includingPropertiesForKeys: keys,
                                                                  options: [.skipsHiddenFiles])) ?? []
        recent = files
            .filter { ["mp4", "mkv"].contains($0.pathExtension.lowercased()) }
            .compactMap { url in
                let values = try? url.resourceValues(forKeys: Set(keys))
                return Recording(url: url,
                                 modified: values?.contentModificationDate ?? .distantPast,
                                 bytes: Int64(values?.fileSize ?? 0))
            }
            .sorted { $0.modified > $1.modified }
            .prefix(5)
            .map { $0 }
    }

    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

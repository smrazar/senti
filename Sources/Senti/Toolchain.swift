import Foundation

/// Unpacks the bundled scrcpy + adb build into Application Support on first launch, and hands
/// out the two binary paths everything else needs.
///
/// The tarball ships inside the app bundle, so provisioning works with no network and nothing
/// to install. Extraction is skipped when the binaries are already present and executable, which
/// makes `provision()` cheap enough to call on every launch.
@MainActor
final class Toolchain: ObservableObject {

    /// The scrcpy release bundled in `Resources/`. One constant — the tarball name, the extracted
    /// directory name and the version shown in Settings all derive from it.
    static let version = "4.0"
    private static let arch = "aarch64"

    enum Status: Equatable {
        case idle
        case provisioning
        case ready
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    /// `~/Library/Application Support/senti/`
    private var supportRoot: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("senti", isDirectory: true)
    }

    /// Extracted payload root — the tarball contains one top-level directory of this name.
    private var extractedRoot: URL {
        supportRoot.appendingPathComponent("scrcpy-macos-\(Self.arch)-v\(Self.version)", isDirectory: true)
    }

    var scrcpyPath: String { extractedRoot.appendingPathComponent("scrcpy").path }
    var adbPath: String { extractedRoot.appendingPathComponent("adb").path }

    /// The tarball inside the app bundle.
    private var bundledTarball: URL? {
        Bundle.main.url(forResource: "scrcpy-macos-\(Self.arch)-v\(Self.version)", withExtension: "tar.gz")
    }

    var isReady: Bool { status == .ready }

    // MARK: - Provisioning

    /// Extracts the toolchain if it is not already in place. Safe to call repeatedly.
    func provision() async {
        if binariesPresent() {
            status = .ready
            return
        }
        await extract(force: false)
    }

    /// Deletes the extracted copy and unpacks it again. For Settings → Toolchain when something
    /// has gone wrong with the files on disk.
    func reprovision() async {
        await extract(force: true)
    }

    private func binariesPresent() -> Bool {
        let fm = FileManager.default
        return fm.isExecutableFile(atPath: scrcpyPath) && fm.isExecutableFile(atPath: adbPath)
    }

    private func extract(force: Bool) async {
        guard let tarball = bundledTarball else {
            status = .failed("The scrcpy toolchain is missing from the app bundle. Reinstall senti.")
            return
        }

        status = .provisioning
        let root = supportRoot
        let extracted = extractedRoot

        let result: String? = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            do {
                if force, fm.fileExists(atPath: extracted.path) {
                    try fm.removeItem(at: extracted)
                }
                try fm.createDirectory(at: root, withIntermediateDirectories: true)
            } catch {
                return "Could not prepare \(root.path): \(error.localizedDescription)"
            }

            // `tar` rather than a Swift archive library: it is on every Mac, it preserves the
            // executable bit, and the alternative is a dependency for one call site.
            guard Shell.run("/usr/bin/tar", ["xzf", tarball.path, "-C", root.path], timeout: 120) != nil else {
                return "Could not unpack the scrcpy toolchain."
            }

            // The files arrive without the quarantine flag cleared. Left in place, macOS blocks
            // the launch with a dialog that names a binary the user has never heard of.
            _ = Shell.run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", extracted.path], timeout: 30)

            for path in [extracted.appendingPathComponent("scrcpy").path,
                         extracted.appendingPathComponent("adb").path] {
                guard fm.fileExists(atPath: path) else {
                    return "The toolchain unpacked but \(URL(fileURLWithPath: path).lastPathComponent) is not where it should be."
                }
                try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
            }
            return nil
        }.value

        if let result {
            status = .failed(result)
        } else {
            status = .ready
        }
    }
}

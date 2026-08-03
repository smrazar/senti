import Foundation

/// Runs a command-line tool and returns its stdout.
///
/// **Never call this from the main thread.** A process launch is tens of milliseconds, and the
/// device poll runs every few seconds — doing that synchronously on main visibly stutters the
/// panel.
enum Shell {

    /// Absolute paths only. A relative name would resolve against whatever `PATH` the app
    /// inherited, which for a launched-from-Finder app is not the user's shell `PATH`.
    static func run(_ launchPath: String, _ arguments: [String], timeout: TimeInterval = 8) -> String? {
        guard FileManager.default.isExecutableFile(atPath: launchPath) else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            NSLog("senti: could not run \(launchPath) — \(error.localizedDescription)")
            return nil
        }

        // Read before waiting. A tool that fills the 64KB pipe buffer blocks forever on write
        // while we block on `waitUntilExit`, and the app deadlocks with no error anywhere.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning {
            process.terminate()
            NSLog("senti: \(launchPath) timed out after \(timeout)s")
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}

import Foundation

/// Talks to `adb`. Nothing here touches the UI — callers hop to the main actor themselves.
enum AdbService {

    /// Parses `adb devices -l`. Lines look like:
    ///
    ///     R5CT30ABCDE   device product:b6qxxx model:SM_F956B device:b6q transport_id:3
    ///     9A271FFAZ004  unauthorized usb:339869696X
    ///
    /// The header line and blank lines are skipped. A line whose token soup we do not recognise
    /// still yields a device with `nil` model rather than being dropped — an unknown phone the
    /// user can see beats a phone that silently does not exist.
    static func listDevices(adbPath: String) -> [Device] {
        guard let output = Shell.run(adbPath, ["devices", "-l"]) else { return [] }
        return parseDevices(output)
    }

    /// Split out from `listDevices` so the parser is testable without an adb binary.
    static func parseDevices(_ output: String) -> [Device] {
        output
            .split(separator: "\n")
            .compactMap { line -> Device? in
                let fields = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
                guard fields.count >= 2 else { return nil }
                guard !line.hasPrefix("List of devices") else { return nil }
                // adb prefixes progress chatter with '*'; ignore it.
                guard !fields[0].hasPrefix("*") else { return nil }

                let serial = fields[0]
                let state = Device.State(adbToken: fields[1])

                func value(_ key: String) -> String? {
                    fields
                        .first { $0.hasPrefix("\(key):") }?
                        .dropFirst(key.count + 1)
                        .replacingOccurrences(of: "_", with: " ")
                }

                return Device(serial: serial,
                              state: state,
                              model: value("model"),
                              product: value("product"))
            }
    }

    /// Starts the adb server explicitly so the first `devices` call is not the thing that pays
    /// the two-second daemon-launch cost.
    static func startServer(adbPath: String) {
        _ = Shell.run(adbPath, ["start-server"], timeout: 20)
    }

    /// Kills any adb server already listening on port 5037 — including one a Homebrew install
    /// or Android Studio started. Two servers on one port is the classic "device not found"
    /// while the phone is plainly plugged in.
    static func killServer(adbPath: String) {
        _ = Shell.run(adbPath, ["kill-server"], timeout: 10)
    }
}

#if DEBUG
extension AdbService {
    static func selfCheck() {
        let sample = """
        List of devices attached
        R5CT30ABCDE            device product:b6qxxx model:SM_F956B device:b6q transport_id:3
        9A271FFAZ004           unauthorized usb:339869696X
        emulator-5554          offline

        """
        let devices = parseDevices(sample)
        assert(devices.count == 3, "expected 3 devices, parsed \(devices.count)")
        assert(devices[0].serial == "R5CT30ABCDE", "serial mis-parsed: \(devices[0].serial)")
        assert(devices[0].state == .ready, "device token should map to .ready")
        assert(devices[0].model == "SM F956B", "model underscores should become spaces: \(devices[0].model ?? "nil")")
        assert(devices[1].state == .unauthorized, "unauthorized token mis-mapped")
        assert(devices[2].state == .offline, "offline token mis-mapped")
        assert(devices[2].model == nil, "a device with no model field must parse with nil model")
        assert(parseDevices("List of devices attached\n").isEmpty, "header alone must yield no devices")
    }
}
#endif

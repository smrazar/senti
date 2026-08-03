import Foundation

/// One Android device as adb reports it.
///
/// A value type on purpose: the poll rebuilds the whole list every few seconds, and comparing
/// two arrays for equality is how the panel avoids redrawing when nothing changed.
struct Device: Identifiable, Hashable, Sendable {

    /// adb's serial. Stable across reconnects, so it keys history and custom names.
    let serial: String
    let state: State
    /// `model:SM_F956B` from `adb devices -l`, underscores already turned back into spaces.
    let model: String?
    let product: String?

    var id: String { serial }

    enum State: String, Sendable {
        /// Connected, authorised, ready to mirror.
        case ready
        /// Plugged in, but the user has not tapped "Allow USB debugging" yet.
        case unauthorized
        /// adb sees it but cannot talk to it — usually a cable or a device still booting.
        case offline

        init(adbToken: String) {
            switch adbToken {
            case "device": self = .ready
            case "unauthorized": self = .unauthorized
            default: self = .offline
            }
        }
    }

    /// What the panel shows when the user has not renamed the device.
    var defaultName: String {
        model ?? product ?? serial
    }

    var isReady: Bool { state == .ready }

    /// One line of plain English under the device name. Never shows a raw adb token.
    var statusText: String {
        switch state {
        case .ready: return "Ready"
        case .unauthorized: return "Tap “Allow USB debugging” on the phone"
        case .offline: return "Not responding — try another cable or port"
        }
    }
}

import Foundation

/// Every SF Symbol name the app uses, in one place. A typo'd symbol name renders as nothing at
/// all — an invisible button — so they are constants rather than string literals at call sites.
enum Sym {
    // Menu bar
    static let menuBarIdle = "iphone"
    static let menuBarActive = "iphone.gen3.radiowaves.left.and.right"

    // Devices
    static let device = "iphone"
    static let deviceMirroring = "iphone.gen3.radiowaves.left.and.right"
    static let deviceLocked = "lock.iphone"
    static let deviceOffline = "iphone.slash"
    static let deviceAbsent = "iphone.badge.exclamationmark"

    // Actions
    static let mirror = "play.fill"
    static let stop = "stop.fill"
    static let settings = "gearshape"
    static let quit = "power"
    static let rename = "pencil"
    static let forget = "trash"
    static let autoMirror = "bolt"
    static let refresh = "arrow.clockwise"
    static let reveal = "folder"
    static let search = "magnifyingglass"

    // Settings panes
    static let paneMirroring = "rectangle.on.rectangle"
    static let paneRecording = "record.circle"
    static let paneToolchain = "shippingbox"
    static let paneShortcuts = "command"
    static let paneGeneral = "gearshape"
    static let paneHelp = "questionmark.circle"
    static let paneAbout = "info.circle"
    static let paneAdvanced = "slider.horizontal.3"
    static let newDisplay = "rectangle.stack.badge.plus"
    static let phoneScreen = "iphone"
    static let appearance = "circle.lefthalf.filled"

    // States
    static let recording = "record.circle"
    static let warning = "exclamationmark.triangle"
    static let ready = "checkmark.circle"
    static let usb = "cable.connector"
}

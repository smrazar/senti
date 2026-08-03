import AppKit
import Carbon.HIToolbox

/// One global keyboard shortcut, registered with Carbon's `RegisterEventHotKey`.
///
/// Carbon rather than a `CGEventTap`: registration needs no Accessibility grant, and senti has
/// no other reason to ask for one. The trade-off is that a chord another app has already claimed
/// silently never fires — `register()` returns false in that case so Settings can say so.
@MainActor
final class HotKey {

    private let keyCode: UInt32
    private let modifiers: UInt32
    private let action: () -> Void

    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let id: UInt32

    /// Every live instance, so the C callback can find the right one from its hot-key id.
    private static var registry: [UInt32: HotKey] = [:]
    private static var nextID: UInt32 = 1

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.action = action
        self.id = Self.nextID
        Self.nextID += 1
    }

    deinit {
        // `unregister` is main-actor; deinit may not be. Copy the refs out and clean up there.
        let hotKeyRef = ref
        let handlerRef = handler
        let identifier = id
        Task { @MainActor in
            if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
            if let handlerRef { RemoveEventHandler(handlerRef) }
            HotKey.registry[identifier] = nil
        }
    }

    /// Returns false when the chord is already owned by another process.
    @discardableResult
    func register() -> Bool {
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let identifier = hotKeyID.id
            Task { @MainActor in HotKey.registry[identifier]?.action() }
            return noErr
        }, 1, &eventType, nil, &handler)

        let hotKeyID = EventHotKeyID(signature: OSType(0x736E_7469), id: id) // 'snti'
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr else {
            unregister()
            return false
        }
        Self.registry[id] = self
        return true
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
        ref = nil
        handler = nil
        Self.registry[id] = nil
    }

    // MARK: - Display

    /// Carbon modifier mask from an `NSEvent` one, for storing what the recorder captured.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    /// `⌃⌥⌘M`-style label for a stored shortcut. Empty string when nothing is set.
    static func label(keyCode: Int, modifiers: Int) -> String {
        guard keyCode != 0 || modifiers != 0 else { return "" }
        var text = ""
        if modifiers & Int(controlKey) != 0 { text += "⌃" }
        if modifiers & Int(optionKey) != 0 { text += "⌥" }
        if modifiers & Int(shiftKey) != 0 { text += "⇧" }
        if modifiers & Int(cmdKey) != 0 { text += "⌘" }
        return text + keyName(UInt32(keyCode))
    }

    /// Names the printable key for a virtual key code, via the current keyboard layout so a
    /// non-US layout does not label its keys with US letters.
    static func keyName(_ keyCode: UInt32) -> String {
        if let special = specialKeyNames[keyCode] { return special }

        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return "Key \(keyCode)" }

        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)

        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                  UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysBit),
                                  &deadKeyState, characters.count, &length, &characters)
        }
        guard status == noErr, length > 0 else { return "Key \(keyCode)" }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }

    private static let specialKeyNames: [UInt32: String] = [
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Return): "↩",
        UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Escape): "⎋",
        UInt32(kVK_Delete): "⌫",
        UInt32(kVK_LeftArrow): "←",
        UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑",
        UInt32(kVK_DownArrow): "↓",
    ]
}

#if DEBUG
extension HotKey {
    @MainActor
    static func selfCheck() {
        assert(label(keyCode: 0, modifiers: 0).isEmpty, "an unset shortcut must render as nothing")
        let all = carbonModifiers(from: [.command, .option, .control, .shift])
        assert(all == UInt32(cmdKey | optionKey | controlKey | shiftKey),
               "modifier translation dropped a flag")
        let rendered = label(keyCode: Int(kVK_Space), modifiers: Int(cmdKey | shiftKey))
        assert(rendered == "⇧⌘Space", "modifier order must read ⌃⌥⇧⌘, got \(rendered)")
    }
}
#endif

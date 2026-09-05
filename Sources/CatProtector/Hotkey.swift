import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// The modifier keys that can be part of the toggle shortcut.
struct HotkeyModifiers: OptionSet, Codable, Hashable {
    let rawValue: UInt8

    static let control = HotkeyModifiers(rawValue: 1 << 0)
    static let option = HotkeyModifiers(rawValue: 1 << 1)
    static let shift = HotkeyModifiers(rawValue: 1 << 2)
    static let command = HotkeyModifiers(rawValue: 1 << 3)

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Extracts only the four "real" modifiers from a Core Graphics flag set,
    /// ignoring things like caps lock, fn, or the numeric keypad bit.
    init(cgFlags: CGEventFlags) {
        var modifiers: HotkeyModifiers = []
        if cgFlags.contains(.maskControl) { modifiers.insert(.control) }
        if cgFlags.contains(.maskAlternate) { modifiers.insert(.option) }
        if cgFlags.contains(.maskShift) { modifiers.insert(.shift) }
        if cgFlags.contains(.maskCommand) { modifiers.insert(.command) }
        self = modifiers
    }

    init(nsFlags: NSEvent.ModifierFlags) {
        var modifiers: HotkeyModifiers = []
        if nsFlags.contains(.control) { modifiers.insert(.control) }
        if nsFlags.contains(.option) { modifiers.insert(.option) }
        if nsFlags.contains(.shift) { modifiers.insert(.shift) }
        if nsFlags.contains(.command) { modifiers.insert(.command) }
        self = modifiers
    }

    /// The modifiers rendered with the standard macOS glyphs, in the order
    /// macOS itself uses in menus: control, option, shift, command.
    var symbols: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }

    /// Shift on its own is too easy to hit by accident (or by paw), so a
    /// shortcut must include at least one of control, option, or command.
    var isSafeForShortcut: Bool {
        !intersection([.control, .option, .command]).isEmpty
    }
}

/// A global keyboard shortcut: a hardware key code plus the modifiers that
/// must be held. Key codes are layout independent, so the shortcut keeps
/// working even if the user switches keyboard layouts.
struct Hotkey: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: HotkeyModifiers

    /// Control + Option + Command + L. Three modifiers is deliberately a lot:
    /// a cat is very unlikely to press it, and a human can still do it with one hand.
    static let defaultHotkey = Hotkey(
        keyCode: UInt16(kVK_ANSI_L),
        modifiers: [.control, .option, .command]
    )

    /// Whether a key press with the given key code and flags is this shortcut.
    /// Modifiers must match exactly, so ⌃⌥⌘L does not match ⌃⌥⇧⌘L.
    func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        keyCode == Int64(self.keyCode) && HotkeyModifiers(cgFlags: flags) == modifiers
    }

    /// Human readable form such as "⌃⌥⌘L".
    var displayString: String {
        modifiers.symbols + KeyNames.name(for: keyCode)
    }
}

/// Turns hardware key codes into something readable.
enum KeyNames {
    private static let specialKeys: [UInt16: String] = [
        UInt16(kVK_Return): "↩",
        UInt16(kVK_Tab): "⇥",
        UInt16(kVK_Space): "Space",
        UInt16(kVK_Delete): "⌫",
        UInt16(kVK_Escape): "⎋",
        UInt16(kVK_ForwardDelete): "⌦",
        UInt16(kVK_Home): "↖",
        UInt16(kVK_End): "↘",
        UInt16(kVK_PageUp): "⇞",
        UInt16(kVK_PageDown): "⇟",
        UInt16(kVK_LeftArrow): "←",
        UInt16(kVK_RightArrow): "→",
        UInt16(kVK_UpArrow): "↑",
        UInt16(kVK_DownArrow): "↓",
        UInt16(kVK_ANSI_KeypadEnter): "⌤",
        UInt16(kVK_ANSI_KeypadClear): "⌧",
        UInt16(kVK_Help): "Help",
        UInt16(kVK_F1): "F1",
        UInt16(kVK_F2): "F2",
        UInt16(kVK_F3): "F3",
        UInt16(kVK_F4): "F4",
        UInt16(kVK_F5): "F5",
        UInt16(kVK_F6): "F6",
        UInt16(kVK_F7): "F7",
        UInt16(kVK_F8): "F8",
        UInt16(kVK_F9): "F9",
        UInt16(kVK_F10): "F10",
        UInt16(kVK_F11): "F11",
        UInt16(kVK_F12): "F12",
        UInt16(kVK_F13): "F13",
        UInt16(kVK_F14): "F14",
        UInt16(kVK_F15): "F15",
        UInt16(kVK_F16): "F16",
        UInt16(kVK_F17): "F17",
        UInt16(kVK_F18): "F18",
        UInt16(kVK_F19): "F19",
        UInt16(kVK_F20): "F20",
    ]

    static func name(for keyCode: UInt16) -> String {
        if let special = specialKeys[keyCode] {
            return special
        }
        if let character = layoutCharacter(for: keyCode), !character.isEmpty {
            return character.uppercased()
        }
        return "Key \(keyCode)"
    }

    /// Asks the current keyboard layout what character a key code produces.
    private static func layoutCharacter(for keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue() as Data

        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)

        let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
            guard let base = buffer.baseAddress else { return OSStatus(paramErr) }
            let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
            return UCKeyTranslate(
                layout,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysMask),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }

        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: characters, count: length)
        // Control characters (tab, return, etc.) are covered by the table above.
        return text.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) } ? text : nil
    }
}

import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import CatProtector

final class HotkeyTests: XCTestCase {
    func testDefaultHotkeyUsesThreeModifiers() {
        XCTAssertEqual(Hotkey.defaultHotkey.modifiers, [.control, .option, .command])
        XCTAssertEqual(Hotkey.defaultHotkey.keyCode, UInt16(kVK_ANSI_L))
    }

    func testModifierSymbolsFollowMacOSOrder() {
        let all: HotkeyModifiers = [.command, .shift, .option, .control]
        XCTAssertEqual(all.symbols, "⌃⌥⇧⌘")
        XCTAssertEqual(HotkeyModifiers([.command]).symbols, "⌘")
    }

    func testMatchesRequiresExactModifiers() {
        let hotkey = Hotkey.defaultHotkey
        let exact: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
        XCTAssertTrue(hotkey.matches(keyCode: Int64(kVK_ANSI_L), flags: exact))

        let withShift: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskShift]
        XCTAssertFalse(hotkey.matches(keyCode: Int64(kVK_ANSI_L), flags: withShift))

        let missingOne: CGEventFlags = [.maskControl, .maskCommand]
        XCTAssertFalse(hotkey.matches(keyCode: Int64(kVK_ANSI_L), flags: missingOne))

        XCTAssertFalse(hotkey.matches(keyCode: Int64(kVK_ANSI_K), flags: exact))
    }

    func testMatchesIgnoresIncidentalFlags() {
        let hotkey = Hotkey.defaultHotkey
        let noisy: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskNonCoalesced, .maskAlphaShift, .maskNumericPad]
        XCTAssertTrue(hotkey.matches(keyCode: Int64(kVK_ANSI_L), flags: noisy))
    }

    func testShiftAloneIsNotASafeShortcut() {
        XCTAssertFalse(HotkeyModifiers([.shift]).isSafeForShortcut)
        XCTAssertFalse(HotkeyModifiers([]).isSafeForShortcut)
        XCTAssertTrue(HotkeyModifiers([.command]).isSafeForShortcut)
        XCTAssertTrue(HotkeyModifiers([.shift, .control]).isSafeForShortcut)
    }

    func testCodableRoundTrip() throws {
        let original = Hotkey(keyCode: UInt16(kVK_F5), modifiers: [.option, .shift])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Hotkey.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSpecialKeyNames() {
        XCTAssertEqual(KeyNames.name(for: UInt16(kVK_Escape)), "⎋")
        XCTAssertEqual(KeyNames.name(for: UInt16(kVK_F5)), "F5")
        XCTAssertEqual(KeyNames.name(for: UInt16(kVK_Space)), "Space")
        XCTAssertEqual(KeyNames.name(for: UInt16(kVK_LeftArrow)), "←")
    }

    func testDisplayStringStartsWithModifiers() {
        let hotkey = Hotkey(keyCode: UInt16(kVK_F5), modifiers: [.control, .command])
        XCTAssertEqual(hotkey.displayString, "⌃⌘F5")
    }
}

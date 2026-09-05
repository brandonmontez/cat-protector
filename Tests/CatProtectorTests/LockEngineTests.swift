import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import CatProtector

final class LockEngineTests: XCTestCase {
    private let hotkeyFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
    private let hotkeyCode = Int64(kVK_ANSI_L)
    private let otherKey = Int64(kVK_ANSI_A)

    private func makeEngine() -> LockEngine {
        LockEngine(hotkey: .defaultHotkey)
    }

    func testEverythingPassesWhenUnlocked() {
        var engine = makeEngine()
        XCTAssertEqual(engine.process(type: .keyDown, keyCode: otherKey, flags: [], isRepeat: false), .pass)
        XCTAssertEqual(engine.process(type: .keyUp, keyCode: otherKey, flags: [], isRepeat: false), .pass)
        XCTAssertEqual(engine.process(type: .mouseMoved, keyCode: 0, flags: [], isRepeat: false), .pass)
        XCTAssertEqual(engine.process(type: .leftMouseDown, keyCode: 0, flags: [], isRepeat: false), .pass)
        XCTAssertEqual(engine.process(type: .scrollWheel, keyCode: 0, flags: [], isRepeat: false), .pass)
    }

    func testHotkeyTogglesLockAndIsSwallowed() {
        var engine = makeEngine()
        XCTAssertEqual(engine.process(type: .keyDown, keyCode: hotkeyCode, flags: hotkeyFlags, isRepeat: false), .toggle)
        XCTAssertTrue(engine.isLocked)

        // The matching keyUp never reaches an app either.
        XCTAssertEqual(engine.process(type: .keyUp, keyCode: hotkeyCode, flags: hotkeyFlags, isRepeat: false), .swallow)

        XCTAssertEqual(engine.process(type: .keyDown, keyCode: hotkeyCode, flags: hotkeyFlags, isRepeat: false), .toggle)
        XCTAssertFalse(engine.isLocked)
        XCTAssertEqual(engine.process(type: .keyUp, keyCode: hotkeyCode, flags: hotkeyFlags, isRepeat: false), .swallow)

        // A later, unrelated keyUp is not affected.
        XCTAssertEqual(engine.process(type: .keyUp, keyCode: otherKey, flags: [], isRepeat: false), .pass)
    }

    func testEverythingIsSwallowedWhenLocked() {
        var engine = makeEngine()
        engine.setLocked(true)

        let types: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .otherMouseDown, .scrollWheel,
            CGEventType(rawValue: 14)!, // NSSystemDefined: media and volume keys
        ]
        for type in types {
            XCTAssertEqual(engine.process(type: type, keyCode: otherKey, flags: [], isRepeat: false), .swallow, "\(type.rawValue)")
        }
        XCTAssertTrue(engine.isLocked)
    }

    func testAutoRepeatOfHotkeyDoesNotRetoggle() {
        var engine = makeEngine()
        XCTAssertEqual(engine.process(type: .keyDown, keyCode: hotkeyCode, flags: hotkeyFlags, isRepeat: false), .toggle)
        XCTAssertTrue(engine.isLocked)
        XCTAssertEqual(engine.process(type: .keyDown, keyCode: hotkeyCode, flags: hotkeyFlags, isRepeat: true), .swallow)
        XCTAssertEqual(engine.process(type: .keyDown, keyCode: hotkeyCode, flags: hotkeyFlags, isRepeat: true), .swallow)
        XCTAssertTrue(engine.isLocked)
    }

    func testHotkeyWorksWhenKeyEventFlagsAreEmptyButModifiersWereTracked() {
        var engine = makeEngine()
        XCTAssertEqual(engine.process(type: .flagsChanged, keyCode: 0, flags: hotkeyFlags, isRepeat: false), .pass)
        XCTAssertEqual(engine.process(type: .keyDown, keyCode: hotkeyCode, flags: [], isRepeat: false), .toggle)
        XCTAssertTrue(engine.isLocked)
    }

    func testModifierEventsAreSwallowedWhileLockedButStillTracked() {
        var engine = makeEngine()
        engine.setLocked(true)
        XCTAssertEqual(engine.process(type: .flagsChanged, keyCode: 0, flags: hotkeyFlags, isRepeat: false), .swallow)
        XCTAssertEqual(engine.trackedFlags, hotkeyFlags)
        XCTAssertEqual(engine.process(type: .keyDown, keyCode: hotkeyCode, flags: [], isRepeat: false), .toggle)
        XCTAssertFalse(engine.isLocked)
    }

    func testWrongModifiersWhileLockedStaySwallowed() {
        var engine = makeEngine()
        engine.setLocked(true)
        XCTAssertEqual(engine.process(type: .keyDown, keyCode: hotkeyCode, flags: [.maskCommand], isRepeat: false), .swallow)
        XCTAssertTrue(engine.isLocked)
    }

    func testPassthroughLetsEverythingThroughEvenWhenLocked() {
        var engine = makeEngine()
        engine.setLocked(true)
        engine.isPassthrough = true
        XCTAssertEqual(engine.process(type: .keyDown, keyCode: otherKey, flags: [], isRepeat: false), .pass)
        XCTAssertEqual(engine.process(type: .keyDown, keyCode: hotkeyCode, flags: hotkeyFlags, isRepeat: false), .pass)
        XCTAssertTrue(engine.isLocked)
    }

    func testChangingHotkeyTakesEffectImmediately() {
        var engine = makeEngine()
        engine.hotkey = Hotkey(keyCode: UInt16(kVK_F12), modifiers: [.command])
        XCTAssertEqual(engine.process(type: .keyDown, keyCode: hotkeyCode, flags: hotkeyFlags, isRepeat: false), .pass)
        XCTAssertEqual(engine.process(type: .keyDown, keyCode: Int64(kVK_F12), flags: [.maskCommand], isRepeat: false), .toggle)
        XCTAssertTrue(engine.isLocked)
    }
}

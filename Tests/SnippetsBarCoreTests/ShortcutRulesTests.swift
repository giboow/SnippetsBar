import XCTest
import Carbon.HIToolbox
import SnippetsBarCore

final class ShortcutRulesTests: XCTestCase {
    func testDefaultShortcutIsAllowed() {
        XCTAssertNil(ShortcutRules.problem(with: KeyCombo(keyCode: kVK_ANSI_V, command: true, control: true)))
    }

    func testSingleModifierIsRefused() {
        let refused = [
            KeyCombo(keyCode: kVK_ANSI_C, command: true),              // Copy
            KeyCombo(keyCode: kVK_ANSI_S, command: true, shift: true), // Save As / Duplicate
            KeyCombo(keyCode: kVK_ANSI_E, option: true),               // types an accent
            KeyCombo(keyCode: kVK_ANSI_C, control: true),              // terminal interrupt
            KeyCombo(keyCode: kVK_F5),                                 // no modifier
        ]
        for combo in refused {
            XCTAssertEqual(ShortcutRules.problem(with: combo), .tooFewModifiers, "\(combo)")
        }
    }

    func testCommonTwoModifierShortcutsAreRefused() {
        XCTAssertEqual(ShortcutRules.problem(with: KeyCombo(keyCode: kVK_ANSI_F, command: true, control: true)), .commonInApps)
        XCTAssertEqual(ShortcutRules.problem(with: KeyCombo(keyCode: kVK_ANSI_I, command: true, option: true)), .commonInApps)
        XCTAssertEqual(ShortcutRules.problem(with: KeyCombo(keyCode: kVK_ANSI_V, command: true, option: true, shift: true)), .commonInApps)
    }

    func testUncommonCombinationsAreAllowed() {
        XCTAssertNil(ShortcutRules.problem(with: KeyCombo(keyCode: kVK_ANSI_K, option: true, control: true)))
        XCTAssertNil(ShortcutRules.problem(with: KeyCombo(keyCode: kVK_ANSI_V, command: true, option: true, control: true)))
        // ⇧ changes the combination: ⌥⌘V is common, ⌃⌥⇧K is not.
        XCTAssertNil(ShortcutRules.problem(with: KeyCombo(keyCode: kVK_ANSI_K, option: true, control: true, shift: true)))
    }
}

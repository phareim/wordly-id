import XCTest
@testable import WordlyRefs

final class SlashPaletteTests: XCTestCase {
    func test_detectsTriggerAtStartOfLine() {
        let result = SlashPalette.detectTrigger(in: "/do quer", caretIndex: 7, schemes: ["do", "write"])
        XCTAssertEqual(result?.trigger, "do")
        XCTAssertEqual(result?.query, "que")  // characters after "/do " up to caret
        XCTAssertEqual(result?.triggerStart, 0)
    }

    func test_detectsTriggerAfterWhitespace() {
        let source = "see /write proj"
        let result = SlashPalette.detectTrigger(in: source, caretIndex: source.count, schemes: ["do", "write"])
        XCTAssertEqual(result?.trigger, "write")
        XCTAssertEqual(result?.query, "proj")
        XCTAssertEqual(result?.triggerStart, 4)
    }

    func test_ignoresSlashMidWord() {
        let source = "config/do/settings"
        let result = SlashPalette.detectTrigger(in: source, caretIndex: source.count, schemes: ["do", "write"])
        XCTAssertNil(result)
    }

    func test_ignoresUnknownTriggerWord() {
        let source = "/link foo"
        let result = SlashPalette.detectTrigger(in: source, caretIndex: source.count, schemes: ["do", "write"])
        XCTAssertNil(result)
    }

    func test_requiresSpaceAfterTriggerWord() {
        let source = "/dosomething"
        let result = SlashPalette.detectTrigger(in: source, caretIndex: source.count, schemes: ["do", "write"])
        XCTAssertNil(result)
    }

    func test_buildsInsertion() {
        let insertion = SlashPalette.insertion(forSelectedID: "DO-COPPER-DRIFTING-LANTERN", scheme: "do")
        XCTAssertEqual(insertion, "<do:DO-COPPER-DRIFTING-LANTERN>")
    }
}

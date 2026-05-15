import XCTest
@testable import WordlyRefs

final class TokenizerTests: XCTestCase {
    let schemes: Set<String> = ["do", "write"]

    func test_findsSingleReference() {
        let source = "Discuss in <do:DO-RABBIT-DANCING-MAUVE>."
        let tokens = Tokenizer.findReferences(in: source, schemes: schemes)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].scheme, "do")
        XCTAssertEqual(tokens[0].wordlyID, "DO-RABBIT-DANCING-MAUVE")
        XCTAssertEqual(source[tokens[0].range], "<do:DO-RABBIT-DANCING-MAUVE>")
    }

    func test_findsAdjacentReferencesOfDifferentKinds() {
        let source = "<write:W-COPPER-DRIFTING-LANTERN><do:DO-RABBIT-DANCING-MAUVE>"
        let tokens = Tokenizer.findReferences(in: source, schemes: schemes)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].scheme, "write")
        XCTAssertEqual(tokens[1].scheme, "do")
    }

    func test_ignoresUnknownSchemes() {
        let source = "Check <link:L-FOO-BAR-BAZ> for more."
        let tokens = Tokenizer.findReferences(in: source, schemes: schemes)
        XCTAssertTrue(tokens.isEmpty)
    }

    func test_ignoresLowercaseWordlyID() {
        let source = "<do:do-rabbit-dancing-mauve>"
        let tokens = Tokenizer.findReferences(in: source, schemes: schemes)
        XCTAssertTrue(tokens.isEmpty)
    }

    func test_ignoresMissingAngleBrackets() {
        let source = "do:DO-RABBIT-DANCING-MAUVE"
        let tokens = Tokenizer.findReferences(in: source, schemes: schemes)
        XCTAssertTrue(tokens.isEmpty)
    }

    func test_acceptsSuffixedID() {
        let source = "<do:DO-RABBIT-DANCING-MAUVE-2>"
        let tokens = Tokenizer.findReferences(in: source, schemes: schemes)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].wordlyID, "DO-RABBIT-DANCING-MAUVE-2")
    }
}

import XCTest
@testable import WordlyID

final class ParseValidateTests: XCTestCase {
    func test_parse_extractsPrefixAndWords() {
        let parsed = WordlyID.parse("W-COPPER-DRIFTING-LANTERN")
        XCTAssertEqual(parsed?.prefix, "W")
        XCTAssertEqual(parsed?.words, ["COPPER", "DRIFTING", "LANTERN"])
    }

    func test_parse_acceptsSuffixAsExtraSegment() {
        let parsed = WordlyID.parse("W-COPPER-DRIFTING-LANTERN-2")
        XCTAssertEqual(parsed?.prefix, "W")
        XCTAssertEqual(parsed?.words, ["COPPER", "DRIFTING", "LANTERN", "2"])
    }

    func test_parse_rejectsTooFewSegments() {
        XCTAssertNil(WordlyID.parse("W-COPPER-DRIFTING"))
        XCTAssertNil(WordlyID.parse("W-COPPER"))
        XCTAssertNil(WordlyID.parse("W"))
        XCTAssertNil(WordlyID.parse(""))
    }

    func test_parse_rejectsLowercase() {
        XCTAssertNil(WordlyID.parse("w-copper-drifting-lantern"))
    }

    func test_parse_rejectsEmptySegments() {
        XCTAssertNil(WordlyID.parse("W--DRIFTING-LANTERN"))
        XCTAssertNil(WordlyID.parse("-COPPER-DRIFTING-LANTERN"))
    }

    func test_validate_acceptsCanonicalRoundtrip() {
        let generated = WordlyID.generate(prefix: "W")
        XCTAssertTrue(WordlyID.validate(generated))
    }

    func test_validate_rejectsObviousJunk() {
        XCTAssertFalse(WordlyID.validate("nope"))
        XCTAssertFalse(WordlyID.validate("W-copper-DRIFTING-LANTERN"))
        XCTAssertFalse(WordlyID.validate("W-COPPER-DRIFTING-LANTERN!"))
    }
}

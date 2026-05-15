import XCTest
@testable import WordlyID

final class WordlistTests: XCTestCase {
    func test_loadsThreePartitions() throws {
        let wordlist = try Wordlist.bundled()
        XCTAssertGreaterThanOrEqual(wordlist.nouns.count, 500, "expected noun bucket of at least 500")
        XCTAssertGreaterThanOrEqual(wordlist.adjectives.count, 500)
        XCTAssertGreaterThanOrEqual(wordlist.verbs.count, 500)
    }

    func test_allWordsAreLowercaseLetters() throws {
        let wordlist = try Wordlist.bundled()
        let all = wordlist.nouns + wordlist.adjectives + wordlist.verbs
        let alphabet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz")
        for word in all {
            XCTAssertFalse(word.isEmpty)
            XCTAssertTrue(
                CharacterSet(charactersIn: word).isSubset(of: alphabet),
                "word should be lowercase letters only: \(word)"
            )
        }
    }

    func test_bucketsAreDisjoint() throws {
        let wordlist = try Wordlist.bundled()
        let nouns = Set(wordlist.nouns)
        let adjectives = Set(wordlist.adjectives)
        let verbs = Set(wordlist.verbs)
        XCTAssertTrue(nouns.intersection(adjectives).isEmpty, "a word may live in only one bucket")
        XCTAssertTrue(nouns.intersection(verbs).isEmpty)
        XCTAssertTrue(adjectives.intersection(verbs).isEmpty)
    }

    func test_parse_wordsGoToCorrectBucket() throws {
        let text = "# noun\napple\n# adjective\nbig\n# verb\nrun\n"
        let wl = try Wordlist.parse(text)
        XCTAssertEqual(wl.nouns, ["apple"])
        XCTAssertEqual(wl.adjectives, ["big"])
        XCTAssertEqual(wl.verbs, ["run"])
    }

    func test_parse_throwsOnWordBeforeHeader() {
        XCTAssertThrowsError(try Wordlist.parse("orphan\n# noun\nfoo\n# adjective\nbar\n# verb\nbaz\n"))
    }

    func test_parse_throwsOnUnknownSection() {
        XCTAssertThrowsError(try Wordlist.parse("# noun\nfoo\n# adjective\nbar\n# verb_phrase\nbaz\n"))
    }

    func test_parse_throwsOnEmptySection() {
        XCTAssertThrowsError(try Wordlist.parse("# noun\n# adjective\nbig\n# verb\nrun\n")) { error in
            guard case Wordlist.LoadError.parseFailed = error else {
                XCTFail("expected parseFailed; got \(error)")
                return
            }
        }
    }
}

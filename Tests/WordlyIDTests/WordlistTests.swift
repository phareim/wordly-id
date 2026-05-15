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
}

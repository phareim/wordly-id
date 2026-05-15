import XCTest
@testable import WordlyID

final class GenerateTests: XCTestCase {
    func test_formatIsPrefixDashThreeUppercaseWords() {
        let id = WordlyID.generate(prefix: "W")
        let parts = id.split(separator: "-").map(String.init)
        XCTAssertEqual(parts.count, 4, "\(id) should split into 4 dash-segments")
        XCTAssertEqual(parts[0], "W")
        for part in parts.dropFirst() {
            XCTAssertFalse(part.isEmpty)
            XCTAssertEqual(part, part.uppercased())
            XCTAssertTrue(part.allSatisfy { $0.isLetter && $0.isASCII })
        }
    }

    func test_acceptsTwoLetterPrefix() {
        let id = WordlyID.generate(prefix: "DO")
        XCTAssertTrue(id.hasPrefix("DO-"))
    }

    func test_acceptsFourLetterPrefix() {
        let id = WordlyID.generate(prefix: "DEMO")
        XCTAssertTrue(id.hasPrefix("DEMO-"))
    }

    func test_consecutiveCallsProduceDistinctIDsWithHighProbability() {
        var seen: Set<String> = []
        for _ in 0..<200 {
            seen.insert(WordlyID.generate(prefix: "T"))
        }
        XCTAssertEqual(seen.count, 200, "200 consecutive draws should be distinct")
    }

    func test_drawsOneFromEachPartition() {
        let wordlist = try! Wordlist.bundled()
        let nouns = Set(wordlist.nouns.map { $0.uppercased() })
        let adjectives = Set(wordlist.adjectives.map { $0.uppercased() })
        let verbs = Set(wordlist.verbs.map { $0.uppercased() })
        var nounHits = 0
        var adjectiveHits = 0
        var verbHits = 0
        for _ in 0..<50 {
            let parts = WordlyID.generate(prefix: "T").split(separator: "-").map(String.init)
            if nouns.contains(parts[1]) { nounHits += 1 }
            if adjectives.contains(parts[2]) { adjectiveHits += 1 }
            if verbs.contains(parts[3]) { verbHits += 1 }
        }
        XCTAssertEqual(nounHits, 50, "every word-1 should be a noun")
        XCTAssertEqual(adjectiveHits, 50, "every word-2 should be an adjective")
        XCTAssertEqual(verbHits, 50, "every word-3 should be a verb")
    }
}

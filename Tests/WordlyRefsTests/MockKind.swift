import Foundation
@testable import WordlyRefs

struct MockItem: ReferenceItem {
    let wordlyID: String
    let title: String
    let mtime: Int64
    let deleted: Bool
    let statusGlyph: String?
}

enum WriteMockKind: ReferenceKind {
    static let prefix = "W"
    static let slashTrigger = "write"
    static let urlScheme = "write"
    static let titlesEndpoint = URL(string: "https://example.test/write/sync/titles")!
    typealias Item = MockItem
}

enum DoMockKind: ReferenceKind {
    static let prefix = "DO"
    static let slashTrigger = "do"
    static let urlScheme = "do"
    static let titlesEndpoint = URL(string: "https://example.test/tasks/titles")!
    typealias Item = MockItem
}

import XCTest

final class ReferenceKindSmokeTests: XCTestCase {
    func test_anyReferenceKindCopiesStaticFields() {
        let any = AnyReferenceKind(WriteMockKind.self)
        XCTAssertEqual(any.prefix, "W")
        XCTAssertEqual(any.slashTrigger, "write")
        XCTAssertEqual(any.urlScheme, "write")
        XCTAssertEqual(any.titlesEndpoint.absoluteString, "https://example.test/write/sync/titles")
    }

    func test_anyReferenceKindIsHashable() {
        let a = AnyReferenceKind(WriteMockKind.self)
        let b = AnyReferenceKind(WriteMockKind.self)
        XCTAssertEqual(a, b)
        XCTAssertEqual(Set([a, b]).count, 1)
    }
}

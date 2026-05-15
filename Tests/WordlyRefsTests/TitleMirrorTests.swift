import XCTest
@testable import WordlyRefs

final class TitleMirrorSchemaTests: XCTestCase {
    var tmpDir: URL!

    override func setUpWithError() throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordly-refs-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func test_openCreatesSchema() async throws {
        let mirror = try await TitleMirror(
            kinds: [AnyReferenceKind(WriteMockKind.self), AnyReferenceKind(DoMockKind.self)],
            storage: tmpDir.appendingPathComponent("titles.sqlite"),
            transport: StubTransport()
        )
        let cursor = await mirror.cursor(for: AnyReferenceKind(WriteMockKind.self))
        XCTAssertEqual(cursor, 0)
    }

    func test_refreshAdvancesCursorAndStoresRows() async throws {
        let stub = StubTransport()
        stub.responses[AnyReferenceKind(WriteMockKind.self)] = [
            TitlesPage<MockItem>(cursor: 42, items: [
                MockItem(wordlyID: "W-A-B-C", title: "First note", mtime: 100, deleted: false, statusGlyph: nil),
                MockItem(wordlyID: "W-D-E-F", title: "Second", mtime: 200, deleted: false, statusGlyph: nil),
            ])
        ]
        let mirror = try await TitleMirror(
            kinds: [AnyReferenceKind(WriteMockKind.self)],
            storage: tmpDir.appendingPathComponent("titles.sqlite"),
            transport: stub
        )
        try await mirror.refresh(kind: WriteMockKind.self)
        let cursor = await mirror.cursor(for: AnyReferenceKind(WriteMockKind.self))
        XCTAssertEqual(cursor, 42)
        let count = await mirror.count(kind: AnyReferenceKind(WriteMockKind.self))
        XCTAssertEqual(count, 2)
    }

    func test_refreshPaginatesUntilEmpty() async throws {
        let stub = StubTransport()
        stub.responses[AnyReferenceKind(WriteMockKind.self)] = [
            TitlesPage<MockItem>(cursor: 10, items: [MockItem(wordlyID: "W-A-B-C", title: "p1", mtime: 1, deleted: false, statusGlyph: nil)]),
            TitlesPage<MockItem>(cursor: 20, items: [MockItem(wordlyID: "W-D-E-F", title: "p2", mtime: 2, deleted: false, statusGlyph: nil)]),
            TitlesPage<MockItem>(cursor: 20, items: []),
        ]
        let mirror = try await TitleMirror(
            kinds: [AnyReferenceKind(WriteMockKind.self)],
            storage: tmpDir.appendingPathComponent("titles.sqlite"),
            transport: stub
        )
        try await mirror.refresh(kind: WriteMockKind.self)
        let cursor = await mirror.cursor(for: AnyReferenceKind(WriteMockKind.self))
        XCTAssertEqual(cursor, 20)
        let count = await mirror.count(kind: AnyReferenceKind(WriteMockKind.self))
        XCTAssertEqual(count, 2)
    }

    func test_refreshHandlesSoftDeletes() async throws {
        let stub = StubTransport()
        stub.responses[AnyReferenceKind(WriteMockKind.self)] = [
            TitlesPage<MockItem>(cursor: 10, items: [MockItem(wordlyID: "W-A-B-C", title: "alive", mtime: 1, deleted: false, statusGlyph: nil)]),
        ]
        let mirror = try await TitleMirror(
            kinds: [AnyReferenceKind(WriteMockKind.self)],
            storage: tmpDir.appendingPathComponent("titles.sqlite"),
            transport: stub
        )
        try await mirror.refresh(kind: WriteMockKind.self)
        let aliveCount = await mirror.count(kind: AnyReferenceKind(WriteMockKind.self))
        XCTAssertEqual(aliveCount, 1)

        stub.responses[AnyReferenceKind(WriteMockKind.self)] = [
            TitlesPage<MockItem>(cursor: 11, items: [MockItem(wordlyID: "W-A-B-C", title: "alive", mtime: 1, deleted: true, statusGlyph: nil)]),
        ]
        try await mirror.refresh(kind: WriteMockKind.self)
        let deletedCount = await mirror.count(kind: AnyReferenceKind(WriteMockKind.self))
        XCTAssertEqual(deletedCount, 0, "soft-deleted rows are pruned from the local store")
    }
}

final class TitleMirrorSearchTests: XCTestCase {
    var tmpDir: URL!
    var mirror: TitleMirror!

    override func setUp() async throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordly-refs-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let stub = StubTransport()
        stub.responses[AnyReferenceKind(WriteMockKind.self)] = [
            TitlesPage<MockItem>(cursor: 100, items: [
                MockItem(wordlyID: "W-COPPER-DRIFTING-LANTERN", title: "Project Migrate Auth", mtime: 300, deleted: false, statusGlyph: nil),
                MockItem(wordlyID: "W-AMBER-WHISPERING-WAVES",  title: "Migration plan",        mtime: 200, deleted: false, statusGlyph: nil),
                MockItem(wordlyID: "W-IRON-WANDERING-OAK",      title: "Unrelated thoughts",    mtime: 100, deleted: false, statusGlyph: nil),
            ])
        ]
        mirror = try await TitleMirror(
            kinds: [AnyReferenceKind(WriteMockKind.self)],
            storage: tmpDir.appendingPathComponent("titles.sqlite"),
            transport: stub
        )
        try await mirror.refresh(kind: WriteMockKind.self)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func test_searchByPrefix() async throws {
        let hits = await mirror.search(query: "Migr", kind: AnyReferenceKind(WriteMockKind.self), limit: 10)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].title, "Migration plan")
    }

    func test_searchBySubstringFallsBackWhenNoPrefixHit() async throws {
        let hits = await mirror.search(query: "Auth", kind: AnyReferenceKind(WriteMockKind.self), limit: 10)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].title, "Project Migrate Auth")
    }

    func test_searchIsCaseInsensitive() async throws {
        let hits = await mirror.search(query: "migr", kind: AnyReferenceKind(WriteMockKind.self), limit: 10)
        XCTAssertGreaterThanOrEqual(hits.count, 1)
    }

    func test_searchRespectsLimit() async throws {
        let hits = await mirror.search(query: "", kind: AnyReferenceKind(WriteMockKind.self), limit: 2)
        XCTAssertEqual(hits.count, 2)
    }

    func test_resolveReturnsItem() async throws {
        let item = await mirror.resolve("W-COPPER-DRIFTING-LANTERN", kind: AnyReferenceKind(WriteMockKind.self))
        XCTAssertEqual(item?.title, "Project Migrate Auth")
    }

    func test_resolveReturnsNilForUnknownID() async throws {
        let item = await mirror.resolve("W-NOPE-NOPE-NOPE", kind: AnyReferenceKind(WriteMockKind.self))
        XCTAssertNil(item)
    }
}

// MARK: - Test helpers

final class StubTransport: TitleMirrorTransport, @unchecked Sendable {
    var responses: [AnyReferenceKind: [TitlesPage<MockItem>]] = [:]

    func fetchPage<K: ReferenceKind>(kind: K.Type, since: Int64, limit: Int) async throws -> TitlesPage<K.Item> {
        let key = AnyReferenceKind(kind)
        guard var queue = responses[key], !queue.isEmpty else {
            return TitlesPage<K.Item>(cursor: since, items: [])
        }
        let next = queue.removeFirst()
        responses[key] = queue
        return next as! TitlesPage<K.Item>
    }
}

//
//  FreeformTests.swift
//  AppleFreeform
//
//  Created by David Sherlock on 2026.
//
//  Freeform's store with no Freeform: a synthetic database with the real
//  tables, and records built the way Freeform's are — `crdt`, a version, a
//  protobuf whose words sit in nested messages and whose last table holds
//  only keys. Every board name and word here is invented.
//

import Foundation
import SQLite3
import XCTest
@testable import AppleFreeform

final class FreeformTests: XCTestCase {

    /// A length-delimited protobuf field.
    static func field(_ number: UInt8, _ bytes: [UInt8]) -> [UInt8] { [number << 3 | 2, UInt8(bytes.count)] + bytes }

    /// A record holding `words` in nested messages, a font name beside them,
    /// and the trailing key table Freeform ends with.
    static func record(_ words: [String], font: Bool = true) -> Data {
        var body: [UInt8] = [0x08, 0x01]                           // a varint, as real records start
        for word in words {
            var inner = field(1, Array(word.utf8))
            if font { inner += field(4, Array("com.apple.Freeform.system.font.regular".utf8)) }
            inner += field(5, Array("baseWritingDirection".utf8))
            body += field(2, field(3, inner))
        }
        body += field(2, Array("a".utf8)) + field(2, Array("b".utf8))
        return Data(Array("crdt".utf8) + [6, 0, 0, 0] + body)
    }

    // MARK: - Pure

    func testWordsComeOutOfNestedMessagesAndPlumbingStaysOut() {
        XCTAssertEqual(RecordStrings.words(Self.record(["Shopping list", "Paint the fence"])), ["Shopping list", "Paint the fence"])
        XCTAssertEqual(RecordStrings.words(Self.record([])), [], "keys and font names are not words")
        XCTAssertEqual(RecordStrings.words(Data("not a record".utf8)), [])
        XCTAssertEqual(RecordStrings.words(nil), [])
        XCTAssertEqual(RecordStrings.words(Self.record(["Cell 7"])), ["Cell 7"], "digits count as words")
    }

    func testKindsIdsAndAssetNames() {
        XCTAssertEqual(ItemKinds.kind(type: 2, subtype: 1), .table)
        XCTAssertEqual(ItemKinds.kind(type: 2, subtype: 0), .shape)
        XCTAssertEqual(ItemKinds.kind(type: 12, subtype: nil), .sticky)
        XCTAssertEqual(ItemKinds.kind(type: 99, subtype: nil), .other)
        XCTAssertTrue(ItemKinds.isAssetName("9A8B7C6D-5E4F-4321-8765-0FEDCBA98765-small.jpeg"))
        XCTAssertFalse(ItemKinds.isAssetName("holiday.jpg"))
        XCTAssertEqual(ItemKinds.url(in: ["Recipe", "https://example.com/r"]), "https://example.com/r")
        XCTAssertEqual(FreeformIDs.uuid("1f2e3d4c5b6a47988877665544332211"), "1F2E3D4C-5B6A-4798-8877-665544332211")
        XCTAssertEqual(FreeformIDs.hex("1F2E3D4C-5B6A-4798-8877-665544332211"), "1F2E3D4C5B6A47988877665544332211")
        XCTAssertNil(FreeformIDs.uuid("short"))
    }

    // MARK: - A synthetic store

    var folder: URL!

    override func setUpWithError() throws {
        folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("freeform-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Assets"), withIntermediateDirectories: true)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: folder) }

    static func id(_ byte: UInt8) -> Data { Data(repeating: byte, count: 16) }

    func makeStore() throws -> URL {
        let url = folder.appendingPathComponent("boards.db")
        var db: OpaquePointer?
        sqlite3_open(url.path, &db)
        defer { sqlite3_close(db) }
        func run(_ sql: String, _ blobs: [Data?] = []) {
            var statement: OpaquePointer?
            XCTAssertEqual(sqlite3_prepare_v2(db, sql, -1, &statement, nil), SQLITE_OK, sql)
            for (index, blob) in blobs.enumerated() {
                if let blob {
                    _ = blob.withUnsafeBytes { sqlite3_bind_blob(statement, Int32(index + 1), $0.baseAddress, Int32(blob.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
                } else { sqlite3_bind_null(statement, Int32(index + 1)) }
            }
            XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE, sql)
            sqlite3_finalize(statement)
        }
        run("CREATE TABLE boards (board_identifier BLOB, data BLOB, last_activity_time REAL, tombstoned INTEGER)")
        run("CREATE TABLE board_items (item_uuid BLOB, board_identifier BLOB, item_type INTEGER, sub_item_type INTEGER, specific_data BLOB, capsule_data BLOB, tombstoned INTEGER)")
        run("CREATE TABLE assets (asset_uuid BLOB, extension TEXT, tombstone_date REAL)")
        run("CREATE TABLE asset_references (referrer_identifier BLOB, board_identifier BLOB, referrer_asset_name TEXT, asset_uuid BLOB)")
        run("INSERT INTO boards VALUES (?, ?, 800000000, 0)", [Self.id(1), Self.record(["Kitchen plan"], font: false)])
        run("INSERT INTO boards VALUES (?, ?, 800100000, 0)", [Self.id(2), Self.record([], font: false)])
        run("INSERT INTO boards VALUES (?, ?, 800200000, 1)", [Self.id(3), Self.record(["Old ideas"], font: false)])
        run("INSERT INTO board_items VALUES (?, ?, 3, NULL, ?, NULL, 0)", [Self.id(10), Self.id(1), Self.record(["Measure the wall"])])
        run("INSERT INTO board_items VALUES (?, ?, 12, NULL, ?, NULL, 0)", [Self.id(11), Self.id(1), Self.record(["Order tiles"])])
        run("INSERT INTO board_items VALUES (?, ?, 2, 1, ?, ?, 0)", [Self.id(12), Self.id(1), Self.record([]), Self.record(["Oak", "Walnut"])])
        run("INSERT INTO board_items VALUES (?, ?, 8, NULL, ?, NULL, 0)", [Self.id(13), Self.id(1), Self.record(["https://example.com/tiles"])])
        run("INSERT INTO board_items VALUES (?, ?, 5, NULL, ?, NULL, 0)", [Self.id(14), Self.id(1), Self.record(["0E0E0E0E-0E0E-0E0E-0E0E-0E0E0E0E0E0E.jpg"])])
        run("INSERT INTO board_items VALUES (?, ?, 2, 0, ?, NULL, 0)", [Self.id(15), Self.id(1), Self.record([])])
        run("INSERT INTO board_items VALUES (?, ?, 12, NULL, ?, NULL, 1)", [Self.id(16), Self.id(1), Self.record(["Removed note"])])
        run("INSERT INTO board_items VALUES (?, ?, 12, NULL, ?, NULL, 0)", [Self.id(17), Self.id(3), Self.record(["Tiles idea"])])
        run("INSERT INTO assets VALUES (?, 'jpg', 0.0)", [Self.id(14 + 100)])
        run("INSERT INTO assets VALUES (?, 'jpeg', 0.0)", [Self.id(15 + 100)])
        run("INSERT INTO asset_references VALUES (?, ?, 'thumbnail', ?)", [Self.id(14), Self.id(1), Self.id(15 + 100)])
        run("INSERT INTO asset_references VALUES (?, ?, 'preview', ?)", [Self.id(14), Self.id(1), Self.id(15 + 100)])
        run("INSERT INTO asset_references VALUES (?, ?, 'image', ?)", [Self.id(14), Self.id(1), Self.id(14 + 100)])
        for (byte, ext) in [(UInt8(114), "jpg"), (UInt8(115), "jpeg")] {
            let name = FreeformIDs.uuid(Self.id(byte).map { String(format: "%02X", $0) }.joined())!
            try Data([1]).write(to: folder.appendingPathComponent("Assets/\(name).\(ext)"))
        }
        return url
    }

    func testBoardsAreNamedCountedAndRecentFirst() throws {
        let store = try FreeformStore(url: try makeStore())
        let boards = store.boards()
        XCTAssertEqual(boards.map(\.name), ["Untitled", "Kitchen plan"], "recent first; a board with no name is Untitled; deleted left out")
        XCTAssertEqual(boards.last?.itemCount, 6, "a removed item is not counted")
        XCTAssertEqual(store.boards(includeDeleted: true).count, 3)
        XCTAssertEqual(try store.board("kitchen PLAN").id, boards.last?.id)
        XCTAssertThrowsError(try store.board("Garage"))
    }

    func testItemsCarryTheirWordsLinksAndFiles() throws {
        let store = try FreeformStore(url: try makeStore())
        let kitchen = try store.board("Kitchen plan")
        let items = store.items(board: kitchen.id)
        XCTAssertEqual(items.map(\.kind), [.text, .sticky, .table, .link, .file, .shape])
        XCTAssertEqual(items[0].text, ["Measure the wall"])
        XCTAssertEqual(items[2].text, ["Oak", "Walnut"], "a table's cells, from its capsule")
        XCTAssertEqual(items[3].url, "https://example.com/tiles")
        XCTAssertEqual(items[3].text, [], "the address is the link, not its words")
        XCTAssertEqual(items[4].text, [], "an asset's own file name is not a word")
        XCTAssertEqual(items[4].file?.pathExtension, "jpg", "the picture itself, not its thumbnail or another rendition")
        XCTAssertNil(items[5].file)
    }

    func testSearchFindsWordsAndLinksOnLiveBoards() throws {
        let store = try FreeformStore(url: try makeStore())
        XCTAssertEqual(store.search("TILES").map(\.kind), [.sticky, .link], "case ignored, links searched, a deleted board's items not")
        XCTAssertEqual(store.search("walnut").map(\.kind), [.table])
        XCTAssertEqual(store.search("removed").count, 0)
        XCTAssertEqual(store.search(" ").count, 0)
    }

    func testAMissingStoreSaysSo() {
        let missing = folder.appendingPathComponent("none.db")
        XCTAssertThrowsError(try FreeformStore(url: missing)) { XCTAssertEqual($0 as? AppleFreeformError, .storeNotFound(missing)) }
    }
}

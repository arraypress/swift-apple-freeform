//
//  FreeformStore.swift
//  AppleFreeform
//
//  Created by David Sherlock on 2026.
//
//  Freeform's boards and what is written on them, read from its store — not
//  by driving the app. The store is a SQLite file in the
//  `group.com.apple.freeform` container, opened read-only; it is not
//  encrypted on the Mac, but the container is protected: the app running
//  this needs Full Disk Access. Each item is a sync record (RecordStrings);
//  pictures and files sit under `Assets/`, found through `asset_references`.
//  Where an item sits on the board is not read.
//

import Foundation
import SQLite3

/// Freeform's boards and items, read-only.
///
/// ```swift
/// let store = try FreeformStore()
/// for board in store.boards() { print(board.name, board.itemCount) }
/// for item in store.items(board: board.id) { print(item.kind, item.text) }
/// ```
public final class FreeformStore {

    /// Where Freeform keeps its store.
    public static var defaultLocation: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.com.apple.freeform/Boards/boards.db")
    }

    private let handle: OpaquePointer
    private let assets: URL

    /// Opens the store, read-only.
    ///
    /// - Parameter url: The store; the live one by default.
    /// - Throws: ``AppleFreeformError/storeNotFound(_:)``, ``AppleFreeformError/permissionDenied(_:)``
    ///   or ``AppleFreeformError/databaseError(_:)``.
    public init(url: URL = FreeformStore.defaultLocation) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw AppleFreeformError.storeNotFound(url) }
        guard FileManager.default.isReadableFile(atPath: url.path) else { throw AppleFreeformError.permissionDenied(url) }
        var opened: OpaquePointer?
        guard sqlite3_open_v2("file:\(url.path)?mode=ro", &opened, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK,
              let opened else {
            let message = opened.map { String(cString: sqlite3_errmsg($0)) } ?? "could not open"
            sqlite3_close(opened)
            throw message.lowercased().contains("authoriz") || message.lowercased().contains("permission")
                ? AppleFreeformError.permissionDenied(url) : AppleFreeformError.databaseError(message)
        }
        handle = opened
        assets = url.deletingLastPathComponent().appendingPathComponent("Assets")
        guard !SQLiteRows.rows(handle, "SELECT count(*) FROM boards;").isEmpty else {
            sqlite3_close(handle)
            throw AppleFreeformError.permissionDenied(url)
        }
    }

    deinit { sqlite3_close(handle) }

    /// Every board, most recently worked on first.
    ///
    /// - Parameter includeDeleted: Include Recently Deleted.
    public func boards(includeDeleted: Bool = false) -> [Board] {
        let counts = Dictionary(SQLiteRows.rows(handle, "SELECT hex(board_identifier), count(*) FROM board_items WHERE COALESCE(tombstoned, 0) = 0 GROUP BY board_identifier;")
            .compactMap { row -> (String, Int)? in (row[0] as? String).map { ($0, Int(row[1] as? Int64 ?? 0)) } }, uniquingKeysWith: +)
        return SQLiteRows.rows(handle, "SELECT hex(board_identifier), data, last_activity_time, tombstoned FROM boards ORDER BY last_activity_time DESC;")
            .compactMap { row -> Board? in
                guard let hex = row[0] as? String else { return nil }
                let deleted = (row[3] as? Int64 ?? 0) != 0
                guard includeDeleted || !deleted else { return nil }
                return Board(id: FreeformIDs.uuid(hex) ?? hex, name: RecordStrings.words(row[1] as? Data).first ?? "Untitled",
                             lastActivity: SQLiteRows.date(row[2]), itemCount: counts[hex] ?? 0, isDeleted: deleted)
            }
    }

    /// A board by its id or its name (exactly, ignoring case).
    public func board(_ idOrName: String) throws -> Board {
        let all = boards(includeDeleted: true)
        if let found = all.first(where: { $0.id.caseInsensitiveCompare(idOrName) == .orderedSame })
            ?? all.first(where: { $0.name.caseInsensitiveCompare(idOrName) == .orderedSame }) {
            return found
        }
        throw AppleFreeformError.boardNotFound(idOrName)
    }

    /// The items on a board — or on every board — with their words.
    public func items(board: String? = nil) -> [BoardItem] {
        let files = assetFiles()
        let clause = board.flatMap(FreeformIDs.hex).map { "AND hex(board_identifier) = '\($0)'" } ?? ""
        return SQLiteRows.rows(handle, """
            SELECT hex(item_uuid), hex(board_identifier), item_type, sub_item_type, specific_data, capsule_data FROM board_items
            WHERE COALESCE(tombstoned, 0) = 0 \(clause) ORDER BY rowid;
            """).compactMap { row -> BoardItem? in
            guard let item = row[0] as? String, let boardHex = row[1] as? String else { return nil }
            let type = Int(row[2] as? Int64 ?? -1)
            let kind = ItemKinds.kind(type: type, subtype: (row[3] as? Int64).map(Int.init))
            let words = (RecordStrings.words(row[4] as? Data) + RecordStrings.words(row[5] as? Data)).filter { !ItemKinds.isAssetName($0) }
            let url = kind == .link ? ItemKinds.url(in: words) : nil
            return BoardItem(id: FreeformIDs.uuid(item) ?? item, board: FreeformIDs.uuid(boardHex) ?? boardHex, kind: kind, type: type,
                             text: words.filter { $0 != url }, url: url, file: files[item])
        }
    }

    /// Items whose words or link hold `text`, ignoring case and accents.
    public func search(_ text: String) -> [BoardItem] {
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        let live = Set(boards().map(\.id))
        return items().filter { item in
            live.contains(item.board) && (item.text + [item.url].compactMap { $0 }).contains {
                $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }

    /// Each item's picture or file on disk, by item (hex): its `image` asset,
    /// else any asset that is not a thumbnail or link preview.
    private func assetFiles() -> [String: URL] {
        var found: [String: URL] = [:]
        for row in SQLiteRows.rows(handle, """
            SELECT hex(r.referrer_identifier), r.referrer_asset_name, hex(a.asset_uuid), a.extension FROM asset_references r
            JOIN assets a ON a.asset_uuid = r.asset_uuid WHERE COALESCE(a.tombstone_date, 0) = 0 ORDER BY r.referrer_asset_name = 'image' DESC;
            """) {
            guard let item = row[0] as? String, let name = row[1] as? String, let hex = row[2] as? String,
                  name != "thumbnail", name != "linkMetadata", found[item] == nil, let uuid = FreeformIDs.uuid(hex) else { continue }
            let ext = (row[3] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let file = assets.appendingPathComponent(ext.map { "\(uuid).\($0)" } ?? uuid)
            if FileManager.default.fileExists(atPath: file.path) { found[item] = file }
        }
        return found
    }
}

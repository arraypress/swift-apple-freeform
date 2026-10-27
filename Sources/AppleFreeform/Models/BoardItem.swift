//
//  BoardItem.swift
//  AppleFreeform
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One item on a board, and what it says.
public struct BoardItem: Sendable, Codable, Equatable {
    /// Its identifier.
    public let id: String
    /// The board it is on.
    public let board: String
    /// What it is.
    public let kind: BoardItemKind
    /// Freeform's own type number, for a kind this does not know.
    public let type: Int
    /// Its words: a text box's or a sticky note's text, a table's cells —
    /// in the order Freeform stores them, which for a table is not the grid's.
    public let text: [String]
    /// A link's address.
    public let url: String?
    /// A picture's or file's file on this Mac, when it is there.
    public let file: URL?

    /// An item.
    public init(id: String, board: String, kind: BoardItemKind, type: Int, text: [String], url: String?, file: URL?) {
        self.id = id
        self.board = board
        self.kind = kind
        self.type = type
        self.text = text
        self.url = url
        self.file = file
    }
}

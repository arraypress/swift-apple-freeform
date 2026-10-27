//
//  BoardItemKind.swift
//  AppleFreeform
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What an item on a board is — Freeform's own item types, as measured on
/// boards made for the purpose.
public enum BoardItemKind: String, Sendable, Codable, CaseIterable, Hashable {
    /// A shape: a rectangle, a triangle, an arrow… (type 2).
    case shape
    /// A table (type 2, subtype 1).
    case table
    /// A text box (type 3).
    case text
    /// A line connecting two items (type 4).
    case connector
    /// A picture or a file (type 5).
    case file
    /// A web link (type 8).
    case link
    /// A sticky note (type 12).
    case sticky
    /// A kind this does not know yet: its words are still read.
    case other
}

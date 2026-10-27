//
//  Board.swift
//  AppleFreeform
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One Freeform board.
public struct Board: Sendable, Codable, Equatable {
    /// Its identifier.
    public let id: String
    /// Its name; "Untitled" until it is named.
    public let name: String
    /// When it was last worked on.
    public let lastActivity: Date?
    /// How many items are on it.
    public let itemCount: Int
    /// Whether it is in Recently Deleted.
    public let isDeleted: Bool

    /// A board.
    public init(id: String, name: String, lastActivity: Date?, itemCount: Int, isDeleted: Bool) {
        self.id = id
        self.name = name
        self.lastActivity = lastActivity
        self.itemCount = itemCount
        self.isDeleted = isDeleted
    }
}

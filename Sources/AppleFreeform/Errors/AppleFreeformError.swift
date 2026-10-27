//
//  AppleFreeformError.swift
//  AppleFreeform
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Why Freeform's store could not be read.
public enum AppleFreeformError: Error, Sendable, Equatable, LocalizedError {
    /// There is no store: Freeform has never been opened on this Mac.
    case storeNotFound(URL)
    /// macOS refused it: the app running this needs Full Disk Access.
    case permissionDenied(URL)
    /// SQLite could not read it.
    case databaseError(String)
    /// No board matches.
    case boardNotFound(String)

    /// A sentence for a person.
    public var errorDescription: String? {
        switch self {
        case .storeNotFound: return "no Freeform store on this Mac — open Freeform once"
        case .permissionDenied: return "macOS refused Freeform's store — give the app running this Full Disk Access"
        case .databaseError(let message): return "Freeform's store could not be read: \(message)"
        case .boardNotFound(let board): return "no Freeform board \(board)"
        }
    }
}

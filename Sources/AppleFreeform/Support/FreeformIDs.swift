//
//  FreeformIDs.swift
//  AppleFreeform
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Freeform's 16-byte identifiers, as SQLite's hex and as UUID strings. Pure.
enum FreeformIDs {

    /// `1F2E3D4C5B6A…` as `1F2E3D4C-5B6A-…`, or nil when it is not 32 hex digits.
    static func uuid(_ hex: String) -> String? {
        guard hex.count == 32, hex.allSatisfy(\.isHexDigit) else { return nil }
        let h = Array(hex.uppercased())
        return [h[0..<8], h[8..<12], h[12..<16], h[16..<20], h[20..<32]].map { String($0) }.joined(separator: "-")
    }

    /// A UUID string (or hex) as the hex SQLite compares, or nil.
    static func hex(_ id: String) -> String? {
        let digits = id.replacingOccurrences(of: "-", with: "").uppercased()
        return digits.count == 32 && digits.allSatisfy(\.isHexDigit) ? digits : nil
    }
}

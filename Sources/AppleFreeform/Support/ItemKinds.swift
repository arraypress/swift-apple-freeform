//
//  ItemKinds.swift
//  AppleFreeform
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Freeform's item type numbers, as measured on boards made for the purpose. Pure.
enum ItemKinds {

    /// The kind for a type and subtype.
    static func kind(type: Int, subtype: Int?) -> BoardItemKind {
        switch type {
        case 2: return subtype == 1 ? .table : .shape
        case 3: return .text
        case 4: return .connector
        case 5: return .file
        case 8: return .link
        case 12: return .sticky
        default: return .other
        }
    }

    /// Whether a word is an asset's own file name (`<UUID>.jpg`,
    /// `<UUID>-small.jpeg`) — plumbing, not something written.
    static func isAssetName(_ word: String) -> Bool {
        let stem = (word as NSString).deletingPathExtension
        let base = stem.hasSuffix("-small") ? String(stem.dropLast(6)) : stem
        return UUID(uuidString: base) != nil && !(word as NSString).pathExtension.isEmpty
    }

    /// The address among a link's words.
    static func url(in words: [String]) -> String? {
        words.first { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
    }
}

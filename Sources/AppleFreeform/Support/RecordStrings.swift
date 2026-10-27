//
//  RecordStrings.swift
//  AppleFreeform
//
//  Created by David Sherlock on 2026.
//
//  The words in a Freeform record. Each item is a sync record — `crdt`, a
//  32-bit version, then a protobuf — whose text sits as string values deep
//  in nested messages, while its last table holds only keys (`a`, `b`…).
//  So the record is walked as protobuf: a length-delimited value that is
//  printable text with letters in it is text; one that parses as a message
//  is walked into; keys, font and attribute names and single characters are
//  left out. Measured on a board made for the purpose: every text box,
//  sticky note, table cell, link and file name came out, and nothing else.
//  Pure.
//

import Foundation

enum RecordStrings {

    /// The words in a record, in the order stored.
    static func words(_ data: Data?) -> [String] {
        guard let data, data.count > 8, data.prefix(4) == Data("crdt".utf8) else { return [] }
        return walk([UInt8](data.dropFirst(8)), depth: 0).filter(isWords)
    }

    /// Whether a string is something someone wrote, not the record's plumbing.
    static func isWords(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 1 else { return false }
        if noise.contains(trimmed) || trimmed.hasPrefix("com.apple.") { return false }
        return true
    }

    /// The record's own names.
    static let noise: Set<String> = ["baseWritingDirection", "link_metadata"]

    /// Every string value in a message, nested ones included.
    static func walk(_ bytes: [UInt8], depth: Int) -> [String] {
        guard depth < 16, let parts = fields(bytes) else { return [] }
        var found: [String] = []
        for part in parts {
            let text = printable(part)
            if let text, text.contains(where: \.isLetter) || text.contains(where: \.isNumber) {
                found.append(text)
            } else if fields(part) != nil {
                found += walk(part, depth: depth + 1)
            } else if let text {
                found.append(text)
            }
        }
        return found
    }

    /// A message's length-delimited values, or nil when the bytes are not a message.
    static func fields(_ bytes: [UInt8]) -> [[UInt8]]? {
        var index = 0
        var parts: [[UInt8]] = []
        while index < bytes.count {
            guard let (key, next) = varint(bytes, at: index), key > 0 else { return nil }
            index = next
            switch key & 7 {
            case 0:
                guard let (_, after) = varint(bytes, at: index) else { return nil }
                index = after
            case 1: index += 8
            case 5: index += 4
            case 2:
                guard let (length, start) = varint(bytes, at: index), start + length <= bytes.count else { return nil }
                parts.append(Array(bytes[start..<(start + length)]))
                index = start + length
            default: return nil
            }
            guard index <= bytes.count else { return nil }
        }
        return parts
    }

    /// A protobuf varint at `index`: its value and the index after it.
    static func varint(_ bytes: [UInt8], at index: Int) -> (Int, Int)? {
        var value = 0, shift = 0, at = index
        while at < bytes.count, shift < 63 {
            let byte = bytes[at]
            value |= Int(byte & 0x7F) << shift
            at += 1
            if byte & 0x80 == 0 { return (value, at) }
            shift += 7
        }
        return nil
    }

    /// The bytes as text when they are UTF-8 with no control characters
    /// (a line break and a tab allowed).
    static func printable(_ bytes: [UInt8]) -> String? {
        guard !bytes.isEmpty, let text = String(bytes: bytes, encoding: .utf8) else { return nil }
        return text.unicodeScalars.allSatisfy({ $0 == "\n" || $0 == "\t" || !CharacterSet.controlCharacters.contains($0) }) ? text : nil
    }
}

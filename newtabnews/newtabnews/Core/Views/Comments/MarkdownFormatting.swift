//
//  MarkdownFormatting.swift
//  newtabnews
//

import Foundation

enum MarkdownFormatAction: Equatable {
    case wrap(prefix: String, suffix: String, placeholder: String)
    case linePrefix(String)
}

enum MarkdownFormatting {
    static func apply(
        action: MarkdownFormatAction,
        to text: inout String,
        selectedRange: inout NSRange
    ) {
        switch action {
        case .wrap(let prefix, let suffix, let placeholder):
            wrapSelection(in: &text, selectedRange: &selectedRange, prefix: prefix, suffix: suffix, placeholder: placeholder)
        case .linePrefix(let linePrefix):
            prefixLines(in: &text, selectedRange: &selectedRange, linePrefix: linePrefix)
        }
    }

    private static func wrapSelection(
        in text: inout String,
        selectedRange: inout NSRange,
        prefix: String,
        suffix: String,
        placeholder: String
    ) {
        let nsText = text as NSString
        let range = clampedRange(selectedRange, in: nsText)

        if range.length > 0 {
            let selected = nsText.substring(with: range)
            let replacement = prefix + selected + suffix
            text = nsText.replacingCharacters(in: range, with: replacement)
            selectedRange = NSRange(
                location: range.location + (prefix as NSString).length,
                length: (selected as NSString).length
            )
        } else {
            let replacement = prefix + placeholder + suffix
            text = nsText.replacingCharacters(in: NSRange(location: range.location, length: 0), with: replacement)
            selectedRange = NSRange(
                location: range.location + (prefix as NSString).length,
                length: (placeholder as NSString).length
            )
        }
    }

    private static func prefixLines(
        in text: inout String,
        selectedRange: inout NSRange,
        linePrefix: String
    ) {
        let nsText = text as NSString
        let range = clampedRange(selectedRange, in: nsText)
        let lineRange = nsText.lineRange(for: range)
        let block = nsText.substring(with: lineRange)
        let prefixed = block
            .components(separatedBy: "\n")
            .map { line in
                if line.hasPrefix(linePrefix) { return line }
                return line.isEmpty ? linePrefix.trimmingCharacters(in: .whitespaces) : linePrefix + line
            }
            .joined(separator: "\n")

        text = nsText.replacingCharacters(in: lineRange, with: prefixed)
        selectedRange = NSRange(location: lineRange.location, length: (prefixed as NSString).length)
    }

    private static func clampedRange(_ range: NSRange, in text: NSString) -> NSRange {
        let location = max(0, min(range.location, text.length))
        let maxLength = text.length - location
        let length = max(0, min(range.length, maxLength))
        return NSRange(location: location, length: length)
    }
}

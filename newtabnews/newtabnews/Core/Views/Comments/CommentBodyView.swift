//
//  CommentBodyView.swift
//  newtabnews
//
//  Created by Luiz Mello on 20/06/26.
//

import SwiftUI

struct CommentBodyView: View {
    let markdown: String

    var body: some View {
        Group {
            if let attributed = try? AttributedString(
                markdown: markdown,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            ) {
                Text(attributed)
            } else if let attributed = try? AttributedString(markdown: markdown) {
                Text(attributed)
            } else {
                Text(markdown)
            }
        }
        .font(.body)
        .fontWeight(.regular)
        .foregroundStyle(.primary)
        .lineSpacing(8)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
}

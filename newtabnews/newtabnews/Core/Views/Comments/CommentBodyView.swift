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
        // Mesmo renderizador dos posts: listas, código e tabelas também funcionam nos comentários
        MarkdownContentView(markdown: markdown, style: .comment)
    }
}

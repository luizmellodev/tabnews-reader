//
//  HybridMarkdownView.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/11/25.
//

import SwiftUI

/// Destaque já localizado dentro de um bloco de texto
struct ResolvedHighlight {
    let highlight: Highlight
    let range: NSRange
}

struct HybridMarkdownView: View {
    let markdown: String
    let postId: String
    let highlights: [Highlight]
    let isHighlightMode: Bool
    var style: MarkdownStyle = .post
    var allowsTextSelection = false
    let onHighlight: (String, NSRange) -> Void
    let onRemoveHighlight: (Highlight) -> Void

    var body: some View {
        let blocks = MarkdownRenderer.blocks(for: markdown, style: style)
        let layout = TextLayout(blocks: blocks)
        let resolved = layout.resolve(highlights)

        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                switch block {
                case .text(let text):
                    let offset = layout.offsets[index] ?? 0
                    HighlightableTextView(
                        attributedText: text,
                        highlights: resolved[index] ?? [],
                        isHighlightMode: isHighlightMode,
                        allowsTextSelection: allowsTextSelection,
                        onHighlight: { selected, range in
                            // Posição no texto do post inteiro, não só deste bloco
                            onHighlight(selected, NSRange(location: range.location + offset, length: range.length))
                        },
                        onRemoveHighlight: onRemoveHighlight
                    )

                case .code(let code, let language):
                    CodeBlockView(code: code, language: language)

                case .table(let table):
                    MarkdownTableView(table: table)

                case .image(let url, let alt, let link):
                    if let link {
                        Link(destination: link) {
                            ImageView(urlString: url, alt: alt)
                        }
                    } else {
                        ImageView(urlString: url, alt: alt)
                    }

                case .divider:
                    Divider()
                        .padding(.vertical, 8)
                }
            }
        }
    }
}

/// Posts sem destaque (comentários, descrições): mesmo renderizador, sem modo de destaque
struct MarkdownContentView: View {
    let markdown: String
    var style: MarkdownStyle = .comment

    var body: some View {
        HybridMarkdownView(
            markdown: markdown,
            postId: "",
            highlights: [],
            isHighlightMode: false,
            style: style,
            allowsTextSelection: true,
            onHighlight: { _, _ in },
            onRemoveHighlight: { _ in }
        )
    }
}

/// Os blocos de texto, emendados com "\n", formam o texto do post em que os destaques são salvos.
private struct TextLayout {
    /// Índice do bloco → posição do bloco no texto emendado
    var offsets: [Int: Int] = [:]
    private var ranges: [(index: Int, range: NSRange)] = []
    private var fullText = ""

    init(blocks: [MarkdownBlock]) {
        var parts: [String] = []
        var position = 0
        for (index, block) in blocks.enumerated() {
            guard case .text(let text) = block else { continue }
            if !parts.isEmpty { position += 1 }
            offsets[index] = position
            ranges.append((index, NSRange(location: position, length: text.length)))
            parts.append(text.string)
            position += text.length
        }
        fullText = parts.joined(separator: "\n")
    }

    /// Encontra cada destaque pelo texto marcado, na ocorrência mais perto da posição salva.
    /// Assim destaques antigos continuam no lugar mesmo se a renderização mudar o texto.
    func resolve(_ highlights: [Highlight]) -> [Int: [ResolvedHighlight]] {
        let text = fullText as NSString
        var result: [Int: [ResolvedHighlight]] = [:]

        for highlight in highlights {
            guard let global = locate(highlight, in: text),
                  let block = ranges.first(where: { NSLocationInRange(global.location, $0.range) && NSMaxRange(global) <= NSMaxRange($0.range) })
            else { continue }
            let local = NSRange(location: global.location - block.range.location, length: global.length)
            result[block.index, default: []].append(ResolvedHighlight(highlight: highlight, range: local))
        }
        return result
    }

    private func locate(_ highlight: Highlight, in text: NSString) -> NSRange? {
        let needle = highlight.highlightedText
        guard !needle.isEmpty else { return nil }

        var best: NSRange?
        var searchRange = NSRange(location: 0, length: text.length)
        while true {
            let found = text.range(of: needle, options: [], range: searchRange)
            guard found.location != NSNotFound else { break }
            if best == nil || abs(found.location - highlight.rangeStart) < abs(best!.location - highlight.rangeStart) {
                best = found
            }
            let next = found.location + 1
            guard next < text.length else { break }
            searchRange = NSRange(location: next, length: text.length - next)
        }
        return best
    }
}

/// Imagem do post, com carregamento, erro e legenda (alt)
struct ImageView: View {
    let urlString: String
    let alt: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let cleanedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let url = URL(string: cleanedURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Carregando...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                        
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(8)
                            
                    case .failure:
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("Erro ao carregar imagem")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(cleanedURL)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(3)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                // URL inválida
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                        Text("URL inválida")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(cleanedURL)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            if let altText = alt, !altText.isEmpty {
                Text(altText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 8)
    }
}


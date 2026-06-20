//
//  HybridMarkdownView.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/11/25.
//

import SwiftUI

struct HybridMarkdownView: View {
    let markdown: String
    let postId: String
    let highlights: [Highlight]
    let isHighlightMode: Bool
    let onHighlight: (String, NSRange) -> Void
    let onRemoveHighlight: (Highlight) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(processedContent.enumerated()), id: \.offset) { index, content in
                switch content {
                case .text(let text):
                    HighlightableTextView(
                        text: text,
                        postId: postId,
                        highlights: highlights,
                        isHighlightMode: isHighlightMode,
                        onHighlight: onHighlight,
                        onRemoveHighlight: onRemoveHighlight
                    )
                    
                case .image(let url, let alt):
                    ImageView(urlString: url, alt: alt)
                }
            }
        }
    }
    
    private var processedContent: [ContentBlock] {
        var blocks: [ContentBlock] = []
        var currentText = ""
        
        let fixedMarkdown = normalizeContent(markdown)
        
        let lines = fixedMarkdown.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("![") {
                if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(.text(currentText))
                    currentText = ""
                }
                
                // Extrair informações da imagem
                let (url, alt) = extractImageInfo(from: line)
                if !url.isEmpty {
                    blocks.append(.image(url, alt))
                    continue
                }
            }
            
            // Acumular texto normal
            if !currentText.isEmpty {
                currentText += "\n"
            }
            currentText += line
        }
        
        if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(.text(currentText))
        }
        
        return blocks
    }
    
    private func normalizeContent(_ text: String) -> String {
        let withMarkdownImages = convertHTMLImagesToMarkdown(text)
        let withoutWrappers = stripHTMLWrapperTags(withMarkdownImages)
        return fixMultilineImages(withoutWrappers)
    }
    
    private func convertHTMLImagesToMarkdown(_ text: String) -> String {
        let pattern = #"<img\b[\s\S]*?/?>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return text
        }
        
        let nsString = text as NSString
        let matches = regex.matches(
            in: text,
            range: NSRange(location: 0, length: nsString.length)
        )
        
        var result = text
        for match in matches.reversed() {
            let tag = nsString.substring(with: match.range)
            guard let src = extractHTMLAttribute("src", from: tag), !src.isEmpty else {
                continue
            }
            
            let alt = extractHTMLAttribute("alt", from: tag) ?? ""
            let markdown = "![\(alt)](\(src))"
            result = (result as NSString).replacingCharacters(in: match.range, with: markdown)
        }
        
        return result
    }
    
    private func extractHTMLAttribute(_ name: String, from tag: String) -> String? {
        let patterns = [
            "\(name)\\s*=\\s*\"([^\"]*)\"",
            "\(name)\\s*=\\s*'([^']*)'"
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }
            
            let nsString = tag as NSString
            guard let match = regex.firstMatch(
                in: tag,
                range: NSRange(location: 0, length: nsString.length)
            ), match.range(at: 1).location != NSNotFound else {
                continue
            }
            
            let value = nsString.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !value.isEmpty {
                return value
            }
        }
        
        return nil
    }
    
    private func stripHTMLWrapperTags(_ text: String) -> String {
        let patterns = [
            #"<div[^>]*>"#,
            #"</div>"#
        ]
        
        var result = text
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }
            
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        
        return result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
    }
    
    private func extractImageInfo(from line: String) -> (String, String?) {
        let pattern = #"!\[([^\]]*)\]\(([^\)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return ("", nil)
        }
        
        let nsString = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsString.length)) else {
            return ("", nil)
        }
        
        let alt = match.range(at: 1).location != NSNotFound ? nsString.substring(with: match.range(at: 1)) : nil
        var urlPart = match.range(at: 2).location != NSNotFound ? nsString.substring(with: match.range(at: 2)) : ""
        
        // Remove o título se houver (tudo depois de espaços + ")
        if let quoteIndex = urlPart.range(of: #"\s+"#, options: .regularExpression) {
            urlPart = String(urlPart[..<quoteIndex.lowerBound])
        }
        
        let url = urlPart.trimmingCharacters(in: .whitespacesAndNewlines)
        return (url, alt)
    }
    
    // Junta linhas de imagens que foram quebradas
    private func fixMultilineImages(_ text: String) -> String {
        var result = text
        
        // Pattern para detectar ![alt]( sem fechar na mesma linha
        // Captura: ![alt]( seguido de quebra de linha e depois url)
        let pattern = #"!\[([^\]]*)\]\(\s*\n\s*([^\)]+)\)"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "![$1]($2)"
            )
        }
        
        return result
    }
}

enum ContentBlock {
    case text(String)
    case image(String, String?) // URL e alt text
}

// View para renderizar imagens (igual ao MDText)
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


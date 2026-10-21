//
//  MarkdownRenderer.swift
//  newtabnews
//

import UIKit
import Markdown

/// Pedaço do post já renderizado. Texto corrido fica num `UITextView` (seleção e destaques);
/// código, tabela, imagem e divisória viram views próprias.
enum MarkdownBlock {
    case text(NSAttributedString)
    case code(String, language: String?)
    case table(MarkdownTable)
    case image(url: String, alt: String?, link: URL?)
    case divider
}

struct MarkdownTable {
    var header: [NSAttributedString]
    var rows: [[NSAttributedString]]
    var alignments: [NSTextAlignment]
}

enum MarkdownStyle: String {
    /// Corpo do post: fonte light, parágrafos justificados
    case post
    /// Comentários: fonte regular, alinhamento natural
    case comment
}

extension NSAttributedString.Key {
    /// Marca trechos de código inline, para o detector de links ignorá-los
    static let markdownCode = NSAttributedString.Key("markdownCode")
}

enum MarkdownRenderer {
    private final class Box {
        let blocks: [MarkdownBlock]
        init(_ blocks: [MarkdownBlock]) { self.blocks = blocks }
    }

    private static let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 40
        return cache
    }()

    /// Blocos do post. O resultado fica em cache (o SwiftUI recalcula o body com frequência).
    static func blocks(for markdown: String, style: MarkdownStyle = .post) -> [MarkdownBlock] {
        let sizeCategory = UIApplication.shared.preferredContentSizeCategory.rawValue
        let key = "\(style.rawValue)|\(sizeCategory)|\(markdown)" as NSString
        if let cached = cache.object(forKey: key) { return cached.blocks }

        let document = Document(parsing: preprocess(markdown), options: [.disableSmartOpts])
        var builder = BlockBuilder(style: style)
        builder.renderChildren(of: document, context: BlockContext())
        let blocks = builder.finish()
        cache.setObject(Box(blocks), forKey: key)
        return blocks
    }

    /// Texto puro para prévia do feed e leitura em voz alta: sem código, imagens nem marcação.
    /// Também em cache: os cards do feed pedem a prévia a cada redesenho.
    static func plainText(from markdown: String) -> String {
        let key = markdown as NSString
        if let cached = plainTextCache.object(forKey: key) { return cached as String }

        var collector = PlainTextCollector()
        collector.collect(Document(parsing: preprocess(markdown), options: [.disableSmartOpts]))
        let text = collector.paragraphs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        plainTextCache.setObject(text as NSString, forKey: key)
        return text
    }

    private static let plainTextCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 200
        return cache
    }()

    // MARK: - Pré-processamento de HTML

    /// O TabNews aceita HTML no meio do Markdown. O parser trata HTML em bloco como texto cru,
    /// então convertemos o que importa (imagens, details/summary) e tiramos os wrappers.
    static func preprocess(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "\r\n", with: "\n")

        // Comentários HTML
        result = result.replacingOccurrences(of: #"<!--[\s\S]*?-->"#, with: "", options: .regularExpression)

        // ![alt](
        //   url) quebrado em duas linhas
        result = result.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(\s*\n\s*([^\)]+)\)"#,
            with: "![$1]($2)",
            options: .regularExpression
        )

        result = convertHTMLImages(result)

        // <summary>Título</summary> vira um parágrafo em negrito; o conteúdo do details fica aberto
        result = result.replacingOccurrences(
            of: #"(?is)<summary[^>]*>(.*?)</summary>"#,
            with: "\n\n**$1**\n\n",
            options: .regularExpression
        )

        // Tags que só embrulham conteúdo: sem elas o Markdown de dentro é interpretado
        result = result.replacingOccurrences(
            of: #"(?i)</?(div|p|center|details|section|article|span)\b[^>]*>"#,
            with: "\n\n",
            options: .regularExpression
        )

        return result.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
    }

    private static let imageTagRegex = try! NSRegularExpression(pattern: #"<img\b[^>]*>"#, options: [.caseInsensitive])

    private static func convertHTMLImages(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n").map { line -> String in
            let ns = line as NSString
            let matches = imageTagRegex.matches(in: line, range: NSRange(location: 0, length: ns.length))
            guard !matches.isEmpty else { return line }

            // Numa linha de tabela a imagem precisa continuar inline para não quebrar a tabela
            let insideTable = line.trimmingCharacters(in: .whitespaces).hasPrefix("|")
            var result = line
            for match in matches.reversed() {
                let tag = ns.substring(with: match.range)
                guard let src = htmlAttribute("src", in: tag), !src.isEmpty else { continue }
                let alt = htmlAttribute("alt", in: tag) ?? ""
                let image = "![\(alt)](<\(src)>)"
                let replacement = insideTable ? image : "\n\n\(image)\n\n"
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            }
            return result
        }
        return lines.joined(separator: "\n")
    }

    private static func htmlAttribute(_ name: String, in tag: String) -> String? {
        let pattern = "\(name)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: (tag as NSString).length))
        else { return nil }
        for group in 1...3 where match.range(at: group).location != NSNotFound {
            return (tag as NSString).substring(with: match.range(at: group))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    /// Texto de um trecho de HTML cru: quebras viram "\n", tags somem, entidades são decodificadas.
    static func textFromHTML(_ html: String) -> String {
        var text = html.replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)</(p|div|li|h[1-6]|tr|summary)>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        return decodeEntities(text)
    }

    private static let namedEntities: [String: String] = [
        "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
        "&#39;": "'", "&apos;": "'", "&mdash;": "—", "&ndash;": "–", "&hellip;": "…",
        "&copy;": "©", "&reg;": "®", "&trade;": "™", "&rarr;": "→", "&larr;": "←"
    ]

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        for (entity, value) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        // &#123; e &#x1F600;
        let regex = try! NSRegularExpression(pattern: #"&#(x?)([0-9a-fA-F]+);"#)
        let ns = result as NSString
        for match in regex.matches(in: result, range: NSRange(location: 0, length: ns.length)).reversed() {
            let isHex = match.range(at: 1).length > 0
            let digits = ns.substring(with: match.range(at: 2))
            guard let code = UInt32(digits, radix: isHex ? 16 : 10),
                  let scalar = Unicode.Scalar(code) else { continue }
            result = (result as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
        }
        return result
    }
}

// MARK: - Estilo

private struct Typography {
    let style: MarkdownStyle

    var bodySize: CGFloat { 17 }
    var bodyWeight: UIFont.Weight { style == .post ? .light : .regular }
    var bodyAlignment: NSTextAlignment { style == .post ? .justified : .natural }
    var lineSpacing: CGFloat { style == .post ? 6 : 4 }
    var paragraphSpacing: CGFloat { style == .post ? 14 : 10 }

    func headingSize(level: Int) -> CGFloat {
        switch level {
        case 1: return 26
        case 2: return 23
        case 3: return 20
        default: return 18
        }
    }

    /// Fonte com Dynamic Type, preservando tamanho e peso de base
    func font(size: CGFloat, weight: UIFont.Weight, bold: Bool, italic: Bool, monospaced: Bool = false) -> UIFont {
        let effectiveWeight: UIFont.Weight = bold ? (weight == .light || weight == .regular ? .semibold : .bold) : weight
        var font = monospaced
            ? UIFont.monospacedSystemFont(ofSize: size * 0.9, weight: bold ? .semibold : .regular)
            : UIFont.systemFont(ofSize: size, weight: effectiveWeight)
        if italic, let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
            font = UIFont(descriptor: descriptor, size: font.pointSize)
        }
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: font)
    }
}

/// Estado herdado pelos elementos inline (negrito dentro de link dentro de título etc.)
private struct InlineAttributes {
    var size: CGFloat
    var weight: UIFont.Weight
    var color: UIColor = .label
    var bold = false
    var italic = false
    var strikethrough = false
    var link: URL?
}

private struct BlockContext {
    var listDepth = 0
    var quoteDepth = 0
    /// Marcador que vai na frente do primeiro parágrafo do item de lista ("•", "1.", "☐")
    var pendingMarker: String?
    /// Parágrafos soltos dentro de item de lista ficam colados (lista "tight")
    var tight = false
}

// MARK: - Construção dos blocos

private struct BlockBuilder {
    static let lineSeparator = "\u{2028}"

    let typography: Typography
    private var blocks: [MarkdownBlock] = []
    private var buffer = NSMutableAttributedString()

    init(style: MarkdownStyle) {
        typography = Typography(style: style)
    }

    mutating func finish() -> [MarkdownBlock] {
        flushText()
        return blocks
    }

    mutating func renderChildren(of markup: Markup, context: BlockContext) {
        for child in markup.children {
            renderBlock(child, context: context)
        }
    }

    mutating func renderBlock(_ markup: Markup, context: BlockContext) {
        switch markup {
        case let heading as Heading:
            let size = typography.headingSize(level: heading.level)
            let attributes = InlineAttributes(size: size, weight: heading.level <= 2 ? .semibold : .medium)
            let paragraph = paragraphStyle(context: context, spacingBefore: buffer.length > 0 ? 8 : 0, alignment: .natural)
            appendParagraph(inline(heading, attributes), style: paragraph, context: context)

        case let paragraph as Paragraph:
            renderParagraph(paragraph, context: context)

        case let quote as BlockQuote:
            var inner = context
            inner.quoteDepth += 1
            renderChildren(of: quote, context: inner)

        case let list as UnorderedList:
            renderList(list, ordered: false, start: 1, context: context)

        case let list as OrderedList:
            renderList(list, ordered: true, start: Int(list.startIndex), context: context)

        case let code as CodeBlock:
            flushText()
            var source = code.code
            if source.hasSuffix("\n") { source.removeLast() }
            let language = code.language?.trimmingCharacters(in: .whitespaces)
            blocks.append(.code(source, language: language?.isEmpty == false ? language : nil))

        case let table as Markdown.Table:
            flushText()
            blocks.append(.table(renderTable(table)))

        case is ThematicBreak:
            flushText()
            blocks.append(.divider)

        case let html as HTMLBlock:
            let text = MarkdownRenderer.textFromHTML(html.rawHTML)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            let attributes = bodyAttributes(context: context)
            appendParagraph(
                NSAttributedString(string: text, attributes: textAttributes(attributes)),
                style: paragraphStyle(context: context),
                context: context
            )

        default:
            // Nós que não conhecemos: renderiza o que tiver dentro
            renderChildren(of: markup, context: context)
        }
    }

    // MARK: Parágrafo e imagens

    private mutating func renderParagraph(_ paragraph: Paragraph, context: BlockContext) {
        var context = context
        let attributes = bodyAttributes(context: context)
        var current = NSMutableAttributedString()

        // Imagens soltas no parágrafo viram blocos próprios, na ordem em que aparecem
        for child in paragraph.children {
            if let image = standaloneImage(child) {
                if !current.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    appendParagraph(current, style: paragraphStyle(context: context), context: context)
                    context.pendingMarker = nil
                }
                current = NSMutableAttributedString()
                flushText()
                blocks.append(image)
            } else {
                current.append(inline(child, attributes))
            }
        }

        trimWhitespace(current)
        if current.length > 0 {
            appendParagraph(current, style: paragraphStyle(context: context), context: context)
        }
    }

    /// `![alt](url)` ou um badge `[![alt](url)](link)`
    private func standaloneImage(_ markup: Markup) -> MarkdownBlock? {
        if let image = markup as? Markdown.Image, let source = image.source, !source.isEmpty {
            return .image(url: source, alt: image.plainText.nilIfEmpty, link: nil)
        }
        if let link = markup as? Markdown.Link {
            let meaningful = link.children.filter { !(($0 as? Markdown.Text)?.string.trimmingCharacters(in: .whitespaces).isEmpty ?? false) }
            if meaningful.count == 1, let image = meaningful.first as? Markdown.Image,
               let source = image.source, !source.isEmpty {
                return .image(url: source, alt: image.plainText.nilIfEmpty, link: link.destination.flatMap(URL.init(string:)))
            }
        }
        return nil
    }

    // MARK: Listas

    private mutating func renderList(_ list: Markup, ordered: Bool, start: Int, context: BlockContext) {
        let bullets = ["•", "◦", "▪︎"]
        var number = start
        // Itens com um parágrafo só ficam colados; com vários, ganham respiro
        let tight = !list.children.contains { item in
            item.children.filter { $0 is Paragraph }.count > 1
        }

        for case let item as ListItem in list.children {
            var marker: String
            if ordered {
                marker = "\(number)."
                number += 1
            } else {
                marker = bullets[context.listDepth % bullets.count]
            }
            switch item.checkbox {
            case .checked: marker = "☑︎"
            case .unchecked: marker = "☐"
            case .none: break
            }

            var inner = context
            inner.listDepth += 1
            inner.pendingMarker = marker
            inner.tight = tight

            var renderedSomething = false
            for child in item.children {
                renderBlock(child, context: inner)
                inner.pendingMarker = nil
                renderedSomething = true
            }
            if !renderedSomething {
                appendParagraph(NSAttributedString(), style: paragraphStyle(context: inner), context: inner)
            }
        }

        // Espaço depois da lista inteira (os itens ficam colados entre si)
        if context.listDepth == 0 { addSpacingToLastParagraph(typography.paragraphSpacing) }
    }

    // MARK: Tabela

    private func renderTable(_ table: Markdown.Table) -> MarkdownTable {
        let base = InlineAttributes(size: 15, weight: typography.bodyWeight)
        var header = base
        header.bold = true

        let headerCells = Array(table.head.cells.map { cleaned(inline($0, header)) })
        let rows = Array(table.body.rows).map { row in
            Array(row.cells.map { cleaned(inline($0, base)) })
        }
        let alignments: [NSTextAlignment] = table.columnAlignments.map {
            switch $0 {
            case .center: return .center
            case .right: return .right
            default: return .natural
            }
        }
        return MarkdownTable(header: headerCells, rows: rows, alignments: alignments)
    }

    private func cleaned(_ string: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: string)
        trimWhitespace(mutable)
        MarkdownLinkDetector.addLinks(to: mutable)
        return mutable
    }

    // MARK: Inline

    private func inline(_ markup: Markup, _ attributes: InlineAttributes) -> NSAttributedString {
        switch markup {
        case let text as Markdown.Text:
            return NSAttributedString(string: text.string, attributes: textAttributes(attributes))

        case let code as InlineCode:
            var attrs = textAttributes(attributes)
            attrs[.font] = typography.font(size: attributes.size, weight: attributes.weight, bold: attributes.bold, italic: false, monospaced: true)
            attrs[.backgroundColor] = UIColor.tertiarySystemFill
            attrs[.foregroundColor] = attributes.link == nil ? UIColor.systemPink : UIColor.link
            attrs[.markdownCode] = true
            return NSAttributedString(string: code.code, attributes: attrs)

        case is SoftBreak, is LineBreak:
            // O TabNews respeita a quebra de linha simples. U+2028 quebra a linha sem abrir
            // um parágrafo novo (sem o espaçamento entre parágrafos)
            return NSAttributedString(string: Self.lineSeparator, attributes: textAttributes(attributes))

        case let html as InlineHTML:
            if html.rawHTML.range(of: #"(?i)^<br\s*/?>$"#, options: .regularExpression) != nil {
                return NSAttributedString(string: Self.lineSeparator, attributes: textAttributes(attributes))
            }
            return NSAttributedString()

        case let image as Markdown.Image:
            // Imagem no meio de link ou ênfase: mostra o texto alternativo como link
            var attrs = attributes
            attrs.link = image.source.flatMap(URL.init(string:))
            let alt = image.plainText.nilIfEmpty ?? "imagem"
            return NSAttributedString(string: "🖼 \(alt)", attributes: textAttributes(attrs))

        default:
            var attrs = attributes
            if markup is Strong { attrs.bold = true }
            if markup is Emphasis { attrs.italic = true }
            if markup is Strikethrough { attrs.strikethrough = true }
            if let link = markup as? Markdown.Link,
               let destination = link.destination?.trimmingCharacters(in: .whitespaces),
               let url = URL(string: destination) ?? URL(string: destination.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "") {
                attrs.link = url
            }
            let result = NSMutableAttributedString()
            for child in markup.children {
                result.append(inline(child, attrs))
            }
            return result
        }
    }

    private func textAttributes(_ attributes: InlineAttributes) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [
            .font: typography.font(size: attributes.size, weight: attributes.weight, bold: attributes.bold, italic: attributes.italic),
            .foregroundColor: attributes.color
        ]
        if attributes.strikethrough {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if let link = attributes.link {
            attrs[.link] = link
            attrs[.foregroundColor] = UIColor.link
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        return attrs
    }

    private func bodyAttributes(context: BlockContext) -> InlineAttributes {
        InlineAttributes(
            size: typography.bodySize,
            weight: typography.bodyWeight,
            color: context.quoteDepth > 0 ? .secondaryLabel : .label,
            italic: false
        )
    }

    // MARK: Parágrafos no buffer

    private func paragraphStyle(context: BlockContext, spacingBefore: CGFloat = 0, alignment: NSTextAlignment? = nil) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = typography.lineSpacing
        style.lineBreakMode = .byWordWrapping
        style.paragraphSpacing = context.tight ? 4 : typography.paragraphSpacing
        style.paragraphSpacingBefore = spacingBefore

        // As barras "┃ " da citação ficam no começo da primeira linha; as linhas seguintes alinham depois delas
        let quoteIndent = CGFloat(context.quoteDepth) * quoteBarWidth
        let listIndent = CGFloat(context.listDepth) * 22
        style.firstLineHeadIndent = max(0, listIndent - 22)
        style.headIndent = quoteIndent + listIndent
        if context.listDepth > 0 {
            // O marcador fica no recuo do nível; o texto alinha no tab
            style.tabStops = [NSTextTab(textAlignment: .natural, location: style.headIndent)]
            style.defaultTabInterval = 22
        }

        style.alignment = alignment ?? ((context.listDepth > 0 || context.quoteDepth > 0) ? .natural : typography.bodyAlignment)
        return style
    }

    private var quoteBarWidth: CGFloat {
        let font = typography.font(size: typography.bodySize, weight: .regular, bold: false, italic: false)
        return ceil(("┃ " as NSString).size(withAttributes: [.font: font]).width)
    }

    private mutating func appendParagraph(_ content: NSAttributedString, style: NSParagraphStyle, context: BlockContext) {
        let content = NSMutableAttributedString(attributedString: content)
        // "linha<br> próxima": o espaço depois da quebra ficaria no começo da linha
        var range = (content.string as NSString).range(of: Self.lineSeparator + " ")
        while range.location != NSNotFound {
            content.deleteCharacters(in: NSRange(location: range.location + 1, length: 1))
            range = (content.string as NSString).range(of: Self.lineSeparator + " ")
        }

        let paragraph = NSMutableAttributedString()

        if context.quoteDepth > 0 {
            let bar = String(repeating: "┃ ", count: context.quoteDepth)
            paragraph.append(NSAttributedString(string: bar, attributes: [
                .font: typography.font(size: typography.bodySize, weight: .regular, bold: false, italic: false),
                .foregroundColor: UIColor.tertiaryLabel
            ]))
        }

        if let marker = context.pendingMarker {
            paragraph.append(NSAttributedString(string: "\(marker)\t", attributes: [
                .font: typography.font(size: typography.bodySize, weight: typography.bodyWeight, bold: false, italic: false),
                .foregroundColor: UIColor.secondaryLabel
            ]))
        } else if context.listDepth > 0 {
            // Parágrafo seguinte do mesmo item: alinha com o texto do item
            paragraph.append(NSAttributedString(string: "\t"))
        }

        paragraph.append(content)
        if buffer.length > 0 {
            buffer.append(NSAttributedString(string: "\n"))
        }
        let start = buffer.length
        buffer.append(paragraph)
        buffer.addAttribute(.paragraphStyle, value: style, range: NSRange(location: start, length: buffer.length - start))
        if start > 0 {
            // O "\n" separador pertence ao parágrafo anterior; mantém o estilo dele
            buffer.addAttribute(.paragraphStyle, value: lastParagraphStyle(before: start - 1), range: NSRange(location: start - 1, length: 1))
        }
    }

    private func lastParagraphStyle(before index: Int) -> NSParagraphStyle {
        guard index > 0 else { return NSParagraphStyle.default }
        return buffer.attribute(.paragraphStyle, at: index - 1, effectiveRange: nil) as? NSParagraphStyle ?? .default
    }

    private mutating func addSpacingToLastParagraph(_ spacing: CGFloat) {
        guard buffer.length > 0 else { return }
        var range = NSRange()
        guard let style = buffer.attribute(.paragraphStyle, at: buffer.length - 1, effectiveRange: &range) as? NSParagraphStyle,
              let mutable = style.mutableCopy() as? NSMutableParagraphStyle else { return }
        mutable.paragraphSpacing = spacing
        buffer.addAttribute(.paragraphStyle, value: mutable, range: range)
    }

    private mutating func flushText() {
        trimWhitespace(buffer)
        guard buffer.length > 0 else { return }
        MarkdownLinkDetector.addLinks(to: buffer)
        blocks.append(.text(buffer))
        buffer = NSMutableAttributedString()
    }

    private func trimWhitespace(_ string: NSMutableAttributedString) {
        while let last = string.string.last, last.isWhitespace || last.isNewline {
            string.deleteCharacters(in: NSRange(location: string.length - 1, length: 1))
        }
        while let first = string.string.first, first == "\n" || first == " " {
            string.deleteCharacters(in: NSRange(location: 0, length: 1))
        }
    }
}

// MARK: - Links soltos

enum MarkdownLinkDetector {
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    /// URLs soltas no texto viram link (o detector já ignora pontuação no fim, como ")" ou ".")
    static func addLinks(to string: NSMutableAttributedString) {
        guard let detector else { return }
        let text = string.string
        let matches = detector.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
        for match in matches {
            guard let url = match.url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { continue }
            var alreadyLinked = false
            string.enumerateAttributes(in: match.range) { attrs, _, stop in
                if attrs[.link] != nil || attrs[.markdownCode] != nil {
                    alreadyLinked = true
                    stop.pointee = true
                }
            }
            guard !alreadyLinked else { continue }
            string.addAttributes([
                .link: url,
                .foregroundColor: UIColor.link,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: match.range)
        }
    }
}

// MARK: - Texto puro

private struct PlainTextCollector {
    var paragraphs: [String] = []

    mutating func collect(_ markup: Markup) {
        switch markup {
        case is CodeBlock, is ThematicBreak:
            return
        case let html as HTMLBlock:
            paragraphs.append(MarkdownRenderer.textFromHTML(html.rawHTML))
        case let table as Markdown.Table:
            let rows = [Array(table.head.cells)] + table.body.rows.map { Array($0.cells) }
            for row in rows {
                paragraphs.append(row.map { inlineText($0) }.joined(separator: " · "))
            }
        case is Paragraph, is Heading:
            paragraphs.append(inlineText(markup))
        default:
            for child in markup.children { collect(child) }
        }
    }

    private func inlineText(_ markup: Markup) -> String {
        switch markup {
        case let text as Markdown.Text: return text.string
        case let code as InlineCode: return code.code
        case is SoftBreak, is LineBreak: return " "
        case is Markdown.Image, is InlineHTML: return ""
        default: return markup.children.map { inlineText($0) }.joined()
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

//
//  MarkdownBlockViews.swift
//  newtabnews
//

import SwiftUI
import UIKit

/// Bloco de código com rolagem horizontal (linhas longas não quebram a indentação) e botão de copiar.
struct CodeBlockView: View {
    let code: String
    let language: String?

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language ?? "código")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    UIPasteboard.general.string = code
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copiado" : "Copiar", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(copied ? "Código copiado" : "Copiar código")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(12)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.vertical, 4)
    }
}

/// Tabela GFM. Colunas com largura limitada; tabelas largas rolam na horizontal.
struct MarkdownTableView: View {
    let table: MarkdownTable

    private var columnCount: Int {
        max(table.header.count, table.rows.map(\.count).max() ?? 0)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(0..<columnCount, id: \.self) { column in
                        cell(table.header[safe: column], column: column)
                            .background(Color(.tertiarySystemFill))
                    }
                }

                ForEach(Array(table.rows.enumerated()), id: \.offset) { index, row in
                    Divider()
                        .gridCellUnsizedAxes(.horizontal)
                    GridRow {
                        ForEach(0..<columnCount, id: \.self) { column in
                            cell(row[safe: column], column: column)
                                .background(index.isMultiple(of: 2) ? Color.clear : Color(.quaternarySystemFill))
                        }
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(.separator), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.vertical, 4)
    }

    private func cell(_ content: NSAttributedString?, column: Int) -> some View {
        let alignment = table.alignments[safe: column] ?? .natural
        return Text(swiftUIString(content ?? NSAttributedString()))
            .multilineTextAlignment(alignment == .center ? .center : alignment == .right ? .trailing : .leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minWidth: 60, maxWidth: 240, maxHeight: .infinity,
                   alignment: alignment == .center ? .top : alignment == .right ? .topTrailing : .topLeading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }
}

/// Converte os atributos UIKit do renderer para os equivalentes do SwiftUI `Text`
func swiftUIString(_ string: NSAttributedString) -> AttributedString {
    var result = AttributedString()
    string.enumerateAttributes(in: NSRange(location: 0, length: string.length)) { attrs, range, _ in
        var run = AttributedString(string.attributedSubstring(from: range).string)
        if let font = attrs[.font] as? UIFont { run.font = Font(font) }
        if let color = attrs[.foregroundColor] as? UIColor { run.foregroundColor = Color(color) }
        if let background = attrs[.backgroundColor] as? UIColor { run.backgroundColor = Color(background) }
        if let link = attrs[.link] as? URL { run.link = link }
        if attrs[.strikethroughStyle] != nil { run.strikethroughStyle = .single }
        if attrs[.underlineStyle] != nil { run.underlineStyle = .single }
        result.append(run)
    }
    return result
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

//
//  HighlightableTextView.swift
//  newtabnews
//
//  Created by Luiz Mello on 19/11/25.
//

import SwiftUI
import SwiftData
import UIKit

struct HighlightableTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    let highlights: [ResolvedHighlight]
    let isHighlightMode: Bool
    var allowsTextSelection = false
    let onHighlight: (String, NSRange) -> Void
    let onRemoveHighlight: (Highlight) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.delegate = context.coordinator
        textView.adjustsFontForContentSizeCategory = true
        
        // Permitir seleção de texto
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
        
        // Configurar para ajustar ao conteúdo
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        
        // Prevenir scroll horizontal
        textView.textContainer.widthTracksTextView = true
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        
        // Sempre permitir seleção para que links funcionem
        textView.isSelectable = true
        
        // No modo normal, os links funcionam mas o usuário não pode selecionar texto
        if !isHighlightMode && !allowsTextSelection {
            textView.selectedTextRange = nil
        }
        
        let rendered = NSMutableAttributedString(attributedString: attributedText)
        for resolved in highlights where NSMaxRange(resolved.range) <= rendered.length {
            rendered.addAttribute(
                .backgroundColor,
                value: UIColor(Color(hex: resolved.highlight.colorHex)).withAlphaComponent(0.4),
                range: resolved.range
            )
        }
        
        // Só troca o texto quando mudou: reatribuir reseta a seleção e o layout
        if !textView.attributedText.isEqual(to: rendered) {
            textView.attributedText = rendered
            textView.invalidateIntrinsicContentSize()
        }
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width - 60 // Padding horizontal
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: HighlightableTextView
        
        init(_ parent: HighlightableTextView) {
            self.parent = parent
        }
        
        // Permitir interação com links
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            // Sempre permitir abrir links
            return true
        }
        
        // Controlar seleção de texto
        func textViewDidChangeSelection(_ textView: UITextView) {
            // Se não estiver no modo destaque, limpar seleção
            // (mas ainda permite cliques em links)
            if !parent.isHighlightMode, !parent.allowsTextSelection, let selectedRange = textView.selectedTextRange {
                // Verificar se há texto selecionado (não é apenas o cursor)
                if !selectedRange.isEmpty {
                    textView.selectedTextRange = nil
                }
            }
        }
        
        // Customizar o menu de contexto
        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            let selectedText = (textView.text as NSString).substring(with: range)
            
            // Verificar se o texto selecionado está em um highlight existente
            let existingHighlight = parent.highlights.first { resolved in
                NSIntersectionRange(range, resolved.range).length > 0
            }?.highlight
            
            var actions: [UIMenuElement] = []
            
            // Se está no modo highlight, mostrar opção de destacar
            if parent.isHighlightMode {
                let highlightAction = UIAction(
                    title: "✨ Destacar",
                    image: UIImage(systemName: "highlighter")
                ) { [weak self] _ in
                    self?.parent.onHighlight(selectedText, range)
                    textView.selectedTextRange = nil
                }
                actions.append(highlightAction)
            }
            
            // Se há um highlight existente, mostrar opção de remover
            if let highlight = existingHighlight {
                let removeAction = UIAction(
                    title: "🗑️ Remover Destaque",
                    image: UIImage(systemName: "trash"),
                    attributes: .destructive
                ) { [weak self] _ in
                    self?.parent.onRemoveHighlight(highlight)
                    textView.selectedTextRange = nil
                }
                actions.append(removeAction)
            }
            
            // Seleção livre (comentários): mantém o menu padrão com Copiar
            guard !actions.isEmpty else {
                return parent.allowsTextSelection ? UIMenu(children: suggestedActions) : nil
            }
            
            return UIMenu(title: "", children: actions)
        }
    }
}

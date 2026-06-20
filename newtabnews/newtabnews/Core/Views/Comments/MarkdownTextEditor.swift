//
//  MarkdownTextEditor.swift
//  newtabnews
//

import SwiftUI
import UIKit

struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var contentHeight: CGFloat
    @Binding var pendingFormat: MarkdownFormatAction?

    var minHeight: CGFloat = 38
    var maxHeight: CGFloat = 140
    var showsFormattingAccessory: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        if showsFormattingAccessory {
            textView.inputAccessoryView = context.coordinator.makeAccessoryView()
        }

        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self

        if let action = pendingFormat {
            context.coordinator.applyFormatting(action)
            DispatchQueue.main.async {
                pendingFormat = nil
            }
            return
        }

        if !context.coordinator.skipBindingSync && textView.text != text {
            textView.text = text
            context.coordinator.expandedSelection = nil
        }
        context.coordinator.skipBindingSync = false

        if isFocused && !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if !isFocused && textView.isFirstResponder {
            textView.resignFirstResponder()
        }

        context.coordinator.recalculateHeight(for: textView)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextEditor
        weak var textView: UITextView?
        var skipBindingSync = false
        var expandedSelection: NSRange?

        init(parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func makeAccessoryView() -> UIView {
            let height: CGFloat = 48
            let container = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height))
            container.backgroundColor = .systemBackground
            container.autoresizingMask = [.flexibleWidth]

            let topBorder = UIView()
            topBorder.backgroundColor = UIColor.separator.withAlphaComponent(0.22)
            topBorder.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(topBorder)

            let scrollView = UIScrollView()
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(scrollView)

            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = 8
            stack.alignment = .center
            stack.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(stack)

            let formatActions: [(String, MarkdownFormatAction)] = [
                ("bold", .wrap(prefix: "**", suffix: "**", placeholder: "texto")),
                ("italic", .wrap(prefix: "*", suffix: "*", placeholder: "texto")),
                ("link", .wrap(prefix: "[", suffix: "](url)", placeholder: "texto")),
                ("chevron.left.forwardslash.chevron.right", .wrap(prefix: "`", suffix: "`", placeholder: "código")),
                ("text.quote", .linePrefix("> ")),
                ("list.bullet", .linePrefix("- "))
            ]

            for (icon, action) in formatActions {
                stack.addArrangedSubview(makeAccessoryButton(icon: icon, action: action))
            }

            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            stack.addArrangedSubview(spacer)

            let dismissButton = UIButton(type: .system)
            dismissButton.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
            dismissButton.tintColor = .secondaryLabel
            dismissButton.accessibilityLabel = "Fechar teclado"
            dismissButton.addAction(UIAction { [weak self] _ in
                self?.dismissKeyboard()
            }, for: .touchUpInside)
            stack.addArrangedSubview(dismissButton)

            NSLayoutConstraint.activate([
                topBorder.topAnchor.constraint(equalTo: container.topAnchor),
                topBorder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                topBorder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                topBorder.heightAnchor.constraint(equalToConstant: 1),

                scrollView.topAnchor.constraint(equalTo: topBorder.bottomAnchor),
                scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

                stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 6),
                stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -6),
                stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor, constant: -12)
            ])

            return container
        }

        private func makeAccessoryButton(icon: String, action: MarkdownFormatAction) -> UIButton {
            let button = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            button.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
            button.tintColor = .secondaryLabel
            button.backgroundColor = UIColor.systemGray5.withAlphaComponent(0.55)
            button.layer.cornerRadius = 16
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 32).isActive = true
            button.heightAnchor.constraint(equalToConstant: 32).isActive = true
            button.addAction(UIAction { [weak self] _ in
                self?.applyFormatting(action)
            }, for: .touchUpInside)
            return button
        }

        private func dismissKeyboard() {
            textView?.resignFirstResponder()
            parent.isFocused = false
        }

        func textViewDidChange(_ textView: UITextView) {
            skipBindingSync = true
            parent.text = textView.text
            expandedSelection = nil
            recalculateHeight(for: textView)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
            recalculateHeight(for: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let range = textView.selectedRange

            if range.length > 0 {
                expandedSelection = range
                return
            }

            guard let expanded = expandedSelection else { return }

            let cursor = range.location
            let start = expanded.location
            let end = expanded.location + expanded.length

            if cursor < start || cursor > end {
                expandedSelection = nil
            }
        }

        func applyFormatting(_ action: MarkdownFormatAction) {
            guard let textView else { return }

            skipBindingSync = true

            var updatedText = textView.text ?? ""
            var selectedRange = selectionForFormatting(in: textView)
            MarkdownFormatting.apply(action: action, to: &updatedText, selectedRange: &selectedRange)

            textView.text = updatedText
            textView.selectedRange = selectedRange
            expandedSelection = nil
            parent.text = updatedText
            textView.becomeFirstResponder()
            recalculateHeight(for: textView)
        }

        func recalculateHeight(for textView: UITextView) {
            let width = textView.bounds.width
            guard width > 0 else { return }

            let fittingSize = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            let clampedHeight = min(max(fittingSize.height, parent.minHeight), parent.maxHeight)
            textView.isScrollEnabled = fittingSize.height > parent.maxHeight

            if abs(parent.contentHeight - clampedHeight) > 0.5 {
                DispatchQueue.main.async {
                    self.parent.contentHeight = clampedHeight
                }
            }
        }

        private func selectionForFormatting(in textView: UITextView) -> NSRange {
            if let expandedSelection, expandedSelection.length > 0 {
                return expandedSelection
            }
            return textView.selectedRange
        }
    }
}

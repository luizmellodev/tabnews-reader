//
//  InlineTip.swift
//  newtabnews
//

import SwiftUI

/// Dicas que aparecem uma única vez, na tela onde a funcionalidade está.
enum AppTip: String, CaseIterable {
    case holdPost
    case pitchFilter
    case highlight
    case author
    case library

    var storageKey: String { "tip.\(rawValue).dismissed" }

    /// Perfil > Ver Dicas Novamente
    static func resetAll() {
        for tip in allCases {
            UserDefaults.standard.removeObject(forKey: tip.storageKey)
        }
    }
}

/// Card de dica no estilo dos cards do feed: ícone, texto, X para dispensar e uma ação opcional.
struct InlineTip: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dispensar dica")
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(.black)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color("CardColor"))
        )
        .overlay(
            // Separa o card quando o fundo da tela tem a mesma cor (ex.: tela do post)
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

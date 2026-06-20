//
//  FailureView.swift
//  newtabnews
//
//  Created by Luiz Mello on 27/07/23.
//

import SwiftUI

struct FailureView: View {
    @Binding var currentTheme: Theme
    var message: String = "Não conseguimos carregar o conteúdo. Pode ser instabilidade na API ou conexão lenta."
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Algo deu errado")
                    .font(.title2.weight(.semibold))

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let onRetry {
                Button(action: onRetry) {
                    Label("Tentar novamente", systemImage: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
                .padding(.top, 4)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FailureView_Previews: PreviewProvider {
    static var previews: some View {
        FailureView(currentTheme: .constant(.dark)) {
            print("retry")
        }
    }
}

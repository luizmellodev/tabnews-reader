//
//  DigestBannerView.swift
//  newtabnews
//
//  Created by Luiz Mello on 27/12/25.
//

import SwiftUI

struct DigestBannerView: View {
    let onTap: () -> Void
    
    // 10 mensagens variadas e fofas
    private let messages = [
        "Perdeu os melhores posts da semana? A gente guardou pra você!",
        "Trabalhou muito a semana e não leu o TabNews? Guardamos os melhores pra você!",
        "Semana corrida? Relaxa! Separamos o melhor do TabNews pra você!",
        "Não deu tempo de acompanhar tudo? A gente fez a curadoria!",
        "Os posts mais quentes da semana estão te esperando!",
        "Sua dose semanal de conhecimento chegou!",
        "O resumo que você não sabia que precisava está aqui! 💡",
        "Fim de semana chegando? Que tal dar uma olhada no melhor da semana?",
        "A comunidade produziu conteúdo incrível essa semana. Vem ver!",
        "Seu resumo semanal está prontinho!"
    ]
    
    @State private var currentMessage: String = ""
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resumo Semanal")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(currentMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            currentMessage = messages.randomElement() ?? messages[0]
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        DigestBannerView(onTap: {})
        DigestBannerView(onTap: {})
        DigestBannerView(onTap: {})
    }
    .padding()
}


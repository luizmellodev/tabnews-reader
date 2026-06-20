//
//  SkeletonCard.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/11/25.
//

import SwiftUI

struct SkeletonCard: View {
    @State private var phase: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    
    var skeletonGradient: LinearGradient {
        let baseColor = colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.25)
        let shimmerColor = colorScheme == .dark ? Color.gray.opacity(0.35) : Color.gray.opacity(0.15)
        
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: baseColor, location: phase - 0.3),
                .init(color: shimmerColor, location: phase),
                .init(color: baseColor, location: phase + 0.3)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Título skeleton (2 linhas)
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(skeletonGradient)
                        .frame(height: 20)
                        .frame(maxWidth: .infinity)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(skeletonGradient)
                        .frame(height: 20)
                        .frame(maxWidth: 250)
                }
                .padding(.bottom, 5)
                .padding(.top, 20)
                
                // Info do autor e data
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 100, height: 12)
                    
                    Spacer()
                    
                    // Ícone de relógio
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 60, height: 12)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 80, height: 12)
                }
                .padding(.bottom, 12)
                
                Divider()
                    .opacity(0.3)
                    .padding(.bottom, 12)
                
                // Preview do corpo (5 linhas)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(height: 14)
                        .frame(maxWidth: .infinity)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(height: 14)
                        .frame(maxWidth: .infinity)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(height: 14)
                        .frame(maxWidth: .infinity)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(height: 14)
                        .frame(maxWidth: .infinity)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(height: 14)
                        .frame(maxWidth: 200)
                }
                .padding(.bottom, 20)
                
                // Botão "Ler mais"
                RoundedRectangle(cornerRadius: 5)
                    .fill(skeletonGradient)
                    .frame(height: 40)
                    .padding(.bottom, 10)
            }
        }
        .padding(.horizontal)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color("CardColor"))
        }
        .frame(height: 330)
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                phase = 2
            }
        }
    }
}

#Preview {
    SkeletonCard()
        .preferredColorScheme(.dark)
}

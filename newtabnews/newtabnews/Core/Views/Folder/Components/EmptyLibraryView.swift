//
//  EmptyLibraryView.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/12/25.
//

import SwiftUI

struct EmptyLibraryView: View {
    let showGameButton: Bool
    let onCreateFolder: () -> Void
    let onPlayGame: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 70))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("Sua Biblioteca")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Curta posts, salve para ler depois ou organize em pastas")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: onCreateFolder) {
                Label("Criar Pasta", systemImage: "folder.badge.plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
            
            if showGameButton {
                Button(action: onPlayGame) {
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.caption)
                        Text("Jogar enquanto isso")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


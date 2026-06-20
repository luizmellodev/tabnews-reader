//
//  DigestListView.swift
//  newtabnews
//
//  Created by Luiz Mello on 27/12/25.
//

import SwiftUI

struct DigestListView: View {
    @State private var digestVM = DigestViewModel()
    
    var body: some View {
        ZStack {
            Color("Background")
                .ignoresSafeArea()
            Image("ruido")
                .resizable()
                .scaledToFill()
                .blendMode(.overlay)
                .ignoresSafeArea()
            
            switch digestVM.state {
            case .loading:
                ProgressView()
                    .scaleEffect(1.5)
                
            case .requestSucceeded:
                ScrollView {
                    LazyVStack(spacing: 16) {
                        headerView
                        
                        ForEach(digestVM.digests) { digest in
                            DigestCard(digest: digest, isNew: isCreatedThisWeek(createdAt: digest.createdAt))
                        }
                    }
                    .padding()
                    .padding(.top, 50)
                }
                
            case .requestFailed:
                FailureView(currentTheme: .constant(.dark)) {
                    Task {
                        await digestVM.fetchDigestContent()
                        await digestVM.fetchDigestPost()
                    }
                }
                
            default:
                Color.clear
            }
        }
        .navigationTitle("Resumo Semanal")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !digestVM.alreadyLoaded {
                await digestVM.fetchDigestContent()
                await digestVM.fetchDigestPost()
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            
            Text("Resumo Semanal")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("O melhor da semana no TabNews")
                .font(.subheadline)
                .foregroundStyle(.gray)
            
            // Crédito e agradecimento
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("Digest criado e mantido por")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Link("italosousa", destination: URL(string: "https://www.tabnews.com.br/italosousa")!)
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                
                Text("💙 Obrigado por manter a comunidade ativa!")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            .padding(.top, 4)
        }
        .padding(.vertical)
    }
    
    private func isCreatedThisWeek(createdAt: String?) -> Bool {
        guard let createdAtString = createdAt else {
            return false
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let createdDate = dateFormatter.date(from: createdAtString) else {
            return false
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Verifica se está na mesma semana
        let createdWeek = calendar.component(.weekOfYear, from: createdDate)
        let currentWeek = calendar.component(.weekOfYear, from: now)
        let createdYear = calendar.component(.year, from: createdDate)
        let currentYear = calendar.component(.year, from: now)
        
        return createdWeek == currentWeek && createdYear == currentYear
    }
}

#Preview {
    NavigationStack {
        DigestListView()
    }
}


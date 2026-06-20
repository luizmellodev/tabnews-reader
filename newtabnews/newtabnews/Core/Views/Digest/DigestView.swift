//
//  DigestView.swift
//  newtabnews
//
//  Created by Luiz Mello on 27/12/25.
//

import SwiftUI
import Foundation

struct DigestView: View {
    
    @Environment(DigestViewModel.self) private var viewModel
    @Binding var isViewInApp: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background")
                    .ignoresSafeArea()
                Image("ruido")
                    .resizable()
                    .scaledToFill()
                    .blendMode(.overlay)
                    .ignoresSafeArea()
                
                switch viewModel.state {
                case .loading:
                    ProgressView()
                        .scaleEffect(1.5)
                    
                case .requestSucceeded:
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            headerView
                            
                            ForEach(viewModel.digests) { digest in
                                DigestCard(digest: digest, isNew: isCreatedThisWeek(createdAt: digest.createdAt))
                            }
                        }
                        .padding()
                    }
                    .padding(.top, 60)
                    
                case .requestFailed:
                    FailureView(currentTheme: .constant(.dark)) {
                        Task {
                            await viewModel.fetchDigestContent()
                            await viewModel.fetchDigestPost()
                        }
                    }
                    
                default:
                    Color.clear
                }
            }
            .task {
                if !viewModel.alreadyLoaded {
                    await viewModel.fetchDigestContent()
                    await viewModel.fetchDigestPost()
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Resumo Semanal")
                .font(.largeTitle)
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


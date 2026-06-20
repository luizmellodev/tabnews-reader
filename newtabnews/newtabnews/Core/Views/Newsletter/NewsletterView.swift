//
//  NewsletterView.swift
//  newtabnews
//
//  Created by Luiz Mello on 02/08/23.
//

import SwiftUI
import Foundation
import StoreKit

struct NewsletterView: View {
    
    @EnvironmentObject var viewModel: NewsletterViewModel
    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme
    @AppStorage("newsletterOpenCount") private var newsletterOpenCount = 0
    @AppStorage("lastReviewRequestDate") private var lastReviewRequestDate: TimeInterval = 0
    @State private var shouldShowReviewPrompt = false
    
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
                            
                            ForEach(viewModel.newsletter) { newsletter in
                                NewsletterCard(
                                    newsletter: newsletter,
                                    isNew: isCreatedToday(createdAt: newsletter.createdAt),
                                    isViewInApp: $isViewInApp,
                                    currentTheme: $currentTheme
                                )
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.fetchNewsletterContent()
                        await viewModel.fetchNewsletterPost()
                    }
                    .padding(.top, 60)
                    
                case .requestFailed:
                    FailureView(currentTheme: .constant(.dark))
                    
                default:
                    Color.clear
                }
            }
            .task {
                if !viewModel.alreadyLoaded {
                    await viewModel.fetchNewsletterContent()
                    await viewModel.fetchNewsletterPost()
                }
                
                checkAndShowReviewPrompt()
            }
        }
    }
    
    // MARK: - Review Request
    
    private func checkAndShowReviewPrompt() {
        newsletterOpenCount += 1
        
        // Condições para mostrar review:
        // 1. Usuário abriu newsletter 3+ vezes
        // 2. Não pediu review nos últimos 90 dias (ou nunca pediu)
        let daysSinceLastRequest = (Date().timeIntervalSince1970 - lastReviewRequestDate) / 86400
        let shouldRequest = newsletterOpenCount >= 3 && (lastReviewRequestDate == 0 || daysSinceLastRequest >= 90)
        
        if shouldRequest {
            // Esperar 2 segundos antes de mostrar (para não ser intrusivo)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                    lastReviewRequestDate = Date().timeIntervalSince1970
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Newsletter")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Fique por dentro das novidades")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .padding(.vertical)
    }
    
    private func isCreatedToday(createdAt: String?) -> Bool {
        guard let createdAtString = createdAt else {
            return false
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let createdDate = dateFormatter.date(from: createdAtString) else {
            return false
        }
        
        let calendar = Calendar.current
        let createdComponents = calendar.dateComponents([.day, .month], from: createdDate)
        let currentComponents = calendar.dateComponents([.day, .month], from: Date())
        
        return createdComponents.day == currentComponents.day &&
               createdComponents.month == currentComponents.month
    }
}

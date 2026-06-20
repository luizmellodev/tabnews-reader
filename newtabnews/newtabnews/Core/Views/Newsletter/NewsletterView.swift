//
//  NewsletterView.swift
//  newtabnews
//
//  Created by Luiz Mello on 02/08/23.
//

import SwiftUI
import Foundation

struct NewsletterView: View {
    
    @EnvironmentObject var viewModel: NewsletterViewModel
    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme
    @Namespace private var zoomNamespace
    
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
                                    isNew: NewsletterViewModel.isCreatedToday(createdAt: newsletter.createdAt),
                                    isViewInApp: $isViewInApp,
                                    currentTheme: $currentTheme,
                                    zoomNamespace: zoomNamespace
                                )
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.fetchNewsletterContent()
                        viewModel.markNewslettersAsSeen()
                    }
                    .padding(.top, 60)
                    
                case .requestFailed:
                    FailureView(currentTheme: .constant(.dark)) {
                        Task {
                            await viewModel.fetchNewsletterContent()
                        }
                    }
                    
                default:
                    Color.clear
                }
            }
            .task {
                if !viewModel.alreadyLoaded {
                    await viewModel.fetchNewsletterContent()
                }
                
                AppReviewManager.shared.recordNewsletterVisit()
            }
            .onAppear {
                viewModel.markNewslettersAsSeen()
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
}

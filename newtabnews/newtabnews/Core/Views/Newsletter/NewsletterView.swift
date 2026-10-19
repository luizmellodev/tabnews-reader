//
//  NewsletterView.swift
//  newtabnews
//
//  Created by Luiz Mello on 02/08/23.
//

import SwiftUI
import Foundation

struct NewsletterView: View {
    
    @Environment(NewsletterViewModel.self) private var viewModel
    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme
    @Namespace private var zoomNamespace
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                        .scaleEffect(1.5)
                    
                case .requestSucceeded:
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 28) {
                            ForEach(viewModel.sections) { section in
                                sectionView(section)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom)
                    }
                    .refreshable {
                        await viewModel.fetchNewsletterContent(showLoading: false)
                        viewModel.markNewslettersAsSeen()
                    }
                    
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Newsletter")
            .navigationBarTitleDisplayMode(.large)
            .background {
                ZStack {
                    Color("Background")
                        .ignoresSafeArea()
                    Image("ruido")
                        .resizable()
                        .scaledToFill()
                        .blendMode(.overlay)
                        .ignoresSafeArea()
                }
            }
            .task {
                if !viewModel.alreadyLoaded {
                    await viewModel.fetchNewsletterContent()
                    viewModel.markNewslettersAsSeen()
                }
                
                AppReviewManager.shared.recordNewsletterVisit()
            }
            .onAppear {
                viewModel.markNewslettersAsSeen()
            }
            .onDisappear {
                viewModel.clearUnseenHighlights()
            }
        }
    }
    
    private func sectionView(_ section: NewsletterSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .font(.caption)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)
            
            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, newsletter in
                if index > 0 {
                    Divider()
                }
                
                NewsletterCard(
                    newsletter: newsletter,
                    isUnseen: newsletter.id.map { viewModel.unseenIds.contains($0) } ?? false,
                    isViewInApp: $isViewInApp,
                    currentTheme: $currentTheme,
                    zoomNamespace: zoomNamespace,
                    onOpen: { viewModel.markAsRead(newsletter) }
                )
            }
        }
    }
}

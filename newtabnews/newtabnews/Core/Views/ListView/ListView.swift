//
//  ListView.swift
//  newtabnews
//
//  Created by Luiz Mello on 22/07/23.
//

import SwiftUI

struct ListView: View {
    
    @Environment(MainViewModel.self) var viewModel
    @Binding var searchText: String
    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme
    var posts: [PostRequest]
    var zoomNamespace: Namespace.ID
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(filteredPosts.enumerated()), id: \.element.id) { index, post in
                PostRow(
                    isViewInApp: $isViewInApp,
                    currentTheme: $currentTheme,
                    post: post,
                    zoomNamespace: zoomNamespace
                )
                .environment(viewModel)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
                .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.05), value: filteredPosts.count)
                .onAppear {
                    if index == filteredPosts.count - 3 {
                        Task {
                            await viewModel.fetchNextPage()
                        }
                    }
                }
            }
            
            if viewModel.isLoadingMore {
                LoadingMoreView()
                    .padding(.vertical, 20)
            }
            
            if !viewModel.hasMorePages && !filteredPosts.isEmpty {
                EndOfListView()
                    .padding(.vertical, 20)
            }
        }
        .padding(.horizontal, 5)
    }
    
    private var filteredPosts: [PostRequest] {
        if searchText.isEmpty {
            return posts
        } else {
            return posts.filter { post in
                guard let title = post.title else { return false }
                return title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

struct LoadingMoreView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Carregando mais posts...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct EndOfListView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
            Text("Você viu todos os posts!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

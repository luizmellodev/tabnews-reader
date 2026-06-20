//
//  ListView.swift
//  newtabnews
//
//  Created by Luiz Mello on 22/07/23.
//

import SwiftUI

struct ListView: View {

    @Environment(MainViewModel.self) var viewModel
    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme
    var posts: [PostRequest]
    var zoomNamespace: Namespace.ID

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
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
                .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.05), value: posts.count)
                .onAppear {
                    if index == posts.count - 3 {
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

            if !viewModel.hasMorePages && !posts.isEmpty {
                EndOfListView()
                    .padding(.vertical, 20)
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

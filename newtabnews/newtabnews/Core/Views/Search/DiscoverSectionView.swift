//
//  DiscoverSectionView.swift
//  newtabnews
//

import SwiftUI

struct DiscoverBentoSectionView: View {
    @Environment(MainViewModel.self) private var viewModel

    let title: String
    let subtitle: String
    let posts: [PostRequest]
    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme
    var zoomNamespace: Namespace.ID

    var body: some View {
        if !posts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader

                VStack(spacing: 8) {
                    if let featured = posts.first {
                        postLink(featured, size: .featured)
                    }

                    let gridPosts = Array(posts.dropFirst())
                    if !gridPosts.isEmpty {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)
                            ],
                            spacing: 10
                        ) {
                            ForEach(gridPosts) { post in
                                postLink(post, size: .compact)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func postLink(_ post: PostRequest, size: DiscoverPostCard.DiscoverCardSize) -> some View {
        NavigationLink {
            ListDetailView(
                isViewInApp: $isViewInApp,
                currentTheme: $currentTheme,
                post: post
            )
            .environment(viewModel)
            .postZoomDestination(id: post.zoomTransitionID, namespace: zoomNamespace)
        } label: {
            DiscoverPostCard(post: post, size: size)
        }
        .buttonStyle(.plain)
        .postZoomSource(id: post.zoomTransitionID, namespace: zoomNamespace)
    }
}

struct DiscoverLoadingView: View {
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color("CardColor").opacity(0.6))
                .frame(height: 130)
                .padding(.horizontal)

            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 120, height: 11)
                        .padding(.horizontal)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color("CardColor").opacity(0.6))
                        .frame(height: 120)
                        .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color("CardColor").opacity(0.6))
                                .frame(height: 100)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}

typealias DiscoverSectionView = DiscoverBentoSectionView

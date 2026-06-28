//
//  DailyDigestView.swift
//  newtabnews
//
//  Created by Luiz Mello on 20/02/26.
//

import SwiftUI

struct DailyDigestView: View {
    @StateObject private var digestManager = DailyDigestManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPost: PostRequest?
    @State private var isLoadingPost = false
    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme
    
    private let contentService = ContentService()
    
    var body: some View {
        NavigationStack {
            ZStack {
                if digestManager.isLoading && digestManager.todayDigest == nil {
                    loadingView
                } else if let digest = digestManager.todayDigest, !digest.items.isEmpty {
                    digestContent(digest)
                        .opacity(digestManager.isLoading ? 0.5 : 1.0)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Briefing Diário")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            await digestManager.generateTodayDigest()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(digestManager.isLoading ? Color.secondary : Color.blue)
                    }
                    .disabled(digestManager.isLoading)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
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
            .sheet(item: $selectedPost) { post in
                ListDetailView(
                    isViewInApp: $isViewInApp,
                    currentTheme: $currentTheme,
                    post: post
                )
            }
            .task {
                await digestManager.generateTodayDigest()
            }
            .overlay(alignment: .top) {
                if digestManager.isLoading && digestManager.todayDigest != nil {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Atualizando...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color("CardColor"), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay {
                if isLoadingPost {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.3)
                                .tint(.white)
                            Text("Carregando post...")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(Color("CardColor"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .animation(.spring(), value: digestManager.isLoading)
        }
    }
    
    // MARK: - Post Loading
    
    private func loadFullPostAndNavigate(_ post: PostRequest) async {
        guard let username = post.ownerUsername, let slug = post.slug else { return }
        
        await MainActor.run {
            isLoadingPost = true
        }
        
        do {
            let fullPost = try await contentService.getPost(user: username, slug: slug)
            
            await MainActor.run {
                self.selectedPost = fullPost
                self.isLoadingPost = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingPost = false
                print("❌ Erro ao carregar post completo: \(error)")
            }
        }
    }
    
    // MARK: - Content Views
    
    private func digestContent(_ digest: DailyDigest) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView(digest)
                
                VStack(spacing: 16) {
                    ForEach(Array(digest.items.enumerated()), id: \.element.id) { index, item in
                        DigestItemCard(
                            item: item,
                            rank: index + 1,
                            onTap: {
                                Task {
                                    await loadFullPostAndNavigate(item.post)
                                }
                            }
                        )
                        .disabled(isLoadingPost)
                    }
                }
            }
            .padding()
        }
    }
    
    private func headerView(_ digest: DailyDigest) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "sunset.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("Briefing Diário")
                .font(.title2)
                .fontWeight(.bold)

            Text(digest.formattedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Top \(digest.items.count) discussões de hoje")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Preparando seu briefing...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Carregando posts...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await digestManager.generateTodayDigest()
        }
    }
}

// MARK: - Digest Item Card

struct DigestItemCard: View {
    let item: DailyDigestItem
    let rank: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                Text("\(rank)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(rank <= 3 ? rankColor : .secondary)
                    .frame(width: 22, alignment: .center)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.post.title ?? "Sem título")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 12) {
                        Label("\(item.post.tabcoins ?? 0)", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)

                        if let comments = item.post.childrenDeepCount, comments > 0 {
                            Label("\(comments)", systemImage: "bubble.left.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let username = item.post.ownerUsername {
                            Text("@\(username)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color("CardColor"))
            )
            .overlay {
                if rank <= 3 {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(rankColor.opacity(0.25), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .orange
        case 2: return .secondary
        case 3: return .blue
        default: return .clear
        }
    }
}

// MARK: - Banner

struct DailyDigestBanner: View {
    let onTap: () -> Void

    private let messages = [
        "Fim de expediente? O resumo do dia no TabNews está pronto!",
        "Antes de fechar o dia, veja o que rolou no TabNews!",
        "Não perdeu nada do TabNews hoje — a gente filtrou pra você!",
        "As discussões mais quentes do dia te esperam!",
        "Pouco tempo? Veja o que rolou hoje no TabNews!",
        "Briefing pronto: o essencial de hoje em um lugar só!",
        "Hora de encerrar? Confira os destaques de hoje!",
        "Seu resumo diário chegou — veja o que a comunidade produziu!"
    ]

    @State private var currentMessage: String = ""

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "sunset.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Briefing Diário")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(currentMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            currentMessage = messages.randomElement() ?? messages[0]
        }
    }
}

#Preview {
    DailyDigestView(isViewInApp: .constant(true), currentTheme: .constant(.light))
}

#Preview("Banner") {
    VStack {
        DailyDigestBanner(onTap: {})
            .padding()
        Spacer()
    }
}

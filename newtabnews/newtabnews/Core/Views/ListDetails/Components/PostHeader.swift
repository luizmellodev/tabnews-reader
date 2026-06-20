//
//  PostHeader.swift
//  newtabnews
//
//  Created by Luiz Mello on 04/01/26.
//

import SwiftUI
import SwiftData

/// Header minimalista do post que integra título, metadados e ações
/// Estilo: Medium, beReal, Apple News
struct PostHeader: View {
    @Environment(MainViewModel.self) var viewModel
    
    let post: PostRequest
    let postHighlights: [Highlight]
    @Binding var isHighlightMode: Bool
    @Binding var showingAddNote: Bool
    @Binding var showAudioControls: Bool
    
    var isNewsletter: Bool = false
    
    @State private var isVoting: Bool = false
    @State private var hasVoted: Bool = false
    @State private var localTabcoins: Int? = nil
    @State private var showConfetti: Bool = false
    @State private var showLoginRequiredAlert: Bool = false
    @State private var showAuthSheet: Bool = false
    
    private let authService = AuthService.shared
    private let voteManager = VoteManager.shared
    
    init(
        post: PostRequest,
        postHighlights: [Highlight],
        isHighlightMode: Binding<Bool>,
        showingAddNote: Binding<Bool>,
        showAudioControls: Binding<Bool>,
        isNewsletter: Bool = false
    ) {
        self.post = post
        self.postHighlights = postHighlights
        self._isHighlightMode = isHighlightMode
        self._showingAddNote = showingAddNote
        self._showAudioControls = showAudioControls
        self.isNewsletter = isNewsletter
        
        // Verificar se já votou
        if let postId = post.id {
            _hasVoted = State(initialValue: VoteManager.shared.hasVoted(contentId: postId))
        }
    }
    
    private var displayTabcoins: Int {
        localTabcoins ?? post.tabcoins ?? 0
    }
    
    private var isLiked: Bool {
        viewModel.likedList.contains(where: { $0.title == post.title })
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                // Título (grande e bold)
                Text(post.title ?? "Título indisponível")
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineSpacing(2)
                
                // Metadados
                HStack(spacing: 6) {
                    if isNewsletter {
                        HStack(spacing: 4) {
                            Image(systemName: "envelope.open.fill")
                                .font(.caption)
                            Text("Newsletter")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(getFormattedDate(value: post.createdAt ?? ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        if let body = post.body, !body.isEmpty, body != "Erro ao carregar conteúdo" {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(body.readingTimeFormatted)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(post.ownerUsername ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(getFormattedDate(value: post.createdAt ?? ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // Tabcoins + botões de voto (inline, mas com área de toque adequada)
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                            Text("\(displayTabcoins)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(displayTabcoins > 0 ? .orange : .secondary)
                        
                        // Botões de voto com área de toque adequada (44x44)
                        if !hasVoted && !isVoting {
                            Button {
                                handleVote(transactionType: "credit")
                            } label: {
                                Image(systemName: "arrow.up.circle")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                handleVote(transactionType: "debit")
                            } label: {
                                Image(systemName: "arrow.down.circle")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else if isVoting {
                            ProgressView()
                                .controlSize(.mini)
                        } else if hasVoted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.green)
                        }
                    }
                }
                
                // Barra de ações (minimalista - apenas ícones)
                HStack(spacing: 16) {
                    // Destacar
                    Button {
                        withAnimation {
                            isHighlightMode.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isHighlightMode ? "checkmark.circle.fill" : "highlighter")
                                .font(.subheadline)
                            if isHighlightMode {
                                Text("Concluir")
                                    .font(.caption)
                            } else if postHighlights.count > 0 {
                                Text("\(postHighlights.count)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        .foregroundStyle(isHighlightMode ? .green : .secondary)
                    }
                    
                    // Anotar
                    Button {
                        showingAddNote = true
                    } label: {
                        Image(systemName: "note.text")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Like
                    Button {
                        let impactHeavy = UIImpactFeedbackGenerator(style: .medium)
                        impactHeavy.impactOccurred()
                        
                        if isLiked {
                            viewModel.removeContentList(content: post)
                        } else {
                            viewModel.likeContentList(content: post)
                        }
                    } label: {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.subheadline)
                            .foregroundStyle(isLiked ? .red : .secondary)
                    }
                    
                    Spacer()
                    
                    // Áudio
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showAudioControls.toggle()
                        }
                    } label: {
                        Image(systemName: showAudioControls ? "speaker.wave.2.fill" : "speaker.wave.2")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 20)
            
            // Confete overlay
            if showConfetti {
                GeometryReader { geometry in
                    ParticleSystemView(
                        configuration: ParticleSystemConfiguration(
                            particleCount: 100,
                            shapes: [.confetti],
                            colors: [.red, .blue, .green, .yellow, .purple, .orange, .pink],
                            minSize: 6,
                            maxSize: 12,
                            minVelocity: 200,
                            maxVelocity: 400,
                            gravity: 600,
                            lifetime: 2.5,
                            emissionAngle: -90...90
                        ),
                        origin: CGPoint(x: geometry.size.width / 2, y: 50)
                    )
                    .allowsHitTesting(false)
                }
            }
        }
        .alert("Login necessário", isPresented: $showLoginRequiredAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Entrar") {
                showAuthSheet = true
            }
        } message: {
            Text("Entre para acessar seu perfil, seus posts e seus votos.")
        }
        .sheet(isPresented: $showAuthSheet) {
            NativeLoginView()
        }
    }
    
    // MARK: - Actions
    
    private func handleVote(transactionType: String) {
        guard let username = post.ownerUsername,
              let slug = post.slug else {
            return
        }
        
        guard !hasVoted else { return }
        
        guard authService.isAuthenticated else {
            showLoginRequiredAlert = true
            return
        }
        
        isVoting = true
        
        // Atualização otimista
        let currentTabcoins = localTabcoins ?? post.tabcoins ?? 0
        localTabcoins = transactionType == "credit" ? currentTabcoins + 1 : currentTabcoins - 1
        
        Task {
            do {
                try await authService.voteOnContent(
                    username: username,
                    slug: slug,
                    transactionType: transactionType
                )
                
                await MainActor.run {
                    isVoting = false
                    hasVoted = true
                    
                    if let postId = post.id {
                        voteManager.markAsVoted(contentId: postId)
                    }
                    
                    if transactionType == "credit" {
                        showConfetti = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            showConfetti = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isVoting = false
                    localTabcoins = post.tabcoins
                }
            }
        }
    }
}


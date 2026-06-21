//
//  CommentsView.swift
//  newtabnews
//
//  Created by Luiz Mello on 04/01/26.
//

import SwiftUI

struct CommentsView: View {
    let user: String
    let slug: String
    let postId: String

    @State private var viewModel = CommentsViewModel()
    @State private var isExpanded: Bool = false
    @State private var replyingToComment: Comment?
    @State private var showAuthSheet = false
    @StateObject private var authService = AuthService.shared
    
    private let previewCount = 2
    private let commentsToggleAnimation = Animation.spring(response: 0.3, dampingFraction: 0.8)
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        VStack {
            switch viewModel.state {
            case .loading:
                loadingView

            case .requestSucceeded:
                if viewModel.comments.isEmpty {
                    emptyStateView
                } else {
                    commentsListView
                }

            case .requestFailed:
                errorView

            default:
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .scrollDismissesKeyboard(.interactively)
        .task(id: postId) {
            isExpanded = false
            replyingToComment = nil
            await viewModel.fetchComments(user: user, slug: slug, postId: postId)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingCommentInput(
                parentId: replyingToComment?.id ?? postId,
                replyingTo: replyingToComment?.ownerUsername,
                onCommentPosted: {
                    Task {
                        await viewModel.refresh(user: user, slug: slug, postId: postId)
                    }
                    replyingToComment = nil
                },
                onCancel: {
                    replyingToComment = nil
                }
            )
            .padding(.horizontal, -20)
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Carregando comentários...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("Nenhum comentário ainda")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text("Seja o primeiro a comentar!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Erro ao carregar comentários")
                .font(.headline)
                .foregroundStyle(.primary)
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                Task {
                    await viewModel.refresh(user: user, slug: slug, postId: postId)
                }
            } label: {
                Label("Tentar novamente", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var commentsListView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header minimalista
            HStack(spacing: 6) {
                Text("\(viewModel.totalCommentsCount())")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(viewModel.totalCommentsCount() == 1 ? "comentário" : "comentários")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    Task {
                        await viewModel.refresh(user: user, slug: slug, postId: postId)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Lista de comentários (colapsada ou expandida)
            VStack(alignment: .leading, spacing: 0) {
                let displayedItems = viewModel.visibleThreadItems(
                    isExpanded: isExpanded,
                    previewCount: previewCount
                )
                
                ForEach(displayedItems, id: \.id) { item in
                    CommentRow(
                        itemID: item.id,
                        comment: item.comment,
                        depth: item.depth,
                        onReply: { replyComment in
                            withAnimation {
                                replyingToComment = replyComment
                            }
                        },
                        onVote: { comment, transactionType, completion in
                            handleVote(comment: comment, transactionType: transactionType, completion: completion)
                        }
                    )
                    .id("\(item.id)-depth-\(item.depth)")
                    .transition(.opacity)
                    
                    if item.id != displayedItems.last?.id {
                        commentSeparator
                    }
                }
                
                if !isExpanded && viewModel.comments.count > previewCount {
                    expandCommentsButton
                        .transition(.opacity)
                }
                
                if isExpanded && viewModel.comments.count > previewCount {
                    collapseCommentsButton
                        .transition(.opacity)
                }
            }
        }
        .sheet(isPresented: $showAuthSheet) {
            NativeLoginView()
        }
    }
    
    /// Linha fina entre comentários de primeiro nível — separa blocos sem o peso visual de um Divider padrão.
    private var commentSeparator: some View {
        Rectangle()
            .fill(.separator.opacity(0.22))
            .frame(height: 1)
            .padding(.vertical, 14)
    }
    
    private var expandCommentsButton: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color(.systemBackground).opacity(0),
                    Color(.systemBackground).opacity(0.8),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)
            
            Button {
                withAnimation(commentsToggleAnimation) {
                    isExpanded = true
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Ver todos os \(viewModel.totalCommentsCount()) comentários")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }
    
    private var collapseCommentsButton: some View {
        Button {
            withAnimation(commentsToggleAnimation) {
                isExpanded = false
            }
        } label: {
            HStack(spacing: 8) {
                Text("Recolher comentários")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "chevron.up")
                    .font(.caption)
            }
            .foregroundStyle(.blue)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }
    
    // MARK: - Actions
    
    private func handleVote(comment: Comment, transactionType: String, completion: @escaping (Bool) -> Void) {
        guard let commentUsername = comment.ownerUsername,
              let commentSlug = comment.slug else {
            print("❌ [CommentsView] Comentário sem username ou slug")
            completion(false)
            return
        }
        
        // Verificar se está autenticado
        guard authService.isAuthenticated else {
            showAuthSheet = true
            completion(false)
            return
        }
        
        // Fazer o voto
        Task {
            do {
                try await authService.voteOnContent(
                    username: commentUsername,
                    slug: commentSlug,
                    transactionType: transactionType
                )
                print("✅ [CommentsView] Voto registrado com sucesso")
                
                // Notificar sucesso PRIMEIRO (para disparar o confete)
                await MainActor.run {
                    completion(true)
                }
                
                // Aguardar 2 segundos para o confete aparecer
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                
                // DEPOIS recarregar comentários
                await viewModel.refresh(user: user, slug: slug, postId: postId)
            } catch {
                print("❌ [CommentsView] Erro ao votar: \(error)")
                
                // Notificar falha
                await MainActor.run {
                    completion(false)
                }
            }
        }
    }
}

#Preview("Loading") {
    CommentsView(user: "test", slug: "test-post", postId: "test-id")
        .environment(CommentsViewModel(service: MockContentService.success))
}

#Preview("With Comments") {
    CommentsView(user: "test", slug: "test-post", postId: "test-id")
        .environment(CommentsViewModel(service: MockContentService.success))
}

#Preview("Empty") {
    struct EmptyMockService: ContentServiceProtocol {
        func getContent(page: String, perPage: String, strategy: String) async throws -> [PostRequest] { [] }
        func getPost(user: String, slug: String) async throws -> PostRequest {
            PostRequest(
                id: "test",
                ownerId: nil,
                parentId: nil,
                slug: "test",
                title: "Test",
                body: nil,
                status: nil,
                type: nil,
                sourceUrl: nil,
                createdAt: nil,
                updatedAt: nil,
                publishedAt: nil,
                deletedAt: nil,
                ownerUsername: "test",
                tabcoins: nil,
                tabcoinsCredit: nil,
                tabcoinsDebit: nil,
                childrenDeepCount: nil
            )
        }
        func getNewsletter(page: String, perPage: String, strategy: String) async throws -> [PostRequest] { [] }
        func getDigest(page: String, perPage: String, strategy: String) async throws -> [PostRequest] { [] }
        func getComments(user: String, slug: String) async throws -> [Comment] { [] }
    }
    
    return CommentsView(user: "test", slug: "test-post", postId: "test-id")
        .environment(CommentsViewModel(service: EmptyMockService()))
}


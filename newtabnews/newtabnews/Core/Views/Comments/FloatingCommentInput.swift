//
//  FloatingCommentInput.swift
//  newtabnews
//
//  Created by Luiz Mello on 04/01/26.
//

import SwiftUI

struct FloatingCommentInput: View {
    let parentId: String
    let replyingTo: String?
    let onCommentPosted: () -> Void
    let onCancel: () -> Void
    
    @StateObject private var authService = AuthService.shared
    @State private var commentText: String = ""
    @State private var isPosting: Bool = false
    @State private var errorMessage: String?
    @State private var showLoginRequiredAlert: Bool = false
    @State private var showLoginSheet: Bool = false
    @State private var isEditorFocused: Bool = false
    @State private var editorHeight: CGFloat = 38
    @State private var pendingFormat: MarkdownFormatAction?
    
    private var canPost: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isPosting
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let errorMessage = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        self.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.08))
            }
            
            if let replyingTo = replyingTo {
                replyingBanner(username: replyingTo)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if commentText.isEmpty {
                        Text(replyingTo != nil ? "Escreva uma resposta…" : "Escreva um comentário…")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                    }
                    
                    MarkdownTextEditor(
                        text: $commentText,
                        isFocused: $isEditorFocused,
                        contentHeight: $editorHeight,
                        pendingFormat: $pendingFormat,
                        minHeight: 38,
                        maxHeight: 140,
                        showsFormattingAccessory: true
                    )
                    .frame(height: editorHeight)
                    .animation(.easeInOut(duration: 0.15), value: editorHeight)
                }
                
                Button {
                    Task {
                        await postComment()
                    }
                } label: {
                    Group {
                        if isPosting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(canPost ? Color.accentColor : Color(.systemGray4))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canPost)
                .accessibilityLabel("Enviar comentário")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.separator.opacity(0.35), lineWidth: 0.5)
            )
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
        .background {
            Color(.systemBackground)
                .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.separator.opacity(0.22))
                .frame(height: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: replyingTo)
        .onAppear {
            if authService.isAuthenticated && replyingTo != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isEditorFocused = true
                }
            }
        }
        .alert("Login necessário", isPresented: $showLoginRequiredAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Entrar") {
                showLoginSheet = true
            }
        } message: {
            Text("Entre para acessar seu perfil, seus posts e seus votos.")
        }
        .sheet(isPresented: $showLoginSheet) {
            NativeLoginView()
                .onDisappear {
                    if authService.isAuthenticated {
                        isEditorFocused = true
                    }
                }
        }
    }
    
    // MARK: - Subviews
    
    private func replyingBanner(username: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrowshape.turn.up.left")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 4) {
                Text("Respondendo")
                    .foregroundStyle(.secondary)
                Text("@\(username)")
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .font(.subheadline)
            
            Spacer(minLength: 8)
            
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color(.systemGray5).opacity(0.8))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancelar resposta")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
    
    // MARK: - Actions
    
    private func postComment() async {
        guard !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        guard authService.isAuthenticated else {
            await MainActor.run {
                showLoginRequiredAlert = true
            }
            return
        }
        
        errorMessage = nil
        isPosting = true
        
        do {
            _ = try await authService.postComment(
                parentId: parentId,
                body: commentText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            await MainActor.run {
                isPosting = false
                commentText = ""
                editorHeight = 38
                isEditorFocused = false
                
                let impact = UINotificationFeedbackGenerator()
                impact.notificationOccurred(.success)
                
                GamificationManager.shared.trackCommentPosted()
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                onCommentPosted()
            }
        } catch {
            await MainActor.run {
                isPosting = false
                errorMessage = error.localizedDescription
                
                let impact = UINotificationFeedbackGenerator()
                impact.notificationOccurred(.error)
            }
        }
    }
}

#Preview {
    VStack {
        Spacer()
        FloatingCommentInput(
            parentId: "test-id",
            replyingTo: nil,
            onCommentPosted: {},
            onCancel: {}
        )
    }
}

#Preview("Respondendo") {
    VStack {
        Spacer()
        FloatingCommentInput(
            parentId: "test-id",
            replyingTo: "luizmellodev",
            onCommentPosted: {},
            onCancel: {}
        )
    }
}

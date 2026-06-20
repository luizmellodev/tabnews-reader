//
//  CommentComposeSheet.swift
//  newtabnews
//
//  Created by Luiz Mello on 04/01/26.
//

import SwiftUI

struct CommentComposeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared
    
    let parentId: String
    let onCommentPosted: (() -> Void)?
    
    @State private var commentText: String = ""
    @State private var isPosting: Bool = false
    @State private var errorMessage: String?
    @State private var showLoginRequiredAlert: Bool = false
    @State private var showLoginSheet: Bool = false
    @State private var isPreviewMode: Bool = false
    @State private var isEditorFocused: Bool = false
    @State private var editorHeight: CGFloat = 150
    @State private var pendingFormat: MarkdownFormatAction?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let user = authService.currentUser {
                    userInfoView(user: user)
                }
                
                Picker("", selection: $isPreviewMode) {
                    Text("Escrever").tag(false)
                    Text("Visualizar").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                
                if isPreviewMode {
                    ScrollView {
                        if commentText.isEmpty {
                            Text("Nada para visualizar")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        } else {
                            Text(.init(commentText))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }
                    .frame(minHeight: 150, maxHeight: 300)
                } else {
                    VStack(spacing: 0) {
                        markdownToolbar
                        
                        MarkdownTextEditor(
                            text: $commentText,
                            isFocused: $isEditorFocused,
                            contentHeight: $editorHeight,
                            pendingFormat: $pendingFormat,
                            minHeight: 150,
                            maxHeight: 300,
                            showsFormattingAccessory: false
                        )
                        .frame(height: editorHeight)
                        .padding(.horizontal, 8)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Fechar") {
                                    isEditorFocused = false
                                }
                            }
                        }
                            .overlay(
                                Group {
                                    if commentText.isEmpty {
                                        Text("Escreva seu comentário em Markdown...")
                                            .foregroundStyle(.secondary)
                                            .padding()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                            .allowsHitTesting(false)
                                    }
                                }
                            )
                    }
                }
                
                Divider()
                
                // Error Message
                if let errorMessage = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                }
                
                // Character Count
                HStack(spacing: 12) {
                    Text("\(commentText.count) caracteres")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text("\(commentText.components(separatedBy: "\n").count) linhas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationTitle("Novo Comentário")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await postComment()
                        }
                    } label: {
                        if isPosting {
                            ProgressView()
                        } else {
                            Text("Publicar")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                }
            }
            .onAppear {
                // Se não estiver autenticado, não fazer nada (vai mostrar a view de login)
                if authService.isAuthenticated {
                    isEditorFocused = true
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
            .overlay {
                // Overlay de "não autenticado"
                if !authService.isAuthenticated {
                    unauthenticatedView
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var markdownToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                MarkdownButton(icon: "bold", label: "Bold") {
                    pendingFormat = .wrap(prefix: "**", suffix: "**", placeholder: "texto")
                }
                
                MarkdownButton(icon: "italic", label: "Italic") {
                    pendingFormat = .wrap(prefix: "*", suffix: "*", placeholder: "texto")
                }
                
                MarkdownButton(icon: "link", label: "Link") {
                    pendingFormat = .wrap(prefix: "[", suffix: "](url)", placeholder: "texto")
                }
                
                MarkdownButton(icon: "chevron.left.forwardslash.chevron.right", label: "Code") {
                    pendingFormat = .wrap(prefix: "`", suffix: "`", placeholder: "código")
                }
                
                MarkdownButton(icon: "text.quote", label: "Quote") {
                    pendingFormat = .linePrefix("> ")
                }
                
                MarkdownButton(icon: "list.bullet", label: "Lista") {
                    pendingFormat = .linePrefix("- ")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
    }
    
    private func userInfoView(user: User) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(user.username.prefix(1).uppercased()))
                        .font(.headline)
                        .foregroundStyle(.blue)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(user.username)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if let tabcoins = user.tabcoins {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("\(tabcoins) tabcoins")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Actions
    
    private func postComment() async {
        guard !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        errorMessage = nil
        isPosting = true
        
        do {
            _ = try await authService.postComment(
                parentId: parentId,
                body: commentText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            await MainActor.run {
                isPosting = false
                isEditorFocused = false
                onCommentPosted?()
                
                let impact = UINotificationFeedbackGenerator()
                impact.notificationOccurred(.success)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                isPosting = false
                errorMessage = error.localizedDescription
                
                // Feedback háptico de erro
                let impact = UINotificationFeedbackGenerator()
                impact.notificationOccurred(.error)
            }
        }
    }
    
    private var unauthenticatedView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "person.fill.questionmark")
                                .font(.title2)
                                .foregroundStyle(.primary)
                        )
                    
                    Text("Login necessário")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Entre para acessar seu perfil, seus posts e seus votos.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Button {
                    showLoginSheet = true
                } label: {
                    Text("Entrar")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary)
                        .foregroundStyle(Color("Background"))
                        .cornerRadius(10)
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Markdown Button

struct MarkdownButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundStyle(.primary)
            .frame(width: 60, height: 50)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }
}

#Preview {
    CommentComposeSheet(parentId: "test-post-id", onCommentPosted: nil)
}


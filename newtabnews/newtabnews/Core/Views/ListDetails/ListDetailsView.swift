//
//  ListDetailsView.swift
//  newtabnews
//
//  Created by Luiz Mello on 27/07/23.
//

import Foundation
import SwiftUI
import SwiftData

struct ListDetailView: View {
    
    @Environment(MainViewModel.self) var viewModel
    @Environment(\.modelContext) private var modelContext
    @StateObject private var ttsManager = TextToSpeechManager.shared

    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme
    
    @State var post: PostRequest
    var isNewsletter: Bool = false
    
    @State private var showingTabNews = false
    @State private var showingAddNote = false
    @State private var showingHighlightSheet = false
    @State private var isHighlightMode = false
    @State private var showAudioControls = false
    @State private var isLoadingBody = false
    @State private var bodyLoadFailed = false
    @Query private var highlights: [Highlight]
    
    @AppStorage("showReadOnTabNewsButton") private var showReadOnTabNewsButton = false
    
    private let contentService: ContentServiceProtocol = ContentService()
    
    private var postHighlights: [Highlight] {
        highlights.filter { $0.postId == post.stableKey }
    }
    
    private var needsBodyLoad: Bool {
        guard let body = post.body, !body.isEmpty else { return true }
        return body == "Erro ao carregar conteúdo"
    }
    
    private var commentUsername: String? {
        if isNewsletter { return "NewsletterOficial" }
        return post.ownerUsername
    }

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading) {
                    // Header unificado e minimalista
                    PostHeader(
                        post: post,
                        postHighlights: postHighlights,
                        isHighlightMode: $isHighlightMode,
                        showingAddNote: $showingAddNote,
                        showAudioControls: $showAudioControls,
                        isNewsletter: isNewsletter
                    )
                    
                    // Controles de áudio (aparecem quando ativado)
                    if showAudioControls {
                        AudioControlsView(ttsManager: ttsManager, post: post)
                            .padding(.top, 8)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    if isHighlightMode {
                        HighlightModeIndicator()
                    }
                    
                    postContent
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            
            if showReadOnTabNewsButton {
                readOnTabNewsButton
            }
        }
        .sheet(isPresented: $showingTabNews) {
            WebContentView(content: post)
                .presentationDetents([.large, .large])
                .presentationDragIndicator(.hidden)
        }
        .onAppear {
            GamificationManager.shared.trackPostRead(postId: post.stableKey)
        }
        .task(id: post.stableKey) {
            guard needsBodyLoad else { return }
            await loadPostBody()
        }
        .onDisappear {
            ttsManager.stop()
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteSheet(post: post, modelContext: modelContext)
                                }
        .sheet(isPresented: $showingHighlightSheet) {
            AddHighlightSheet(post: post, modelContext: modelContext)
        }
    }
    
    // MARK: - View Builders
    
    private var postContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoadingBody {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Carregando conteúdo...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if bodyLoadFailed {
                ContentUnavailableView {
                    Label("Não foi possível carregar", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("Verifique sua conexão e tente novamente.")
                } actions: {
                    Button("Tentar novamente") {
                        Task { await loadPostBody() }
                    }
                }
                .padding(.vertical, 20)
            } else {
                HybridMarkdownView(
                    markdown: post.body ?? "",
                    postId: post.stableKey,
                    highlights: postHighlights,
                    isHighlightMode: isHighlightMode,
                    onHighlight: { text, range in
                        saveHighlight(text: text, range: range)
                    },
                    onRemoveHighlight: { highlight in
                        removeHighlight(highlight)
                    }
                )
                .fixedSize(horizontal: false, vertical: true)
            }
            
            if !isLoadingBody && !bodyLoadFailed {
                PostCTAView(post: post)
            }
            
            // Seção de Comentários
            if !isLoadingBody && !bodyLoadFailed,
               let username = commentUsername,
               let slug = post.slug,
               let postId = post.id {
                Divider()
                    .padding(.vertical, 16)
                
                CommentsView(user: username, slug: slug, postId: postId)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.bottom, 80)
    }
    
    private var readOnTabNewsButton: some View {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        self.showingTabNews = true
                    }, label: {
                        Text("Ler no Tab News")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.blue)
                            }
                            .padding(.trailing, 30)
                            .padding(.bottom, 20)
                    })
                }
            }
        }
    
    // MARK: - Actions
    
    private func saveHighlight(text: String, range: NSRange) {
        let highlight = Highlight(
            postId: post.stableKey,
            postTitle: post.title,
            highlightedText: text,
            note: nil,
            colorHex: HighlightColor.yellow.rawValue,
            rangeStart: range.location,
            rangeLength: range.length
        )
        
        modelContext.insert(highlight)
        modelContext.upsertSavedPost(from: post)
        
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
        
        NotificationCenter.default.post(name: .highlightsUpdated, object: nil)
        
        GamificationManager.shared.trackHighlightCreated(postId: post.stableKey)
    }
    
    private func removeHighlight(_ highlight: Highlight) {
        modelContext.delete(highlight)
        
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.warning)
        
        NotificationCenter.default.post(name: .highlightsUpdated, object: nil)
    }
    
    @MainActor
    private func loadPostBody() async {
        guard let slug = post.slug, !slug.isEmpty else {
            bodyLoadFailed = true
            return
        }
        
        let username: String
        if isNewsletter {
            username = "NewsletterOficial"
        } else if let owner = post.ownerUsername, !owner.isEmpty {
            username = owner
        } else {
            bodyLoadFailed = true
            return
        }
        
        isLoadingBody = true
        bodyLoadFailed = false
        
        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 600_000_000)
            }
            
            do {
                let response = try await contentService.getPost(user: username, slug: slug)
                if let body = response.body, !body.isEmpty {
                    post = response
                    isLoadingBody = false
                    bodyLoadFailed = false
                    return
                }
            } catch {
                print("Erro ao carregar post [\(slug)] tentativa \(attempt + 1): \(error)")
            }
        }
        
        isLoadingBody = false
        bodyLoadFailed = true
    }
}

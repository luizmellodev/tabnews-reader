//
//  FoldersView.swift
//  newtabnews
//
//  Created by Luiz Mello on 20/11/25.
//

import SwiftUI
import SwiftData

struct FoldersView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MainViewModel.self) private var viewModel
    @Query(sort: \Folder.createdAt) private var folders: [Folder]
    @Query private var highlights: [Highlight]
    @Query private var notes: [Note]
    @Query private var savedPosts: [SavedPost]
    
    // Usar String IDs para pastas especiais (mais seguro que UUID)
    private enum SpecialFolder: String {
        case readLater = "special_read_later"
        case liked = "special_liked"
        case highlights = "special_highlights"
        case notes = "special_notes"
    }
    
    @State private var expandedFolders: Set<String> = [] // String ao invés de UUID
    @State private var showingAddFolder = false
    @State private var selectedPost: PostRequest?
    @State private var selectedHighlights: [Highlight] = []
    @State private var isEditMode = false
    @State private var selectedFolderIds: Set<UUID> = []
    @AppStorage("debugShowDigestBanner") private var debugShowDigestBanner = false
    
    // Verifica se é fim de semana - sábado ou domingo (ou modo debug ativado)
    private var shouldShowDigestBanner: Bool {
        #if DEBUG
        if debugShowDigestBanner {
            return true
        }
        #endif
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        return weekday == 7 || weekday == 1 // 7 = Sábado, 1 = Domingo
    }
    
    var body: some View {
        NavigationStack {
            Group {
            if folders.isEmpty && highlights.isEmpty && notes.isEmpty && uniqueLikedPosts.isEmpty && viewModel.readLaterList.isEmpty {
                emptyState
            } else {
                    List {
                        if shouldShowDigestBanner {
                            digestSection
                        }
                        readLaterSection
                        likedPostsSection
                        highlightsSection
                        notesSection
                        userFoldersSection
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Biblioteca")
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFolder) {
                AddFolderSheet()
            }
            .sheet(item: $selectedPost) { post in
                PostWithHighlightsView(
                    post: post,
                    highlights: selectedHighlights
                )
                .onDisappear {
                    selectedHighlights = []
                }
            }
            .onAppear {
                viewModel.getLikedContent()
                viewModel.getReadLaterContent()
                if !viewModel.readLaterList.isEmpty {
                    expandedFolders.insert(SpecialFolder.readLater.rawValue)
                }
            }
            .onChange(of: viewModel.readLaterList.count) { _, count in
                if count > 0 {
                    expandedFolders.insert(SpecialFolder.readLater.rawValue)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !folders.isEmpty {
                    editModeButton
                }
            }
            .overlay(alignment: .bottom) {
                if isEditMode && !selectedFolderIds.isEmpty {
                    EditModeToolbar(
                        selectedCount: selectedFolderIds.count,
                        onDelete: deleteSelectedFolders,
                        onClear: clearSelectedFolders
                    )
                }
            }
        }
    }
    
    // MARK: - View Builders
    
    @ViewBuilder
    private var digestSection: some View {
        Section {
            NavigationLink {
                DigestListView()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "flame.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Resumo Semanal")
                            .font(.headline)
                        Text("O melhor da semana no TabNews")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
            }
        } header: {
            Label("Conteúdo Especial", systemImage: "star.fill")
        }
    }
    
    @ViewBuilder
    private var readLaterSection: some View {
        if !viewModel.readLaterList.isEmpty {
            Section {
                SpecialFolderRow(
                    name: "Ler Depois",
                    icon: "bookmark.fill",
                    color: "#007AFF",
                    count: viewModel.readLaterList.count,
                    isExpanded: expandedFolders.contains(SpecialFolder.readLater.rawValue),
                    onToggle: {
                        toggleSpecialFolder(.readLater)
                    }
                )
                .contextMenu {
                    Button(role: .destructive) {
                        clearAllReadLater()
                    } label: {
                        Label("Limpar Ler Depois", systemImage: "bookmark.slash")
                    }
                }
                
                if expandedFolders.contains(SpecialFolder.readLater.rawValue) {
                    ForEach(viewModel.readLaterList) { post in
                        PostFileRow(
                            post: post,
                            onTap: {
                                selectedPost = post
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.removeFromReadLater(content: post)
                            } label: {
                                Label("Remover", systemImage: "bookmark.slash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.removeFromReadLater(content: post)
                            } label: {
                                Label("Remover de Ler Depois", systemImage: "bookmark.slash")
                            }
                        }
                    }
                }
            } header: {
                Label("Para Ler", systemImage: "bookmark.fill")
            }
        }
    }
    
    @ViewBuilder
    private var likedPostsSection: some View {
                        if !uniqueLikedPosts.isEmpty {
                            Section {
                                SpecialFolderRow(
                                    name: "Curtidos",
                                    icon: "heart.fill",
                                    color: "#FF3B30",
                                    count: uniqueLikedPosts.count,
                                    isExpanded: expandedFolders.contains(SpecialFolder.liked.rawValue),
                                    onToggle: {
                                        toggleSpecialFolder(.liked)
                                    }
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        clearAllLiked()
                                    } label: {
                                        Label("Remover Todos os Curtidos", systemImage: "heart.slash.fill")
                                    }
                                    .disabled(uniqueLikedPosts.isEmpty)
                                }
                                
                                if expandedFolders.contains(SpecialFolder.liked.rawValue) {
                                    ForEach(uniqueLikedPosts) { post in
                                        PostFileRow(
                                            post: post,
                                            onTap: {
                                                selectedPost = post
                                            }
                                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.removeContentList(content: post)
                            } label: {
                                Label("Remover", systemImage: "heart.slash")
                            }
                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                viewModel.removeContentList(content: post)
                                            } label: {
                                                Label("Remover dos Curtidos", systemImage: "heart.slash")
                            }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
    @ViewBuilder
    private var highlightsSection: some View {
                        if !highlights.isEmpty {
                            Section {
                                SpecialFolderRow(
                                    name: "Destaques",
                                    icon: "highlighter",
                                    color: "#FFFF00",
                                    count: highlights.count,
                                    isExpanded: expandedFolders.contains(SpecialFolder.highlights.rawValue),
                                    onToggle: {
                                        toggleSpecialFolder(.highlights)
                                    }
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        clearAllHighlights()
                                    } label: {
                                        Label("Excluir Todos os Destaques", systemImage: "trash")
                                    }
                                    .disabled(highlights.isEmpty)
                                }
                                
                                if expandedFolders.contains(SpecialFolder.highlights.rawValue) {
                                    ForEach(groupedHighlights, id: \.key) { postId, postHighlights in
                                        if let post = getPost(byId: postId) {
                                            PostFileRow(
                                                post: post,
                                                hasHighlights: true,
                                                highlightPreview: postHighlights.first?.highlightedText,
                                                onTap: {
                                                    selectedPost = post
                                                    selectedHighlights = postHighlights
                                                }
                                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteHighlightsForPost(postId: postId)
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                            }
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    deleteHighlightsForPost(postId: postId)
                                                } label: {
                                                    Label("Excluir Todos os Destaques", systemImage: "trash")
                                }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
    @ViewBuilder
    private var notesSection: some View {
                        if !notes.isEmpty {
                            Section {
                                SpecialFolderRow(
                                    name: "Anotações",
                                    icon: "note.text",
                                    color: "#FF9500",
                                    count: notes.count,
                                    isExpanded: expandedFolders.contains(SpecialFolder.notes.rawValue),
                                    onToggle: {
                                        toggleSpecialFolder(.notes)
                                    }
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        clearAllNotes()
                                    } label: {
                                        Label("Excluir Todas as Anotações", systemImage: "trash")
                                    }
                                    .disabled(notes.isEmpty)
                                }
                                
                                if expandedFolders.contains(SpecialFolder.notes.rawValue) {
                                    ForEach(notes) { note in
                                        if let post = getPost(byId: note.postId) {
                                            PostFileRow(
                                                post: post,
                                                hasNote: true,
                                                onTap: {
                                                    selectedPost = post
                                                }
                                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteNotesForPost(postId: note.postId)
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                            }
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    deleteNotesForPost(postId: note.postId)
                                                } label: {
                                                    Label("Excluir Todas as Anotações", systemImage: "trash")
                                }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
    @ViewBuilder
    private var userFoldersSection: some View {
        Section {
            if folders.isEmpty {
                Button {
                    showingAddFolder = true
                } label: {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                            .foregroundStyle(.blue)
                        Text("Criar Primeira Pasta")
                            .foregroundStyle(.blue)
                    }
                }
            } else {
                                ForEach(folders) { folder in
                                    UserFolderRow(
                                        name: folder.name,
                                        icon: folder.icon,
                                        color: folder.colorHex,
                                        count: folder.postCount,
                                        isExpanded: expandedFolders.contains(folder.id.uuidString),
                                        isEditMode: isEditMode,
                                        isSelected: selectedFolderIds.contains(folder.id),
                                        onToggle: {
                                            if isEditMode {
                                                toggleSelection(folder.id)
                                            } else {
                                                toggleUserFolder(folder.id)
                                            }
                                        }
                                    )
                                    .contextMenu {
                                        Button {
                                            clearFolder(folder)
                                        } label: {
                                            Label("Limpar Tudo", systemImage: "trash.slash")
                                        }
                                        .disabled(folder.postIds.isEmpty)
                                        
                                        Divider()
                                        
                                        Button(role: .destructive) {
                                            deleteFolder(folder)
                                        } label: {
                                            Label("Excluir Pasta", systemImage: "trash")
                                        }
                                    }
                                    
                                    if expandedFolders.contains(folder.id.uuidString) {
                                        ForEach(getPostsInFolder(folder)) { post in
                                            PostFileRow(
                                                post: post,
                                                onTap: {
                                                    selectedPost = post
                                                }
                                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    removePostFromFolder(post, folder: folder)
                                } label: {
                                    Label("Remover", systemImage: "folder.badge.minus")
                                }
                            }
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    removePostFromFolder(post, folder: folder)
                                                } label: {
                                                    Label("Remover da Pasta", systemImage: "folder.badge.minus")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
        } header: {
            HStack {
                Text("Minhas Pastas")
                Spacer()
                if !folders.isEmpty {
                    Button {
                        showingAddFolder = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                            .imageScale(.medium)
                }
            }
            }
        }
    }
    
    private var editModeButton: some View {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isEditMode.toggle()
                            if !isEditMode {
                                selectedFolderIds.removeAll()
                            }
                        }
                    } label: {
            Image(systemName: isEditMode ? "checkmark.circle.fill" : "slider.horizontal.3")
                .font(.title2)
                        .foregroundColor(.white)
                .frame(width: 56, height: 56)
                        .background {
                    Circle()
                                .fill(isEditMode ? Color.green : Color.blue)
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .accessibilityLabel(isEditMode ? "Concluir edição" : "Entrar no modo de edição")
    }
    
    private var emptyState: some View {
        EmptyLibraryView(onCreateFolder: { showingAddFolder = true })
            }
    
    // MARK: - Computed Properties
    
    private var groupedHighlights: [(key: String, value: [Highlight])] {
        Dictionary(grouping: highlights, by: { $0.postId })
            .sorted { $0.key < $1.key }
    }
    
    private var uniqueLikedPosts: [PostRequest] {
        var seen: Set<String> = []
        return viewModel.likedList.filter { post in
            guard let id = post.id, !id.isEmpty else { return false }
            if seen.contains(id) {
                return false
            }
            seen.insert(id)
            return true
        }
    }
    
    // MARK: - Actions
    
    private func toggleSpecialFolder(_ folder: SpecialFolder) {
        withAnimation {
            if expandedFolders.contains(folder.rawValue) {
                expandedFolders.remove(folder.rawValue)
            } else {
                expandedFolders.insert(folder.rawValue)
            }
        }
    }
    
    private func toggleUserFolder(_ id: UUID) {
        withAnimation {
            let idString = id.uuidString
            if expandedFolders.contains(idString) {
                expandedFolders.remove(idString)
            } else {
                expandedFolders.insert(idString)
            }
        }
    }
    
    private func getPost(byId id: String) -> PostRequest? {
        if let post = viewModel.readLaterList.first(where: { $0.id == id || $0.stableKey == id }) {
            return post
        }
        if let post = viewModel.likedList.first(where: { $0.id == id || $0.stableKey == id }) {
            return post
        }
        if let post = viewModel.content.first(where: { $0.id == id || $0.stableKey == id }) {
            return post
        }
        if let savedPost = savedPosts.first(where: { $0.id == id }) {
            return savedPost.toPostRequest()
        }
        if let highlight = highlights.first(where: { $0.postId == id }) {
            return PostRequest.fromLibraryReference(id: id, title: highlight.postTitle)
        }
        if let note = notes.first(where: { $0.postId == id }) {
            return PostRequest.fromLibraryReference(id: id, title: note.postTitle)
        }
        return nil
    }
    
    private func getPostsInFolder(_ folder: Folder) -> [PostRequest] {
        return folder.postIds.compactMap { postId in
            getPost(byId: postId)
        }
    }
    
    private func deleteFolder(_ folder: Folder) {
        withAnimation {
            modelContext.delete(folder)
        }
        
        NotificationCenter.default.post(name: .foldersUpdated, object: nil)
    }
    
    private func clearFolder(_ folder: Folder) {
        withAnimation {
            folder.postIds.removeAll()
        }
    }
    
    private func removePostFromFolder(_ post: PostRequest, folder: Folder) {
        let postId = post.stableKey
        withAnimation {
            folder.postIds.removeAll { $0 == postId || $0 == post.id }
        }
    }
    
    private func deleteHighlightsForPost(postId: String) {
        withAnimation {
            let highlightsToDelete = highlights.filter { $0.postId == postId }
            for highlight in highlightsToDelete {
                modelContext.delete(highlight)
            }
        }
    }
    
    private func deleteNotesForPost(postId: String) {
        withAnimation {
            let notesToDelete = notes.filter { $0.postId == postId }
            for note in notesToDelete {
                modelContext.delete(note)
            }
        }
    }
    
    private func clearAllLiked() {
        withAnimation {
            viewModel.clearAllLikedContent()
        }
    }
    
    private func clearAllReadLater() {
        withAnimation {
            viewModel.clearAllReadLater()
        }
    }
    
    private func clearAllHighlights() {
        withAnimation {
            for highlight in highlights {
                modelContext.delete(highlight)
            }
        }
    }
    
    private func clearAllNotes() {
        withAnimation {
            for note in notes {
                modelContext.delete(note)
            }
        }
    }
    
    private func toggleSelection(_ folderId: UUID) {
        withAnimation {
        if selectedFolderIds.contains(folderId) {
            selectedFolderIds.remove(folderId)
        } else {
            selectedFolderIds.insert(folderId)
            }
        }
    }
    
    private func deleteSelectedFolders() {
        withAnimation {
            for folderId in selectedFolderIds {
                if let folder = folders.first(where: { $0.id == folderId }) {
                    modelContext.delete(folder)
                }
            }
            selectedFolderIds.removeAll()
        }
    }
    
    private func clearSelectedFolders() {
        withAnimation {
            for folderId in selectedFolderIds {
                if let folder = folders.first(where: { $0.id == folderId }) {
                    folder.postIds.removeAll()
                }
            }
            selectedFolderIds.removeAll()
        }
    }
}

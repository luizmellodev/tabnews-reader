//
//  PostRow.swift
//  newtabnews
//
//  Created by Luiz Mello on 31/03/25.
//

import SwiftUI
import SwiftData

struct PostRow: View {
    @Environment(MainViewModel.self) var viewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [Folder]
    
    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme
    
    let post: PostRequest
    var zoomNamespace: Namespace.ID
    @State private var showingFolderPicker = false

    var body: some View {
        NavigationLink {
            destinationView
        } label: {
            CardList(post: post)
        }
        .postZoomSource(id: post.zoomTransitionID, namespace: zoomNamespace)
        .contextMenu {
            Button {
                let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                impactHeavy.impactOccurred()
                
                if viewModel.likedList.contains(where: { $0.title == post.title }) {
                    viewModel.removeContentList(content: post)
                } else {
                    viewModel.likeContentList(content: post)
                }
            } label: {
                Label(
                    viewModel.likedList.contains(where: { $0.title == post.title }) ? "Descurtir" : "Curtir",
                    systemImage: viewModel.likedList.contains(where: { $0.title == post.title }) ? "heart.slash" : "heart"
                )
            }
            .accessibilityLabel(viewModel.likedList.contains(where: { $0.title == post.title }) ? "Remover dos curtidos" : "Adicionar aos curtidos")
            
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                withAnimation(.spring(response: 0.3)) {
                    ReadLaterActions.toggle(post: post, viewModel: viewModel)
                }
            } label: {
                Label(
                    viewModel.isReadLater(post) ? "Remover de Ler Depois" : "Ler Depois",
                    systemImage: viewModel.isReadLater(post) ? "bookmark.slash" : "bookmark"
                )
            }
            
            Button {
                TextToSpeechManager.shared.speak(text: post.body ?? "", title: post.title)
            } label: {
                Label("Ouvir Post", systemImage: "speaker.wave.2")
            }
            .accessibilityLabel("Ouvir post usando síntese de voz")
            
            Button {
                showingFolderPicker = true
            } label: {
                Label("Salvar em Pasta", systemImage: "folder.badge.plus")
            }
            .accessibilityLabel("Salvar post em uma pasta")
        }
        .sheet(isPresented: $showingFolderPicker) {
            FolderPickerSheet(post: post, folders: folders, modelContext: modelContext)
                .id(post.id ?? UUID().uuidString)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var destinationView: some View {
        if isViewInApp {
            ListDetailView(
                isViewInApp: $isViewInApp,
                currentTheme: $currentTheme,
                post: post
            )
            .environment(viewModel)
            .postZoomDestination(id: post.zoomTransitionID, namespace: zoomNamespace)
        } else {
            WebContentView(content: post)
        }
    }
}

// Sheet para escolher pasta
struct FolderPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let post: PostRequest
    let folders: [Folder]
    let modelContext: ModelContext
    @Query private var savedPosts: [SavedPost]
    
    @State private var showingNewFolderSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                if folders.isEmpty {
                    ContentUnavailableView(
                        "Nenhuma pasta",
                        systemImage: "folder.badge.plus",
                        description: Text("Crie sua primeira pasta para organizar posts")
                    )
                } else {
                    ForEach(folders) { folder in
                        Button {
                            saveToFolder(folder)
                        } label: {
                            HStack {
                                Image(systemName: folder.icon)
                                    .foregroundColor(Color(hex: folder.colorHex))
                                
                                VStack(alignment: .leading) {
                                    Text(folder.name)
                                        .foregroundColor(.primary)
                                    
                                    Text("\(folder.postCount) posts")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if let postId = post.id, !postId.isEmpty, folder.postIds.contains(postId) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Salvar em Pasta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewFolderSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewFolderSheet) {
                AddFolderSheet()
            }
        }
    }
    
    private func saveToFolder(_ folder: Folder) {
        guard let postId = post.id, !postId.isEmpty else {
            print("⚠️ Tentativa de salvar post sem ID válido. Título: \(post.title ?? "sem título")")
            dismiss()
            return
        }
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        let wasInFolder = folder.postIds.contains(postId)
        
        if wasInFolder {
            folder.removePost(postId)
        } else {
            folder.addPost(postId)
            
            if !savedPosts.contains(where: { $0.id == postId }) {
                let savedPost = SavedPost(from: post)
                modelContext.insert(savedPost)
            }
        }
        
        dismiss()
    }
}

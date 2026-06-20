//
//  PostCTAView.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/12/25.
//

import SwiftUI
import SwiftData

struct PostCTAView: View {
    @Environment(MainViewModel.self) var viewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [Folder]
    
    let post: PostRequest
    @State private var showingFolderPicker = false
    
    private var isLiked: Bool {
        viewModel.likedList.contains(where: { $0.id == post.id })
    }
    
    private var isReadLater: Bool {
        viewModel.isReadLater(post)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.vertical, 8)
            
            // Texto minimalista
            HStack(spacing: 6) {
                Text("Gostou do post?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Link(destination: URL(string: "https://www.tabnews.com.br/\(post.ownerUsername ?? "")/\(post.slug ?? "")")!) {
                    HStack(spacing: 4) {
                        Text("Dê upvote no TabNews")
                            .font(.subheadline)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }
            
            // Botões minimalistas (inline)
            HStack(spacing: 12) {
                // Ler depois
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.3)) {
                        ReadLaterActions.toggle(post: post, viewModel: viewModel)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isReadLater ? "bookmark.fill" : "bookmark")
                            .font(.subheadline)
                        Text(isReadLater ? "Salvo" : "Ler depois")
                            .font(.subheadline)
                    }
                    .foregroundStyle(isReadLater ? .blue : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                // Salvar em pasta
                Button {
                    showingFolderPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                            .font(.subheadline)
                        Text("Pasta")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                // Curtir
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    
                    if isLiked {
                        viewModel.removeContentList(content: post)
                    } else {
                        viewModel.likeContentList(content: post)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.subheadline)
                        Text(isLiked ? "Curtido" : "Curtir")
                            .font(.subheadline)
                    }
                    .foregroundStyle(isLiked ? .red : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 12)
        .sheet(isPresented: $showingFolderPicker) {
            FolderPickerSheet(post: post, folders: folders, modelContext: modelContext)
                .id(post.id ?? UUID().uuidString)
        }
    }
}


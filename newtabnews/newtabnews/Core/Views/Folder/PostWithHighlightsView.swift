//
//  PostWithHighlightsView.swift
//  newtabnews
//
//  Created by Luiz Mello on 19/11/25.
//

import SwiftUI
import SwiftData

struct PostWithHighlightsView: View {
    let post: PostRequest
    let highlights: [Highlight]
    
    @Environment(\.dismiss) private var dismiss
    @Query private var notes: [Note]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background")
                    .ignoresSafeArea()
                Image("ruido")
                    .resizable()
                    .scaledToFill()
                    .blendMode(.overlay)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Título
                        Text(post.title ?? "Sem título")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                            .padding(.top, 60)
                        
                        // Metadata
                        HStack {
                            Text(post.ownerUsername ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("\(post.tabcoins ?? 0) tabcoins")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Highlights
                        if !highlights.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Destaques", systemImage: "highlighter")
                                    .font(.headline)
                                    .foregroundStyle(.yellow)
                                    .padding(.horizontal)
                                
                                ForEach(highlights) { highlight in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(highlight.highlightedText)
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(hex: highlight.colorHex).opacity(0.3))
                                            .cornerRadius(8)
                                        
                                        if let note = highlight.note, !note.isEmpty {
                                            HStack(spacing: 6) {
                                                Image(systemName: "note.text")
                                                    .font(.caption)
                                                Text(note)
                                                    .font(.caption)
                                            }
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 4)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                        
                        // Anotações
                        if let note = postNotes.first {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Anotações", systemImage: "note.text")
                                    .font(.headline)
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal)
                                
                                Text(note.content)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                        
                        // Conteúdo do post
                        Divider()
                            .padding(.horizontal)
                        
                        HybridMarkdownView(
                            markdown: post.body ?? "Sem conteúdo",
                            postId: post.stableKey,
                            highlights: highlights,
                            isHighlightMode: false,
                            onHighlight: { _, _ in },
                            onRemoveHighlight: { _ in }
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                    .padding(.top)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
    }
    
    private var postNotes: [Note] {
        notes.filter { $0.postId == post.stableKey }
    }
}


//
//  PostActionsBar.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/12/25.
//

import SwiftUI
import SwiftData

struct PostActionsBar: View {
    @Environment(MainViewModel.self) var viewModel
    
    let post: PostRequest
    let postHighlights: [Highlight]
    @Binding var isHighlightMode: Bool
    @Binding var showingAddNote: Bool
    @Binding var showAudioControls: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            HighlightButton(
                isHighlightMode: $isHighlightMode,
                highlightsCount: postHighlights.count
            )
            
            NoteButton(showingAddNote: $showingAddNote)
            
            ReadLaterButton(post: post)
            
            LikeButton(post: post, viewModel: viewModel)
            
            Spacer()
            
            AudioButton(showAudioControls: $showAudioControls)
        }
        .padding(.bottom, 4)
    }
}

struct HighlightButton: View {
    @Binding var isHighlightMode: Bool
    let highlightsCount: Int
    
    var body: some View {
        Button {
            withAnimation {
                isHighlightMode.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isHighlightMode ? "checkmark.circle.fill" : "highlighter")
                if isHighlightMode {
                    Text("Concluir")
                        .font(.caption)
                } else if highlightsCount > 0 {
                    Text("\(highlightsCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                } else {
                    Text("Destacar")
                        .font(.caption)
                }
            }
            .foregroundColor(isHighlightMode ? .green : (highlightsCount == 0 ? .yellow : .orange))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background((isHighlightMode ? Color.green : (highlightsCount == 0 ? Color.yellow : Color.orange)).opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct NoteButton: View {
    @Binding var showingAddNote: Bool
    
    var body: some View {
        Button {
            showingAddNote = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "note.text.badge.plus")
                Text("Anotar")
                    .font(.caption)
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct ReadLaterButton: View {
    @Environment(MainViewModel.self) private var viewModel
    
    let post: PostRequest
    
    private var isSaved: Bool {
        viewModel.isReadLater(post)
    }
    
    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            withAnimation(.spring(response: 0.3)) {
                ReadLaterActions.toggle(post: post, viewModel: viewModel)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                Text(isSaved ? "Salvo" : "Depois")
                    .font(.caption)
            }
            .foregroundColor(isSaved ? .blue : .gray)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSaved ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .accessibilityLabel(isSaved ? "Remover de ler depois" : "Salvar para ler depois")
    }
}

struct LikeButton: View {
    let post: PostRequest
    let viewModel: MainViewModel
    
    private var isLiked: Bool {
        viewModel.likedList.contains(where: { $0.title == post.title })
    }
    
    var body: some View {
        Button {
            let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
            impactHeavy.impactOccurred()
            
            if isLiked {
                viewModel.removeContentList(content: post)
            } else {
                viewModel.likeContentList(content: post)
            }
        } label: {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .foregroundColor(isLiked ? .red : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct AudioButton: View {
    @Binding var showAudioControls: Bool
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showAudioControls.toggle()
            }
        } label: {
            Image(systemName: showAudioControls ? "speaker.wave.2.fill" : "speaker.wave.2")
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(showAudioControls ? 0.2 : 0.1))
                .cornerRadius(8)
        }
    }
}

// MARK: - Toast

struct ToastMessage: Equatable {
    let text: String
    let icon: String
}

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: ToastMessage?
    
    private var dismissTask: Task<Void, Never>?
    
    private init() {}
    
    func show(text: String, icon: String = "checkmark.circle.fill") {
        dismissTask?.cancel()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentToast = ToastMessage(text: text, icon: icon)
        }
        
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                if currentToast?.text == text {
                    currentToast = nil
                }
            }
        }
    }
}

struct ToastBanner: View {
    let message: ToastMessage
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: message.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
            
            Text(message.text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

enum ReadLaterActions {
    @discardableResult
    static func toggle(post: PostRequest, viewModel: MainViewModel) -> ReadLaterResult {
        let result = viewModel.toggleReadLater(content: post)
        
        switch result {
        case .added:
            Task { @MainActor in
                ToastManager.shared.show(text: "Adicionado à leitura", icon: "bookmark.fill")
            }
        case .removed:
            Task { @MainActor in
                ToastManager.shared.show(text: "Removido de Ler Depois", icon: "bookmark.slash")
            }
        }
        
        return result
    }
}


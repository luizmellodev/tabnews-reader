//
//  CommentsViewModel.swift
//  newtabnews
//
//  Created by Luiz Mello on 04/01/26.
//

import Foundation
import SwiftUI

@Observable
class CommentsViewModel {
    private let service: ContentServiceProtocol
    
    var comments: [Comment] = []
    var state: DefaultViewState = .started
    var errorMessage: String?
    
    init(service: ContentServiceProtocol = ContentService()) {
        self.service = service
    }
    
    @MainActor
    func fetchComments(user: String, slug: String) async {
        self.state = .loading
        
        do {
            let fetchedComments = try await service.getComments(user: user, slug: slug)
            self.comments = fetchedComments
            self.state = .requestSucceeded
            
            print("✅ [CommentsViewModel] Carregados \(fetchedComments.count) comentários")
        } catch {
            self.state = .requestFailed
            self.errorMessage = error.localizedDescription
            print("❌ [CommentsViewModel] Erro ao carregar comentários: \(error)")
        }
    }
    
    @MainActor
    func refresh(user: String, slug: String) async {
        await fetchComments(user: user, slug: slug)
    }
    
    // Helper para contar total de comentários (incluindo respostas)
    func totalCommentsCount() -> Int {
        return countComments(in: comments)
    }
    
    /// IDs dos comentários ancestrais (para expandir a thread até um comentário).
    func ancestorIds(for commentId: String?) -> Set<String> {
        guard let commentId else { return [] }
        var ancestors: Set<String> = []
        
        func search(_ items: [Comment], path: [String]) -> Bool {
            for item in items {
                let currentPath = path + (item.id.map { [$0] } ?? [])
                
                if item.id == commentId {
                    ancestors = Set(path)
                    return true
                }
                
                if let children = item.children, search(children, path: currentPath) {
                    return true
                }
            }
            return false
        }
        
        search(comments, path: [])
        return ancestors
    }
    
    /// IDs que precisam estar expandidos para exibir um comentário e suas respostas.
    func threadIdsToExpand(for comment: Comment) -> Set<String> {
        var ids = ancestorIds(for: comment.id)
        if let id = comment.id {
            ids.insert(id)
        }
        return ids
    }
    
    private func countComments(in comments: [Comment]) -> Int {
        var count = comments.count
        for comment in comments {
            if let children = comment.children {
                count += countComments(in: children)
            }
        }
        return count
    }
}


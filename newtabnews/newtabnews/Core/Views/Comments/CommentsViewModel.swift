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
    var threadItems: [CommentThreadItem] = []
    var rootParentID: String = ""
    var state: DefaultViewState = .started
    var errorMessage: String?
    
    init(service: ContentServiceProtocol = ContentService()) {
        self.service = service
    }
    
    @MainActor
    func fetchComments(user: String, slug: String, postId: String) async {
        self.state = .loading
        
        do {
            let fetchedComments = try await service.getComments(user: user, slug: slug)
            let thread = CommentTreeBuilder.buildThread(
                from: fetchedComments,
                fallbackRootParentID: postId
            )
            self.rootParentID = thread.rootParentID
            self.threadItems = thread.items
            self.comments = thread.items.filter { $0.depth == 0 }.map(\.comment)
            self.state = .requestSucceeded
            
            print("✅ [CommentsViewModel] \(self.comments.count) comentários raiz (postId: \(thread.rootParentID.prefix(8))…)")
            for item in thread.items {
                print("   depth=\(item.depth) @\(item.comment.ownerUsername ?? "?")")
            }
        } catch {
            self.state = .requestFailed
            self.errorMessage = error.localizedDescription
            print("❌ [CommentsViewModel] Erro ao carregar comentários: \(error)")
        }
    }
    
    @MainActor
    func refresh(user: String, slug: String, postId: String) async {
        await fetchComments(user: user, slug: slug, postId: postId)
    }
    
    func totalCommentsCount() -> Int {
        threadItems.count
    }
    
    func visibleThreadItems(isExpanded: Bool, previewCount: Int) -> [CommentThreadItem] {
        guard !isExpanded else { return threadItems }
        
        let previewRootIDs = Set(comments.prefix(previewCount).compactMap(\.id))
        guard !previewRootIDs.isEmpty else { return [] }
        
        return threadItems.filter { item in
            rootAncestorID(for: item, among: previewRootIDs) != nil
        }
    }
    
    /// IDs dos comentários ancestrais (para expandir a thread até um comentário).
    func ancestorIds(for commentId: String?) -> Set<String> {
        guard let commentId else { return [] }
        
        var ancestors: Set<String> = []
        var currentParentID = threadItems.first(where: { $0.id == commentId })?.comment.parentID
        
        while let parentID = currentParentID,
              let parentItem = threadItems.first(where: { $0.id == parentID }) {
            ancestors.insert(parentID)
            currentParentID = parentItem.comment.parentID
        }
        
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
    
    private func rootAncestorID(for item: CommentThreadItem, among previewRootIDs: Set<String>) -> String? {
        if item.depth == 0 {
            return previewRootIDs.contains(item.id) ? item.id : nil
        }
        
        var currentParentID = item.comment.parentID
        
        while let parentID = currentParentID {
            if previewRootIDs.contains(parentID) {
                return parentID
            }
            currentParentID = threadItems.first(where: { $0.id == parentID })?.comment.parentID
        }
        
        return nil
    }
}

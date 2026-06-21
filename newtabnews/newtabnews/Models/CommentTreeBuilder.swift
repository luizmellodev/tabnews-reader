//
//  CommentTreeBuilder.swift
//  newtabnews
//
//  Created by Luiz Mello on 20/06/26.
//

import Foundation

struct CommentThreadItem: Identifiable, Hashable {
    let id: String
    let comment: Comment
    /// Profundidade visual: 0 = comentário no array raiz da API, 1+ = dentro de `children`.
    let depth: Int
}

enum CommentTreeBuilder {
    static func buildThread(
        from comments: [Comment],
        fallbackRootParentID: String
    ) -> (rootParentID: String, items: [CommentThreadItem]) {
        let flattened = flattenUniquePreservingStructure(comments)
        let flatComments = flattened.map(\.comment)
        let rootParentID = resolveRootParentID(from: flatComments, fallback: fallbackRootParentID)

        let items = flattened.compactMap { entry -> CommentThreadItem? in
            guard let id = entry.comment.id else { return nil }
            return CommentThreadItem(id: id, comment: entry.comment, depth: entry.depth)
        }

        return (rootParentID, items)
    }

    /// O post raiz é o `parent_id` que não corresponde ao `id` de nenhum comentário.
    static func resolveRootParentID(from flatComments: [Comment], fallback: String) -> String {
        let commentIDs = Set(flatComments.compactMap(\.id))

        if let postID = flatComments
            .compactMap(\.parentID)
            .first(where: { !commentIDs.contains($0) }) {
            return postID
        }

        return fallback
    }

    /// Achata a árvore mantendo a profundidade da estrutura JSON da API.
    /// Comentários irmãos no array raiz ficam todos em depth 0.
    private static func flattenUniquePreservingStructure(_ comments: [Comment]) -> [(comment: Comment, depth: Int)] {
        var seen = Set<String>()
        var result: [(comment: Comment, depth: Int)] = []

        func walk(_ items: [Comment], depth: Int) {
            for var item in items {
                guard let id = item.id, !seen.contains(id) else { continue }
                seen.insert(id)

                let nested = item.children
                item.children = nil
                result.append((item, depth))

                if let nested {
                    walk(nested, depth: depth + 1)
                }
            }
        }

        walk(comments, depth: 0)
        return result
    }
}

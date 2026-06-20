//
//  SavedPost.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/12/25.
//

import Foundation
import SwiftData
import SwiftData

@Model
final class SavedPost {
    var id: String
    var ownerId: String?
    var parentId: String?
    var slug: String?
    var title: String?
    var body: String?
    var status: String?
    var type: String?
    var sourceUrl: String?
    var createdAt: String?
    var updatedAt: String?
    var publishedAt: String?
    var deletedAt: String?
    var ownerUsername: String?
    var tabcoins: Int?
    var tabcoinsCredit: Int?
    var tabcoinsDebit: Int?
    var childrenDeepCount: Int?
    var savedDate: Date
    var isReadLater: Bool
    var readLaterDate: Date?
    
    init(from post: PostRequest) {
        self.id = post.stableKey
        self.ownerId = post.ownerId
        self.parentId = post.parentId
        self.slug = post.slug
        self.title = post.title
        self.body = post.body
        self.status = post.status
        self.type = post.type
        self.sourceUrl = post.sourceUrl
        self.createdAt = post.createdAt
        self.updatedAt = post.updatedAt
        self.publishedAt = post.publishedAt
        self.deletedAt = post.deletedAt
        self.ownerUsername = post.ownerUsername
        self.tabcoins = post.tabcoins
        self.tabcoinsCredit = post.tabcoinsCredit
        self.tabcoinsDebit = post.tabcoinsDebit
        self.childrenDeepCount = post.childrenDeepCount
        self.savedDate = Date()
        self.isReadLater = false
        self.readLaterDate = nil
    }
    
    func toPostRequest() -> PostRequest {
        return PostRequest(
            id: id,
            ownerId: ownerId,
            parentId: parentId,
            slug: slug,
            title: title,
            body: body,
            status: status,
            type: type,
            sourceUrl: sourceUrl,
            createdAt: createdAt,
            updatedAt: updatedAt,
            publishedAt: publishedAt,
            deletedAt: deletedAt,
            ownerUsername: ownerUsername,
            tabcoins: tabcoins,
            tabcoinsCredit: tabcoinsCredit,
            tabcoinsDebit: tabcoinsDebit,
            childrenDeepCount: childrenDeepCount
        )
    }
    
    func update(from post: PostRequest) {
        slug = post.slug
        title = post.title
        if let body = post.body, !body.isEmpty {
            self.body = body
        }
        ownerUsername = post.ownerUsername
        ownerId = post.ownerId
        createdAt = post.createdAt
        tabcoins = post.tabcoins
    }
}

extension PostRequest {
    static func fromLibraryReference(id: String, title: String?) -> PostRequest {
        if id.contains("/") {
            let parts = id.split(separator: "/", maxSplits: 1)
            let owner = String(parts[0])
            let slug = parts.count > 1 ? String(parts[1]) : nil
            
            return PostRequest(
                id: nil,
                ownerId: nil,
                parentId: nil,
                slug: slug,
                title: title,
                body: nil,
                status: nil,
                type: nil,
                sourceUrl: nil,
                createdAt: nil,
                updatedAt: nil,
                publishedAt: nil,
                deletedAt: nil,
                ownerUsername: owner,
                tabcoins: nil,
                tabcoinsCredit: nil,
                tabcoinsDebit: nil,
                childrenDeepCount: nil
            )
        }
        
        return PostRequest(
            id: id,
            ownerId: nil,
            parentId: nil,
            slug: nil,
            title: title,
            body: nil,
            status: nil,
            type: nil,
            sourceUrl: nil,
            createdAt: nil,
            updatedAt: nil,
            publishedAt: nil,
            deletedAt: nil,
            ownerUsername: nil,
            tabcoins: nil,
            tabcoinsCredit: nil,
            tabcoinsDebit: nil,
            childrenDeepCount: nil
        )
    }
}

extension ModelContext {
    func upsertSavedPost(from post: PostRequest) {
        let key = post.stableKey
        let descriptor = FetchDescriptor<SavedPost>(
            predicate: #Predicate { $0.id == key }
        )
        
        if let existing = try? fetch(descriptor).first {
            existing.update(from: post)
        } else {
            insert(SavedPost(from: post))
        }
        
        try? save()
    }
}


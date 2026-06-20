//
//  SavedPost.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/12/25.
//

import Foundation
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
}


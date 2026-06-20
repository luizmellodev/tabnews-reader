//
//  PostRequest.swift
//  newtabnews
//
//  Created by Luiz Mello on 27/03/25.
//

import Foundation

struct PostRequest: Codable, Identifiable, Hashable {
    let id: String?
    let ownerId: String?
    let parentId: String?
    let slug: String?
    let title: String?
    var body: String?
    let status: String?
    let type: String?
    let sourceUrl: String?
    let createdAt: String?
    let updatedAt: String?
    let publishedAt: String?
    let deletedAt: String?
    let ownerUsername: String?
    let tabcoins: Int?
    let tabcoinsCredit: Int?
    let tabcoinsDebit: Int?
    let childrenDeepCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case parentId = "parent_id"
        case slug
        case title
        case body
        case status
        case type
        case sourceUrl = "source_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case publishedAt = "published_at"
        case deletedAt = "deleted_at"
        case ownerUsername = "owner_username"
        case tabcoins
        case tabcoinsCredit = "tabcoins_credit"
        case tabcoinsDebit = "tabcoins_debit"
        case childrenDeepCount = "children_deep_count"
    }
}

extension PostRequest {
    /// Identificador estável para persistência local quando `id` da API não está disponível.
    var stableKey: String {
        if let id, !id.isEmpty { return id }
        if let ownerUsername, let slug, !slug.isEmpty {
            return "\(ownerUsername)/\(slug)"
        }
        if let title, !title.isEmpty { return "title:\(title)" }
        return UUID().uuidString
    }
}

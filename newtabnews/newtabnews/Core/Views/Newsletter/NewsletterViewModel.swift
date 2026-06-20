//
//  NewsletterViewModel.swift
//  newtabnews
//
//  Created by Luiz Mello on 11/03/25.
//

import Foundation
import SwiftUI

@Observable
class NewsletterViewModel: ObservableObject {
    private let service: ContentServiceProtocol
    private let lastSeenNewsletterIdKey = "lastSeenNewsletterId"
    
    var newsletter: [PostRequest] = []
    var state: DefaultViewState = .started
    var alreadyLoaded: Bool = false
    var unreadNewCount: Int = 0
    
    init(service: ContentServiceProtocol = ContentService()) {
        self.service = service
    }
    
    @MainActor
    func fetchNewsletterContent(showLoading: Bool = true) async {
        if showLoading {
            self.state = .loading
        }
        
        do {
            let allNewsletters = try await service.getNewsletter(page: "1", perPage: "15", strategy: "new")
            
            self.newsletter = allNewsletters.filter { newsletter in
                guard let title = newsletter.title, !title.isEmpty else {
                    return false
                }
                return true
            }
            
            self.state = .requestSucceeded
            self.alreadyLoaded = true
            updateUnreadCount()
        } catch {
            if showLoading || !alreadyLoaded {
                self.state = .requestFailed
            }
            print(error)
        }
    }
    
    @MainActor
    func refreshUnreadBadge() async {
        await fetchNewsletterContent(showLoading: false)
    }
    
    @MainActor
    func markNewslettersAsSeen() {
        guard let latestId = newsletter.first?.id, !latestId.isEmpty else { return }
        UserDefaults.standard.set(latestId, forKey: lastSeenNewsletterIdKey)
        unreadNewCount = 0
    }
    
    @MainActor
    func updateUnreadCount() {
        guard !newsletter.isEmpty else {
            unreadNewCount = 0
            return
        }
        
        guard let lastSeenId = UserDefaults.standard.string(forKey: lastSeenNewsletterIdKey),
              !lastSeenId.isEmpty else {
            unreadNewCount = newsletter.filter { Self.isCreatedToday(createdAt: $0.createdAt) }.count
            return
        }
        
        if let lastSeenIndex = newsletter.firstIndex(where: { $0.id == lastSeenId }) {
            unreadNewCount = lastSeenIndex
        } else {
            unreadNewCount = newsletter.filter { Self.isCreatedToday(createdAt: $0.createdAt) }.count
        }
    }
    
    static func isCreatedToday(createdAt: String?) -> Bool {
        guard let createdAtString = createdAt else { return false }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let createdDate = dateFormatter.date(from: createdAtString) else {
            return false
        }
        
        return Calendar.current.isDateInToday(createdDate)
    }
}

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
    /// Itens que chegaram desde a última visita. Fica guardado enquanto a aba está aberta,
    /// porque `markNewslettersAsSeen()` atualiza o último visto assim que a tela aparece.
    var unseenIds: Set<String> = []
    
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
        unseenIds.formUnion(currentlyUnseen().compactMap(\.id))
        UserDefaults.standard.set(latestId, forKey: lastSeenNewsletterIdKey)
        unreadNewCount = 0
    }
    
    @MainActor
    func markAsRead(_ newsletter: PostRequest) {
        guard let id = newsletter.id else { return }
        unseenIds.remove(id)
    }
    
    @MainActor
    func clearUnseenHighlights() {
        unseenIds.removeAll()
    }
    
    var sections: [NewsletterSection] {
        let calendar = Calendar.current
        var result: [NewsletterSection] = []
        
        for item in newsletter {
            let date = Self.parseDate(item.createdAt)
            let day = date.map { calendar.startOfDay(for: $0) }
            
            if let last = result.last, last.day == day {
                result[result.count - 1].items.append(item)
            } else {
                result.append(NewsletterSection(day: day, items: [item]))
            }
        }
        
        return result
    }
    
    /// Itens mais novos que o último visto salvo. Sem referência (primeira abertura
    /// ou último visto fora da página), considera os publicados hoje.
    private func currentlyUnseen() -> [PostRequest] {
        if let lastSeenId = UserDefaults.standard.string(forKey: lastSeenNewsletterIdKey),
           !lastSeenId.isEmpty,
           let lastSeenIndex = newsletter.firstIndex(where: { $0.id == lastSeenId }) {
            return Array(newsletter.prefix(lastSeenIndex))
        }
        return newsletter.filter { Self.isCreatedToday(createdAt: $0.createdAt) }
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
        guard let createdDate = parseDate(createdAt) else { return false }
        return Calendar.current.isDateInToday(createdDate)
    }
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return isoFormatter.date(from: value)
    }
}

struct NewsletterSection: Identifiable {
    /// Início do dia; `nil` agrupa itens sem data válida.
    let day: Date?
    var items: [PostRequest]
    
    var id: String { day.map { String($0.timeIntervalSince1970) } ?? "sem-data" }
    
    var title: String {
        guard let day else { return "Sem data" }
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Hoje" }
        if calendar.isDateInYesterday(day) { return "Ontem" }
        
        var style = Date.FormatStyle.dateTime
            .weekday(.abbreviated)
            .day()
            .month(.abbreviated)
            .locale(Locale(identifier: "pt_BR"))
        if !calendar.isDate(day, equalTo: Date(), toGranularity: .year) {
            style = style.year()
        }
        let text = day.formatted(style)
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

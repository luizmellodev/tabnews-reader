//
//  DiscoverService.swift
//  newtabnews
//

import Foundation

struct DiscoverSections: Codable, Equatable {
    let hero: PostRequest?
    let classics: [PostRequest]
    let worthReading: [PostRequest]
    let missed: [PostRequest]
    let cachedAt: Date
}

final class DiscoverService {
    private let contentService: ContentServiceProtocol
    private let defaults: UserDefaults

    init(
        contentService: ContentServiceProtocol = ContentService(),
        defaults: UserDefaults = .standard
    ) {
        self.contentService = contentService
        self.defaults = defaults
    }

    func loadSections(forceRefresh: Bool = false) async throws -> DiscoverSections {
        if !forceRefresh, let cached = loadCachedSections() {
            return cached
        }

        let seed = daySeed()
        let heroPage = (seed % 15) + 1
        let recentClassicPage = (seed % 40) + 60
        let missedPageA = (seed % 50) + 80
        let missedPageB = ((seed + 17) % 50) + 100

        async let heroPosts = fetchPage(strategy: "relevant", page: heroPage)
        async let classicAncient1 = fetchPage(strategy: "old", page: 1)
        async let classicAncient2 = fetchPage(strategy: "old", page: 2)
        async let classicAncient3 = fetchPage(strategy: "old", page: 3)
        async let classicRecentA = fetchPage(strategy: "new", page: recentClassicPage)
        async let classicRecentB = fetchPage(strategy: "new", page: recentClassicPage + 15)
        async let worthRelevant1 = fetchPage(strategy: "relevant", page: 1)
        async let worthRelevant2 = fetchPage(strategy: "relevant", page: (seed % 8) + 2)
        async let worthNew1 = fetchPage(strategy: "new", page: (seed % 20) + 10)
        async let worthNew2 = fetchPage(strategy: "new", page: (seed % 30) + 40)
        async let worthOld = fetchPage(strategy: "old", page: (seed % 100) + 20)
        async let missedPostsA = fetchPage(strategy: "new", page: missedPageA)
        async let missedPostsB = fetchPage(strategy: "new", page: missedPageB)

        let ancientClassicPool = try await classicAncient1 + classicAncient2 + classicAncient3
        let recentClassicPool = try await classicRecentA + classicRecentB
        let worthPool = try await worthRelevant1 + worthRelevant2 + worthNew1 + worthNew2 + worthOld
        let missedPool = try await missedPostsA + missedPostsB
        let surprisePool = try await heroPosts

        var usedKeys = Set<String>()

        // Clássicos: lendários antigos + destaques com pelo menos ~1 mês
        let classics: [PostRequest]
        (classics, usedKeys) = ancientClassicPool.topDiscoverPostsMixed(
            limit: 6,
            primaryLimit: 3,
            primary: (ancientClassicPool, minTabcoins: 12, minAgeDays: nil, maxAgeDays: nil),
            secondary: (recentClassicPool, minTabcoins: 8, minAgeDays: 30, maxAgeDays: nil),
            excluding: usedKeys
        )

        // Você pode ter perdido — antes de "Vale a pena ler" para não esvaziar o pool
        let missed: [PostRequest]
        (missed, usedKeys) = missedPool.topDiscoverPosts(
            limit: 6,
            minTabcoins: 4,
            minAgeDays: 14,
            maxAgeDays: 120,
            excluding: usedKeys
        )

        let resolvedMissed: [PostRequest]
        if missed.isEmpty {
            (resolvedMissed, usedKeys) = missedPool.topDiscoverPosts(
                limit: 6,
                minTabcoins: 3,
                minAgeDays: 7,
                maxAgeDays: 90,
                excluding: usedKeys
            )
        } else {
            resolvedMissed = missed
        }

        // Vale a pena ler: mais votados no geral — recentes e antigos, sem viés de idade
        let worthReading: [PostRequest]
        (worthReading, usedKeys) = worthPool.topDiscoverPosts(
            limit: 6,
            minTabcoins: 6,
            minAgeDays: 3,
            excluding: usedKeys
        )

        let hero = pickHero(from: surprisePool, seed: seed, excluding: usedKeys)

        let sections = DiscoverSections(
            hero: hero,
            classics: classics,
            worthReading: worthReading,
            missed: resolvedMissed,
            cachedAt: Date()
        )

        saveCachedSections(sections)
        return sections
    }

    // MARK: - Private

    private func fetchPage(strategy: String, page: Int) async throws -> [PostRequest] {
        try await contentService.getContent(
            page: String(page),
            perPage: "30",
            strategy: strategy
        )
    }

    private func daySeed() -> Int {
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let year = calendar.component(.year, from: Date())
        return (year * 366) + day
    }

    private func cacheKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "discover_cache_v4_\(formatter.string(from: Date()))"
    }

    private func loadCachedSections() -> DiscoverSections? {
        guard let data = defaults.data(forKey: cacheKey()) else { return nil }
        return try? JSONDecoder().decode(DiscoverSections.self, from: data)
    }

    private func saveCachedSections(_ sections: DiscoverSections) {
        guard let data = try? JSONEncoder().encode(sections) else { return }
        defaults.set(data, forKey: cacheKey())
    }

    private func pickHero(
        from posts: [PostRequest],
        seed: Int,
        excluding usedKeys: Set<String>
    ) -> PostRequest? {
        let candidates = posts
            .rootPostsOnly()
            .excludingKeys(usedKeys)

        guard !candidates.isEmpty else { return nil }

        let index = seed % candidates.count
        return candidates[index]
    }
}

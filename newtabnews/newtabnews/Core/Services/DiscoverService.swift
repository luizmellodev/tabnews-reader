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

    /// Seções salvas da última carga (de hoje ou de outro dia), para mostrar sem esperar a rede.
    func cachedSections() -> DiscoverSections? {
        if let memory = Self.memoryCache { return memory }
        guard let data = defaults.data(forKey: Self.cacheKey),
              let sections = try? JSONDecoder().decode(DiscoverSections.self, from: data) else { return nil }
        Self.memoryCache = sections
        return sections
    }

    /// O SwiftUI recria o ViewModel a cada init do SearchView; evita decodificar o JSON toda vez
    private nonisolated(unsafe) static var memoryCache: DiscoverSections?

    /// Busca as seções do dia na rede e salva no cache.
    /// Páginas que falham ficam de fora; só dá erro se nenhuma chegar.
    func fetchSections() async throws -> DiscoverSections {
        let seed = daySeed()

        // 7 páginas de 100 posts (antes eram 13 de 30): o RequestThrottler solta uma requisição
        // a cada 0,35s, então menos requisições é menos tempo de skeleton
        async let worthRelevant = fetchPage(strategy: "relevant", page: 1)
        // "relevant" tem só ~140 posts (2 páginas de 100); antes a página era sorteada até a 15
        // e vinha vazia na maioria dos dias, sumindo com a Surpresa do dia
        async let heroPosts = fetchPage(strategy: "relevant", page: 2)
        async let classicAncient = fetchPage(strategy: "old", page: 1)
        async let classicRecent = fetchPage(strategy: "new", page: (seed % 12) + 18)
        async let worthNew = fetchPage(strategy: "new", page: (seed % 10) + 3)
        async let worthOld = fetchPage(strategy: "old", page: (seed % 30) + 7)
        async let missedPosts = fetchPage(strategy: "new", page: (seed % 15) + 24)

        let pages = await [worthRelevant, heroPosts, classicAncient, classicRecent, worthNew, worthOld, missedPosts]
        guard pages.contains(where: { $0 != nil }) else {
            throw NetworkError.badServerResponse
        }

        let ancientClassicPool = pages[2] ?? []
        let recentClassicPool = pages[3] ?? []
        let worthPool = (pages[0] ?? []) + (pages[4] ?? []) + (pages[5] ?? [])
        let missedPool = pages[6] ?? []
        let surprisePool = (pages[0] ?? []) + (pages[1] ?? [])

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

    /// `nil` quando a página falha, para as outras seções continuarem
    private func fetchPage(strategy: String, page: Int) async -> [PostRequest]? {
        try? await contentService.getContent(
            page: String(page),
            perPage: "100",
            strategy: strategy
        )
    }

    private func daySeed() -> Int {
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let year = calendar.component(.year, from: Date())
        return (year * 366) + day
    }

    /// Uma chave só: antes era uma por dia e as antigas nunca eram apagadas
    private static let cacheKey = "discover_cache_v5"

    private func saveCachedSections(_ sections: DiscoverSections) {
        Self.memoryCache = sections
        guard let data = try? JSONEncoder().encode(sections) else { return }
        defaults.set(data, forKey: Self.cacheKey)

        // Limpa as chaves por dia das versões anteriores (discover_cache_v4_2026-10-21 etc.)
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("discover_cache_") && key != Self.cacheKey {
            defaults.removeObject(forKey: key)
        }
    }

    private func pickHero(
        from posts: [PostRequest],
        seed: Int,
        excluding usedKeys: Set<String>
    ) -> PostRequest? {
        // Sem Pitch: com "Ocultar Pitch" ligado a surpresa sumiria da tela
        let candidates = posts
            .rootPostsOnly()
            .excludingKeys(usedKeys)
            .filter { !PitchFilter.isPitch(title: $0.title) }

        guard !candidates.isEmpty else { return nil }

        let index = seed % candidates.count
        return candidates[index]
    }
}

//
//  MainViewModel.swift
//  newtabnews
//
//  Created by Luiz Mello on 22/07/23.
//

import Foundation


@Observable
class MainViewModel {
    
    private let service: ContentServiceProtocol
    var likedList: [PostRequest] = []
    var readLaterList: [PostRequest] = []
    var content: [PostRequest] = []
    var state: DefaultViewState = .loading
    var currentStrategy: ContentStrategy = .relevant
    
    var currentPage: Int = 1
    var isLoadingMore: Bool = false
    var hasMorePages: Bool = true
    /// Quantos Pitches o filtro tirou do feed carregado (mostrado na Home).
    var hiddenPitchCount: Int = 0
    private let postsPerPage: Int = 10
    /// Com o filtro de Pitch, uma página pode voltar quase vazia. Busca as seguintes
    /// até ter pelo menos isso de posts novos (ou até `maxExtraPages`).
    private let minimumVisiblePerFetch: Int = 5
    private let maxExtraPages: Int = 3
    private let maxCachedPages: Int = 5
    
    let defaults = UserDefaults.standard
    
    init(service: ContentServiceProtocol = ContentService()) {
        self.service = service
        getReadLaterContent()
    }
}

// MARK: - Fetch Functions
extension MainViewModel {
    
    @MainActor
    func fetchContent(showLoading: Bool? = nil) async {
        let shouldShowLoading = showLoading ?? content.isEmpty
        if shouldShowLoading {
            self.state = .loading
        }
        self.currentPage = 1
        self.hasMorePages = true
        
        do {
            let newPosts = try await fetchVisiblePosts(strategy: currentStrategy, excluding: [], resetHiddenCount: true)
            
            let previousContent = self.content
            self.content = mergePostsPreservingBodies(newPosts, existing: previousContent)
            self.state = .requestSucceeded
        } catch {
            if content.isEmpty {
                self.state = .requestFailed
            } else if state == .loading {
                // Falhou com conteúdo antigo na tela: volta a mostrá-lo em vez de ficar no skeleton
                self.state = .requestSucceeded
            }
            #if DEBUG
            print(error)
            #endif
        }
    }
    
    @MainActor
    func fetchContent(with strategy: ContentStrategy) async {
        let strategyChanged = self.currentStrategy != strategy
        self.currentStrategy = strategy

        if strategyChanged {
            self.currentPage = 1
            self.hasMorePages = true
            self.content = []
        }

        await fetchContent()
        await fetchPost()
    }

    @MainActor
    func reloadForStrategy(_ strategy: ContentStrategy) async {
        currentStrategy = strategy
        currentPage = 1
        hasMorePages = true
        content = []
        isLoadingMore = false
        state = .loading
        await fetchContent()
        await fetchPost()
    }
    
    @MainActor
    func fetchPost() async {
        let filled = await fetchBodies(for: content)
        let filledByKey = Dictionary(filled.map { ($0.stableKey, $0) }, uniquingKeysWith: { first, _ in first })

        // Aplica por chave (não por índice): o feed pode ter mudado durante os awaits (refresh, troca de estratégia)
        content = content.map { post in
            guard post.body?.isEmpty != false,
                  let full = filledByKey[post.stableKey],
                  full.body?.isEmpty == false else { return post }
            return full
        }

        saveCachedContent(page: currentPage)
        
        // Sincronizar com widgets
        WidgetSyncManager.shared.syncRecentPosts(content)
        
        // Sincronizar digest em background
        Task.detached(priority: .background) {
            await self.syncDigestForWidget()
        }
        
        NotificationCenter.default.post(name: .postsLoaded, object: nil)
    }
    
    /// Busca o corpo completo dos posts em paralelo, mantendo a ordem. Posts que falharem voltam como vieram.
    private func fetchBodies(for posts: [PostRequest]) async -> [PostRequest] {
        let service = self.service

        return await withTaskGroup(of: (Int, PostRequest?).self) { group in
            for (index, post) in posts.enumerated() where post.body?.isEmpty != false {
                guard let user = post.ownerUsername, let slug = post.slug else { continue }

                group.addTask {
                    do {
                        return (index, try await service.getPost(user: user, slug: slug))
                    } catch {
                        #if DEBUG
                        print("Erro ao buscar post [\(slug)]: \(error)")
                        #endif
                        return (index, nil)
                    }
                }
            }

            var result = posts
            for await (index, full) in group {
                if let full { result[index] = full }
            }
            return result
        }
    }

    /// Busca `currentPage` já sem os Pitches (antes de baixar o texto dos posts) e, se sobrar pouco,
    /// avança para as próximas páginas. Atualiza `currentPage` e `hasMorePages`.
    /// Só a primeira página propaga erro; falha numa página extra só encerra a busca.
    @MainActor
    private func fetchVisiblePosts(
        strategy: ContentStrategy,
        excluding existingKeys: Set<String>,
        resetHiddenCount: Bool = false
    ) async throws -> [PostRequest] {
        var seenKeys = existingKeys
        var visible: [PostRequest] = []
        var hidden = 0
        var extraPages = 0

        func load(page: Int) async throws {
            let raw = try await service.getContent(
                page: "\(page)",
                perPage: "\(postsPerPage)",
                strategy: strategy.rawValue
            )
            hasMorePages = raw.count == postsPerPage
            let kept = PitchFilter.apply(to: raw)
            hidden += raw.count - kept.count
            for post in kept where seenKeys.insert(post.stableKey).inserted {
                visible.append(post)
            }
        }

        try await load(page: currentPage)
        defer { hiddenPitchCount = (resetHiddenCount ? 0 : hiddenPitchCount) + hidden }

        while visible.count < minimumVisiblePerFetch, hasMorePages, extraPages < maxExtraPages, strategy == currentStrategy {
            extraPages += 1
            do {
                try await load(page: currentPage + 1)
                currentPage += 1
            } catch {
                break
            }
        }

        return visible
    }

    private func mergePostsPreservingBodies(_ newPosts: [PostRequest], existing: [PostRequest]) -> [PostRequest] {
        let existingByKey = Dictionary(existing.map { ($0.stableKey, $0) }, uniquingKeysWith: { first, _ in first })
        
        return newPosts.map { newPost in
            guard let existingPost = existingByKey[newPost.stableKey],
                  let existingBody = existingPost.body,
                  !existingBody.isEmpty,
                  newPost.body?.isEmpty != false else {
                return newPost
            }
            
            var merged = newPost
            merged.body = existingBody
            return merged
        }
    }
    
    @MainActor
    func syncDigestForWidget() async {
        do {
            // Buscar o digest mais recente
            let digests = try await service.getDigest(page: "1", perPage: "1", strategy: "new")
            
            guard let latestDigest = digests.first else {
                #if DEBUG
                print("⚠️ [MainViewModel] Nenhum digest encontrado")
                #endif
                return
            }
            
            // Buscar o conteúdo completo do digest
            let fullDigest = try await service.getPost(
                user: latestDigest.ownerUsername ?? "",
                slug: latestDigest.slug ?? ""
            )
            
            // Sincronizar com widgets
            WidgetSyncManager.shared.syncWeekDigest(fullDigest)
            #if DEBUG
            print("✅ [MainViewModel] Digest sincronizado automaticamente para widgets")
            #endif
            
        } catch {
            #if DEBUG
            print("⚠️ [MainViewModel] Erro ao sincronizar digest: \(error)")
            #endif
        }
    }
    
    @MainActor
    func fetchNextPage() async {
        guard !isLoadingMore && hasMorePages else { return }
        
        isLoadingMore = true
        currentPage += 1
        let strategy = currentStrategy

        do {
            let newPosts = try await fetchVisiblePosts(
                strategy: strategy,
                excluding: Set(content.map(\.stableKey))
            )

            let filled = await fetchBodies(for: newPosts)

            // Usuário trocou de estratégia enquanto carregava: descarta essa página
            guard strategy == currentStrategy else {
                isLoadingMore = false
                return
            }

            // Ordenação "relevantes" muda entre páginas; evita posts duplicados (IDs repetidos no ForEach)
            let existingKeys = Set(content.map(\.stableKey))
            content.append(contentsOf: filled.filter { !existingKeys.contains($0.stableKey) })

            saveCachedContent(page: currentPage)
            isLoadingMore = false
        } catch {
            #if DEBUG
            print("Error fetching next page: \(error)")
            #endif
            currentPage -= 1
            isLoadingMore = false
        }
    }
    
    /// Pull to refresh: mantém a lista atual na tela (sem skeleton) e troca quando a resposta chega
    @MainActor
    func refresh() async {
        await fetchContent(showLoading: false)
        await fetchPost()
    }

    /// Chamado quando a opção de ocultar Pitch muda no Perfil.
    @MainActor
    func pitchFilterChanged() async {
        if PitchFilter.isEnabled {
            let kept = PitchFilter.apply(to: content)
            hiddenPitchCount = content.count - kept.count
            content = kept
            saveCachedContent(page: 1)
        } else {
            // Os Pitches nunca foram baixados: recarrega a partir da primeira página.
            hiddenPitchCount = 0
            clearOldCache()
            await refresh()
        }
    }

    @MainActor
    func resetPagination() async {
        currentPage = 1
        hasMorePages = true
        content = []
        clearOldCache()
        await fetchContent()
        await fetchPost()
    }
    
    @MainActor
    func loadCachedContent() {
        let cacheKey = "CachedPosts_\(currentStrategy.rawValue)_page1"
        let timestampKey = "CachedPosts_\(currentStrategy.rawValue)_timestamp"
        
        if let timestamp = defaults.object(forKey: timestampKey) as? Date {
            let hoursSinceCache = Date().timeIntervalSince(timestamp) / 3600
            
            if hoursSinceCache > 1 {
                clearOldCache()
                return
            }
        }
        
        if let cachedData = defaults.object(forKey: cacheKey) as? Data {
            let decoder = JSONDecoder()
            if let cachedPosts = try? decoder.decode([PostRequest].self, from: cachedData) {
                self.content = PitchFilter.apply(to: cachedPosts)
                self.hiddenPitchCount = cachedPosts.count - self.content.count
                self.state = .requestSucceeded
                self.currentPage = 1
                self.hasMorePages = true
            }
        }
    }
    
    private func saveCachedContent(page: Int) {
        guard page <= maxCachedPages else { return }
        
        let cacheKey = "CachedPosts_\(currentStrategy.rawValue)_page\(page)"
        let timestampKey = "CachedPosts_\(currentStrategy.rawValue)_timestamp"
        let encoder = JSONEncoder()
        
        let startIndex = (page - 1) * postsPerPage
        let endIndex = min(startIndex + postsPerPage, content.count)
        
        guard startIndex < content.count else { return }
        
        let postsForPage = Array(content[startIndex..<endIndex])
        
        if let encoded = try? encoder.encode(postsForPage) {
            defaults.set(encoded, forKey: cacheKey)
            
            if page == 1 {
                defaults.set(Date(), forKey: timestampKey)
            }
        }
    }
    
    private func clearOldCache() {
        for page in 1...maxCachedPages {
            let cacheKey = "CachedPosts_\(currentStrategy.rawValue)_page\(page)"
            defaults.removeObject(forKey: cacheKey)
        }
        
        let timestampKey = "CachedPosts_\(currentStrategy.rawValue)_timestamp"
        defaults.removeObject(forKey: timestampKey)
    }
}

// MARK: - Notification
extension Notification.Name {
    static let postsLoaded = Notification.Name("postsLoaded")
    static let likedListUpdated = Notification.Name("likedListUpdated")
    static let readLaterListUpdated = Notification.Name("readLaterListUpdated")
}

// MARK: - UserDefaults
extension MainViewModel {
    func saveInAppSettings(viewInApp: Bool) {
        defaults.bool(forKey: "viewInApp")
    }
    
    func likeContentList(content: PostRequest) {
        let alreadyExists = likedList.contains { existingPost in
            isSamePost(existingPost, content)
        }
        
        if !alreadyExists {
            self.likedList.append(content)
            saveLikedContent()
            
            GamificationManager.shared.trackPostLiked()
        }
    }
    
    func removeContentList(content: PostRequest) {
        self.likedList.removeAll { existingPost in
            isSamePost(existingPost, content)
        }
        saveLikedContent()
    }
    
    func clearAllLikedContent() {
        self.likedList = []
        saveLikedContent()
    }
    
    private func isSamePost(_ post1: PostRequest, _ post2: PostRequest) -> Bool {
        post1.stableKey == post2.stableKey
    }
    
    private func saveLikedContent() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(likedList) {
            defaults.set(encoded, forKey: "LikedContent")
        }
        
        SharedDataService.saveLikedPosts(likedList)
        NotificationCenter.default.post(name: .likedListUpdated, object: nil)
    }
    
    func getLikedContent() {
        if let likedContent = defaults.object(forKey: "LikedContent") as? Data {
            let decoder = JSONDecoder()
            if let loadedContent = try? decoder.decode([PostRequest].self, from: likedContent) {
                self.likedList = removeDuplicates(from: loadedContent)
                saveLikedContent()
            }
        }
    }
    
    private func removeDuplicates(from posts: [PostRequest]) -> [PostRequest] {
        var seen: Set<String> = []
        return posts.filter { post in
            let identifier = post.stableKey
            if seen.contains(identifier) {
                return false
            }
            seen.insert(identifier)
            return true
        }
    }
    
}

// MARK: - Read Later

enum ReadLaterResult {
    case added
    case removed
}

extension MainViewModel {
    func isReadLater(_ post: PostRequest) -> Bool {
        readLaterList.contains { isSamePost($0, post) }
    }
    
    @discardableResult
    func toggleReadLater(content: PostRequest) -> ReadLaterResult {
        if isReadLater(content) {
            removeFromReadLater(content: content)
            return .removed
        } else {
            addToReadLater(content: content)
            return .added
        }
    }
    
    func addToReadLater(content: PostRequest) {
        guard !isReadLater(content) else { return }
        readLaterList.insert(content, at: 0)
        saveReadLaterContent()
    }
    
    func removeFromReadLater(content: PostRequest) {
        readLaterList.removeAll { isSamePost($0, content) }
        saveReadLaterContent()
    }
    
    func clearAllReadLater() {
        readLaterList = []
        saveReadLaterContent()
    }
    
    func getReadLaterContent() {
        if let data = defaults.object(forKey: "ReadLaterContent") as? Data {
            let decoder = JSONDecoder()
            if let loaded = try? decoder.decode([PostRequest].self, from: data) {
                readLaterList = removeDuplicates(from: loaded)
            }
        }
    }
    
    private func saveReadLaterContent() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(readLaterList) {
            defaults.set(encoded, forKey: "ReadLaterContent")
        }
        NotificationCenter.default.post(name: .readLaterListUpdated, object: nil)
    }
}

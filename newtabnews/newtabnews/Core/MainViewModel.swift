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

    /// Posts cujo body falhou na última tentativa: o card mostra um aviso em vez do skeleton infinito
    var failedBodyKeys: Set<String> = []
    private var lastFeedFetch: Date?
    private let staleFeedInterval: TimeInterval = 15 * 60
    /// Body por post+versão, para não baixar de novo ao trocar de aba ou paginar
    private var bodyCache: [String: String] = [:]
    private var inFlightBodyKeys: Set<String> = []
    private var lastDigestSync: Date?
    private let digestSyncInterval: TimeInterval = 6 * 3600

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
            self.lastFeedFetch = Date()
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
        await loadMissingBodies()

        saveCachedContent(page: currentPage)

        // Sincronizar com widgets
        WidgetSyncManager.shared.syncRecentPosts(content)

        // Sincronizar digest em background
        Task.detached(priority: .background) {
            await self.syncDigestForWidget()
        }

        NotificationCenter.default.post(name: .postsLoaded, object: nil)
    }

    /// Body baixado fora do feed (ex.: ao abrir o post): preenche o card e o cache
    @MainActor
    func applyLoadedBody(_ full: PostRequest) {
        guard full.hasLoadedBody else { return }
        let key = full.stableKey
        bodyCache[bodyCacheKey(full)] = full.body
        failedBodyKeys.remove(key)
        if let index = content.firstIndex(where: { $0.stableKey == key }),
           !content[index].hasLoadedBody {
            content[index].body = full.body
        }
    }

    private func bodyCacheKey(_ post: PostRequest) -> String {
        "\(post.stableKey)|\(post.updatedAt ?? "")"
    }

    /// Busca os bodies que faltam no feed e aplica cada um assim que chega: um post lento
    /// não segura o skeleton dos outros. Aplica por chave (não por índice), porque o feed
    /// pode mudar durante os awaits.
    @MainActor
    private func loadMissingBodies() async {
        // Bodies já baixados nesta sessão (ex.: o mesmo post em Relevantes e Recentes)
        for index in content.indices where !content[index].hasLoadedBody {
            if let body = bodyCache[bodyCacheKey(content[index])] {
                content[index].body = body
            }
        }

        // Outra chamada já está buscando esses posts (ex.: resume durante um refresh)
        let pending = content.filter { !$0.hasLoadedBody && !inFlightBodyKeys.contains($0.stableKey) }
        guard !pending.isEmpty else { return }
        failedBodyKeys.subtract(pending.map(\.stableKey))

        let service = self.service
        await withTaskGroup(of: (String, PostRequest?).self) { group in
            for post in pending {
                let key = post.stableKey
                // Sem usuário/slug não dá para buscar: mostra o aviso em vez do skeleton eterno
                guard let user = post.ownerUsername, let slug = post.slug else {
                    failedBodyKeys.insert(key)
                    continue
                }
                inFlightBodyKeys.insert(key)

                group.addTask {
                    do {
                        return (key, try await service.getPost(user: user, slug: slug))
                    } catch {
                        #if DEBUG
                        print("Erro ao buscar post [\(slug)]: \(error)")
                        #endif
                        return (key, nil)
                    }
                }
            }

            for await (key, full) in group {
                inFlightBodyKeys.remove(key)
                guard let full, full.hasLoadedBody else {
                    failedBodyKeys.insert(key)
                    continue
                }
                bodyCache[bodyCacheKey(full)] = full.body
                if let index = content.firstIndex(where: { $0.stableKey == key }),
                   !content[index].hasLoadedBody {
                    content[index] = full
                }
            }
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
        // O digest é semanal: não precisa de 2 requisições a cada carregamento do feed
        if let lastDigestSync, Date().timeIntervalSince(lastDigestSync) < digestSyncInterval { return }
        lastDigestSync = Date()

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
            lastDigestSync = nil
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

            // Usuário trocou de estratégia enquanto carregava: descarta essa página
            guard strategy == currentStrategy else {
                isLoadingMore = false
                return
            }

            // Ordenação "relevantes" muda entre páginas; evita posts duplicados (IDs repetidos no ForEach).
            // Mostra a página na hora; os bodies chegam card a card.
            let existingKeys = Set(content.map(\.stableKey))
            content.append(contentsOf: newPosts.filter { !existingKeys.contains($0.stableKey) })
            isLoadingMore = false

            let page = currentPage
            await loadMissingBodies()
            saveCachedContent(page: page)
        } catch {
            #if DEBUG
            print("Error fetching next page: \(error)")
            #endif
            currentPage -= 1
            isLoadingMore = false
        }
    }
    
    /// Ao voltar para o app: o iOS suspende o app no meio dos downloads e eles falham em silêncio.
    /// Feed antigo é recarregado; senão, só busca de novo os bodies que faltam.
    @MainActor
    func resumeIfNeeded() async {
        guard state == .requestSucceeded, !content.isEmpty else { return }

        if let lastFeedFetch, Date().timeIntervalSince(lastFeedFetch) > staleFeedInterval {
            await refresh()
        } else if content.contains(where: { !$0.hasLoadedBody }) {
            await fetchPost()
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

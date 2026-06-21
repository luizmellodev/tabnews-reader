//
//  ContentView.swift
//  newtabnews
//
//  Created by Luiz Mello on 01/07/23.
//

import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
        
    let contentService: ContentServiceProtocol
        
    @AppStorage("current_theme") var currentTheme: Theme = .system
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @AppStorage("hasSeenTipsOnboarding") var hasSeenTipsOnboarding: Bool = false
    @AppStorage(RestGamesAnnouncement.storageKey) var hasSeenRestGamesAnnouncement: Bool = false
    
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [Folder]
    @Query private var highlights: [Highlight]
    @Query private var notes: [Note]
    
    @State var viewModel: MainViewModel
    @State var newsletterVM: NewsletterViewModel
    @State var showSnack: Bool = false
    @State var isViewInApp: Bool = true
    @State var alreadyLoaded: Bool = false
    @State var selectedTab: AppTab = .home
    @State var postToOpen: PostRequest? = nil
    @State var isLoadingPost: Bool = false
    @State var showTipsOnboarding: Bool = false
	@State var showDigestSheet: Bool = false
    @State private var showRestGamesAnnouncement = false
    @State private var showRestGamesHub = false
    @State private var showSplash = true
    @StateObject private var gamificationManager = GamificationManager.shared
    @StateObject private var toastManager = ToastManager.shared
        
    init(
        contentService: ContentServiceProtocol = ContentService(),
        viewModel: MainViewModel? = nil,
        newsletterVM: NewsletterViewModel? = nil
    ) {
        self.contentService = contentService
        self._viewModel = State(initialValue: viewModel ?? MainViewModel(service: contentService))
        self._newsletterVM = State(initialValue: newsletterVM ?? NewsletterViewModel(service: contentService))
    }
    
    var body: some View {
        ZStack {
            Group {
                if !hasSeenOnboarding {
                    OnboardingView(showOnboarding: $hasSeenOnboarding)
                } else {
                    mainContent

                    if showTipsOnboarding {
                        OnboardingTipsView(
                            showOnboarding: $showTipsOnboarding,
                            onNavigateToLibrary: {
                                selectedTab = .library
                            }
                        )
                        .transition(.opacity)
                    }
                }
            }
            .allowsHitTesting(!showSplash)

            // Badge Unlocked Banner - Global
            VStack {
                if let badge = gamificationManager.showBadgeUnlocked {
                    BadgeUnlockedBanner(badge: badge)
                        .padding(.top, 60)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()

                if let toast = toastManager.currentToast {
                    ToastBanner(message: toast)
                        .padding(.bottom, 90)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(), value: gamificationManager.showBadgeUnlocked)
            .animation(.spring(), value: toastManager.currentToast)

            if showSplash {
                SplashView(showSplash: $showSplash)
                    .zIndex(999)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(currentTheme.colorScheme)
        .sheet(isPresented: $showDigestSheet) {
            NavigationStack {
                DigestListView()
                    .navigationTitle("Resumo Semanal")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Fechar") {
                                showDigestSheet = false
                            }
                        }
                    }
            }
            .environment(viewModel)
            .presentationDragIndicator(.hidden)
            .presentationDetents([.large])
            .interactiveDismissDisabled(false)
        }
        .sheet(isPresented: $showRestGamesAnnouncement, onDismiss: {
            if !hasSeenRestGamesAnnouncement {
                RestGamesAnnouncement.markSeen()
                hasSeenRestGamesAnnouncement = true
            }
        }) {
            RestGamesAnnouncementSheet(
                onPlay: {
                    RestGamesAnnouncement.markSeen()
                    hasSeenRestGamesAnnouncement = true
                    showRestGamesAnnouncement = false
                    selectedTab = .settings
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showRestGamesHub = true
                    }
                },
                onLater: {
                    RestGamesAnnouncement.markSeen()
                    hasSeenRestGamesAnnouncement = true
                    showRestGamesAnnouncement = false
                }
            )
            .presentationDetents([.height(288)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
            .interactiveDismissDisabled(false)
        }
        .fullScreenCover(isPresented: $showRestGamesHub) {
            RestGamesHubView(onClose: { showRestGamesHub = false })
        }
        .onAppear {
            setupObservers()
            
            if !hasSeenTipsOnboarding && hasSeenOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation {
                        showTipsOnboarding = true
                    }
                }
            } else {
                evaluateRestGamesAnnouncement()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                clearBadge()
                syncToWatch()
                AppReviewManager.shared.handleAppBecameActive()
            } else if newPhase == .background {
                AppReviewManager.shared.handleAppEnteredBackground()
            }
        }
        .onChange(of: showTipsOnboarding) { _, newValue in
            if !newValue {
                hasSeenTipsOnboarding = true
                evaluateRestGamesAnnouncement()
            }
        }
        .onChange(of: showSplash) { _, isShowing in
            if !isShowing {
                evaluateRestGamesAnnouncement()
            }
        }
        .onChange(of: hasSeenOnboarding) { _, newValue in
            // Quando terminar o onboarding inicial, mostrar tips automaticamente
            if newValue && !hasSeenTipsOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        showTipsOnboarding = true
                    }
                }
            }
        }
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
    }
    
    // MARK: - Views
    
    private var mainContent: some View {
        MainTabView(
            selectedTab: $selectedTab,
            isViewInApp: $isViewInApp,
            currentTheme: $currentTheme,
            viewModel: viewModel,
            newsletterVM: newsletterVM,
            postToOpen: $postToOpen,
            isLoadingPost: $isLoadingPost
        )
        .environment(viewModel)
        .onAppear {
            loadInitialContent()
        }
    }
    
    // MARK: - Lifecycle

    private func evaluateRestGamesAnnouncement() {
        guard hasSeenOnboarding,
              hasSeenTipsOnboarding,
              !hasSeenRestGamesAnnouncement,
              !showSplash,
              !showTipsOnboarding,
              !showRestGamesAnnouncement else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard !hasSeenRestGamesAnnouncement, !showTipsOnboarding, !showSplash else { return }
            showRestGamesAnnouncement = true
        }
    }

    private func loadInitialContent() {
        viewModel.getLikedContent()
        
        if !alreadyLoaded {
            // Carrega cache silenciosamente (sem mostrar skeleton)
            viewModel.loadCachedContent()
            
            Task {
                // Busca conteúdo fresco (com skeleton se não tiver cache)
                await viewModel.fetchContent(showLoading: viewModel.content.isEmpty)
                await viewModel.fetchPost()
                alreadyLoaded = true
            }
        }
        
        viewModel.saveInAppSettings(viewInApp: isViewInApp)
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            forName: .postsLoaded,
            object: nil,
            queue: .main
        ) { _ in
            syncToWatch()
        }
        
        NotificationCenter.default.addObserver(
            forName: .likedListUpdated,
            object: nil,
            queue: .main
        ) { _ in
            syncToWatch()
        }
        
        NotificationCenter.default.addObserver(
            forName: .highlightsUpdated,
            object: nil,
            queue: .main
        ) { _ in
            syncToWatch()
        }
        
        NotificationCenter.default.addObserver(
            forName: .notesUpdated,
            object: nil,
            queue: .main
        ) { _ in
            syncToWatch()
        }
        
        NotificationCenter.default.addObserver(
            forName: .foldersUpdated,
            object: nil,
            queue: .main
        ) { _ in
            syncToWatch()
        }
        
        NotificationCenter.default.addObserver(
            forName: .openNewsletterTab,
            object: nil,
            queue: .main
        ) { [self] _ in
            handleOpenNewsletterTab()
        }
        
        NotificationCenter.default.addObserver(
            forName: .openPostFromNotification,
            object: nil,
            queue: .main
        ) { [self] notification in
            handleOpenPost(from: notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: .watchLikedPostsReceived,
            object: nil,
            queue: .main
        ) { [self] notification in
            handleWatchLikedPosts(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: .showTipsOnboarding,
            object: nil,
            queue: .main
        ) { [self] _ in
            selectedTab = .home
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    showTipsOnboarding = true
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .showRestGamesAnnouncement,
            object: nil,
            queue: .main
        ) { [self] _ in
            hasSeenRestGamesAnnouncement = false
            showRestGamesAnnouncement = true
        }
        
        NotificationCenter.default.addObserver(
            forName: .navigateToHome,
            object: nil,
            queue: .main
        ) { [self] _ in
            selectedTab = .home
        }
        
        NotificationCenter.default.addObserver(
            forName: .navigateToDigest,
            object: nil,
            queue: .main
        ) { [self] _ in
            handleNavigateToDigest()
        }
    }
    
    // MARK: - Notification Handlers
    
    private func handleOpenNewsletterTab() {
        selectedTab = .newsletter
    }
    
    private func handleNavigateToDigest() {
        // Abre sheet com DigestListView
        showDigestSheet = true
    }
    
    private func handleOpenPost(from notification: Notification) {
        guard let postData = notification.object as? PostDeepLinkData else {
            return
        }
        
        if postData.type.isNewsletter {
            selectedTab = .newsletter
        } else if postData.type.isDigest {
            // Digest abre em sheet
            showDigestSheet = true
            return // Não precisa abrir post específico
        } else {
            selectedTab = .home
        }
        
        Task {
            await openPost(owner: postData.owner, slug: postData.slug)
        }
    }
    
    // MARK: - Deep Link
    
    /// Handler para URLs do tipo tabnews://
    private func handleDeepLink(url: URL) {
        print("🔗 Deep link recebido: \(url)")
        
        guard url.scheme == "tabnews" else {
            print("⚠️ Scheme inválido: \(url.scheme ?? "nil")")
            return
        }
        
        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        print("📍 Host: \(host), Path: \(pathComponents)")
        
        switch host {
        case "home":
            selectedTab = .home
            
        case "newsletter":
            selectedTab = .newsletter
            
        case "digest":
            showDigestSheet = true
            
        case "post":
            // URL: tabnews://post/username/slug
            guard pathComponents.count >= 2 else {
                print("⚠️ URL de post inválida: faltam parâmetros")
                return
            }
            
            let owner = pathComponents[0]
            let slug = pathComponents[1]
            
            print("📰 Abrindo post: \(owner)/\(slug)")
            
            selectedTab = .home
            Task {
                await openPost(owner: owner, slug: slug)
            }
            
        default:
            print("⚠️ Host desconhecido: \(host)")
        }
    }
    
    @MainActor
    private func openPost(owner: String, slug: String) async {
        isLoadingPost = true
        
        do {
            let post = try await contentService.getPost(user: owner, slug: slug)
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            postToOpen = post
            isLoadingPost = false
        } catch {
            isLoadingPost = false
        }
    }
    
    // MARK: - Watch Sync
    
    private func syncToWatch() {
        let recentPosts = Array(viewModel.content.prefix(10))
        let likedPosts = Array(viewModel.likedList.prefix(15))
        
        let stats = [
            "liked": viewModel.likedList.count,
            "highlights": highlights.count,
            "notes": notes.count,
            "folders": folders.count
        ]
        
        WatchSyncManager.shared.syncToWatch(
            posts: recentPosts,
            likedPosts: likedPosts,
            stats: stats
        )
    }
    
    private func handleWatchLikedPosts(_ notification: Notification) {
        guard let watchLikedPosts = notification.object as? [PostRequest] else { return }
        
        for post in watchLikedPosts {
            if !viewModel.likedList.contains(where: { $0.id == post.id }) {
                viewModel.likeContentList(content: post)
            }
        }
    }
    
    // MARK: - Badge Management
    
    /// Limpa o badge de notificações quando o app abre
    private func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("❌ Erro ao limpar badge: \(error.localizedDescription)")
            } else {
                print("✅ Badge limpo ao abrir o app")
            }
        }
    }
}

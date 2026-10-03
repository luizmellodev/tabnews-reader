//
//  SettingsView.swift
//  tabnewsios
//
//  Created by Luiz Eduardo Mello dos Reis on 31/12/22.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(MainViewModel.self) var viewModel
    @Query private var folders: [Folder]
    @Query private var highlights: [Highlight]
    @Query private var notes: [Note]
    
    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme
    
    @State private var showingClearCache = false
    @State private var showingClearLibrary = false
    @State private var showLoginSheet = false
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var deletedAccount: DeletedAccountInfo?
    @State private var showingGames = false
    @State private var showingRankings = false
    @State private var gamesCardRefreshID = UUID()
    @Namespace private var gamesTransition
    @StateObject private var authService = AuthService.shared
    @AppStorage("showReadOnTabNewsButton") private var showReadOnTabNewsButton = false
    @AppStorage("isBetaTester") private var isBetaTester = false
    @State private var isRefreshing = false
    @State private var userPublicationsCount: Int?
    #if DEBUG
    @AppStorage("debugShowDigestBanner") private var debugShowDigestBanner = false
    @AppStorage("debugShowDailyDigestBanner") private var appStorage_debugShowDailyDigestBanner = false
    @State private var pushTokenDebugInfo: FirebasePushNotificationService.DebugInfo?
    @State private var isLoadingPushTokenDebug = false
    @State private var pushDebugMessage: String?
    #endif
    
    var body: some View {
        NavigationStack {
            settingsModals(settingsChrome(settingsList))
        }
    }

    private var settingsList: some View {
        List {
            // Cada card em sua própria linha: botões dividindo a mesma linha da List não recebem toque
            Section {
                profileSection
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 6, trailing: 0))

                RestGamesProfileCard(
                    onPlay: { showingGames = true },
                    onRankings: { showingRankings = true }
                )
                .id(gamesCardRefreshID)
                .matchedTransitionSource(id: "restGames", in: gamesTransition)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 16, trailing: 0))
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            activitySection
            preferencesSection
            moreSection

            if authService.isAuthenticated {
                accountSection
            }

            #if DEBUG
            debugSection
            #endif
        }
    }

    @ViewBuilder
    private func settingsChrome<Content: View>(_ content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshUserData()
            }
            .overlay(alignment: .top) {
                if isRefreshing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Atualizando...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(), value: isRefreshing)
            .background {
                ZStack {
                    Color("Background")
                        .ignoresSafeArea()
                    Image("ruido")
                        .resizable()
                        .scaledToFill()
                        .blendMode(.overlay)
                        .ignoresSafeArea()
                }
            }
    }

    @ViewBuilder
    private func settingsModals<Content: View>(_ content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showingGames, onDismiss: {
                // Atualiza o progresso diário do card ao voltar dos jogos
                gamesCardRefreshID = UUID()
            }) {
                RestGamesHubView(onClose: { showingGames = false })
                    .navigationTransition(.zoom(sourceID: "restGames", in: gamesTransition))
            }
            .sheet(isPresented: $showingRankings) {
                RestGameLeaderboardsSheet()
            }
            #if DEBUG
            .sheet(item: $pushTokenDebugInfo) { info in
                PushTokenDebugSheet(info: info)
            }
            #endif
            .alert("Limpar Cache da API", isPresented: $showingClearCache) {
                Button("Cancelar", role: .cancel) { }
                Button("Limpar", role: .destructive) {
                    clearAPICache()
                }
            } message: {
                Text("Isso irá remover respostas HTTP em cache, forçando o app a buscar posts atualizados.")
            }
            .alert("⚠️ Limpar Biblioteca Completa", isPresented: $showingClearLibrary) {
                Button("Cancelar", role: .cancel) { }
                Button("Limpar TUDO", role: .destructive) {
                    clearCompleteLibrary()
                }
            } message: {
                Text("Isso irá remover PERMANENTEMENTE todos os seus dados: curtidas (\(viewModel.likedList.count)), destaques (\(highlights.count)), anotações (\(notes.count)) e pastas (\(folders.count)). Esta ação não pode ser desfeita!")
            }
            .alert("Sair da Conta", isPresented: $showLogoutAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Sair", role: .destructive) {
                    authService.logout()
                }
            } message: {
                Text("Tem certeza que deseja sair da sua conta?")
            }
            .alert("Excluir Conta", isPresented: $showDeleteAccountAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Continuar", role: .destructive) {
                    // Captura os dados antes do logout para pré-preencher o email de exclusão
                    let user = authService.currentUser
                    authService.logout()
                    deletedAccount = DeletedAccountInfo(
                        username: user?.username ?? "",
                        email: user?.email ?? ""
                    )
                }
            } message: {
                Text("Sua conta será desconectada deste app. A exclusão permanente é feita pelo suporte do TabNews, e no próximo passo você pode enviar o pedido por email.")
            }
            .sheet(item: $deletedAccount) { account in
                DeleteAccountContactView(username: account.username, email: account.email)
            }
            .task {
                if authService.isAuthenticated, let username = authService.currentUser?.username {
                    await loadPublicationsCount(username: username)
                }
            }
    }

    private var activitySection: some View {
        Section {
            HStack(spacing: 0) {
                activityStat(viewModel.likedList.count, label: "Curtidos", icon: "heart")
                activityStat(highlights.count, label: "Destaques", icon: "highlighter")
                activityStat(notes.count, label: "Anotações", icon: "note.text")
                activityStat(folders.count, label: "Pastas", icon: "folder")
            }
            .padding(.vertical, 4)

            NavigationLink {
                GamificationView()
            } label: {
                Label("Badges & Desafios", systemImage: "star")
            }
        } header: {
            Label("Atividade", systemImage: "chart.bar")
        }
    }

    private func activityStat(_ value: Int, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 16)
            Text("\(value)")
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var accountSection: some View {
        Section {
            Button(role: .destructive) {
                showLogoutAlert = true
            } label: {
                Label("Sair da conta", systemImage: "rectangle.portrait.and.arrow.right")
            }

            // O app não cria contas (só login), então a guideline 5.1.1(v) não exige isto; mantido como cortesia.
            // Faz logout e abre o pedido de exclusão por email para o suporte do TabNews.
            Button {
                showDeleteAccountAlert = true
            } label: {
                Label("Excluir conta", systemImage: "person.crop.circle.badge.xmark")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("Conta", systemImage: "person.crop.circle")
        }
    }

    private var preferencesSection: some View {
        Section {
            Picker("Tema", selection: $currentTheme) {
                Label("Sistema", systemImage: "iphone").tag(Theme.system)
                Label("Claro", systemImage: "sun.max").tag(Theme.light)
                Label("Escuro", systemImage: "moon").tag(Theme.dark)
            }
            .pickerStyle(.menu)

            Toggle("Visualizar no App", isOn: $isViewInApp)

            Toggle("Botão 'Ler no TabNews'", isOn: $showReadOnTabNewsButton)

            HStack {
                Label("Notificações", systemImage: "bell.badge")
                Spacer()
                Text(NotificationManager.shared.isPermissionGranted ? "Ativadas" : "Desativadas")
                    .foregroundStyle(NotificationManager.shared.isPermissionGranted ? .green : .secondary)
            }

            if !NotificationManager.shared.isPermissionGranted {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Abrir Ajustes do Sistema", systemImage: "gear")
                }
            }
        } header: {
            Label("Preferências", systemImage: "slider.horizontal.3")
        } footer: {
            Text("Leitura no app, botão Safari nos posts e alertas de newsletter e resumo semanal.")
        }
    }

    private var moreSection: some View {
        Section {
            Button {
                AppReviewManager.shared.openAppStoreReviewPage()
            } label: {
                HStack(spacing: 12) {
                    Label("Avaliar o App", systemImage: "star.bubble.fill")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            NavigationLink {
                aboutAppView
            } label: {
                Label("Sobre o TabNews Reader", systemImage: "info.circle")
            }

            Button {
                UserDefaults.standard.set(false, forKey: "hasSeenTipsOnboarding")
                NotificationCenter.default.post(name: .showTipsOnboarding, object: nil)
            } label: {
                Label("Ver Dicas Novamente", systemImage: "lightbulb.fill")
            }

            Button(role: .destructive) {
                showingClearCache = true
            } label: {
                Label("Limpar Cache da API", systemImage: "arrow.clockwise.circle")
            }

            Button(role: .destructive) {
                showingClearLibrary = true
            } label: {
                Label("Limpar Biblioteca Completa", systemImage: "trash.fill")
            }

            HStack {
                Text("Versão")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("Mais", systemImage: "ellipsis.circle")
        } footer: {
            Text("Limpar cache força posts atualizados. Limpar biblioteca remove curtidas, destaques, anotações e pastas.")
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section {
            Button {
                RestGamesAnnouncement.resetForTesting()
                NotificationCenter.default.post(name: .showRestGamesAnnouncement, object: nil)
            } label: {
                Label("Mostrar Novidade dos Jogos", systemImage: "gamecontroller.fill")
            }

            Button {
                UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
                UserDefaults.standard.set(false, forKey: "hasSeenTipsOnboarding")
                exit(0)
            } label: {
                Label("Resetar Onboarding Completo", systemImage: "arrow.counterclockwise.circle")
            }

            Button {
                syncWithWatchManually()
            } label: {
                HStack {
                    Label("⌚ Sincronizar com Watch", systemImage: "applewatch")
                    Spacer()
                    Text("\(viewModel.content.count) posts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                isLoadingPushTokenDebug = true
                FirebasePushNotificationService.shared.fetchDebugInfo { info in
                    isLoadingPushTokenDebug = false
                    pushTokenDebugInfo = info
                }
            } label: {
                HStack {
                    Label("Ver FCM Token deste device", systemImage: "bell.badge")
                    Spacer()
                    if isLoadingPushTokenDebug {
                        ProgressView()
                    }
                }
            }
            .disabled(isLoadingPushTokenDebug)

            Button {
                FirebasePushNotificationService.shared.sendLocalTestNotification { message in
                    pushDebugMessage = message
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Testar notificação local", systemImage: "bell.and.waves.left.and.right")
                    Text("Confirma se o iOS exibe notificações deste app")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let pushDebugMessage {
                Text(pushDebugMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: $debugShowDigestBanner) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔥 Mostrar Banner Weekly Digest")
                    Text("Simula fim de semana para testar o banner")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $appStorage_debugShowDailyDigestBanner) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🧭 Mostrar Banner Daily Digest")
                    Text("Força o Daily Digest aparecer sempre")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                UserDefaults.standard.removeObject(forKey: "last_daily_digest_date")
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🗑️ Resetar Daily Digest")
                        Text("Remove flag de 'já visto hoje'")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.clockwise.circle")
                }
            }

            Button {
                AppReviewManager.shared.resetForTesting()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("⭐ Resetar Review Request")
                        Text("Força o pre-prompt de avaliação aparecer de novo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.clockwise.circle")
                }
            }

            Button {
                withAnimation {
                    isBetaTester.toggle()
                    BetaTesterService.shared.forceBetaTesterStatus(isBetaTester)
                }
            } label: {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text(isBetaTester ? "Remover Badge Beta" : "Ativar Badge Beta")
                    }

                    Spacer()

                    if isBetaTester {
                        HStack(spacing: 3) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 9))
                            Text("BETA")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(0.5)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(6)
                    }
                }
            }
        } header: {
            Label("Debug", systemImage: "hammer.fill")
        } footer: {
            Text("Ferramentas de desenvolvimento para testes. Push remoto: olhe o console do Xcode por 📬 ao enviar o curl. O banner de Digest normalmente só aparece nos fins de semana.")
        }
    }
    #endif

    // MARK: - About

    private var aboutAppView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("O TabNews Reader é um aplicativo não-oficial do TabNews, criado por um entusiasta da comunidade. O objetivo é facilitar o acesso ao conteúdo e permitir organização pessoal através de destaques e anotações.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Criadores")
                        .font(.headline)

                    CreatorSocialCard(
                        creator: CreatorInfo(
                            name: "Filipe Deschamps",
                            role: "Criador do TabNews",
                            accent: .blue,
                            github: "filipedeschamps",
                            linkedin: "filipedeschamps",
                            youtube: "FilipeDeschamps",
                            instagram: "filipedeschamps"
                        )
                    )

                    CreatorSocialCard(
                        creator: CreatorInfo(
                            name: "Luiz Mello",
                            role: "Desenvolvedor deste app",
                            accent: .green,
                            github: "luizmellodev",
                            linkedin: "luizmellodev",
                            youtube: "euluizmello",
                            instagram: "luizmello.dev",
                            website: "https://luizmello.dev"
                        )
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Sobre o TabNews Reader")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            ZStack {
                Color("Background")
                    .ignoresSafeArea()
                Image("ruido")
                    .resizable()
                    .scaledToFill()
                    .blendMode(.overlay)
                    .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Profile Section
    
    private var profileSection: some View {
        Group {
            if authService.isAuthenticated, let user = authService.currentUser {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(String(user.username.prefix(1).uppercased()))
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(.primary)
                                )

                            if isBetaTester {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(
                                        LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        in: Circle()
                                    )
                                    .offset(x: 2, y: 2)
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("@\(user.username)")
                                    .font(.title3.weight(.bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                if isBetaTester {
                                    Text("BETA")
                                        .font(.system(size: 9, weight: .bold))
                                        .tracking(0.5)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing),
                                            in: RoundedRectangle(cornerRadius: 6)
                                        )
                                }
                            }

                            Text(user.memberSince.map { "No TabNews desde \($0)" } ?? "TabNews")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 10) {
                        profileStat(user.tabcoins, label: "TabCoins", icon: "star.fill", tint: .orange)
                        profileStat(user.tabcash, label: "TabCash", icon: "dollarsign.circle.fill", tint: .green)
                    }

                    NavigationLink {
                        UserPublicationsView(username: user.username)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .font(.subheadline)
                            Text(userPublicationsCount == 0 ? "Nenhuma publicação ainda" : "Minhas Publicações")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.borderless)
                }
                .padding(16)
                .background(Color("CardColor"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }
            } else {
                Button {
                    showLoginSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Entrar no TabNews")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text("Opcional: libera votos, TabCoins e suas publicações.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(Color("CardColor"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showLoginSheet) {
                    NativeLoginView()
                }
            }
        }
    }

    private func profileStat(_ value: Int?, label: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value.map(String.init) ?? "—")
                    .font(.headline.monospacedDigit())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var betaTesterBadgeCard: some View {
        HStack(spacing: 16) {
            // Ícone animado com gradiente
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            // Conteúdo
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Beta Tester")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                        .font(.body)
                }
            }
            
            Spacer()
            
            // Sparkles decoration
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("CardColor"))
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .blue.opacity(0.3), .pink.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Data Management
    
    private func refreshUserData() async {
        guard authService.isAuthenticated else { return }
        
        isRefreshing = true
        
        do {
            try await authService.refreshUserData()
            
            if let username = authService.currentUser?.username {
                await loadPublicationsCount(username: username)
            }
        } catch {
            print("Erro ao atualizar dados do usuário: \(error)")
        }
        
        isRefreshing = false
    }
    
    private func loadPublicationsCount(username: String) async {
        do {
            let publications = try await authService.getUserPublications(
                username: username,
                page: 1,
                perPage: 1
            )
            
            // A API do TabNews não retorna o total, então vamos buscar a primeira página
            // e fazer uma estimativa baseada no retorno
            await MainActor.run {
                self.userPublicationsCount = publications.isEmpty ? 0 : nil
            }
        } catch {
            print("Erro ao carregar contagem de publicações: \(error)")
        }
    }
    
    private func clearAPICache() {
        URLCache.shared.removeAllCachedResponses()
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
    }
    
    #if DEBUG
    private func syncWithWatchManually() {
        let recentPosts = Array(viewModel.content.prefix(5))
        let likedPosts = Array(viewModel.likedList.prefix(10))
        
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
    #endif
    
    private func clearCompleteLibrary() {
        viewModel.clearAllLikedContent()
        
        for highlight in highlights {
            modelContext.delete(highlight)
        }
        
        for note in notes {
            modelContext.delete(note)
        }
        
        for folder in folders {
            modelContext.delete(folder)
        }
        
        try? modelContext.save()
    }
}

#if DEBUG
private struct DeletedAccountInfo: Identifiable {
    let username: String
    let email: String
    var id: String { username + email }
}

private struct PushTokenDebugSheet: View {
    let info: FirebasePushNotificationService.DebugInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GroupBox("Status") {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent("Permissão", value: info.permissionStatus)
                            LabeledContent("APNs registrado", value: info.apnsTokenRegistered ? "sim" : "não")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("Device ID") {
                        Text(info.deviceId)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("FCM Token") {
                        Text(info.fcmToken)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Push Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Copiar") {
                        UIPasteboard.general.string = info.fcmToken
                    }
                }
            }
        }
    }
}
#endif

struct SettingsView_Previews: PreviewProvider {
    static var currentTheme: Theme = .light
    static var previews: some View {
        SettingsView(isViewInApp: .constant(true), currentTheme: .constant(currentTheme))
    }
}

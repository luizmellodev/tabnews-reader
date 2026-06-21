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
    @State private var showingGames = false
    @State private var showingRankings = false
    @StateObject private var authService = AuthService.shared
    @AppStorage("debugShowDigestBanner") private var debugShowDigestBanner = false
    @AppStorage("debugShowDailyDigestBanner") private var appStorage_debugShowDailyDigestBanner = false
    @AppStorage("showReadOnTabNewsButton") private var showReadOnTabNewsButton = false
    @AppStorage("isBetaTester") private var isBetaTester = false
    @State private var isRefreshing = false
    @State private var userPublicationsCount: Int?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        profileSection

                        RestGamesHubBanner(onTap: { showingGames = true })
                        RestGamesRankingsBanner(onTap: { showingRankings = true })
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 16, trailing: 0))
                .listRowSeparator(.hidden)
                
                Section {
                    NavigationLink {
                        GamificationView()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple, .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "star.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Badges & Desafios")
                                    .font(.headline)
                                Text("Veja suas conquistas e desafios semanais")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                } header: {
                    Label("Gamificação", systemImage: "trophy.fill")
                }
                
                Section {
                    HStack {
                        Label("Posts Curtidos", systemImage: "heart")
                        Spacer()
                        Text("\(viewModel.likedList.count)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("Destaques", systemImage: "highlighter")
                        Spacer()
                        Text("\(highlights.count)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("Anotações", systemImage: "note.text")
                        Spacer()
                        Text("\(notes.count)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("Pastas Criadas", systemImage: "folder")
                        Spacer()
                        Text("\(folders.count)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Sua Biblioteca", systemImage: "chart.bar")
                }

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
                        Text("2.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Mais", systemImage: "ellipsis.circle")
                } footer: {
                    Text("Limpar cache força posts atualizados. Limpar biblioteca remove curtidas, destaques, anotações e pastas.")
                }
                
                #if DEBUG
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
                        #if DEBUG
                        AppReviewManager.shared.resetForTesting()
                        #else
                        UserDefaults.standard.set(0, forKey: "newsletterOpenCount")
                        UserDefaults.standard.set(0, forKey: "lastReviewPrePromptDate")
                        UserDefaults.standard.set(0, forKey: "lastReviewRequestDate")
                        UserDefaults.standard.set(0, forKey: "appReviewSessionCount")
                        #endif
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
                    Text("Ferramentas de desenvolvimento para testes. O banner de Digest normalmente só aparece nos fins de semana (sábado e domingo).")
                }
                #endif
            }
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
            .sheet(isPresented: $showLoginSheet) {
                NativeLoginView()
            }
            .fullScreenCover(isPresented: $showingGames) {
                RestGamesHubView(onClose: { showingGames = false })
            }
            .sheet(isPresented: $showingRankings) {
                RestGameLeaderboardsSheet()
            }
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
            .task {
                if authService.isAuthenticated, let username = authService.currentUser?.username {
                    await loadPublicationsCount(username: username)
                }
            }
        }
    }
    
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
                VStack(spacing: 12) {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(Color.primary.opacity(0.1))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Text(String(user.username.prefix(1).uppercased()))
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    )
                                
                                if isBetaTester {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.purple, .blue],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 18, height: 18)
                                            .shadow(color: .purple.opacity(0.4), radius: 2, x: 0, y: 1)
                                        
                                        Image(systemName: "trophy.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(.white)
                                    }
                                    .offset(x: 2, y: 2)
                                }
                            }
                            
                            // Username e badge
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("@\(user.username)")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    // Badge Beta Tester - design de troféu
                                    if isBetaTester {
                                        HStack(spacing: 3) {
                                            Image(systemName: "trophy.fill")
                                                .font(.system(size: 10))
                                            Text("BETA")
                                                .font(.system(size: 9, weight: .bold))
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
                                        .shadow(color: .purple.opacity(0.3), radius: 3, x: 0, y: 1)
                                    }
                                }
                                
                                Text("TabNews")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Stats (TabCoins, TabCash e Publicações) - horizontal compacto
                        HStack(spacing: 20) {
                            if let tabcoins = user.tabcoins {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("\(tabcoins)")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text("TabCoins")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            
                            if let tabcash = user.tabcash {
                                HStack(spacing: 6) {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("\(tabcash)")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text("TabCash")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Botão de Publicações
                        NavigationLink {
                            UserPublicationsView(username: user.username)
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    if let count = userPublicationsCount {
                                        Text("\(count) \(count == 1 ? "Publicação" : "Publicações")")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                    } else {
                                        Text("Minhas Publicações")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                    }
                                    Text("Ver todas")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color(.systemGray5).opacity(0.5))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Botão de Logout separado - minimalista
                    Button {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline)
                            Text("Sair")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .foregroundStyle(.red)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                VStack(spacing: 10) {
                    Button {
                        showLoginSheet = true
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.primary.opacity(0.1))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Entrar")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("O login é opcional e libera recursos da conta.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)
                }
            }
        }
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

struct SettingsView_Previews: PreviewProvider {
    static var currentTheme: Theme = .light
    static var previews: some View {
        SettingsView(isViewInApp: .constant(true), currentTheme: .constant(currentTheme))
    }
}

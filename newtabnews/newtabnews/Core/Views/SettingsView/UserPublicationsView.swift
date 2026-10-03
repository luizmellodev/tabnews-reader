//
//  UserPublicationsView.swift
//  newtabnews
//
//  Created by Luiz Mello on 07/01/26.
//

import SwiftUI

struct UserPublicationsView: View {
    let username: String
    /// true quando aberto a partir do @ de alguém: mostra cabeçalho com bio e tabcoins da pessoa
    var showsProfileHeader: Bool = false
    
    @State private var profile: PublicUser?
    @State private var publications: [PostRequest] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentPage = 1
    @State private var hasMorePages = true
    @State private var isLoadingMore = false
    @State private var isLoadingPost = false
    @State private var selectedPost: PostRequest?
    @State private var navigateToPost = false
    
    @StateObject private var authService = AuthService.shared
    private let contentService = ContentService()
    
    var body: some View {
        Group {
            if isLoading && publications.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Carregando publicações...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Erro ao carregar")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        Task {
                            await loadPublications()
                        }
                    } label: {
                        Label("Tentar Novamente", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if publications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    if showsProfileHeader {
                        profileHeader
                    }
                    Text("Nenhuma publicação")
                        .font(.headline)
                    Text(showsProfileHeader ? "@\(username) ainda não publicou nada no TabNews" : "Você ainda não publicou nada no TabNews")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if showsProfileHeader {
                            profileHeader
                        }
                        
                        ForEach(publications) { post in
                            Button {
                                Task {
                                    await loadFullPostAndNavigate(post)
                                }
                            } label: {
                                PublicationCard(post: post)
                            }
                            .buttonStyle(.borderless)
                            .tint(.primary)
                            
                            if post.id == publications.last?.id && hasMorePages && !isLoadingMore {
                                Color.clear
                                    .frame(height: 1)
                                    .onAppear {
                                        Task {
                                            await loadMorePublications()
                                        }
                                    }
                            }
                        }
                        
                        if isLoadingMore {
                            HStack {
                                ProgressView()
                                    .padding()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await refreshPublications()
                }
            }
        }
        .navigationTitle(showsProfileHeader ? "@\(username)" : "Minhas Publicações")
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
        .navigationDestination(isPresented: $navigateToPost) {
            if let post = selectedPost {
                ListDetailView(
                    isViewInApp: .constant(true),
                    currentTheme: .constant(.system),
                    post: post
                )
            }
        }
        .overlay {
            if isLoadingPost {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Carregando publicação...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
        }
        .task {
            await loadPublications()
        }
        .task {
            guard showsProfileHeader else { return }
            profile = try? await authService.getPublicUser(username: username)
        }
    }
    
    // MARK: - Profile Header
    
    @ViewBuilder
    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text(String(username.prefix(1)).uppercased())
                            .font(.title2)
                            .fontWeight(.semibold)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(username)")
                        .font(.headline)
                    if let memberSince = profile?.memberSince {
                        Text("No TabNews desde \(memberSince)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if let profile {
                HStack(spacing: 20) {
                    profileStat(value: profile.tabcoins, label: "TabCoins", icon: "star.fill", color: .orange)
                    profileStat(value: profile.tabcash, label: "TabCash", icon: "dollarsign.circle.fill", color: .green)
                    Spacer()
                }
                
                if let description = profile.description, !description.isEmpty {
                    CommentBodyView(markdown: description)
                        .font(.subheadline)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.bottom, 8)
    }
    
    private func profileStat(value: Int?, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value ?? 0)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Navigation
    
    private func loadFullPostAndNavigate(_ post: PostRequest) async {
        guard let username = post.ownerUsername, let slug = post.slug else { return }
        
        isLoadingPost = true
        
        do {
            let fullPost = try await contentService.getPost(user: username, slug: slug)
            
            await MainActor.run {
                self.selectedPost = fullPost
                self.isLoadingPost = false
                self.navigateToPost = true
            }
        } catch {
            await MainActor.run {
                self.isLoadingPost = false
                print("Erro ao carregar post completo: \(error)")
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadPublications() async {
        isLoading = true
        errorMessage = nil
        currentPage = 1
        
        do {
            let posts = try await authService.getUserPublications(
                username: username,
                page: currentPage,
                perPage: 30
            )
            
            let filteredPosts = posts.filter { post in
                post.parentId == nil && post.title != nil && !post.title!.isEmpty
            }
            
            await MainActor.run {
                self.publications = filteredPosts
                self.hasMorePages = posts.count >= 30
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func loadMorePublications() async {
        guard !isLoadingMore && hasMorePages else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        do {
            let posts = try await authService.getUserPublications(
                username: username,
                page: currentPage,
                perPage: 30
            )
            
            let filteredPosts = posts.filter { post in
                post.parentId == nil && post.title != nil && !post.title!.isEmpty
            }
            
            await MainActor.run {
                self.publications.append(contentsOf: filteredPosts)
                self.hasMorePages = posts.count >= 30
                self.isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                self.currentPage -= 1
                self.isLoadingMore = false
            }
        }
    }
    
    private func refreshPublications() async {
        currentPage = 1
        
        do {
            let posts = try await authService.getUserPublications(
                username: username,
                page: currentPage,
                perPage: 30
            )
            
            let filteredPosts = posts.filter { post in
                post.parentId == nil && post.title != nil && !post.title!.isEmpty
            }
            
            await MainActor.run {
                self.publications = filteredPosts
                self.hasMorePages = posts.count >= 30
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Publication Card

struct PublicationCard: View {
    let post: PostRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = post.title {
                Text(title)
                    .font(.body)
                    .fontWeight(.regular)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange.opacity(0.8))
                    Text("\(post.tabcoins ?? 0)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let comments = post.childrenDeepCount {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("\(comments)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if let createdAt = post.createdAt {
                    Text(formatDate(createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(10)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return days == 1 ? "há 1 dia" : "há \(days) dias"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "há 1 hora" : "há \(hours) horas"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "há 1 minuto" : "há \(minutes) minutos"
        } else {
            return "agora"
        }
    }
}

#Preview {
    NavigationStack {
        UserPublicationsView(username: "filipedeschamps")
    }
}


// MARK: - Profile Sheet

/// Perfil de outro usuário, aberto ao tocar no @ em posts e comentários.
/// Sheet com NavigationStack própria para funcionar em qualquer tela que mostra um post.
struct UserProfileSheet: View {
    let username: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            UserPublicationsView(username: username, showsProfileHeader: true)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fechar") { dismiss() }
                    }
                }
        }
    }
}

/// Wrapper Identifiable para `.sheet(item:)`
struct ProfileTarget: Identifiable {
    let username: String
    var id: String { username }
}

//
//  SearchView.swift
//  newtabnews
//

import SwiftUI

struct SearchView: View {
    @Environment(MainViewModel.self) private var viewModel
    @Binding var searchText: String
    @Binding var isViewInApp: Bool
    var isTabActive: Bool = true
    @AppStorage("current_theme") var currentTheme: Theme = .light
    @Namespace private var zoomNamespace

    @State private var discoverVM = DiscoverViewModel()
    @State private var searchVM = SearchViewModel()
    @State private var isSearchPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    discoverContent
                } else {
                    searchResultsContent
                }
            }
            .navigationTitle("Buscar")
            .background(searchBackground)
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                prompt: "Pesquisar posts, @usuário ou link"
            )
            .onAppear {
                presentSearchField()
            }
            .onDisappear {
                isSearchPresented = false
            }
            .onChange(of: isTabActive) { _, isActive in
                if isActive {
                    presentSearchField()
                } else {
                    isSearchPresented = false
                }
            }
            .task {
                await discoverVM.load()
            }
            .onChange(of: searchText) { _, newValue in
                Task {
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        await searchVM.reset()
                    } else {
                        await searchVM.search(query: newValue, localPosts: viewModel.content)
                    }
                }
            }
        }
    }

    // MARK: - Discover

    @ViewBuilder
    private var discoverContent: some View {
        switch discoverVM.state {
        case .idle, .loading:
            ScrollView {
                DiscoverLoadingView()
                    .padding(.vertical, 16)
            }

        case .failed(let message):
            ScrollView {
                VStack(spacing: 16) {
                    FailureView(currentTheme: $currentTheme) {
                        Task {
                            await discoverVM.load(forceRefresh: true)
                        }
                    }

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 24)
            }

        case .loaded:
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let hero = discoverVM.sections?.hero {
                        NavigationLink {
                            ListDetailView(
                                isViewInApp: $isViewInApp,
                                currentTheme: $currentTheme,
                                post: hero
                            )
                            .environment(viewModel)
                            .postZoomDestination(id: hero.zoomTransitionID, namespace: zoomNamespace)
                        } label: {
                            DiscoverHeroCard(post: hero)
                        }
                        .buttonStyle(.plain)
                        .postZoomSource(id: hero.zoomTransitionID, namespace: zoomNamespace)
                        .padding(.horizontal)
                    }

                    if let sections = discoverVM.sections {
                        DiscoverBentoSectionView(
                            title: "Clássicos do TabNews",
                            subtitle: "",
                            posts: sections.classics,
                            isViewInApp: $isViewInApp,
                            currentTheme: $currentTheme,
                            zoomNamespace: zoomNamespace
                        )

                        DiscoverBentoSectionView(
                            title: "Vale a pena ler",
                            subtitle: "",
                            posts: sections.worthReading,
                            isViewInApp: $isViewInApp,
                            currentTheme: $currentTheme,
                            zoomNamespace: zoomNamespace
                        )

                        DiscoverBentoSectionView(
                            title: "Você pode ter perdido",
                            subtitle: "",
                            posts: sections.missed,
                            isViewInApp: $isViewInApp,
                            currentTheme: $currentTheme,
                            zoomNamespace: zoomNamespace
                        )
                    }

                    ForEach(PromotedContent.catalog) { card in
                        PromotedCardLink(
                            card: card,
                            isViewInApp: $isViewInApp,
                            size: .featured
                        )
                        .padding(.horizontal)
                    }

                    Text("Busque por @usuário, link do TabNews ou palavra-chave")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                }
                .padding(.top, 8)
            }
            .refreshable {
                await discoverVM.load(forceRefresh: true)
            }
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsContent: some View {
        switch searchVM.state {
        case .idle:
            if searchVM.mode == .author,
               let username = searchVM.authorUsername,
               username.count < SearchQueryParser.minimumUsernameLength {
                ContentUnavailableView {
                    Label("Continue digitando", systemImage: "at")
                } description: {
                    Text("O username precisa ter pelo menos \(SearchQueryParser.minimumUsernameLength) caracteres.")
                }
            } else if searchVM.mode == .author || searchVM.mode == .post {
                VStack(spacing: 12) {
                    if let mode = searchVM.mode {
                        SearchModeBadge(mode: mode)
                    }
                    Text("Aguardando você terminar de digitar…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("Buscando...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            ContentUnavailableView {
                Label("Erro na busca", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }

        case .empty:
            ContentUnavailableView {
                Label(emptyStateTitle, systemImage: "magnifyingglass")
            } description: {
                Text(emptyStateDescription)
            }

        case .loaded:
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let mode = searchVM.mode {
                        SearchModeBadge(mode: mode)
                            .padding(.horizontal)
                    }

                    if searchVM.mode == .author, let username = searchVM.authorUsername {
                        Text("@\(username)")
                            .font(.subheadline)
                            .padding(.horizontal)

                        Text("\(searchVM.results.count) publicações")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    if searchVM.mode == .local {
                        Text("Resultados no feed carregado")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(searchVM.results) { post in
                            NavigationLink {
                                ListDetailView(
                                    isViewInApp: $isViewInApp,
                                    currentTheme: $currentTheme,
                                    post: post
                                )
                                .environment(viewModel)
                                .postZoomDestination(id: post.zoomTransitionID, namespace: zoomNamespace)
                            } label: {
                                DiscoverPostCard(post: post, size: .list)
                            }
                            .buttonStyle(.plain)
                            .postZoomSource(id: post.zoomTransitionID, namespace: zoomNamespace)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .padding(.top, 8)
            }
        }
    }

    private var emptyStateTitle: String {
        switch searchVM.mode {
        case .author:
            return searchVM.authorNotFound ? "Autor não encontrado" : "Nenhuma publicação"
        case .post:
            return "Post não encontrado"
        case .local, .none:
            return "Nenhum resultado"
        }
    }

    private var emptyStateDescription: String {
        switch searchVM.mode {
        case .author:
            return searchVM.authorNotFound
                ? "Verifique se o @usuário está correto."
                : "Este usuário ainda não publicou posts."
        case .post:
            return "Verifique o link ou o formato usuario/slug."
        case .local, .none:
            return "Tente outra palavra-chave ou busque por @usuário."
        }
    }

    private var searchBackground: some View {
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

    private func presentSearchField() {
        DispatchQueue.main.async {
            isSearchPresented = true
        }
    }
}

private struct SearchModeBadge: View {
    let mode: SearchViewModel.Mode

    var body: some View {
        Text(mode.label)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.08))
            )
    }
}

// MARK: - Previews

#Preview("Discover") {
    let deps = AppDependencies.preview
    return SearchView(
        searchText: .constant(""),
        isViewInApp: .constant(true)
    )
    .environment(deps.makeMainViewModel())
}

#Preview("Search Results") {
    let deps = AppDependencies.preview
    return SearchView(
        searchText: .constant("swift"),
        isViewInApp: .constant(true)
    )
    .environment(deps.makeMainViewModel())
}

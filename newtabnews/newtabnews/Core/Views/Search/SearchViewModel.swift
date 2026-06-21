//
//  SearchViewModel.swift
//  newtabnews
//

import Foundation
import Observation

@Observable
final class SearchViewModel {
    enum Mode: Equatable {
        case author
        case post
        case local

        var label: String {
            switch self {
            case .author: return "Autor"
            case .post: return "Post"
            case .local: return "Feed local"
            }
        }
    }

    enum ResultState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(String)
    }

    private(set) var mode: Mode?
    private(set) var state: ResultState = .idle
    private(set) var results: [PostRequest] = []
    private(set) var authorUsername: String?
    /// `true` quando a API retorna 404; `false` quando o usuário existe mas não tem posts.
    private(set) var authorNotFound = false

    private let contentService: ContentServiceProtocol
    private let authService: AuthService
    private var searchTask: Task<Void, Never>?
    private var latestQuery = ""

    /// Filtro local no feed já carregado.
    private static let localDebounceNanoseconds: UInt64 = 400_000_000
    /// Busca na API (@usuário, link de post) — espera o usuário parar de digitar.
    private static let networkDebounceNanoseconds: UInt64 = 1_500_000_000

    init(
        contentService: ContentServiceProtocol = ContentService(),
        authService: AuthService = .shared
    ) {
        self.contentService = contentService
        self.authService = authService
    }

    @MainActor
    func search(query: String, localPosts: [PostRequest]) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        latestQuery = trimmed

        guard !trimmed.isEmpty else {
            reset()
            return
        }

        searchTask?.cancel()

        searchTask = Task { @MainActor in
            let currentQuery = latestQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !currentQuery.isEmpty else {
                reset()
                return
            }

            guard let parsedQuery = SearchQueryParser.parse(currentQuery) else {
                reset()
                return
            }

            func isCurrentQuery() -> Bool {
                latestQuery.trimmingCharacters(in: .whitespacesAndNewlines) == currentQuery
            }

            results = []
            authorNotFound = false

            if case .author(let username) = parsedQuery, username.count < SearchQueryParser.minimumUsernameLength {
                mode = .author
                authorUsername = username
                state = .idle
                return
            }

            let debounce = parsedQuery.requiresNetwork
                ? Self.networkDebounceNanoseconds
                : Self.localDebounceNanoseconds

            if parsedQuery.requiresNetwork {
                switch parsedQuery {
                case .author(let username):
                    mode = .author
                    authorUsername = username
                case .post:
                    mode = .post
                    authorUsername = nil
                case .local:
                    break
                }
                state = .idle
            }

            try? await Task.sleep(nanoseconds: debounce)
            guard !Task.isCancelled, isCurrentQuery() else { return }

            state = .loading
            if !parsedQuery.requiresNetwork {
                authorUsername = nil
            }

            do {
                switch parsedQuery {
                case .author(let username):
                    mode = .author
                    authorUsername = username
                    let posts = try await authService.getUserPublications(
                        username: username,
                        page: 1,
                        perPage: 30
                    )
                    guard !Task.isCancelled, isCurrentQuery() else { return }
                    results = posts.rootPostsOnly()
                    authorNotFound = false
                    state = results.isEmpty ? .empty : .loaded

                case .post(let user, let slug):
                    mode = .post
                    authorUsername = nil
                    let post = try await contentService.getPost(user: user, slug: slug)
                    guard !Task.isCancelled, isCurrentQuery() else { return }
                    results = [post]
                    state = .loaded

                case .local(let text):
                    mode = .local
                    authorUsername = nil
                    guard !Task.isCancelled, isCurrentQuery() else { return }
                    results = localPosts.filtered(by: text)
                    state = results.isEmpty ? .empty : .loaded
                }
            } catch let error as NetworkError {
                guard !Task.isCancelled, isCurrentQuery() else { return }
                results = []

                if case .author = parsedQuery,
                   case .apiError(let apiError) = error,
                   apiError.statusCode == 404 {
                    authorNotFound = true
                    state = .empty
                    return
                }

                state = .failed(error.localizedDescription)
            } catch {
                guard !Task.isCancelled, isCurrentQuery() else { return }
                results = []
                state = .failed(error.localizedDescription)
            }
        }

        await searchTask?.value
    }

    @MainActor
    func reset() {
        searchTask?.cancel()
        latestQuery = ""
        mode = nil
        state = .idle
        results = []
        authorUsername = nil
        authorNotFound = false
    }
}

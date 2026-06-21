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

    private let contentService: ContentServiceProtocol
    private let authService: AuthService
    private var searchTask: Task<Void, Never>?

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

        guard !trimmed.isEmpty else {
            reset()
            return
        }

        searchTask?.cancel()

        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }

            guard let parsedQuery = SearchQueryParser.parse(trimmed) else {
                reset()
                return
            }

            state = .loading
            results = []
            authorUsername = nil

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
                    guard !Task.isCancelled else { return }
                    results = posts.rootPostsOnly()
                    state = results.isEmpty ? .empty : .loaded

                case .post(let user, let slug):
                    mode = .post
                    let post = try await contentService.getPost(user: user, slug: slug)
                    guard !Task.isCancelled else { return }
                    results = [post]
                    state = .loaded

                case .local(let text):
                    mode = .local
                    guard !Task.isCancelled else { return }
                    results = localPosts.filtered(by: text)
                    state = results.isEmpty ? .empty : .loaded
                }
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                state = .failed(error.localizedDescription)
            }
        }

        await searchTask?.value
    }

    @MainActor
    func reset() {
        searchTask?.cancel()
        mode = nil
        state = .idle
        results = []
        authorUsername = nil
    }
}

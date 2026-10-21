//
//  DiscoverViewModel.swift
//  newtabnews
//

import Foundation
import Observation

@Observable
final class DiscoverViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: LoadState = .idle
    private(set) var sections: DiscoverSections?

    @ObservationIgnored private let service: DiscoverService
    @ObservationIgnored private var isFetching = false

    init(service: DiscoverService = DiscoverService()) {
        self.service = service

        // Com cache, a tela já abre com as seções, sem passar pelo skeleton
        if let cached = service.cachedSections() {
            sections = cached
            state = .loaded
        }
    }

    private var hasTodaySections: Bool {
        guard let sections else { return false }
        return Calendar.current.isDateInToday(sections.cachedAt)
    }

    /// Seções de outro dia continuam na tela enquanto as de hoje carregam.
    /// O skeleton só aparece quando não há nada salvo.
    @MainActor
    func load(forceRefresh: Bool = false) async {
        if !forceRefresh, hasTodaySections { return }
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        if sections == nil {
            state = .loading
        }

        do {
            sections = try await service.fetchSections()
            state = .loaded
        } catch {
            // Falhou mas tem seções antigas: melhor mostrá-las do que a tela de erro
            if sections == nil {
                state = .failed(error.localizedDescription)
            }
        }
    }
}

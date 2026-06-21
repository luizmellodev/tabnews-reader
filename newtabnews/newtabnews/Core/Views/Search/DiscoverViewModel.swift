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

    private let service: DiscoverService

    init(service: DiscoverService = DiscoverService()) {
        self.service = service
    }

    @MainActor
    func load(forceRefresh: Bool = false) async {
        if !forceRefresh, sections != nil, state == .loaded {
            return
        }

        state = .loading

        do {
            sections = try await service.loadSections(forceRefresh: forceRefresh)
            state = .loaded
        } catch {
            sections = nil
            state = .failed(error.localizedDescription)
        }
    }
}

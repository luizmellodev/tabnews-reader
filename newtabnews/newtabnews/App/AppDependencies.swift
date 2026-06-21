//
//  AppDependencies.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/12/25.
//

import Foundation

class AppDependencies {
    
    static let shared = AppDependencies()
    let contentService: ContentServiceProtocol
        
    init(contentService: ContentServiceProtocol? = nil) {
        self.contentService = contentService ?? ContentService()
    }
    
    func makeMainViewModel() -> MainViewModel {
        return MainViewModel(service: contentService)
    }
    
    func makeNewsletterViewModel() -> NewsletterViewModel {
        return NewsletterViewModel(service: contentService)
    }
    
    func makeDigestViewModel() -> DigestViewModel {
        return DigestViewModel(service: contentService)
    }

    func makeDiscoverViewModel() -> DiscoverViewModel {
        return DiscoverViewModel(service: DiscoverService(contentService: contentService))
    }

    func makeSearchViewModel() -> SearchViewModel {
        return SearchViewModel(contentService: contentService)
    }
}

extension AppDependencies {
    static var preview: AppDependencies {
        return AppDependencies(contentService: MockContentService.success)
    }
    
    static func test(service: ContentServiceProtocol) -> AppDependencies {
        return AppDependencies(contentService: service)
    }
}

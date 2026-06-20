//
//  AppTab.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/12/25.
//

import Foundation

enum AppTab: Int, CaseIterable, Hashable {
    case home = 0
    case library = 1
    case newsletter = 2
    case settings = 3
    case search = 4

    var title: String {
        switch self {
        case .home: return "Início"
        case .library: return "Biblioteca"
        case .newsletter: return "Newsletter"
        case .settings: return "Ajustes"
        case .search: return "Buscar"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .library: return "book.pages"
        case .newsletter: return "newspaper.fill"
        case .settings: return "gearshape.fill"
        case .search: return "magnifyingglass"
        }
    }
}

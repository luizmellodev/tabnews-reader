//
//  SearchView.swift
//  newtabnews
//

import SwiftUI

struct SearchView: View {
    @Environment(MainViewModel.self) private var viewModel
    @Binding var searchText: String
    @Binding var isViewInApp: Bool
    @AppStorage("current_theme") var currentTheme: Theme = .light
    @Namespace private var zoomNamespace

    private var filteredPosts: [PostRequest] {
        viewModel.content.filtered(by: searchText)
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    ContentUnavailableView {
                        Label("Buscar posts", systemImage: "magnifyingglass")
                    } description: {
                        Text("Digite para buscar nos posts carregados")
                    }
                } else if filteredPosts.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        ListView(
                            isViewInApp: $isViewInApp,
                            currentTheme: $currentTheme,
                            posts: filteredPosts,
                            zoomNamespace: zoomNamespace
                        )
                        .environment(viewModel)
                    }
                }
            }
            .navigationTitle("Buscar")
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
            .searchable(text: $searchText, prompt: "Pesquisar posts")
        }
    }
}

//
//  MainTabView.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/12/25.
//

import SwiftUI

/// TabView principal do app com todas as abas
struct MainTabView: View {
    @Binding var selectedTab: AppTab
    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme

    @Bindable var viewModel: MainViewModel
    @Bindable var newsletterVM: NewsletterViewModel

    @Binding var postToOpen: PostRequest?
    @Binding var isLoadingPost: Bool

    @State private var searchText = ""
    @StateObject private var reviewManager = AppReviewManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.icon, value: AppTab.home) {
                MainView(
                    isViewInApp: $isViewInApp,
                    postToOpen: $postToOpen,
                    isLoadingPost: $isLoadingPost
                )
            }

            Tab(AppTab.library.title, systemImage: AppTab.library.icon, value: AppTab.library) {
                FoldersView()
                    .environment(viewModel)
            }
            .badge(viewModel.readLaterList.isEmpty ? 0 : viewModel.readLaterList.count)

            Tab(AppTab.newsletter.title, systemImage: AppTab.newsletter.icon, value: AppTab.newsletter) {
                NewsletterView(
                    isViewInApp: $isViewInApp,
                    currentTheme: $currentTheme
                )
                .environment(newsletterVM)
                .environment(viewModel)
            }
            .badge(newsletterVM.unreadNewCount > 0 ? newsletterVM.unreadNewCount : 0)

            Tab(AppTab.settings.title, systemImage: AppTab.settings.icon, value: AppTab.settings) {
                SettingsView(
                    isViewInApp: $isViewInApp,
                    currentTheme: $currentTheme
                )
                .environment(viewModel)
                .onChange(of: isViewInApp) { _, newValue in
                    viewModel.defaults.set(newValue, forKey: "viewInApp")
                }
            }

            Tab(AppTab.search.title, systemImage: AppTab.search.icon, value: AppTab.search, role: .search) {
                SearchView(
                    searchText: $searchText,
                    isViewInApp: $isViewInApp,
                    isTabActive: selectedTab == .search
                )
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(viewModel)
        .task {
            await newsletterVM.refreshUnreadBadge()
        }
        .alert("Gostando do TabNews Reader?", isPresented: $reviewManager.showPrePrompt) {
            Button("Sim, estou gostando") {
                reviewManager.confirmPositiveReview()
            }
            Button("Ainda não", role: .cancel) {
                reviewManager.dismissPrePrompt()
            }
        } message: {
            Text("Sua avaliação na App Store ajuda muito o app a crescer.")
        }
    }
}

// MARK: - Previews

#Preview("Tab Home") {
    let deps = AppDependencies.preview
    return MainTabView(
        selectedTab: .constant(.home),
        isViewInApp: .constant(true),
        currentTheme: .constant(.system),
        viewModel: deps.makeMainViewModel(),
        newsletterVM: deps.makeNewsletterViewModel(),
        postToOpen: .constant(nil),
        isLoadingPost: .constant(false)
    )
}

#Preview("Tab Newsletter") {
    let deps = AppDependencies.preview
    return MainTabView(
        selectedTab: .constant(.newsletter),
        isViewInApp: .constant(true),
        currentTheme: .constant(.system),
        viewModel: deps.makeMainViewModel(),
        newsletterVM: deps.makeNewsletterViewModel(),
        postToOpen: .constant(nil),
        isLoadingPost: .constant(false)
    )
}

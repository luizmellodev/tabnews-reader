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
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MainView(
                isViewInApp: $isViewInApp,
                postToOpen: $postToOpen,
                isLoadingPost: $isLoadingPost
            )
                .tabItem {
                    Label(AppTab.home.title, systemImage: AppTab.home.icon)
                }
                .tag(AppTab.home)
            
            FoldersView()
                .tabItem {
                    Label(AppTab.library.title, systemImage: AppTab.library.icon)
                }
                .badge(viewModel.readLaterList.isEmpty ? 0 : viewModel.readLaterList.count)
                .environment(viewModel)
                .tag(AppTab.library)
            
            NewsletterView(
                isViewInApp: $isViewInApp,
                currentTheme: $currentTheme
            )
                .tabItem {
                    Label(AppTab.newsletter.title, systemImage: AppTab.newsletter.icon)
                }
                .badge(newsletterVM.unreadNewCount > 0 ? newsletterVM.unreadNewCount : 0)
                .environment(newsletterVM)
                .environment(viewModel)
                .tag(AppTab.newsletter)
            
            SettingsView(
                isViewInApp: $isViewInApp,
                currentTheme: $currentTheme
            )
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
            }
            .environment(viewModel)
            .onChange(of: isViewInApp) { _, newValue in
                viewModel.defaults.set(newValue, forKey: "viewInApp")
            }
            .tag(AppTab.settings)
        }
        .environment(viewModel)
        .task {
            await newsletterVM.refreshUnreadBadge()
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


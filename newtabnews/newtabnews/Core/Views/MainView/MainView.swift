//
//  MainView.swift
//  newtabnews
//
//  Created by Luiz Mello on 22/07/23.
//

import SwiftUI

struct MainView: View {

    @Environment(MainViewModel.self) private var viewModel
    @AppStorage("current_theme") var currentTheme: Theme = .light

    @Binding var isViewInApp: Bool
    @State private var isLoadingStrategy = false
    @AppStorage("debugShowDigestBanner") private var debugShowDigestBanner = false
    @AppStorage("debugShowDailyDigestBanner") private var debugShowDailyDigestBanner = false
    @State private var showDigestSheet = false
    @State private var showDailyDigestSheet = false
    @StateObject private var dailyDigestManager = DailyDigestManager.shared
    @Namespace private var zoomNamespace

    @Binding var postToOpen: PostRequest?
    @Binding var isLoadingPost: Bool

    private var shouldShowDigestBanner: Bool {
        #if DEBUG
        if debugShowDigestBanner {
            return true
        }
        #endif

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        return weekday == 7 || weekday == 1
    }

    private var shouldShowDailyDigestBanner: Bool {
        #if DEBUG
        if debugShowDailyDigestBanner {
            return true
        }
        #endif

        return dailyDigestManager.shouldShowBanner()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ContentStrategyPicker(
                        selection: viewModel.currentStrategy,
                        isLoading: isLoadingStrategy
                    ) { strategy in
                        Task {
                            isLoadingStrategy = true
                            await viewModel.reloadForStrategy(strategy)
                            isLoadingStrategy = false
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 2)

                    if shouldShowDailyDigestBanner {
                        DailyDigestBanner {
                            dailyDigestManager.markAsViewed()
                            showDailyDigestSheet = true
                        }
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if shouldShowDigestBanner {
                        DigestBannerView {
                            showDigestSheet = true
                        }
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    feedContent
                        .padding(.horizontal)
                        .padding(.top, 5)
                }
            }
            .refreshable {
                await refreshContent()
            }
            .animation(.spring(), value: shouldShowDigestBanner)
            .animation(.spring(), value: shouldShowDailyDigestBanner)
            .navigationTitle("Tab News")
            .navigationBarTitleDisplayMode(.large)
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
            .navigationDestination(item: $postToOpen) { post in
                ListDetailView(
                    isViewInApp: $isViewInApp,
                    currentTheme: $currentTheme,
                    post: post
                )
                .environment(viewModel)
                .postZoomDestination(id: post.zoomTransitionID, namespace: zoomNamespace)
            }
            .overlay {
                if isLoadingPost {
                    LoadingOverlayView(message: "Carregando post...")
                }
            }
            .sheet(isPresented: $showDigestSheet) {
                NavigationStack {
                    DigestListView()
                        .navigationTitle("Resumo Semanal")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Fechar") {
                                    showDigestSheet = false
                                }
                            }
                        }
                }
                .environment(viewModel)
                .presentationDragIndicator(.hidden)
                .presentationDetents([.large])
                .interactiveDismissDisabled(false)
            }
            .sheet(isPresented: $showDailyDigestSheet) {
                DailyDigestView(
                    isViewInApp: $isViewInApp,
                    currentTheme: $currentTheme
                )
                .presentationDragIndicator(.hidden)
                .presentationDetents([.large])
            }
        }
    }

    @ViewBuilder
    private var feedContent: some View {
        switch viewModel.state {
        case .loading:
            SkeletonListView()
                .transition(.opacity)

        case .requestSucceeded:
            ListView(
                isViewInApp: $isViewInApp,
                currentTheme: $currentTheme,
                posts: viewModel.content,
                zoomNamespace: zoomNamespace
            )
            .environment(viewModel)
            .transition(.opacity)
            .id(viewModel.currentStrategy)

        case .requestFailed:
            FailureView(currentTheme: $currentTheme) {
                Task {
                    await viewModel.resetPagination()
                }
            }
            .transition(.opacity)

        default:
            SkeletonListView()
                .transition(.opacity)
        }
    }

    private func refreshContent() async {
        await viewModel.resetPagination()
    }
}

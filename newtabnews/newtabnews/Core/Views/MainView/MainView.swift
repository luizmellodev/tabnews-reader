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
    @GestureState var press = false
    
    @State private var keyboardHeight: CGFloat = 0
    @State var searchText: String = ""
    @State var showSnack: Bool = false
    @State var isSearching = false
    @Binding var isViewInApp: Bool
    @State private var scrollOffset: CGFloat = 0
    @State private var isLoadingStrategy = false
    @AppStorage("debugShowDigestBanner") private var debugShowDigestBanner = false
    @AppStorage("debugShowDailyDigestBanner") private var debugShowDailyDigestBanner = false
    @State private var showDigestSheet = false
    @State private var showDailyDigestSheet = false
    @StateObject private var dailyDigestManager = DailyDigestManager.shared
    @Namespace private var zoomNamespace

    @Binding var postToOpen: PostRequest?
    @Binding var isLoadingPost: Bool
    
    // Verifica se é fim de semana - sábado ou domingo (ou modo debug ativado)
    private var shouldShowDigestBanner: Bool {
        #if DEBUG
        if debugShowDigestBanner {
            return true
        }
        #endif
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        return weekday == 7 || weekday == 1 // 7 = Sábado, 1 = Domingo
    }
    
    // Verifica se deve mostrar o Daily Digest banner (às 18h)
    private var shouldShowDailyDigestBanner: Bool {
        #if DEBUG
        if debugShowDailyDigestBanner {
            return true
        }
        #endif
        
        return dailyDigestManager.shouldShowBanner()
    }
    
    var body: some View {
        @Bindable var bindableViewModel = viewModel
        
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.state == .requestSucceeded || isLoadingStrategy {
                    Picker("Filtro", selection: $bindableViewModel.currentStrategy) {
                        ForEach(ContentStrategy.allCases, id: \.self) { strategy in
                            Label(strategy.displayName, systemImage: strategy.icon)
                                .tag(strategy)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .disabled(isLoadingStrategy)
                    .onChange(of: bindableViewModel.currentStrategy) { _, newStrategy in
                        Task {
                            isLoadingStrategy = true
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.state = .loading
                            }
                            await viewModel.fetchContent(with: newStrategy)
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isLoadingStrategy = false
                            }
                        }
                    }
                }
                
                Group {
                    switch viewModel.state {
                    case .loading:
                        SkeletonListView()
                            .transition(.opacity)
                        
                    case .requestSucceeded:
                        ScrollView {
                            VStack(spacing: 16) {
                                // Banner de Daily Digest (às 18h)
                                if shouldShowDailyDigestBanner {
                                    DailyDigestBanner {
                                        dailyDigestManager.markAsViewed()
                                        showDailyDigestSheet = true
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                                
                                // Banner de Digest (só aos sábados ou em debug)
                                if shouldShowDigestBanner {
                                    DigestBannerView {
                                        // Abre sheet com DigestListView
                                        showDigestSheet = true
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, shouldShowDailyDigestBanner ? 0 : 8)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                                
                                ListView(
                                    searchText: $searchText,
                                    isViewInApp: $isViewInApp,
                                    currentTheme: $currentTheme,
                                    posts: viewModel.content,
                                    zoomNamespace: zoomNamespace
                                )
                                .environment(viewModel)
                            }
                            .padding(.top, 5)
                        }
                        .refreshable {
                            await refreshContent()
                        }
                        .transition(.opacity)
                        .id(viewModel.currentStrategy)
                        .animation(.spring(), value: shouldShowDigestBanner)
                        .animation(.spring(), value: shouldShowDailyDigestBanner)
                        
                    case .requestFailed:
                        FailureView(currentTheme: $currentTheme)
                            .transition(.opacity)
                    default:
                        SkeletonListView()
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.state)
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentStrategy)
            }
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
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Pesquisar")
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
    
    private func refreshContent() async {
        await viewModel.resetPagination()
    }
}

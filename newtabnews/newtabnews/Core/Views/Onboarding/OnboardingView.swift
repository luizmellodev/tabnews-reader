//
//  OnboardingView.swift
//  newtabnews
//
//  Created by Luiz Mello on 31/03/25.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "TabNews",
            subtitle: "O app não oficial da sua plataforma favorita de conteúdo de tecnologia",
            imageName: "square.text.square.fill",
            secondaryImageName: "square.text.square"
        ),
        OnboardingPage(
            title: "Notificações",
            subtitle: "Receba notificações locais sobre novas newsletters. Simples e direto.",
            imageName: "bell.fill",
            secondaryImageName: "bell.badge"
        ),
        OnboardingPage(
            title: "Leitura",
            subtitle: "Escolha como quer ler: no app ou no site oficial. Recomendamos o site para uma experiência markdown completa",
            imageName: "doc.text.fill",
            secondaryImageName: "arrow.up.forward.app"
        ),
        OnboardingPage(
            title: "Jogos Dev",
            subtitle: "Descanse entre as leituras com DevWordle, DevSpot, Color Match e Sound Match. Dispute rankings no Game Center!",
            imageName: "gamecontroller.fill",
            secondaryImageName: "trophy.fill"
        ),
        OnboardingPage(
            title: "Além do App",
            subtitle: "Widgets para tela inicial, Apple Watch e muito mais. Seu TabNews em todos os lugares!",
            imageName: "applewatch",
            secondaryImageName: "square.grid.2x2"
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("Background")
                    .ignoresSafeArea()
                Image("ruido")
                    .resizable()
                    .scaledToFill()
                    .blendMode(.overlay)
                    .ignoresSafeArea()
                
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(
                            page: pages[index],
                            isLast: index == pages.count - 1,
                            screenSize: geometry.size,
                            completion: {
                                withAnimation {
                                    showOnboarding = false
                                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                                    UserDefaults.standard.set(true, forKey: RestGamesAnnouncement.storageKey)
                                    // Garantir que os tips vão aparecer após o onboarding inicial
                                    UserDefaults.standard.set(false, forKey: "hasSeenTipsOnboarding")
                                }
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.primary : Color.primary.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .scaleEffect(currentPage == index ? 1.2 : 1)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding()
                .offset(y: geometry.size.height * 0.4)
            }
        }
    }
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let secondaryImageName: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let isLast: Bool
    let screenSize: CGSize
    let completion: () -> Void
    
    @State private var showContent = false
    @State private var showSecondaryImage = false
    @State private var rotationAngle = 0.0
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated icons
            ZStack {
                Image(systemName: page.imageName)
                    .font(.system(size: 65, weight: .light))
                    .foregroundStyle(.primary)
                    .rotationEffect(.degrees(showContent ? 360 : 0))
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.5)
                
                Image(systemName: page.secondaryImageName)
                    .font(.system(size: 35, weight: .light))
                    .foregroundStyle(.primary.opacity(0.7))
                    .offset(x: showSecondaryImage ? 30 : 0, y: showSecondaryImage ? -30 : 0)
                    .rotationEffect(.degrees(showSecondaryImage ? 15 : 0))
                    .opacity(showSecondaryImage ? 1 : 0)
                    .scaleEffect(showSecondaryImage ? 1 : 0.5)
            }
            .frame(height: screenSize.height * 0.2)
            
            VStack(spacing: 24) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                
                Text(page.subtitle)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
            }
            
            Spacer()
            
            if isLast {
                Button {
                    completion()
                } label: {
                    Text("Começar")
                        .font(.headline)
                        .foregroundStyle(.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary)
                        }
                        .padding(.horizontal, 32)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            }
            
            Spacer()
                .frame(height: 100)
        }
        .padding()
        .onAppear {
            withAnimation(.spring(duration: 0.7)) {
                showContent = true
            }
            
            withAnimation(.spring(duration: 0.7).delay(0.3)) {
                showSecondaryImage = true
            }
            
            // Continuous rotation animation for icons
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
        .onDisappear {
            showContent = false
            showSecondaryImage = false
        }
    }
}

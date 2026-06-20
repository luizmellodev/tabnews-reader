//
//  SplashView.swift
//  newtabnews
//

import SwiftUI

struct SplashView: View {
    @Binding var showSplash: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var logoOffsetX: CGFloat = 0
    @State private var logoOffsetY: CGFloat = 0
    @State private var logoScale: CGFloat = 1
    @State private var logoOpacity: Double = 1
    @State private var titleOpacity: Double = 0
    @State private var titleOffsetY: CGFloat = 12
    @State private var titleBlur: CGFloat = 8
    @State private var splashOpacity: Double = 1

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

                VStack(spacing: 20) {
                    Image("TabnewsLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .foregroundStyle(.primary)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .offset(x: logoOffsetX, y: logoOffsetY)

                    Text("TabNews")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.primary)
                        .opacity(titleOpacity)
                        .offset(y: titleOffsetY)
                        .blur(radius: titleBlur)
                }
            }
            .opacity(splashOpacity)
            .onAppear {
                if reduceMotion {
                    runReducedMotionSequence()
                } else {
                    runAnimationSequence(in: geometry.size)
                }
            }
        }
        .ignoresSafeArea()
    }

    @MainActor
    private func runAnimationSequence(in size: CGSize) {
        logoOffsetX = -size.width * 0.6

        Task { @MainActor in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                logoOffsetX = 0
            }
            try? await Task.sleep(nanoseconds: 550_000_000)

            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                titleOpacity = 1
                titleOffsetY = 0
                titleBlur = 0
            }
            try? await Task.sleep(nanoseconds: 650_000_000)

            withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                logoScale = 2.2
                logoOffsetY = -size.height * 0.28
                logoOpacity = 0
                titleOpacity = 0
                titleBlur = 4
            }
            try? await Task.sleep(nanoseconds: 650_000_000)

            withAnimation(.easeOut(duration: 0.35)) {
                splashOpacity = 0
            }
            try? await Task.sleep(nanoseconds: 350_000_000)

            showSplash = false
        }
    }

    @MainActor
    private func runReducedMotionSequence() {
        logoOffsetX = 0
        titleOpacity = 1
        titleOffsetY = 0
        titleBlur = 0

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)

            withAnimation(.easeOut(duration: 0.3)) {
                splashOpacity = 0
            }
            try? await Task.sleep(nanoseconds: 300_000_000)

            showSplash = false
        }
    }
}

#Preview {
    SplashView(showSplash: .constant(true))
}

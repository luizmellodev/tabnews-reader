//
//  SplashView.swift
//  newtabnews
//

import SwiftUI

struct SplashView: View {
    @Binding var showSplash: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let title = "TabNews"
    private static let logoSize = CGSize(width: 84, height: 67)
    /// Escala final do zoom: grande o bastante para o furo da pasta cobrir a tela toda.
    private static let revealScale: CGFloat = 40

    @State private var outlineProgress: CGFloat = 0
    @State private var fillOpacity: Double = 0
    @State private var logoScale: CGFloat = 1
    @State private var lettersShown = 0
    @State private var titleOpacity: Double = 1
    /// A partir daqui o furo da pasta fica transparente e mostra o app por baixo.
    @State private var isRevealing = false
    @State private var splashOpacity: Double = 1

    var body: some View {
        ZStack {
            Color("Background")

            Image("ruido")
                .resizable()
                .scaledToFill()
                .blendMode(.overlay)

            logo
                .frame(width: Self.logoSize.width, height: Self.logoSize.height)
                .scaleEffect(logoScale)

            animatedTitle
                .opacity(titleOpacity)
                .offset(y: Self.logoSize.height / 2 + 40)
        }
        .compositingGroup()
        .mask {
            SplashRevealMask(logoSize: Self.logoSize, scale: logoScale, isRevealing: isRevealing)
                .fill(style: FillStyle(eoFill: true))
        }
        .opacity(splashOpacity)
        .ignoresSafeArea()
        .onAppear {
            if reduceMotion {
                runReducedMotionSequence()
            } else {
                runAnimationSequence()
            }
        }
    }

    // MARK: - Subviews

    private var logo: some View {
        ZStack {
            // Contorno sendo "desenhado"
            TabNewsLogoOutline()
                .trim(from: 0, to: outlineProgress)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .opacity(1 - fillOpacity)

            // Preenchimento final, igual ao asset TabnewsLogo
            TabNewsLogoShape()
                .fill(Color.primary, style: FillStyle(eoFill: true))
                .opacity(fillOpacity)
        }
    }

    private var animatedTitle: some View {
        HStack(spacing: 0) {
            ForEach(Array(title.enumerated()), id: \.offset) { index, letter in
                Text(String(letter))
                    .opacity(index < lettersShown ? 1 : 0)
                    .offset(y: index < lettersShown ? 0 : 10)
                    .blur(radius: index < lettersShown ? 0 : 4)
            }
        }
        .font(.title.weight(.semibold))
        .foregroundStyle(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    // MARK: - Sequences

    @MainActor
    private func runAnimationSequence() {
        Task { @MainActor in
            // 1. Desenha o contorno
            withAnimation(.easeInOut(duration: 0.55)) {
                outlineProgress = 1
            }
            try? await Task.sleep(nanoseconds: 500_000_000)

            // 2. Preenche com um "pop"
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.2)) {
                fillOpacity = 1
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                logoScale = 1.12
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                logoScale = 1
            }

            // 3. Título entra letra a letra
            for index in 1...title.count {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    lettersShown = index
                }
                try? await Task.sleep(nanoseconds: 35_000_000)
            }
            try? await Task.sleep(nanoseconds: 380_000_000)

            // 4. Saída: a pasta do logo vira uma janela e cresce até revelar o app
            isRevealing = true
            withAnimation(.easeOut(duration: 0.15)) {
                titleOpacity = 0
            }
            withAnimation(.timingCurve(0.7, 0, 0.84, 0, duration: 0.6)) {
                logoScale = Self.revealScale
            }
            try? await Task.sleep(nanoseconds: 600_000_000)

            showSplash = false
        }
    }

    @MainActor
    private func runReducedMotionSequence() {
        outlineProgress = 1
        fillOpacity = 1
        lettersShown = title.count

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

/// Máscara da splash: a tela inteira, menos o furo da pasta do logo durante a revelação.
/// Acompanha a mesma escala do logo, centralizada na tela.
private struct SplashRevealMask: Shape {
    let logoSize: CGSize
    var scale: CGFloat
    let isRevealing: Bool

    var animatableData: CGFloat {
        get { scale }
        set { scale = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        guard isRevealing else { return path }

        let size = CGSize(width: logoSize.width * scale, height: logoSize.height * scale)
        let logoRect = CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        path.addPath(TabNewsLogoGeometry.hole(in: logoRect))
        return path
    }
}

// MARK: - Logo Shapes

/// Geometria do logo do TabNews (asset `TabnewsLogo`), em coordenadas de referência 1610x1286
/// normalizadas para o rect recebido. Moldura arredondada com um "furo" em formato de pasta.
private enum TabNewsLogoGeometry {
    static let size = CGSize(width: 1610, height: 1286)

    static func outer(in rect: CGRect) -> Path {
        Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 240)
            .applying(transform(for: rect))
    }

    static func hole(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 162, y: 239))
        path.addArc(tangent1End: CGPoint(x: 162, y: 161), tangent2End: CGPoint(x: 240, y: 161), radius: 78)
        path.addLine(to: CGPoint(x: 697, y: 161))
        path.addLine(to: CGPoint(x: 777, y: 368))
        path.addQuadCurve(to: CGPoint(x: 885, y: 453), control: CGPoint(x: 810, y: 453))
        path.addLine(to: CGPoint(x: 1450, y: 453))
        path.addLine(to: CGPoint(x: 1450, y: 1048))
        path.addArc(tangent1End: CGPoint(x: 1450, y: 1126), tangent2End: CGPoint(x: 1372, y: 1126), radius: 78)
        path.addLine(to: CGPoint(x: 240, y: 1126))
        path.addArc(tangent1End: CGPoint(x: 162, y: 1126), tangent2End: CGPoint(x: 162, y: 1048), radius: 78)
        path.closeSubpath()
        return path.applying(transform(for: rect))
    }

    private static func transform(for rect: CGRect) -> CGAffineTransform {
        let scale = min(rect.width / size.width, rect.height / size.height)
        let dx = rect.minX + (rect.width - size.width * scale) / 2
        let dy = rect.minY + (rect.height - size.height * scale) / 2
        return CGAffineTransform(translationX: dx, y: dy).scaledBy(x: scale, y: scale)
    }
}

/// Logo preenchido (usar com `eoFill` para o furo da pasta ficar vazado)
private struct TabNewsLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = TabNewsLogoGeometry.outer(in: rect)
        path.addPath(TabNewsLogoGeometry.hole(in: rect))
        return path
    }
}

/// Contorno da pasta interna seguido da moldura, para a animação de "desenho" com `trim`
private struct TabNewsLogoOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = TabNewsLogoGeometry.hole(in: rect)
        path.addPath(TabNewsLogoGeometry.outer(in: rect))
        return path
    }
}

#Preview {
    SplashView(showSplash: .constant(true))
}

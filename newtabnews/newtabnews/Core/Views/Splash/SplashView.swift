//
//  SplashView.swift
//  newtabnews
//

import SwiftUI

struct SplashView: View {
    @Binding var showSplash: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let title = "TabNews"

    @State private var outlineProgress: CGFloat = 0
    @State private var fillOpacity: Double = 0
    @State private var logoScale: CGFloat = 1
    @State private var logoOffsetY: CGFloat = 0
    @State private var logoOpacity: Double = 1
    @State private var typedCount = 0
    @State private var showCursor = false
    @State private var cursorVisible = true
    @State private var titleOpacity: Double = 1
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

                VStack(spacing: 22) {
                    logo
                        .frame(width: 84, height: 67)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .offset(y: logoOffsetY)

                    typedTitle
                        .opacity(titleOpacity)
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

    // MARK: - Subviews

    private var logo: some View {
        ZStack {
            // Contorno sendo "desenhado"
            TabNewsLogoOutline()
                .trim(from: 0, to: outlineProgress)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            // Preenchimento final, igual ao asset TabnewsLogo
            TabNewsLogoShape()
                .fill(Color.primary, style: FillStyle(eoFill: true))
                .opacity(fillOpacity)
        }
    }

    private var typedTitle: some View {
        // Texto completo invisível reserva a largura final, evitando que o título "ande" enquanto digita
        ZStack(alignment: .leading) {
            Text(title).opacity(0)

            // Cursor acompanha as letras já digitadas
            HStack(spacing: 1) {
                Text(String(title.prefix(typedCount)))

                Rectangle()
                    .frame(width: 3, height: 28)
                    .opacity(showCursor && cursorVisible ? 1 : 0)
            }
        }
        .font(.title.weight(.semibold))
        .foregroundStyle(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    // MARK: - Sequences

    @MainActor
    private func runAnimationSequence(in size: CGSize) {
        Task { @MainActor in
            // 1. Desenha o contorno
            withAnimation(.easeInOut(duration: 0.7)) {
                outlineProgress = 1
            }
            try? await Task.sleep(nanoseconds: 650_000_000)

            // 2. Preenche com um "pop"
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.25)) {
                fillOpacity = 1
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                logoScale = 1.12
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                logoScale = 1
            }

            // 3. Digita o título com cursor piscando
            showCursor = true
            for index in 1...title.count {
                try? await Task.sleep(nanoseconds: 55_000_000)
                typedCount = index
            }
            for _ in 0..<3 {
                try? await Task.sleep(nanoseconds: 180_000_000)
                cursorVisible.toggle()
            }
            showCursor = false

            // 4. Saída: logo cresce e sobe enquanto tudo some
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                logoScale = 2.2
                logoOffsetY = -size.height * 0.25
                logoOpacity = 0
                titleOpacity = 0
            }
            try? await Task.sleep(nanoseconds: 400_000_000)

            withAnimation(.easeOut(duration: 0.3)) {
                splashOpacity = 0
            }
            try? await Task.sleep(nanoseconds: 300_000_000)

            showSplash = false
        }
    }

    @MainActor
    private func runReducedMotionSequence() {
        outlineProgress = 1
        fillOpacity = 1
        typedCount = title.count

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

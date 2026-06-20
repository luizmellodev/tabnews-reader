//
//  SkeletonCard.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/11/25.
//

import SwiftUI

enum CardLayout {
    static let bodyLineLimit = 6
    static let cardHeight: CGFloat = 350
    static let bodyPreviewMinHeight: CGFloat = 108
}

struct SkeletonShimmer: View {
    @State private var phase: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    private var gradient: LinearGradient {
        let baseColor = colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.25)
        let shimmerColor = colorScheme == .dark ? Color.gray.opacity(0.35) : Color.gray.opacity(0.15)

        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: baseColor, location: phase - 0.3),
                .init(color: shimmerColor, location: phase),
                .init(color: baseColor, location: phase + 0.3)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        Rectangle()
            .fill(gradient)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2
                }
            }
    }
}

struct CardBodySkeleton: View {
    var lineCount: Int = CardLayout.bodyLineLimit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<lineCount, id: \.self) { index in
                SkeletonShimmer()
                    .frame(height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(maxWidth: index == lineCount - 1 ? 200 : .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: CardLayout.bodyPreviewMinHeight, alignment: .topLeading)
    }
}

struct SkeletonCard: View {
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonShimmer()
                        .frame(height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .frame(maxWidth: .infinity)

                    SkeletonShimmer()
                        .frame(height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .frame(maxWidth: 250)
                }
                .padding(.bottom, 5)
                .padding(.top, 20)

                HStack {
                    SkeletonShimmer()
                        .frame(width: 100, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Spacer()

                    SkeletonShimmer()
                        .frame(width: 60, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    SkeletonShimmer()
                        .frame(width: 80, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.bottom, 12)

                Divider()
                    .opacity(0.3)
                    .padding(.bottom, 12)

                CardBodySkeleton()
                    .padding(.bottom, 20)

                SkeletonShimmer()
                    .frame(height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .padding(.bottom, 10)
            }
        }
        .padding(.horizontal)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color("CardColor"))
        }
        .frame(height: CardLayout.cardHeight)
    }
}

#Preview {
    SkeletonCard()
        .preferredColorScheme(.dark)
}

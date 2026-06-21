//
//  DiscoverHeroCard.swift
//  newtabnews
//

import SwiftUI

struct DiscoverHeroCard: View {
    let post: PostRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Surpresa do dia")
                .font(.caption2)
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.tertiary)

            Text(post.title ?? "Sem título")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .lineSpacing(1)

            DiscoverPostMetadata(post: post)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color("CardColor"))
        )
    }
}

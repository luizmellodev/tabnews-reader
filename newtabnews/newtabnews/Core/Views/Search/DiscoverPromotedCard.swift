//
//  DiscoverPromotedCard.swift
//  newtabnews
//

import SwiftUI

struct DiscoverPromotedCard: View {
    let card: PromotedCard
    var size: DiscoverPostCard.DiscoverCardSize = .compact

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("(AD)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 0)
            }

            Text(card.title)
                .font(titleFont)
                .foregroundStyle(.primary)
                .lineLimit(titleLineLimit)
                .multilineTextAlignment(.leading)
                .lineSpacing(0)
                .frame(maxWidth: .infinity, alignment: .leading)

            if size != .list {
                Spacer(minLength: 0)
            }

            promotedMetadata
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            minHeight: minHeight,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color("CardColor"))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.title). Anúncio.")
        .accessibilityHint("Abre \(card.destinationLabel) na web")
        .accessibilityAddTraits(.isButton)
    }

    private var promotedMetadata: some View {
        HStack(spacing: 0) {
            Text("@\(card.authorLabel)")
                .lineLimit(1)

            Spacer(minLength: 6)

            HStack(spacing: 3) {
                Text(card.destinationLabel)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .semibold))
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var titleFont: Font {
        switch size {
        case .featured:
            return .subheadline
        case .compact, .list:
            return .footnote
        }
    }

    private var titleLineLimit: Int {
        switch size {
        case .featured: return 4
        case .compact: return 3
        case .list: return 3
        }
    }

    private var minHeight: CGFloat? {
        switch size {
        case .featured: return 120
        case .compact: return 100
        case .list: return nil
        }
    }
}

struct PromotedCardLink: View {
    let card: PromotedCard
    @Binding var isViewInApp: Bool
    var size: DiscoverPostCard.DiscoverCardSize = .featured

    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if isViewInApp {
                NavigationLink {
                    ExternalWebView(url: card.url, title: card.destinationLabel)
                } label: {
                    DiscoverPromotedCard(card: card, size: size)
                }
            } else {
                Button {
                    openURL(card.url)
                } label: {
                    DiscoverPromotedCard(card: card, size: size)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PromotedCardLink(
        card: PromotedContent.catalog[0],
        isViewInApp: .constant(true)
    )
    .padding()
}

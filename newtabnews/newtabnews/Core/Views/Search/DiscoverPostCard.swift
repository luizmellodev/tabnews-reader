//
//  DiscoverPostCard.swift
//  newtabnews
//

import SwiftUI

struct DiscoverPostCard: View {
    let post: PostRequest
    var size: DiscoverCardSize = .compact

    enum DiscoverCardSize {
        case featured
        case compact
        case list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.title ?? "Sem título")
                .font(titleFont)
                .foregroundStyle(.primary)
                .lineLimit(titleLineLimit)
                .multilineTextAlignment(.leading)
                .lineSpacing(0)
                .frame(maxWidth: .infinity, alignment: .leading)

            if size != .list {
                Spacer(minLength: 0)
            }

            DiscoverPostMetadata(post: post, compact: size == .compact)
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

struct DiscoverPostMetadata: View {
    let post: PostRequest
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                if let username = post.ownerUsername {
                    Text("@\(username)")
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text(DiscoverDateFormatter.relativeDate(from: post.createdAt))
            }

            Text("\(post.tabcoins ?? 0) tabcoins")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

enum DiscoverDateFormatter {
    static func relativeDate(from dateString: String?) -> String {
        guard let dateString,
              let date = parseDate(dateString) else {
            return "Data indisponível"
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: Date())

        if let days = components.day, days > 0 {
            return days == 1 ? "há 1 dia" : "há \(days) dias"
        }

        if let hours = components.hour, hours > 0 {
            return hours == 1 ? "há 1 hora" : "há \(hours) horas"
        }

        if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "há 1 minuto" : "há \(minutes) minutos"
        }

        return "agora"
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

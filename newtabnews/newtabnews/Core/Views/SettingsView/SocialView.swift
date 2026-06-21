//
//  SocialView.swift
//  newtabnews
//
//  Created by Luiz Mello on 31/03/25.
//

import SwiftUI

enum SocialPlatform: String, Identifiable {
    case website
    case instagram
    case github
    case linkedin
    case youtube

    var id: String { rawValue }

    var label: String {
        switch self {
        case .website: "Site"
        case .instagram: "Instagram"
        case .github: "GitHub"
        case .linkedin: "LinkedIn"
        case .youtube: "YouTube"
        }
    }

    var icon: String {
        switch self {
        case .website: "globe"
        case .instagram: "camera.fill"
        case .github: "chevron.left.forwardslash.chevron.right"
        case .linkedin: "link"
        case .youtube: "play.rectangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .website: .blue
        case .instagram: .pink
        case .github: .primary
        case .linkedin: .blue
        case .youtube: .red
        }
    }
}

struct CreatorInfo {
    let name: String
    let role: String
    let accent: Color
    let github: String
    let linkedin: String
    let youtube: String
    let instagram: String
    var website: String? = nil

    var socialLinks: [(SocialPlatform, String)] {
        var links: [(SocialPlatform, String)] = []
        if let website { links.append((.website, website)) }
        links.append(contentsOf: [
            (.instagram, instagram),
            (.github, github),
            (.linkedin, linkedin),
        ])
        if !youtube.isEmpty { links.append((.youtube, youtube)) }
        return links
    }
}

enum SocialLinkOpener {
    static func open(platform: SocialPlatform, value: String) {
        switch platform {
        case .website:
            openWebsite(url: value)
        case .instagram:
            openInstagram(username: value)
        case .github:
            openGithub(username: value)
        case .linkedin:
            openLinkedin(username: value)
        case .youtube:
            openYouTube(username: value)
        }
    }

    private static func openWebURL(_ webURL: URL) {
        UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
    }

    private static func openInstagram(username: String) {
        let appURL = URL(string: "instagram://user?username=\(username)")!
        let webURL = URL(string: "https://instagram.com/\(username)")!
        if UIApplication.shared.canOpenURL(appURL) {
            openWebURL(appURL)
        } else {
            openWebURL(webURL)
        }
    }

    private static func openGithub(username: String) {
        let appURL = URL(string: "github://\(username)")!
        let webURL = URL(string: "https://github.com/\(username)")!
        if UIApplication.shared.canOpenURL(appURL) {
            openWebURL(appURL)
        } else {
            openWebURL(webURL)
        }
    }

    private static func openYouTube(username: String) {
        let appURL = URL(string: "youtube://@\(username)")!
        let webURL = URL(string: "https://youtube.com/@\(username)")!
        if UIApplication.shared.canOpenURL(appURL) {
            openWebURL(appURL)
        } else {
            openWebURL(webURL)
        }
    }

    private static func openLinkedin(username: String) {
        let appURL = URL(string: "linedin://\(username)")!
        let webURL = URL(string: "https://www.linkedin.com/in/\(username)")!
        if UIApplication.shared.canOpenURL(appURL) {
            openWebURL(appURL)
        } else {
            openWebURL(webURL)
        }
    }

    private static func openWebsite(url: String) {
        if let webURL = URL(string: url) {
            openWebURL(webURL)
        }
    }
}

struct SocialLinkButton: View {
    let platform: SocialPlatform
    let value: String

    var body: some View {
        Button {
            SocialLinkOpener.open(platform: platform, value: value)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: platform.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(platform.tint)
                    .frame(width: 34, height: 34)
                    .background(platform.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(platform.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct CreatorSocialCard: View {
    let creator: CreatorInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(creator.accent.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(String(creator.name.prefix(1)))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(creator.accent)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(creator.name)
                        .font(.headline)
                    Text(creator.role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Redes sociais")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                VStack(spacing: 8) {
                    ForEach(creator.socialLinks, id: \.0.id) { platform, value in
                        SocialLinkButton(platform: platform, value: value)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

struct SocialView: View {
    var github, linkedin, youtube, instagram: String
    var website: String? = nil

    private var creator: CreatorInfo {
        CreatorInfo(
            name: "",
            role: "",
            accent: .blue,
            github: github,
            linkedin: linkedin,
            youtube: youtube,
            instagram: instagram,
            website: website
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(creator.socialLinks, id: \.0.id) { platform, value in
                    SocialLinkButton(platform: platform, value: value)
                }
            }
            .padding()
        }
        .navigationTitle("Redes Sociais")
        .navigationBarTitleDisplayMode(.inline)
    }
}

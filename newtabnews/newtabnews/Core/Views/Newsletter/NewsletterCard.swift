//
//  NewsletterCard.swift
//  newtabnews
//
//  Created by Luiz Mello on 31/03/25.
//

import SwiftUI

struct NewsletterCard: View {
    @Environment(MainViewModel.self) private var viewModel
    
    let newsletter: PostRequest
    let isUnseen: Bool
    
    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme
    var zoomNamespace: Namespace.ID
    var onOpen: () -> Void = {}
    
    var body: some View {
        NavigationLink {
            NewsletterDetailsView(
                nw: newsletter,
                isViewInApp: $isViewInApp,
                currentTheme: $currentTheme
            )
            .environment(viewModel)
            .postZoomDestination(id: newsletter.zoomTransitionID, namespace: zoomNamespace)
            .onAppear(perform: onOpen)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if isUnseen {
                    // Mesmo estilo do selo "Em destaque" da Home.
                    Text("Novo")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 6)
                }
                
                Text(newsletter.title ?? "Sem título")
                    .multilineTextAlignment(.leading)
                    .font(.body)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .foregroundStyle(.primary)
                    .padding(.bottom, 6)
                
                HStack {
                    if let sourceHost {
                        Text(sourceHost)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if let time {
                        Text(time)
                            .italic()
                    }
                }
                .font(.footnote)
                .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityValue(isUnseen ? "Novo" : "")
        }
        .postZoomSource(id: newsletter.zoomTransitionID, namespace: zoomNamespace)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var sourceHost: String? {
        guard let source = newsletter.sourceUrl,
              let host = URL(string: source)?.host(), !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
    
    private var time: String? {
        NewsletterViewModel.parseDate(newsletter.createdAt)?
            .formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: "pt_BR")))
    }
}

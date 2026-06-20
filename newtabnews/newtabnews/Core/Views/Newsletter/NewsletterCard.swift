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
    let isNew: Bool
    
    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme
    var zoomNamespace: Namespace.ID
    
    @State private var isPressed = false
    
    var body: some View {
        NavigationLink {
            NewsletterDetailsView(
                nw: newsletter,
                isViewInApp: $isViewInApp,
                currentTheme: $currentTheme
            )
            .environment(viewModel)
            .postZoomDestination(id: newsletter.zoomTransitionID, namespace: zoomNamespace)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(newsletter.title ?? "Sem título")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if isNew {
                        Text("NOVO")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.background)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.primary)
                            )
                    }
                }
                
                Text(getFormattedDate(value: newsletter.createdAt ?? ""))
                        .font(.caption)
                        .foregroundStyle(.gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("CardColor"))
            )
        }
        .postZoomSource(id: newsletter.zoomTransitionID, namespace: zoomNamespace)
        .buttonStyle(PlainButtonStyle())
    }
}

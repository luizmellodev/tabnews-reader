//
//  NewsletterCard.swift
//  newtabnews
//
//  Created by Luiz Mello on 31/03/25.
//

import SwiftUI

struct NewsletterCard: View {
    let newsletter: PostRequest
    let isNew: Bool
    
    @Binding var isViewInApp: Bool
    @Binding var currentTheme: Theme
    
    @State private var isPressed = false
    
    var body: some View {
        NavigationLink {
            NewsletterDetailsView(
                nw: newsletter,
                isViewInApp: $isViewInApp,
                currentTheme: $currentTheme
            )
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
                
                Text(isNew ? "Publicado hoje" : formatDate(newsletter.createdAt))
                        .font(.caption)
                        .foregroundStyle(.gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("CardColor"))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else {
            return "Data indisponível"
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            return "Data indisponível"
        }
        
        let output = DateFormatter()
        output.locale = Locale(identifier: "pt_BR")
        output.dateStyle = .long
        return output.string(from: date)
    }
}

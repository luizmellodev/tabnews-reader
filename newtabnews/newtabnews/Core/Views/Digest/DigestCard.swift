//
//  DigestCard.swift
//  newtabnews
//
//  Created by Luiz Mello on 27/12/25.
//

import SwiftUI

struct DigestCard: View {
    let digest: PostRequest
    let isNew: Bool
    
    @State private var isPressed = false
    
    var body: some View {
        NavigationLink {
            DigestDetailsView(digest: digest)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text(digest.title ?? "Sem título")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Text(isNew ? "Publicado hoje" : formatDate(digest.createdAt))
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
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


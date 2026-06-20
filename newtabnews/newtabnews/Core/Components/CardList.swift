//
//  CardList.swift
//  newtabnews
//
//  Created by Luiz Mello on 22/07/23.
//

import SwiftUI

struct CardList: View {
    var post: PostRequest
    
    private var isFeatured: Bool {
        (post.tabcoins ?? 0) >= 10
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            if isFeatured {
                featuredBadge
                    .padding(.bottom, 6)
            }
            
            Text(post.title ?? "Ops, não há título para este post")
                .multilineTextAlignment(.leading)
                .font(.title3)
                .fontWeight(.medium)
                .lineSpacing(2)
                .foregroundColor(.primary)
                .padding(.bottom, 8)
                .padding(.top, isFeatured ? 0 : 20)
            
            HStack {
                Text(post.ownerUsername ?? "luizmellodev")
                    .font(.footnote)
                
                Spacer()
                
                if post.hasLoadedBody, let body = post.body {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(body.readingTimeFormatted)
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
                
                Text(getFormattedDate(value: post.createdAt ?? "sábado-feira, 31 fevereiro"))
                    .font(.footnote)
                    .italic()
            }
            .foregroundColor(.gray)
            
            Divider()
                .padding(.bottom, 15)
            
            Group {
                if post.hasLoadedBody, let body = post.body {
                    Text(body.feedPreview())
                        .font(.subheadline)
                        .fontWeight(.light)
                        .lineSpacing(3)
                        .lineLimit(CardLayout.bodyLineLimit)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                } else {
                    CardBodySkeleton()
                }
            }
            .frame(maxWidth: .infinity, minHeight: CardLayout.bodyPreviewMinHeight, alignment: .topLeading)
            
            Spacer(minLength: 8)
            
            HStack {
                RoundedRectangle(cornerRadius: 5)
                    .frame(height: 40)
                    .foregroundColor(.black)
                    .overlay {
                        Text("Ler mais")
                            .foregroundColor(.white)
                    }
            }
            .padding(.bottom, 10)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .padding(.horizontal)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color("CardColor"))
        }
        .frame(height: CardLayout.cardHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Toque duas vezes para ler o post completo")
        .accessibilityAddTraits(.isButton)
    }
    
    private var featuredBadge: some View {
        Text("Em destaque")
            .font(.caption2)
            .fontWeight(.medium)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.tertiary)
            .padding(.top, 16)
    }
    
    private var accessibilityText: String {
        let title = post.title ?? "Post sem título"
        let author = post.ownerUsername ?? "Autor desconhecido"
        let tabcoins = post.tabcoins ?? 0
        let readTime = post.body?.readingTimeFormatted ?? "tempo desconhecido"
        let featured = isFeatured ? "Em destaque. " : ""
        
        return "\(featured)\(title). Por \(author). \(tabcoins) tabcoins. Tempo de leitura: \(readTime)."
    }
}

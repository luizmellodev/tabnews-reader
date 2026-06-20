//
//  CardList.swift
//  newtabnews
//
//  Created by Luiz Mello on 22/07/23.
//

import SwiftUI

struct CardList: View {
    var post: PostRequest
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                Text(post.title ?? "Ops, não há título para este post")
                    .multilineTextAlignment(.leading)
                    .font(.title3)
                    .fontWeight(.medium)
                    .lineSpacing(2)
                    .foregroundColor(.primary)
                    .padding(.bottom, 8)
                    .padding(.top, 20)
                
                HStack {
                    Text(post.ownerUsername ?? "luizmellodev")
                        .font(.footnote)
                    
                    Spacer()
                    
                    if let body = post.body {
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
                .padding(.bottom, 10)
                
                if let body = post.body, !body.isEmpty {
                    Text(body.feedPreview())
                        .fontWeight(.regular)
                        .font(.subheadline)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                        .padding(.bottom, 20)
                }
                
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
            
            if post.tabcoins ?? 5 >= 15 {
                VStack {
                    HStack {
                        Spacer()
                        Text("Em alta")
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.green)
                                    .brightness(-0.2)
                            }
                    }
                    .padding(.top, -10)
                    Spacer()
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .padding(.horizontal)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color("CardColor"))
                .shadow(color: (post.tabcoins ?? 5 >= 10) ? .green.opacity(0.5) : .clear, radius: (post.tabcoins ?? 5 >= 10) ? 1 : 0)
        }
        .frame(height: 300)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Toque duas vezes para ler o post completo")
        .accessibilityAddTraits(.isButton)
    }
    
    private var accessibilityText: String {
        let title = post.title ?? "Post sem título"
        let author = post.ownerUsername ?? "Autor desconhecido"
        let tabcoins = post.tabcoins ?? 0
        let readTime = post.body?.readingTimeFormatted ?? "tempo desconhecido"
        let isPopular = tabcoins >= 10 ? "Post em alta. " : ""
        
        return "\(isPopular)\(title). Por \(author). \(tabcoins) tabcoins. Tempo de leitura: \(readTime)."
    }
}

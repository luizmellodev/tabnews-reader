//
//  PromotedContent.swift
//  newtabnews
//

import Foundation

struct PromotedCard: Identifiable, Hashable {
    let id: String
    let title: String
    let authorLabel: String
    let destinationLabel: String
    let url: URL
}

enum PromotedContent {
    /// Cards estáticos exibidos na aba Buscar. Edite aqui para divulgar novos projetos.
    static let catalog: [PromotedCard] = [
        PromotedCard(
            id: "ritus-club",
            title: "Guia completo de cafés especiais — do cultivo à xícara",
            authorLabel: "luizmellodev",
            destinationLabel: "ritus.club",
            url: URL(string: "https://ritus.club")!
        )
    ]
}

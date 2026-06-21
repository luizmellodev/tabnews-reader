//
//  NetworkError.swift
//  newtabnews
//
//  Created by Luiz Mello on 27/03/25.
//

import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case badServerResponse
    case decodingError
    case apiError(APIError)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .badServerResponse:
            return "Resposta inválida do servidor"
        case .decodingError:
            return "Erro ao decodificar dados"
        case .apiError(let error):
            return "\(error.message)\n\(error.action)"
        }
    }
}

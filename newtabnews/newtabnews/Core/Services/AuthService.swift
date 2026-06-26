//
//  AuthService.swift
//  newtabnews
//
//  Created by Luiz Mello on 04/01/26.
//

import Foundation
import Combine
import WebKit

// MARK: - Auth Error

// Erro customizado para preservar mensagem de validação da API
struct ValidationError: LocalizedError {
    let message: String
    
    var errorDescription: String? {
        return message
    }
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case userNotFound
    case emailAlreadyExists
    case usernameAlreadyExists
    case weakPassword
    case invalidEmail
    case networkError
    case serverError
    case encodingError
    case unauthorized
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Email ou senha incorretos"
        case .userNotFound:
            return "Usuário não encontrado"
        case .emailAlreadyExists:
            return "Este email já está cadastrado"
        case .usernameAlreadyExists:
            return "Este nome de usuário já existe"
        case .weakPassword:
            return "A senha deve ter pelo menos 6 caracteres"
        case .invalidEmail:
            return "Email inválido"
        case .networkError:
            return "Erro de conexão. Verifique sua internet"
        case .serverError:
            return "Erro no servidor. Tente novamente"
        case .encodingError:
            return "Erro ao processar dados"
        case .unauthorized:
            return "Não autorizado. Faça login novamente"
        case .unknown:
            return "Erro desconhecido. Tente novamente"
        }
    }
    
    static func from(_ error: Error) -> AuthError {
        if let authError = error as? AuthError {
            return authError
        }
        
        if let networkError = error as? NetworkError {
            switch networkError {
            case .apiError(let apiError):
                switch apiError.statusCode {
                case 401:
                    return .invalidCredentials
                case 404:
                    return .userNotFound
                case 409:
                    let message = apiError.message.lowercased()
                    if message.contains("email") {
                        return .emailAlreadyExists
                    } else if message.contains("username") || message.contains("usuário") {
                        return .usernameAlreadyExists
                    }
                    return .emailAlreadyExists
                case 422:
                    let message = apiError.message.lowercased()
                    if message.contains("email") {
                        return .invalidEmail
                    } else if message.contains("password") || message.contains("senha") {
                        return .weakPassword
                    }
                    return .invalidEmail
                default:
                    let message = apiError.message.lowercased()
                    if message.contains("credentials") || message.contains("password") || message.contains("senha") || message.contains("incorret") {
                        return .invalidCredentials
                    } else if message.contains("email") && message.contains("already") {
                        return .emailAlreadyExists
                    } else if message.contains("username") && message.contains("already") {
                        return .usernameAlreadyExists
                    } else if message.contains("not found") {
                        return .userNotFound
                    }
                    return .serverError
                }
            case .badServerResponse:
                return .serverError
            case .invalidURL:
                return .networkError
            case .decodingError:
                return .serverError
            }
        }
        
        let nsError = error as NSError
        switch nsError.code {
        case -1009, -1001:
            return .networkError
        default:
            return .unknown
        }
    }
}

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    
    private let networkManager: NetworkManagerProtocol
    private let keychainManager = KeychainManager.shared
    
    init(networkManager: NetworkManagerProtocol = NetworkManager.shared) {
        self.networkManager = networkManager
        checkAuthStatus()
    }
    
    // MARK: - Auth
    
    func checkAuthStatus() {
        if let token = keychainManager.getSessionToken() {
            if let user = keychainManager.getUser() {
                // Tem token e usuário, está autenticado
                self.isAuthenticated = true
                self.currentUser = user
                #if DEBUG
                print("✅ [AuthService] Usuário autenticado: @\(user.username)")
                #endif
            } else {
                // Tem token mas não tem usuário, buscar da API
                #if DEBUG
                print("⚠️ [AuthService] Token encontrado mas usuário ausente, buscando da API...")
                #endif
                Task {
                    do {
                        try await fetchCurrentUser(token: token)
                        #if DEBUG
                        print("✅ [AuthService] Usuário recuperado da API")
                        #endif
                    } catch {
                        #if DEBUG
                        print("❌ [AuthService] Erro ao recuperar usuário, limpando token: \(error)")
                        #endif
                        // Token inválido, limpar tudo
                        logout()
                    }
                }
            }
        } else {
            // Sem token, deslogado
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
    
    func login(email: String, password: String) async throws {
        let loginRequest = LoginRequest(email: email, password: password)
        
        guard let body = try? JSONEncoder().encode(loginRequest) else {
            throw AuthError.encodingError
        }
        
        do {
            let response: SessionResponse = try await networkManager.sendRequest(
                "/sessions",
                method: "POST",
                parameters: nil,
                authentication: nil,
                token: nil,
                body: body
            )
            
            _ = keychainManager.saveSessionToken(response.token)
            try await fetchCurrentUser(token: response.token)
            
            await MainActor.run {
                self.isAuthenticated = true
            }
        } catch {
            // Para erros de validação (400), preservar mensagem original da API
            if let networkError = error as? NetworkError,
               case .apiError(let apiError) = networkError,
               apiError.statusCode == 400 {
                // Criar erro customizado que preserva a mensagem original
                throw ValidationError(message: apiError.message)
            }
            throw AuthError.from(error)
        }
    }
    
    func signup(username: String, email: String, password: String) async throws {
        let signupRequest = SignupRequest(username: username, email: email, password: password)
        
        guard let body = try? JSONEncoder().encode(signupRequest) else {
            throw AuthError.encodingError
        }
        
        do {
            let _: User = try await networkManager.sendRequest(
                "/users",
                method: "POST",
                parameters: nil,
                authentication: nil,
                token: nil,
                body: body
            )
        } catch {
            throw AuthError.from(error)
        }
    }
    
    func logout() {
        _ = keychainManager.clearAll()
        VoteManager.shared.clearAllVotes()
        
        // Limpar cookies da WebView
        clearWebViewCookies()
        
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
    
    private func clearWebViewCookies() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = Set([WKWebsiteDataTypeCookies])
        
        dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            // Filtrar apenas cookies do TabNews
            let tabnewsRecords = records.filter { $0.displayName.contains("tabnews.com.br") }
            
            dataStore.removeData(ofTypes: dataTypes, for: tabnewsRecords) {
                #if DEBUG
                print("🍪 [AuthService] Cookies da WebView limpos")
                #endif
            }
        }
    }
    
    private func fetchCurrentUser(token: String) async throws {
        let user: User = try await networkManager.sendRequest(
            "/user",
            method: "GET",
            parameters: nil,
            authentication: "Cookie",
            token: "session_id=\(token)",
            body: nil
        )
        
        _ = keychainManager.saveUser(user)
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    // MARK: - User Data
    
    func refreshUserData() async throws {
        guard let token = keychainManager.getSessionToken() else {
            throw AuthError.unauthorized
        }
        
        try await fetchCurrentUser(token: token)
    }
    
    func getUserPublications(username: String, page: Int = 1, perPage: Int = 30) async throws -> [PostRequest] {
        let posts: [PostRequest] = try await networkManager.sendRequest(
            "/contents/\(username)",
            method: "GET",
            parameters: [
                "page": page,
                "per_page": perPage,
                "strategy": "new"
            ],
            authentication: nil,
            token: nil,
            body: nil
        )
        
        return posts
    }
    
    // MARK: - Content Actions
    
    func postComment(parentId: String, body: String) async throws -> Comment {
        guard let token = keychainManager.getSessionToken() else {
            throw NSError(domain: "AuthService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuário não autenticado"])
        }
        
        let commentRequest = CommentRequest(
            parentId: parentId,
            body: body,
            status: "published"
        )
        
        guard let requestBody = try? JSONEncoder().encode(commentRequest) else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Erro ao codificar comentário"])
        }
        
        let comment: Comment = try await networkManager.sendRequest(
            "/contents",
            method: "POST",
            parameters: nil,
            authentication: "Cookie",
            token: "session_id=\(token)",
            body: requestBody
        )
        
        return comment
    }
    
    func voteOnContent(username: String, slug: String, transactionType: String) async throws {
        guard let token = keychainManager.getSessionToken() else {
            throw AuthError.unauthorized
        }
        
        let jsonString = "{\"transaction_type\":\"\(transactionType)\"}"
        guard let requestBody = jsonString.data(using: .utf8) else {
            throw AuthError.encodingError
        }
        
        let _: Comment = try await networkManager.sendRequest(
            "/contents/\(username)/\(slug)/tabcoins",
            method: "POST",
            parameters: nil,
            authentication: "Cookie",
            token: "session_id=\(token)",
            body: requestBody
        )
    }
}


import Foundation

/// Garante intervalo mínimo entre requisições para respeitar rate limits da API.
private actor RequestThrottler {
    static let shared = RequestThrottler()

    private var lastRequestTime: Date = .distantPast
    private let minimumInterval: TimeInterval = 0.35

    func waitIfNeeded() async {
        let elapsed = Date().timeIntervalSince(lastRequestTime)
        guard elapsed < minimumInterval else {
            lastRequestTime = Date()
            return
        }

        let waitTime = minimumInterval - elapsed
        try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        lastRequestTime = Date()
    }
}

class NetworkManager: NetworkManagerProtocol {
    
    static let shared = NetworkManager()
    let baseURL = URL(string: "https://www.tabnews.com.br/api/v1")!
    
    private let maxRetries = 3
    private let retryableStatusCodes: Set<Int> = [429, 503]
    
    private init() {}
    
    func sendRequest<T: Decodable>(
        _ endpoint: String,
        method: String,
        parameters: [String: Any]? = nil,
        authentication: String?,
        token: String?,
        body: Data? = nil
    ) async throws -> T {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)
        
        if let parameters = parameters {
            urlComponents?.queryItems = parameters.map { 
                URLQueryItem(name: $0.key, value: "\($0.value)")
            }
        }
        
        guard let url = urlComponents?.url else {
            Logger.error("Invalid URL for endpoint: \(endpoint)")
            throw NetworkError.invalidURL
        }
        
        guard let request = RequestBuilder.buildRequest(
            url: url,
            httpMethod: method,
            token: token,
            parameters: parameters,
            authentication: authentication,
            body: body
        ) else {
            Logger.error("Failed to build request for endpoint: \(endpoint)")
            throw NetworkError.badServerResponse
        }
        
        var lastError: Error = NetworkError.badServerResponse
        
        for attempt in 0..<maxRetries {
            await RequestThrottler.shared.waitIfNeeded()
            
            if attempt > 0 {
                let backoff = pow(2.0, Double(attempt - 1)) * 0.75
                Logger.info("⏳ Retry \(attempt + 1)/\(maxRetries) para \(endpoint) em \(backoff)s")
                try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            }
            
            Logger.info("📤 Sending request to: \(url)")
            
            if let body = body, let bodyString = String(data: body, encoding: .utf8) {
                Logger.info("📄 Request body: \(bodyString)")
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    Logger.error("Invalid response type")
                    throw NetworkError.badServerResponse
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
                    Logger.error("⚠️ Error: Bad server response (status code: \(httpResponse.statusCode))")
                    Logger.error("Error body: \(errorBody)")
                    
                    if retryableStatusCodes.contains(httpResponse.statusCode), attempt < maxRetries - 1 {
                        if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                            lastError = NetworkError.apiError(errorResponse)
                        } else {
                            lastError = NetworkError.badServerResponse
                        }
                        continue
                    }
                    
                    if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                        throw NetworkError.apiError(errorResponse)
                    }
                    throw NetworkError.badServerResponse
                }
                
                Logger.prettyPrintJSON(from: data)
                
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    Logger.error("❌ Error decoding \(T.self): \(error)")
                    throw NetworkError.decodingError
                }
            } catch let error as NetworkError {
                lastError = error
                if case .apiError(let apiError) = error, retryableStatusCodes.contains(apiError.statusCode), attempt < maxRetries - 1 {
                    continue
                }
                throw error
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    continue
                }
                throw error
            }
        }
        
        throw lastError
    }
}

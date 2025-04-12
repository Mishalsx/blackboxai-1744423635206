import Foundation

enum TranslationError: Error {
    case invalidResponse
    case apiError(String)
    case networkError(Error)
    case unsupportedLanguage
    case rateLimitExceeded
    case noAPIKey
}

final class TranslationService {
    // MARK: - Properties
    private let apiKey: String
    private let provider: Provider
    private let session: URLSession
    private var rateLimitTimer: Timer?
    private var requestCount: Int = 0
    
    // Rate limiting
    private let maxRequestsPerMinute = 60
    private let requestResetInterval: TimeInterval = 60
    
    // MARK: - Provider Configuration
    enum Provider {
        case openAI
        case deepL
        case azure
        
        var baseURL: String {
            switch self {
            case .openAI:
                return "https://api.openai.com/v1/chat/completions"
            case .deepL:
                return "https://api-free.deepl.com/v2/translate"
            case .azure:
                return "https://api.cognitive.microsofttranslator.com/translate"
            }
        }
        
        var headers: [String: String] {
            switch self {
            case .openAI:
                return [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer {API_KEY}"
                ]
            case .deepL:
                return [
                    "Content-Type": "application/json",
                    "Authorization": "DeepL-Auth-Key {API_KEY}"
                ]
            case .azure:
                return [
                    "Content-Type": "application/json",
                    "Ocp-Apim-Subscription-Key": "{API_KEY}",
                    "Ocp-Apim-Subscription-Region": "{REGION}"
                ]
            }
        }
    }
    
    // MARK: - Initialization
    init(provider: Provider, apiKey: String) {
        self.provider = provider
        self.apiKey = apiKey
        self.session = URLSession(configuration: .default)
        setupRateLimiting()
    }
    
    // MARK: - Translation
    func translate(text: String, from: String, to: String) async throws -> String {
        // Check rate limiting
        guard !isRateLimited() else {
            throw TranslationError.rateLimitExceeded
        }
        
        // Validate API key
        guard !apiKey.isEmpty else {
            throw TranslationError.noAPIKey
        }
        
        // Create request based on provider
        let request = try createRequest(text: text, from: from, to: to)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranslationError.invalidResponse
            }
            
            // Handle rate limiting response
            if httpResponse.statusCode == 429 {
                throw TranslationError.rateLimitExceeded
            }
            
            // Handle other error responses
            guard (200...299).contains(httpResponse.statusCode) else {
                throw TranslationError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            // Parse response based on provider
            let translation = try parseResponse(data: data)
            
            // Increment request counter
            incrementRequestCount()
            
            return translation
        } catch {
            throw TranslationError.networkError(error)
        }
    }
    
    // MARK: - Request Creation
    private func createRequest(text: String, from: String, to: String) throws -> URLRequest {
        var urlComponents = URLComponents(string: provider.baseURL)!
        var headers = provider.headers
        
        switch provider {
        case .openAI:
            // OpenAI Chat API request
            let body: [String: Any] = [
                "model": "gpt-3.5-turbo",
                "messages": [
                    [
                        "role": "system",
                        "content": "You are a professional translator. Translate the following text from \(from) to \(to). Maintain the original meaning and tone."
                    ],
                    [
                        "role": "user",
                        "content": text
                    ]
                ]
            ]
            
            var request = URLRequest(url: urlComponents.url!)
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = headers.mapValues { $0.replacingOccurrences(of: "{API_KEY}", with: apiKey) }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            return request
            
        case .deepL:
            // DeepL API request
            let body: [String: Any] = [
                "text": [text],
                "source_lang": from.uppercased(),
                "target_lang": to.uppercased()
            ]
            
            var request = URLRequest(url: urlComponents.url!)
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = headers.mapValues { $0.replacingOccurrences(of: "{API_KEY}", with: apiKey) }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            return request
            
        case .azure:
            // Azure Translator API request
            urlComponents.queryItems = [
                URLQueryItem(name: "api-version", value: "3.0"),
                URLQueryItem(name: "from", value: from),
                URLQueryItem(name: "to", value: to)
            ]
            
            let body: [[String: Any]] = [["text": text]]
            
            var request = URLRequest(url: urlComponents.url!)
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = headers.mapValues { $0
                .replacingOccurrences(of: "{API_KEY}", with: apiKey)
                .replacingOccurrences(of: "{REGION}", with: "eastus") // Configure as needed
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            return request
        }
    }
    
    // MARK: - Response Parsing
    private func parseResponse(data: Data) throws -> String {
        switch provider {
        case .openAI:
            let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            return response.choices.first?.message.content ?? ""
            
        case .deepL:
            let response = try JSONDecoder().decode(DeepLResponse.self, from: data)
            return response.translations.first?.text ?? ""
            
        case .azure:
            let response = try JSONDecoder().decode([AzureResponse].self, from: data)
            return response.first?.translations.first?.text ?? ""
        }
    }
    
    // MARK: - Rate Limiting
    private func setupRateLimiting() {
        rateLimitTimer = Timer.scheduledTimer(withTimeInterval: requestResetInterval, repeats: true) { [weak self] _ in
            self?.requestCount = 0
        }
    }
    
    private func isRateLimited() -> Bool {
        return requestCount >= maxRequestsPerMinute
    }
    
    private func incrementRequestCount() {
        requestCount += 1
    }
    
    deinit {
        rateLimitTimer?.invalidate()
    }
}

// MARK: - Response Models
private struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

private struct DeepLResponse: Codable {
    struct Translation: Codable {
        let text: String
    }
    let translations: [Translation]
}

private struct AzureResponse: Codable {
    struct Translation: Codable {
        let text: String
    }
    let translations: [Translation]
}

// MARK: - Convenience Extensions
extension TranslationService {
    static func configure(with provider: Provider, apiKey: String) -> TranslationService {
        return TranslationService(provider: provider, apiKey: apiKey)
    }
}

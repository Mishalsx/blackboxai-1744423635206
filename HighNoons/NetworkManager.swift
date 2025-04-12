import Network
import Foundation

final class NetworkManager {
    // MARK: - Properties
    static let shared = NetworkManager()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.highnoons.network")
    private let analytics = AnalyticsManager.shared
    
    private var isConnected = false
    private var connectionType: NWInterface.InterfaceType?
    
    // API Configuration
    private let baseURL = "https://api.highnoons.com"
    private let apiVersion = "v1"
    private let timeoutInterval: TimeInterval = 30
    
    // Authentication
    private var authToken: String?
    private let keychain = KeychainWrapper.standard
    
    // MARK: - Types
    enum NetworkError: Error {
        case noConnection
        case invalidURL
        case invalidResponse
        case authenticationRequired
        case serverError(Int)
        case decodingError
        case timeout
        case unknown
        
        var description: String {
            switch self {
            case .noConnection: return "No internet connection"
            case .invalidURL: return "Invalid URL"
            case .invalidResponse: return "Invalid server response"
            case .authenticationRequired: return "Authentication required"
            case .serverError(let code): return "Server error: \(code)"
            case .decodingError: return "Failed to decode response"
            case .timeout: return "Request timed out"
            case .unknown: return "Unknown error occurred"
            }
        }
    }
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
    
    // MARK: - Initialization
    private init() {
        setupNetworkMonitoring()
        loadAuthToken()
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
            self?.connectionType = path.availableInterfaces.first?.type
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .networkStatusChanged,
                    object: nil,
                    userInfo: ["isConnected": path.status == .satisfied]
                )
            }
        }
        monitor.start(queue: queue)
    }
    
    // MARK: - Authentication
    private func loadAuthToken() {
        authToken = keychain.string(forKey: "authToken")
    }
    
    func setAuthToken(_ token: String) {
        authToken = token
        keychain.set(token, forKey: "authToken")
    }
    
    func clearAuthToken() {
        authToken = nil
        keychain.removeObject(forKey: "authToken")
    }
    
    // MARK: - Network Requests
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard isConnected else {
            throw NetworkError.noConnection
        }
        
        guard let url = URL(string: "\(baseURL)/\(apiVersion)/\(endpoint)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval
        
        // Headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("HighNoons-iOS/\(Bundle.main.appVersion)", forHTTPHeaderField: "User-Agent")
        
        if requiresAuth {
            guard let token = authToken else {
                throw NetworkError.authenticationRequired
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Parameters
        if let parameters = parameters {
            if method == .get {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
                components?.queryItems = parameters.map {
                    URLQueryItem(name: $0.key, value: String(describing: $0.value))
                }
                request.url = components?.url
            } else {
                request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
            }
        }
        
        let startTime = Date()
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let duration = Date().timeInterval(since: startTime)
            trackRequestMetrics(endpoint: endpoint, duration: duration, statusCode: (response as? HTTPURLResponse)?.statusCode)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return try JSONDecoder().decode(T.self, from: data)
            case 401:
                throw NetworkError.authenticationRequired
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.invalidResponse
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                throw NetworkError.timeout
            }
            throw NetworkError.unknown
        }
    }
    
    // MARK: - API Endpoints
    
    // User Management
    func login(username: String, password: String) async throws -> User {
        let response: AuthResponse = try await request(
            endpoint: "auth/login",
            method: .post,
            parameters: [
                "username": username,
                "password": password
            ],
            requiresAuth: false
        )
        
        setAuthToken(response.token)
        return response.user
    }
    
    func updateProfile(name: String, avatar: String) async throws -> User {
        return try await request(
            endpoint: "user/profile",
            method: .put,
            parameters: [
                "name": name,
                "avatar": avatar
            ]
        )
    }
    
    // Leaderboard
    func getLeaderboard(timeframe: String = "all") async throws -> [LeaderboardEntry] {
        return try await request(
            endpoint: "leaderboard",
            parameters: ["timeframe": timeframe]
        )
    }
    
    // Match History
    func getMatchHistory(page: Int = 1) async throws -> MatchHistory {
        return try await request(
            endpoint: "matches",
            parameters: ["page": page]
        )
    }
    
    // Store
    func getPurchaseHistory() async throws -> [Purchase] {
        return try await request(endpoint: "store/purchases")
    }
    
    func validateReceipt(_ receipt: String) async throws -> ReceiptValidation {
        return try await request(
            endpoint: "store/validate",
            method: .post,
            parameters: ["receipt": receipt]
        )
    }
    
    // MARK: - Analytics
    private func trackRequestMetrics(endpoint: String, duration: TimeInterval, statusCode: Int?) {
        analytics.trackEvent(.loadingTime(
            screen: "api_\(endpoint)",
            duration: duration
        ))
        
        if let code = statusCode, code >= 400 {
            analytics.trackEvent(.networkError(
                api: endpoint,
                code: code
            ))
        }
    }
    
    // MARK: - Utility
    func isReachable() -> Bool {
        return isConnected
    }
    
    func getCurrentConnectionType() -> String {
        guard let type = connectionType else { return "unknown" }
        
        switch type {
        case .wifi: return "wifi"
        case .cellular: return "cellular"
        case .wiredEthernet: return "ethernet"
        default: return "other"
        }
    }
}

// MARK: - Models
extension NetworkManager {
    struct User: Codable {
        let id: String
        let username: String
        let name: String
        let avatar: String
        let stats: UserStats
    }
    
    struct UserStats: Codable {
        let wins: Int
        let losses: Int
        let averageReactionTime: Double
        let rank: Int
    }
    
    struct AuthResponse: Codable {
        let token: String
        let user: User
    }
    
    struct LeaderboardEntry: Codable {
        let userId: String
        let username: String
        let score: Int
        let rank: Int
        let reactionTime: Double
    }
    
    struct MatchHistory: Codable {
        let matches: [Match]
        let totalPages: Int
        let currentPage: Int
    }
    
    struct Match: Codable {
        let id: String
        let opponent: String
        let result: String
        let reactionTime: Double
        let timestamp: Date
    }
    
    struct Purchase: Codable {
        let id: String
        let productId: String
        let timestamp: Date
        let status: String
    }
    
    struct ReceiptValidation: Codable {
        let isValid: Bool
        let products: [String]
        let expiryDate: Date?
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

// MARK: - Bundle Extension
extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Date Extension
extension Date {
    func timeInterval(since date: Date) -> TimeInterval {
        return self.timeIntervalSince1970 - date.timeIntervalSince1970
    }
}

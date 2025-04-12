import Foundation
import SpriteKit

final class SpectatorManager {
    // MARK: - Properties
    static let shared = SpectatorManager()
    
    private let networkManager = NetworkManager.shared
    private let analytics = AnalyticsManager.shared
    private let replayManager = ReplayManager.shared
    
    private var activeSpectators: [String: [Spectator]] = [:]
    private var spectatedMatches: [String: SpectatedMatch] = [:]
    private var streamConnection: StreamConnection?
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct Spectator: Codable {
        let userId: String
        let username: String
        let joinTime: Date
        let permissions: Permissions
        
        struct Permissions: OptionSet, Codable {
            let rawValue: Int
            
            static let view = Permissions(rawValue: 1 << 0)
            static let chat = Permissions(rawValue: 1 << 1)
            static let emote = Permissions(rawValue: 1 << 2)
            static let moderate = Permissions(rawValue: 1 << 3)
            
            static let all: Permissions = [.view, .chat, .emote, .moderate]
        }
    }
    
    struct SpectatedMatch {
        let matchId: String
        let players: [Player]
        let gameState: GameState
        let startTime: Date
        var spectatorCount: Int
        var chatMessages: [ChatMessage]
        
        struct Player: Codable {
            let userId: String
            let username: String
            let character: String
            let stats: Stats
            
            struct Stats: Codable {
                var health: Int
                var reactionTime: Double?
                var accuracy: Double
                var powerups: [String]
            }
        }
        
        struct GameState: Codable {
            let phase: Phase
            let timeRemaining: TimeInterval
            let score: [String: Int]
            let events: [GameEvent]
            
            enum Phase: String, Codable {
                case warmup
                case ready
                case action
                case result
            }
        }
        
        struct ChatMessage: Codable {
            let userId: String
            let username: String
            let content: MessageContent
            let timestamp: Date
            
            enum MessageContent: Codable {
                case text(String)
                case emote(String)
                case system(String)
            }
        }
    }
    
    class StreamConnection {
        private var webSocket: URLSessionWebSocketTask?
        private var isConnected = false
        private var reconnectTimer: Timer?
        
        var onStateUpdate: ((SpectatedMatch.GameState) -> Void)?
        var onChatMessage: ((SpectatedMatch.ChatMessage) -> Void)?
        var onSpectatorUpdate: (([Spectator]) -> Void)?
        
        func connect(to matchId: String) {
            guard let url = URL(string: "\(NetworkConfig.wsURL)/spectate/\(matchId)") else { return }
            
            let session = URLSession(configuration: .default)
            webSocket = session.webSocketTask(with: url)
            webSocket?.resume()
            
            receiveMessage()
            isConnected = true
            stopReconnectTimer()
        }
        
        func disconnect() {
            webSocket?.cancel(with: .goingAway, reason: nil)
            webSocket = nil
            isConnected = false
        }
        
        private func receiveMessage() {
            webSocket?.receive { [weak self] result in
                switch result {
                case .success(let message):
                    self?.handleMessage(message)
                    self?.receiveMessage() // Continue receiving
                case .failure(let error):
                    print("WebSocket error: \(error.localizedDescription)")
                    self?.handleDisconnect()
                }
            }
        }
        
        private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
            switch message {
            case .string(let text):
                guard let data = text.data(using: .utf8) else { return }
                handleMessageData(data)
            case .data(let data):
                handleMessageData(data)
            @unknown default:
                break
            }
        }
        
        private func handleMessageData(_ data: Data) {
            do {
                let message = try JSONDecoder().decode(SpectatorMessage.self, from: data)
                
                switch message.type {
                case .state:
                    if let state = try? JSONDecoder().decode(SpectatedMatch.GameState.self, from: message.data) {
                        onStateUpdate?(state)
                    }
                case .chat:
                    if let chat = try? JSONDecoder().decode(SpectatedMatch.ChatMessage.self, from: message.data) {
                        onChatMessage?(chat)
                    }
                case .spectators:
                    if let spectators = try? JSONDecoder().decode([Spectator].self, from: message.data) {
                        onSpectatorUpdate?(spectators)
                    }
                }
            } catch {
                print("Failed to decode message: \(error.localizedDescription)")
            }
        }
        
        private func handleDisconnect() {
            isConnected = false
            startReconnectTimer()
        }
        
        private func startReconnectTimer() {
            stopReconnectTimer()
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                // Attempt reconnection
            }
        }
        
        private func stopReconnectTimer() {
            reconnectTimer?.invalidate()
            reconnectTimer = nil
        }
        
        struct SpectatorMessage: Codable {
            let type: MessageType
            let data: Data
            
            enum MessageType: String, Codable {
                case state
                case chat
                case spectators
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupRefreshTimer()
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 30,
            repeats: true
        ) { [weak self] _ in
            self?.refreshSpectatorData()
        }
    }
    
    // MARK: - Spectating
    func spectateMatch(
        _ matchId: String,
        completion: @escaping (Result<SpectatedMatch, Error>) -> Void
    ) {
        Task {
            do {
                let match: SpectatedMatch = try await networkManager.request(
                    endpoint: "spectate/\(matchId)"
                )
                
                spectatedMatches[matchId] = match
                
                // Connect to stream
                connectToMatch(matchId)
                
                analytics.trackEvent(.featureUsed(name: "match_spectate"))
                completion(.success(match))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func stopSpectating(_ matchId: String) {
        streamConnection?.disconnect()
        streamConnection = nil
        spectatedMatches.removeValue(forKey: matchId)
        
        analytics.trackEvent(.featureUsed(name: "spectate_stop"))
    }
    
    private func connectToMatch(_ matchId: String) {
        let connection = StreamConnection()
        
        connection.onStateUpdate = { [weak self] state in
            self?.handleStateUpdate(matchId, state)
        }
        
        connection.onChatMessage = { [weak self] message in
            self?.handleChatMessage(matchId, message)
        }
        
        connection.onSpectatorUpdate = { [weak self] spectators in
            self?.handleSpectatorUpdate(matchId, spectators)
        }
        
        connection.connect(to: matchId)
        streamConnection = connection
    }
    
    // MARK: - Event Handling
    private func handleStateUpdate(_ matchId: String, _ state: SpectatedMatch.GameState) {
        guard var match = spectatedMatches[matchId] else { return }
        match.gameState = state
        spectatedMatches[matchId] = match
        
        NotificationCenter.default.post(
            name: .spectatorStateUpdated,
            object: nil,
            userInfo: ["matchId": matchId, "state": state]
        )
    }
    
    private func handleChatMessage(_ matchId: String, _ message: SpectatedMatch.ChatMessage) {
        guard var match = spectatedMatches[matchId] else { return }
        match.chatMessages.append(message)
        spectatedMatches[matchId] = match
        
        NotificationCenter.default.post(
            name: .spectatorChatReceived,
            object: nil,
            userInfo: ["matchId": matchId, "message": message]
        )
    }
    
    private func handleSpectatorUpdate(_ matchId: String, _ spectators: [Spectator]) {
        activeSpectators[matchId] = spectators
        
        guard var match = spectatedMatches[matchId] else { return }
        match.spectatorCount = spectators.count
        spectatedMatches[matchId] = match
        
        NotificationCenter.default.post(
            name: .spectatorsUpdated,
            object: nil,
            userInfo: ["matchId": matchId, "spectators": spectators]
        )
    }
    
    // MARK: - Chat & Interaction
    func sendChatMessage(
        _ content: String,
        inMatch matchId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let spectator = activeSpectators[matchId]?.first(where: { $0.userId == playerStats.userId }),
              spectator.permissions.contains(.chat) else {
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }
        
        Task {
            do {
                try await networkManager.request(
                    endpoint: "spectate/\(matchId)/chat",
                    method: .post,
                    parameters: ["content": content]
                )
                
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func sendEmote(
        _ emoteId: String,
        inMatch matchId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let spectator = activeSpectators[matchId]?.first(where: { $0.userId == playerStats.userId }),
              spectator.permissions.contains(.emote) else {
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }
        
        Task {
            do {
                try await networkManager.request(
                    endpoint: "spectate/\(matchId)/emote",
                    method: .post,
                    parameters: ["emote_id": emoteId]
                )
                
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Data Management
    private func refreshSpectatorData() {
        for matchId in spectatedMatches.keys {
            Task {
                do {
                    let spectators: [Spectator] = try await networkManager.request(
                        endpoint: "spectate/\(matchId)/spectators"
                    )
                    handleSpectatorUpdate(matchId, spectators)
                } catch {
                    print("Failed to refresh spectators: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Queries
    func getSpectatedMatch(_ matchId: String) -> SpectatedMatch? {
        return spectatedMatches[matchId]
    }
    
    func getSpectators(_ matchId: String) -> [Spectator] {
        return activeSpectators[matchId] ?? []
    }
    
    func getCurrentPermissions(_ matchId: String) -> Spectator.Permissions {
        return activeSpectators[matchId]?
            .first { $0.userId == playerStats.userId }?
            .permissions ?? []
    }
    
    // MARK: - Cleanup
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        streamConnection?.disconnect()
        streamConnection = nil
        activeSpectators.removeAll()
        spectatedMatches.removeAll()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let spectatorStateUpdated = Notification.Name("spectatorStateUpdated")
    static let spectatorChatReceived = Notification.Name("spectatorChatReceived")
    static let spectatorsUpdated = Notification.Name("spectatorsUpdated")
}

// MARK: - Convenience Methods
extension SpectatorManager {
    func isSpectating(_ matchId: String) -> Bool {
        return spectatedMatches[matchId] != nil
    }
    
    func canSendChat(_ matchId: String) -> Bool {
        return getCurrentPermissions(matchId).contains(.chat)
    }
    
    func canSendEmotes(_ matchId: String) -> Bool {
        return getCurrentPermissions(matchId).contains(.emote)
    }
    
    func canModerate(_ matchId: String) -> Bool {
        return getCurrentPermissions(matchId).contains(.moderate)
    }
}

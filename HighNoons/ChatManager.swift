import Foundation
import Network

final class ChatManager {
    // MARK: - Properties
    static let shared = ChatManager()
    
    private let networkManager = NetworkManager.shared
    private let analytics = AnalyticsManager.shared
    private let notificationManager = NotificationManager.shared
    
    private var webSocket: URLSessionWebSocketTask?
    private var messageHandlers: [String: (ChatMessage) -> Void] = [:]
    private var reconnectTimer: Timer?
    private var isConnected = false
    private var messageCache: [String: [ChatMessage]] = [:]
    
    // MARK: - Types
    struct ChatMessage: Codable {
        let id: String
        let channelId: String
        let senderId: String
        let senderName: String
        let content: MessageContent
        let timestamp: Date
        let status: MessageStatus
        
        enum MessageContent: Codable {
            case text(String)
            case emoji(String)
            case gameInvite(GameInvite)
            case systemMessage(String)
            
            var displayText: String {
                switch self {
                case .text(let message): return message
                case .emoji(let emoji): return emoji
                case .gameInvite: return "Game Invite"
                case .systemMessage(let message): return message
                }
            }
        }
        
        struct GameInvite: Codable {
            let gameMode: String
            let expiryTime: Date
            var isExpired: Bool {
                return Date() > expiryTime
            }
        }
        
        enum MessageStatus: String, Codable {
            case sent
            case delivered
            case read
            case failed
        }
    }
    
    struct ChatChannel: Codable {
        let id: String
        let type: ChannelType
        let participants: [String]
        let lastMessage: ChatMessage?
        let unreadCount: Int
        
        enum ChannelType: String, Codable {
            case direct
            case group
            case global
            case system
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    // MARK: - Connection Management
    func connect() {
        guard !isConnected else { return }
        
        guard let url = URL(string: "\(NetworkConfig.wsURL)/chat") else { return }
        
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        
        webSocket?.resume()
        receiveMessage()
        
        isConnected = true
        analytics.trackEvent(.featureUsed(name: "chat_connect"))
    }
    
    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false
        stopReconnectTimer()
    }
    
    private func reconnect() {
        disconnect()
        connect()
    }
    
    private func startReconnectTimer() {
        stopReconnectTimer()
        reconnectTimer = Timer.scheduledTimer(
            withTimeInterval: 5.0,
            repeats: true
        ) { [weak self] _ in
            self?.reconnect()
        }
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    // MARK: - Message Handling
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleWebSocketMessage(message)
                self?.receiveMessage() // Continue receiving
                
            case .failure(let error):
                print("WebSocket receive error: \(error.localizedDescription)")
                self?.handleDisconnect()
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let chatMessage = try? JSONDecoder().decode(ChatMessage.self, from: data) else {
                return
            }
            
            // Cache message
            cacheMessage(chatMessage)
            
            // Notify handlers
            messageHandlers[chatMessage.channelId]?(chatMessage)
            
            // Show notification if app is in background
            if UIApplication.shared.applicationState == .background {
                showMessageNotification(chatMessage)
            }
            
        case .data(let data):
            guard let chatMessage = try? JSONDecoder().decode(ChatMessage.self, from: data) else {
                return
            }
            
            cacheMessage(chatMessage)
            messageHandlers[chatMessage.channelId]?(chatMessage)
            
        @unknown default:
            break
        }
    }
    
    private func handleDisconnect() {
        isConnected = false
        startReconnectTimer()
    }
    
    // MARK: - Message Sending
    func sendMessage(
        _ content: ChatMessage.MessageContent,
        toChannel channelId: String,
        completion: @escaping (Result<ChatMessage, Error>) -> Void
    ) {
        let message = ChatMessage(
            id: UUID().uuidString,
            channelId: channelId,
            senderId: PlayerStats.shared.userId,
            senderName: PlayerStats.shared.username,
            content: content,
            timestamp: Date(),
            status: .sent
        )
        
        guard let data = try? JSONEncoder().encode(message) else {
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }
        
        webSocket?.send(.data(data)) { [weak self] error in
            if let error = error {
                completion(.failure(error))
            } else {
                self?.cacheMessage(message)
                completion(.success(message))
                
                self?.analytics.trackEvent(.featureUsed(name: "chat_message_sent"))
            }
        }
    }
    
    func sendGameInvite(
        toUserId: String,
        gameMode: String,
        completion: @escaping (Result<ChatMessage, Error>) -> Void
    ) {
        let invite = ChatMessage.GameInvite(
            gameMode: gameMode,
            expiryTime: Date().addingTimeInterval(300) // 5 minutes
        )
        
        sendMessage(
            .gameInvite(invite),
            toChannel: "direct_\(toUserId)",
            completion: completion
        )
    }
    
    // MARK: - Channel Management
    func joinChannel(
        _ channelId: String,
        handler: @escaping (ChatMessage) -> Void
    ) {
        messageHandlers[channelId] = handler
        
        // Load cached messages
        if let cached = messageCache[channelId] {
            cached.forEach(handler)
        }
        
        // Subscribe to channel
        let subscription = ["action": "subscribe", "channel": channelId]
        if let data = try? JSONEncoder().encode(subscription) {
            webSocket?.send(.data(data)) { error in
                if let error = error {
                    print("Failed to subscribe to channel: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func leaveChannel(_ channelId: String) {
        messageHandlers.removeValue(forKey: channelId)
        
        // Unsubscribe from channel
        let unsubscription = ["action": "unsubscribe", "channel": channelId]
        if let data = try? JSONEncoder().encode(unsubscription) {
            webSocket?.send(.data(data)) { error in
                if let error = error {
                    print("Failed to unsubscribe from channel: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Cache Management
    private func cacheMessage(_ message: ChatMessage) {
        var messages = messageCache[message.channelId] ?? []
        messages.append(message)
        
        // Keep only last 100 messages
        if messages.count > 100 {
            messages.removeFirst(messages.count - 100)
        }
        
        messageCache[message.channelId] = messages
    }
    
    func clearCache() {
        messageCache.removeAll()
    }
    
    // MARK: - Notifications
    private func showMessageNotification(_ message: ChatMessage) {
        switch message.content {
        case .text(let text):
            notificationManager.scheduleNotification(
                title: message.senderName,
                body: text,
                delay: 0
            )
            
        case .gameInvite:
            notificationManager.scheduleNotification(
                title: "Game Invite",
                body: "\(message.senderName) invited you to a game!",
                delay: 0
            )
            
        default:
            break
        }
    }
    
    // MARK: - App Lifecycle
    @objc private func handleAppBackground() {
        // Maintain connection for a short while in background
        DispatchQueue.main.asyncAfter(deadline: .now() + 180) { [weak self] in
            self?.disconnect()
        }
    }
    
    @objc private func handleAppForeground() {
        if !isConnected {
            connect()
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        disconnect()
        clearCache()
        messageHandlers.removeAll()
    }
}

// MARK: - Convenience Methods
extension ChatManager {
    func getChannelMessages(_ channelId: String) -> [ChatMessage] {
        return messageCache[channelId] ?? []
    }
    
    func getUnreadCount(_ channelId: String) -> Int {
        return messageCache[channelId]?.filter { $0.status != .read }.count ?? 0
    }
    
    func markChannelAsRead(_ channelId: String) {
        guard var messages = messageCache[channelId] else { return }
        
        messages = messages.map { message in
            var updated = message
            updated.status = .read
            return updated
        }
        
        messageCache[channelId] = messages
    }
}

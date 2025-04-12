import GameKit
import Foundation

final class FriendManager {
    // MARK: - Properties
    static let shared = FriendManager()
    
    private let networkManager = NetworkManager.shared
    private let analytics = AnalyticsManager.shared
    private let notificationManager = NotificationManager.shared
    
    private var friends: [Friend] = []
    private var pendingInvites: [FriendInvite] = []
    private var onlineFriends: Set<String> = []
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct Friend: Codable {
        let userId: String
        let username: String
        let level: Int
        let rank: Int
        let stats: Stats
        let lastActive: Date
        let status: Status
        
        struct Stats: Codable {
            let wins: Int
            let losses: Int
            let bestReactionTime: Double
            let favoriteCharacter: String
            let gamesPlayed: Int
        }
        
        enum Status: String, Codable {
            case online
            case inGame
            case offline
            case away
            
            var color: SKColor {
                switch self {
                case .online: return .green
                case .inGame: return .blue
                case .offline: return .gray
                case .away: return .orange
                }
            }
        }
    }
    
    struct FriendInvite: Codable {
        let id: String
        let fromUserId: String
        let fromUsername: String
        let toUserId: String
        let status: Status
        let sentDate: Date
        
        enum Status: String, Codable {
            case pending
            case accepted
            case declined
            case expired
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupRefreshTimer()
        loadFriends()
        authenticateGameCenter()
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 30,
            repeats: true
        ) { [weak self] _ in
            self?.refreshFriendStatuses()
        }
    }
    
    // MARK: - Friend Management
    func sendFriendInvite(
        toUserId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                let invite: FriendInvite = try await networkManager.request(
                    endpoint: "friends/invite",
                    method: .post,
                    parameters: ["to_user_id": toUserId]
                )
                
                pendingInvites.append(invite)
                
                analytics.trackEvent(.featureUsed(name: "friend_invite_sent"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func respondToInvite(
        _ invite: FriendInvite,
        accept: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                let response: FriendInvite = try await networkManager.request(
                    endpoint: "friends/invite/\(invite.id)/respond",
                    method: .post,
                    parameters: ["accept": accept]
                )
                
                if accept && response.status == .accepted {
                    // Load new friend
                    loadFriends()
                }
                
                // Remove from pending
                pendingInvites.removeAll { $0.id == invite.id }
                
                analytics.trackEvent(.featureUsed(
                    name: accept ? "friend_invite_accepted" : "friend_invite_declined"
                ))
                
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func removeFriend(
        _ userId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await networkManager.request(
                    endpoint: "friends/\(userId)",
                    method: .delete
                )
                
                friends.removeAll { $0.userId == userId }
                
                analytics.trackEvent(.featureUsed(name: "friend_removed"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Status Management
    private func refreshFriendStatuses() {
        Task {
            do {
                let statuses: [String: Friend.Status] = try await networkManager.request(
                    endpoint: "friends/status",
                    parameters: ["user_ids": friends.map { $0.userId }]
                )
                
                // Update friend statuses
                for (userId, status) in statuses {
                    if let index = friends.firstIndex(where: { $0.userId == userId }) {
                        var friend = friends[index]
                        if friend.status != status {
                            friend.status = status
                            friends[index] = friend
                            
                            // Update online friends set
                            if status == .online || status == .inGame {
                                onlineFriends.insert(userId)
                            } else {
                                onlineFriends.remove(userId)
                            }
                            
                            // Notify if friend came online
                            if status == .online && !onlineFriends.contains(userId) {
                                notifyFriendOnline(friend)
                            }
                        }
                    }
                }
            } catch {
                print("Failed to refresh friend statuses: \(error.localizedDescription)")
            }
        }
    }
    
    private func notifyFriendOnline(_ friend: Friend) {
        notificationManager.scheduleNotification(
            title: "Friend Online",
            body: "\(friend.username) is now online!",
            delay: 0
        )
    }
    
    // MARK: - Game Center Integration
    private func authenticateGameCenter() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            if let error = error {
                print("Game Center authentication failed: \(error.localizedDescription)")
                return
            }
            
            if GKLocalPlayer.local.isAuthenticated {
                self?.loadGameCenterFriends()
            }
        }
    }
    
    private func loadGameCenterFriends() {
        Task {
            do {
                let gcFriends = try await GKLocalPlayer.local.loadFriends()
                
                // Sync Game Center friends with our system
                for gcFriend in gcFriends {
                    if !friends.contains(where: { $0.userId == gcFriend.gamePlayerID }) {
                        sendFriendInvite(toUserId: gcFriend.gamePlayerID) { _ in }
                    }
                }
            } catch {
                print("Failed to load GC friends: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadFriends() {
        Task {
            do {
                let response: FriendsResponse = try await networkManager.request(
                    endpoint: "friends"
                )
                
                friends = response.friends
                pendingInvites = response.pendingInvites
                
                // Update online friends set
                onlineFriends = Set(friends.filter {
                    $0.status == .online || $0.status == .inGame
                }.map { $0.userId })
            } catch {
                print("Failed to load friends: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Queries
    func getFriends() -> [Friend] {
        return friends
    }
    
    func getOnlineFriends() -> [Friend] {
        return friends.filter { onlineFriends.contains($0.userId) }
    }
    
    func getPendingInvites() -> [FriendInvite] {
        return pendingInvites
    }
    
    func getFriend(userId: String) -> Friend? {
        return friends.first { $0.userId == userId }
    }
    
    func isOnline(userId: String) -> Bool {
        return onlineFriends.contains(userId)
    }
    
    // MARK: - Cleanup
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        friends.removeAll()
        pendingInvites.removeAll()
        onlineFriends.removeAll()
    }
}

// MARK: - Network Models
private struct FriendsResponse: Codable {
    let friends: [FriendManager.Friend]
    let pendingInvites: [FriendManager.FriendInvite]
}

// MARK: - Convenience Methods
extension FriendManager {
    func sendGameInvite(
        toUserId: String,
        gameMode: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await networkManager.request(
                    endpoint: "friends/\(toUserId)/invite/game",
                    method: .post,
                    parameters: ["game_mode": gameMode]
                )
                
                analytics.trackEvent(.featureUsed(name: "game_invite_sent"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func getFriendLeaderboard() -> [Friend] {
        return friends.sorted { $0.rank < $1.rank }
    }
    
    func getRecentlyActiveFriends() -> [Friend] {
        let threeDaysAgo = Date().addingTimeInterval(-259200) // 3 days
        return friends.filter { $0.lastActive > threeDaysAgo }
    }
}

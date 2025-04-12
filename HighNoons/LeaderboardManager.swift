import GameKit
import Foundation

final class LeaderboardManager {
    // MARK: - Properties
    static let shared = LeaderboardManager()
    
    private let networkManager = NetworkManager.shared
    private let analytics = AnalyticsManager.shared
    private let playerStats = PlayerStats.shared
    
    private var currentSeason: Season?
    private var cachedLeaderboards: [String: [LeaderboardEntry]] = [:]
    private var lastUpdateTime: [String: Date] = [:]
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct Season: Codable {
        let id: String
        let name: String
        let startDate: Date
        let endDate: Date
        let rewards: [Reward]
        
        struct Reward: Codable {
            let rank: RankRange
            let rewards: [RewardItem]
            
            struct RankRange: Codable {
                let min: Int
                let max: Int
                
                func contains(_ rank: Int) -> Bool {
                    return rank >= min && rank <= max
                }
            }
            
            enum RewardItem: Codable {
                case coins(Int)
                case character(String)
                case badge(String)
                case title(String)
                case special(String)
                
                var description: String {
                    switch self {
                    case .coins(let amount): return "\(amount) Coins"
                    case .character(let name): return "Character: \(name)"
                    case .badge(let name): return "Badge: \(name)"
                    case .title(let name): return "Title: \(name)"
                    case .special(let desc): return desc
                    }
                }
            }
        }
    }
    
    struct LeaderboardEntry: Codable, Comparable {
        let userId: String
        let username: String
        let rank: Int
        let score: Int
        let wins: Int
        let losses: Int
        let averageReactionTime: Double
        let characterId: String
        let title: String?
        let badge: String?
        
        static func < (lhs: LeaderboardEntry, rhs: LeaderboardEntry) -> Bool {
            return lhs.score > rhs.score // Higher score = better rank
        }
    }
    
    enum LeaderboardType: String {
        case global = "global"
        case season = "season"
        case weekly = "weekly"
        case daily = "daily"
        case friends = "friends"
        
        var refreshInterval: TimeInterval {
            switch self {
            case .global: return 300 // 5 minutes
            case .season: return 300
            case .weekly: return 180 // 3 minutes
            case .daily: return 60 // 1 minute
            case .friends: return 60
            }
        }
        
        var cacheLifetime: TimeInterval {
            switch self {
            case .global: return 600 // 10 minutes
            case .season: return 600
            case .weekly: return 300 // 5 minutes
            case .daily: return 120 // 2 minutes
            case .friends: return 120
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupRefreshTimer()
        loadCurrentSeason()
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 60,
            repeats: true
        ) { [weak self] _ in
            self?.refreshStaleLeaderboards()
        }
    }
    
    // MARK: - Leaderboard Management
    func fetchLeaderboard(
        _ type: LeaderboardType,
        forceRefresh: Bool = false
    ) async throws -> [LeaderboardEntry] {
        // Check cache if not forcing refresh
        if !forceRefresh,
           let cached = cachedLeaderboards[type.rawValue],
           let lastUpdate = lastUpdateTime[type.rawValue],
           Date().timeIntervalSince(lastUpdate) < type.cacheLifetime {
            return cached
        }
        
        // Fetch from server
        let entries: [LeaderboardEntry] = try await networkManager.request(
            endpoint: "leaderboards/\(type.rawValue)",
            parameters: [
                "season_id": currentSeason?.id ?? "current"
            ]
        )
        
        // Update cache
        cachedLeaderboards[type.rawValue] = entries
        lastUpdateTime[type.rawValue] = Date()
        
        return entries
    }
    
    func getPlayerRank(
        _ type: LeaderboardType
    ) async throws -> LeaderboardEntry? {
        let entries = try await fetchLeaderboard(type)
        return entries.first { $0.userId == playerStats.userId }
    }
    
    func submitScore(_ score: Int) async throws {
        try await networkManager.request(
            endpoint: "leaderboards/submit",
            method: .post,
            parameters: [
                "score": score,
                "season_id": currentSeason?.id ?? "current"
            ]
        )
        
        // Invalidate caches
        invalidateAllCaches()
        
        // Track analytics
        analytics.trackEvent(.featureUsed(name: "score_submit"))
    }
    
    // MARK: - Season Management
    private func loadCurrentSeason() {
        Task {
            do {
                let season: Season = try await networkManager.request(
                    endpoint: "seasons/current"
                )
                currentSeason = season
                
                // Schedule end of season notification
                NotificationManager.shared.scheduleNotification(
                    title: "Season Ending Soon!",
                    body: "Complete your ranked matches before the season ends!",
                    date: season.endDate.addingTimeInterval(-86400) // 1 day before
                )
            } catch {
                print("Failed to load current season: \(error.localizedDescription)")
            }
        }
    }
    
    func getCurrentSeason() -> Season? {
        return currentSeason
    }
    
    func getSeasonTimeRemaining() -> TimeInterval? {
        guard let season = currentSeason else { return nil }
        return season.endDate.timeIntervalSince(Date())
    }
    
    // MARK: - Rewards
    func claimSeasonRewards() async throws {
        guard let season = currentSeason else { return }
        
        let response: SeasonRewardsResponse = try await networkManager.request(
            endpoint: "seasons/\(season.id)/rewards",
            method: .post
        )
        
        // Grant rewards
        for reward in response.rewards {
            grantReward(reward)
        }
        
        // Track analytics
        analytics.trackEvent(.featureUsed(name: "season_rewards_claim"))
    }
    
    private func grantReward(_ reward: Season.Reward.RewardItem) {
        switch reward {
        case .coins(let amount):
            playerStats.addCoins(amount)
        case .character(let id):
            CharacterManager.shared.unlockCharacter(id)
        case .badge(let id):
            playerStats.addBadge(id)
        case .title(let id):
            playerStats.addTitle(id)
        case .special:
            break
        }
    }
    
    // MARK: - Game Center Integration
    func submitGameCenterScore(_ score: Int) {
        guard let leaderboardID = Bundle.main.object(forInfoDictionaryKey: "GKLeaderboardID") as? String else {
            return
        }
        
        let scoreReporter = GKScore(leaderboardIdentifier: leaderboardID)
        scoreReporter.value = Int64(score)
        
        GKScore.report([scoreReporter]) { error in
            if let error = error {
                print("Failed to submit GC score: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Cache Management
    private func refreshStaleLeaderboards() {
        for type in LeaderboardType.allCases {
            if let lastUpdate = lastUpdateTime[type.rawValue],
               Date().timeIntervalSince(lastUpdate) >= type.refreshInterval {
                Task {
                    try? await fetchLeaderboard(type, forceRefresh: true)
                }
            }
        }
    }
    
    private func invalidateAllCaches() {
        cachedLeaderboards.removeAll()
        lastUpdateTime.removeAll()
    }
    
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        invalidateAllCaches()
    }
}

// MARK: - Network Models
private struct SeasonRewardsResponse: Codable {
    let rewards: [Season.Reward.RewardItem]
}

// MARK: - LeaderboardType Extension
extension LeaderboardManager.LeaderboardType: CaseIterable {}

// MARK: - Convenience Methods
extension LeaderboardManager {
    func getTopPlayers(_ type: LeaderboardType, count: Int = 10) async throws -> [LeaderboardEntry] {
        let entries = try await fetchLeaderboard(type)
        return Array(entries.prefix(count))
    }
    
    func getNearbyPlayers(_ type: LeaderboardType, range: Int = 5) async throws -> [LeaderboardEntry] {
        let entries = try await fetchLeaderboard(type)
        guard let playerEntry = entries.first(where: { $0.userId == playerStats.userId }),
              let playerIndex = entries.firstIndex(of: playerEntry) else {
            return []
        }
        
        let startIndex = max(0, playerIndex - range)
        let endIndex = min(entries.count, playerIndex + range + 1)
        return Array(entries[startIndex..<endIndex])
    }
    
    func getFriendsLeaderboard() async throws -> [LeaderboardEntry] {
        return try await fetchLeaderboard(.friends)
    }
}

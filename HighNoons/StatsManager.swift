import Foundation

final class StatsManager {
    // MARK: - Properties
    static let shared = StatsManager()
    
    private let analytics = AnalyticsManager.shared
    private let networkManager = NetworkManager.shared
    
    private var currentStats: PlayerStatistics?
    private var historicalData: [String: [DataPoint]] = [:]
    private var sessionStats: SessionStats?
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct PlayerStatistics: Codable {
        let overall: OverallStats
        let duels: DuelStats
        let characters: [String: CharacterStats]
        let progression: ProgressionStats
        let social: SocialStats
        let achievements: AchievementStats
        
        struct OverallStats: Codable {
            let totalGames: Int
            let winRate: Double
            let playtime: TimeInterval
            let averageReactionTime: Double
            let accuracy: Double
            let rank: Int
            let seasonRank: Int
            let peakRank: Int
            let level: Int
            let experience: Int
        }
        
        struct DuelStats: Codable {
            let wins: Int
            let losses: Int
            let draws: Int
            let perfectWins: Int
            let earlyDraws: Int
            let fastestReaction: Double
            let averageReactionTime: Double
            let winStreak: Int
            let bestWinStreak: Int
            let matchHistory: [MatchResult]
            
            struct MatchResult: Codable {
                let timestamp: Date
                let opponent: String
                let result: Result
                let reactionTime: Double
                let character: String
                
                enum Result: String, Codable {
                    case win
                    case loss
                    case draw
                }
            }
        }
        
        struct CharacterStats: Codable {
            let gamesPlayed: Int
            let wins: Int
            let losses: Int
            let winRate: Double
            let averageReactionTime: Double
            let bestReactionTime: Double
            let playtime: TimeInterval
            let favoriteMatchup: String?
            let worstMatchup: String?
        }
        
        struct ProgressionStats: Codable {
            let currentSeason: SeasonStats
            let totalSeasons: Int
            let highestSeasonRank: Int
            let totalChallengesCompleted: Int
            let questCompletion: Double
            
            struct SeasonStats: Codable {
                let level: Int
                let experience: Int
                let challengesCompleted: Int
                let rewards: Int
                let startDate: Date
                let endDate: Date
            }
        }
        
        struct SocialStats: Codable {
            let friends: Int
            let clanContribution: Int
            let tournamentsParticipated: Int
            let tournamentsWon: Int
            let reputation: Int
            let commendations: Int
            let reports: Int
        }
        
        struct AchievementStats: Codable {
            let total: Int
            let completed: Int
            let completionRate: Double
            let rarest: String?
            let recent: [String]
        }
    }
    
    struct SessionStats {
        var startTime: Date
        var gamesPlayed: Int
        var wins: Int
        var losses: Int
        var totalReactionTime: Double
        var reactionTimes: [Double]
        var characters: [String: Int]
        var experienceGained: Int
        var coinsEarned: Int
        
        static func start() -> SessionStats {
            return SessionStats(
                startTime: Date(),
                gamesPlayed: 0,
                wins: 0,
                losses: 0,
                totalReactionTime: 0,
                reactionTimes: [],
                characters: [:],
                experienceGained: 0,
                coinsEarned: 0
            )
        }
    }
    
    struct DataPoint: Codable {
        let timestamp: Date
        let value: Double
    }
    
    enum StatType: String {
        case winRate
        case reactionTime
        case accuracy
        case rank
        case level
        case experience
        
        var title: String {
            switch self {
            case .winRate: return "Win Rate"
            case .reactionTime: return "Reaction Time"
            case .accuracy: return "Accuracy"
            case .rank: return "Rank"
            case .level: return "Level"
            case .experience: return "Experience"
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupRefreshTimer()
        startSession()
        loadStats()
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 300, // 5 minutes
            repeats: true
        ) { [weak self] _ in
            self?.refreshStats()
        }
    }
    
    // MARK: - Session Management
    private func startSession() {
        sessionStats = SessionStats.start()
    }
    
    func endSession() {
        guard let stats = sessionStats else { return }
        
        // Track session analytics
        analytics.trackEvent(.sessionEnd(
            duration: Date().timeIntervalSince(stats.startTime),
            gamesPlayed: stats.gamesPlayed,
            winRate: Double(stats.wins) / Double(stats.gamesPlayed)
        ))
        
        sessionStats = nil
    }
    
    // MARK: - Stats Recording
    func recordMatch(
        result: PlayerStatistics.DuelStats.MatchResult,
        reactionTime: Double,
        character: String,
        experience: Int,
        coins: Int
    ) {
        // Update session stats
        sessionStats?.gamesPlayed += 1
        switch result.result {
        case .win:
            sessionStats?.wins += 1
        case .loss:
            sessionStats?.losses += 1
        case .draw:
            break
        }
        
        sessionStats?.totalReactionTime += reactionTime
        sessionStats?.reactionTimes.append(reactionTime)
        sessionStats?.characters[character, default: 0] += 1
        sessionStats?.experienceGained += experience
        sessionStats?.coinsEarned += coins
        
        // Record data points
        recordDataPoint(.winRate, value: calculateWinRate())
        recordDataPoint(.reactionTime, value: reactionTime)
        
        // Update server
        syncStats()
        
        // Track analytics
        analytics.trackEvent(.matchComplete(
            result: result.result.rawValue,
            reactionTime: reactionTime,
            character: character
        ))
    }
    
    private func recordDataPoint(_ type: StatType, value: Double) {
        let point = DataPoint(timestamp: Date(), value: value)
        historicalData[type.rawValue, default: []].append(point)
        
        // Keep only last 100 points
        if historicalData[type.rawValue]?.count ?? 0 > 100 {
            historicalData[type.rawValue]?.removeFirst()
        }
    }
    
    // MARK: - Stats Calculation
    private func calculateWinRate() -> Double {
        guard let stats = sessionStats,
              stats.gamesPlayed > 0 else {
            return 0
        }
        return Double(stats.wins) / Double(stats.gamesPlayed)
    }
    
    func calculateAverageReactionTime() -> Double {
        guard let stats = sessionStats,
              !stats.reactionTimes.isEmpty else {
            return 0
        }
        return stats.totalReactionTime / Double(stats.reactionTimes.count)
    }
    
    func getFavoriteCharacter() -> String? {
        return sessionStats?.characters
            .max(by: { $0.value < $1.value })?
            .key
    }
    
    // MARK: - Data Loading
    private func loadStats() {
        Task {
            do {
                let stats: PlayerStatistics = try await networkManager.request(
                    endpoint: "stats"
                )
                currentStats = stats
                
                // Load historical data
                let history: [String: [DataPoint]] = try await networkManager.request(
                    endpoint: "stats/history"
                )
                historicalData = history
                
                analytics.trackEvent(.featureUsed(name: "stats_loaded"))
            } catch {
                print("Failed to load stats: \(error.localizedDescription)")
            }
        }
    }
    
    private func refreshStats() {
        loadStats()
    }
    
    private func syncStats() {
        guard let stats = currentStats else { return }
        
        Task {
            do {
                try await networkManager.request(
                    endpoint: "stats/sync",
                    method: .post,
                    parameters: ["stats": stats]
                )
            } catch {
                print("Failed to sync stats: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Queries
    func getCurrentStats() -> PlayerStatistics? {
        return currentStats
    }
    
    func getSessionStats() -> SessionStats? {
        return sessionStats
    }
    
    func getHistoricalData(_ type: StatType) -> [DataPoint] {
        return historicalData[type.rawValue] ?? []
    }
    
    func getCharacterStats(_ characterId: String) -> PlayerStatistics.CharacterStats? {
        return currentStats?.characters[characterId]
    }
    
    // MARK: - Analytics
    func generateAnalytics() -> StatsAnalytics {
        guard let stats = currentStats else {
            return StatsAnalytics()
        }
        
        return StatsAnalytics(
            peakPerformance: calculatePeakPerformance(stats),
            improvement: calculateImprovement(),
            recommendations: generateRecommendations(stats)
        )
    }
    
    private func calculatePeakPerformance(_ stats: PlayerStatistics) -> PeakPerformance {
        return PeakPerformance(
            bestReactionTime: stats.duels.fastestReaction,
            highestWinStreak: stats.duels.bestWinStreak,
            bestCharacter: findBestCharacter(stats)
        )
    }
    
    private func calculateImprovement() -> [StatType: Double] {
        var improvements: [StatType: Double] = [:]
        
        for type in StatType.allCases {
            if let data = historicalData[type.rawValue],
               data.count >= 2 {
                let first = data.prefix(10).reduce(0) { $0 + $1.value } / 10
                let last = data.suffix(10).reduce(0) { $0 + $1.value } / 10
                improvements[type] = ((last - first) / first) * 100
            }
        }
        
        return improvements
    }
    
    private func findBestCharacter(_ stats: PlayerStatistics) -> String? {
        return stats.characters
            .max(by: { $0.value.winRate < $1.value.winRate })?
            .key
    }
    
    private func generateRecommendations(_ stats: PlayerStatistics) -> [String] {
        var recommendations: [String] = []
        
        // Reaction time recommendations
        if stats.overall.averageReactionTime > 0.5 {
            recommendations.append("Practice quick-draw timing to improve reaction speed")
        }
        
        // Character recommendations
        if let worstCharacter = stats.characters
            .min(by: { $0.value.winRate < $1.value.winRate })?
            .key {
            recommendations.append("Consider practicing with \(worstCharacter) to improve matchup knowledge")
        }
        
        return recommendations
    }
    
    // MARK: - Cleanup
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        endSession()
    }
}

// MARK: - Supporting Types
extension StatsManager {
    struct StatsAnalytics {
        let peakPerformance: PeakPerformance
        let improvement: [StatType: Double]
        let recommendations: [String]
        
        init(
            peakPerformance: PeakPerformance = PeakPerformance(),
            improvement: [StatType: Double] = [:],
            recommendations: [String] = []
        ) {
            self.peakPerformance = peakPerformance
            self.improvement = improvement
            self.recommendations = recommendations
        }
    }
    
    struct PeakPerformance {
        let bestReactionTime: Double
        let highestWinStreak: Int
        let bestCharacter: String?
        
        init(
            bestReactionTime: Double = 0,
            highestWinStreak: Int = 0,
            bestCharacter: String? = nil
        ) {
            self.bestReactionTime = bestReactionTime
            self.highestWinStreak = highestWinStreak
            self.bestCharacter = bestCharacter
        }
    }
}

// MARK: - StatType Extension
extension StatsManager.StatType: CaseIterable {}

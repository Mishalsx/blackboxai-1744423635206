import Foundation
import GameKit

final class PlayerStats {
    // MARK: - Singleton
    static let shared = PlayerStats()
    private init() {
        loadStats()
    }
    
    // MARK: - Types
    struct Stats: Codable {
        var totalDuels: Int
        var wins: Int
        var losses: Int
        var fastestReaction: TimeInterval
        var averageReaction: TimeInterval
        var totalXP: Int
        var currentLevel: Int
        var selectedCharacter: Int
        var unlockedCharacters: Set<Int>
        var achievements: Set<Achievement>
        var lastDailyReward: Date?
        
        static var new: Stats {
            Stats(
                totalDuels: 0,
                wins: 0,
                losses: 0,
                fastestReaction: 999.0,
                averageReaction: 0.0,
                totalXP: 0,
                currentLevel: 1,
                selectedCharacter: 0,
                unlockedCharacters: [0], // Start with default character
                achievements: [],
                lastDailyReward: nil
            )
        }
    }
    
    enum Achievement: String, Codable {
        case firstWin = "achievement_first_win"
        case quickDraw = "achievement_quick_draw" // Win under 0.3s
        case sharpshooter = "achievement_sharpshooter" // Win 10 duels
        case gunslinger = "achievement_gunslinger" // Win 50 duels
        case legend = "achievement_legend" // Win 100 duels
        case consistent = "achievement_consistent" // Win 5 duels in a row
        
        var xpReward: Int {
            switch self {
            case .firstWin: return 100
            case .quickDraw: return 200
            case .sharpshooter: return 500
            case .gunslinger: return 1000
            case .legend: return 2000
            case .consistent: return 300
            }
        }
    }
    
    // MARK: - Properties
    private(set) var stats: Stats = .new
    private var winStreak: Int = 0
    
    // XP thresholds for each level
    private let levelThresholds: [Int] = [
        0, 1000, 2500, 5000, 10000, 20000, 35000, 50000, 75000, 100000
    ]
    
    // MARK: - Game Center Integration
    private let leaderboardID = "com.highnoons.leaderboard"
    private let achievementPrefix = "com.highnoons.achievement."
    
    // MARK: - Stats Management
    func recordDuel(didWin: Bool, reactionTime: TimeInterval) {
        stats.totalDuels += 1
        
        if didWin {
            stats.wins += 1
            winStreak += 1
            checkWinAchievements()
        } else {
            stats.losses += 1
            winStreak = 0
        }
        
        // Update reaction time stats
        if reactionTime < stats.fastestReaction {
            stats.fastestReaction = reactionTime
            checkReactionAchievements()
        }
        
        // Update average reaction time
        let totalDuels = Double(stats.totalDuels)
        stats.averageReaction = ((stats.averageReaction * (totalDuels - 1)) + reactionTime) / totalDuels
        
        saveStats()
        updateGameCenter()
    }
    
    func addXP(_ amount: Int) {
        stats.totalXP += amount
        checkLevelUp()
        saveStats()
    }
    
    private func checkLevelUp() {
        while stats.currentLevel < levelThresholds.count &&
              stats.totalXP >= levelThresholds[stats.currentLevel] {
            stats.currentLevel += 1
            NotificationCenter.default.post(
                name: .playerLeveledUp,
                object: nil,
                userInfo: ["level": stats.currentLevel]
            )
        }
    }
    
    // MARK: - Character Management
    func selectCharacter(_ index: Int) {
        guard stats.unlockedCharacters.contains(index) else { return }
        stats.selectedCharacter = index
        saveStats()
    }
    
    func unlockCharacter(_ index: Int) {
        stats.unlockedCharacters.insert(index)
        saveStats()
    }
    
    // MARK: - Achievement Checking
    private func checkWinAchievements() {
        // First Win
        if stats.wins == 1 {
            unlockAchievement(.firstWin)
        }
        
        // Win count achievements
        if stats.wins == 10 {
            unlockAchievement(.sharpshooter)
        }
        if stats.wins == 50 {
            unlockAchievement(.gunslinger)
        }
        if stats.wins == 100 {
            unlockAchievement(.legend)
        }
        
        // Win streak achievement
        if winStreak == 5 {
            unlockAchievement(.consistent)
        }
    }
    
    private func checkReactionAchievements() {
        // Quick Draw achievement
        if stats.fastestReaction < 0.3 {
            unlockAchievement(.quickDraw)
        }
    }
    
    private func unlockAchievement(_ achievement: Achievement) {
        guard !stats.achievements.contains(achievement) else { return }
        
        stats.achievements.insert(achievement)
        addXP(achievement.xpReward)
        
        // Report to Game Center
        let gcAchievement = GKAchievement(
            identifier: achievementPrefix + achievement.rawValue
        )
        gcAchievement.percentComplete = 100
        gcAchievement.showsCompletionBanner = true
        
        GKAchievement.report([gcAchievement]) { error in
            if let error = error {
                print("Failed to report achievement: \(error.localizedDescription)")
            }
        }
        
        NotificationCenter.default.post(
            name: .achievementUnlocked,
            object: nil,
            userInfo: ["achievement": achievement]
        )
    }
    
    // MARK: - Daily Rewards
    func checkDailyReward() -> Int? {
        let calendar = Calendar.current
        
        if let lastReward = stats.lastDailyReward,
           calendar.isDate(lastReward, inSameDayAs: Date()) {
            return nil
        }
        
        let reward = calculateDailyReward()
        stats.lastDailyReward = Date()
        addXP(reward)
        saveStats()
        
        return reward
    }
    
    private func calculateDailyReward() -> Int {
        // Base reward + bonus for consecutive days
        return 100 + (stats.currentLevel * 10)
    }
    
    // MARK: - Game Center
    private func updateGameCenter() {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        
        // Report score (based on wins and reaction time)
        let score = GKScore(leaderboardIdentifier: leaderboardID)
        score.value = Int64(stats.wins * 1000 + Int(stats.averageReaction * 1000))
        
        GKScore.report([score]) { error in
            if let error = error {
                print("Failed to report score: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Persistence
    private func saveStats() {
        do {
            let data = try JSONEncoder().encode(stats)
            UserDefaults.standard.set(data, forKey: "playerStats")
        } catch {
            print("Failed to save stats: \(error.localizedDescription)")
        }
    }
    
    private func loadStats() {
        guard let data = UserDefaults.standard.data(forKey: "playerStats") else {
            return
        }
        
        do {
            stats = try JSONDecoder().decode(Stats.self, from: data)
        } catch {
            print("Failed to load stats: \(error.localizedDescription)")
            stats = .new
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let playerLeveledUp = Notification.Name("playerLeveledUp")
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
}

// MARK: - Convenience Extensions
extension PlayerStats {
    var winRate: Double {
        guard stats.totalDuels > 0 else { return 0 }
        return Double(stats.wins) / Double(stats.totalDuels)
    }
    
    var nextLevelXP: Int {
        guard stats.currentLevel < levelThresholds.count else { return 0 }
        return levelThresholds[stats.currentLevel]
    }
    
    var xpProgress: Double {
        guard stats.currentLevel < levelThresholds.count else { return 1.0 }
        let currentThreshold = levelThresholds[stats.currentLevel - 1]
        let nextThreshold = levelThresholds[stats.currentLevel]
        let xpInLevel = stats.totalXP - currentThreshold
        let levelRange = nextThreshold - currentThreshold
        return Double(xpInLevel) / Double(levelRange)
    }
}

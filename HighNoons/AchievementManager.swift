import GameKit
import Foundation

final class AchievementManager {
    // MARK: - Properties
    static let shared = AchievementManager()
    
    private let analytics = AnalyticsManager.shared
    private let popupManager = PopupManager.shared
    private let haptics = HapticsManager.shared
    
    private var cachedAchievements: [Achievement] = []
    private var isAuthenticated = false
    
    // MARK: - Types
    struct Achievement: Codable {
        let id: String
        let title: String
        let description: String
        let points: Int
        let icon: String
        let category: Category
        let requirement: Requirement
        var progress: Double
        var isUnlocked: Bool
        var unlockDate: Date?
        
        enum Category: String, Codable {
            case duel
            case character
            case collection
            case social
            case mastery
            case secret
        }
        
        enum Requirement: Codable {
            case wins(Int)
            case streak(Int)
            case reactionTime(Double)
            case characters(Int)
            case matches(Int)
            case custom(String)
            
            var description: String {
                switch self {
                case .wins(let count):
                    return "Win \(count) duels"
                case .streak(let count):
                    return "Win \(count) duels in a row"
                case .reactionTime(let time):
                    return "React in under \(String(format: "%.2f", time)) seconds"
                case .characters(let count):
                    return "Unlock \(count) characters"
                case .matches(let count):
                    return "Complete \(count) matches"
                case .custom(let desc):
                    return desc
                }
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupAchievements()
        authenticateGameCenter()
    }
    
    private func setupAchievements() {
        cachedAchievements = [
            // Duel Achievements
            Achievement(
                id: "first_win",
                title: "First Blood",
                description: "Win your first duel",
                points: 10,
                icon: "achievement_first_win",
                category: .duel,
                requirement: .wins(1),
                progress: 0,
                isUnlocked: false
            ),
            Achievement(
                id: "quick_draw",
                title: "Quick Draw",
                description: "React in under 0.5 seconds",
                points: 20,
                icon: "achievement_quick_draw",
                category: .duel,
                requirement: .reactionTime(0.5),
                progress: 0,
                isUnlocked: false
            ),
            Achievement(
                id: "winning_streak",
                title: "Hot Streak",
                description: "Win 5 duels in a row",
                points: 30,
                icon: "achievement_streak",
                category: .duel,
                requirement: .streak(5),
                progress: 0,
                isUnlocked: false
            ),
            
            // Character Achievements
            Achievement(
                id: "character_collector",
                title: "Character Collector",
                description: "Unlock all characters",
                points: 50,
                icon: "achievement_collector",
                category: .character,
                requirement: .characters(5),
                progress: 0,
                isUnlocked: false
            ),
            
            // Mastery Achievements
            Achievement(
                id: "duel_master",
                title: "Duel Master",
                description: "Win 100 duels",
                points: 100,
                icon: "achievement_master",
                category: .mastery,
                requirement: .wins(100),
                progress: 0,
                isUnlocked: false
            ),
            
            // Secret Achievements
            Achievement(
                id: "impossible_draw",
                title: "Lightning Reflexes",
                description: "React in under 0.2 seconds",
                points: 200,
                icon: "achievement_impossible",
                category: .secret,
                requirement: .reactionTime(0.2),
                progress: 0,
                isUnlocked: false
            )
        ]
        
        loadProgress()
    }
    
    // MARK: - Game Center
    private func authenticateGameCenter() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            if let viewController = viewController {
                // Present Game Center login if needed
                if let topVC = UIApplication.shared.keyWindow?.rootViewController {
                    topVC.present(viewController, animated: true)
                }
            } else if let error = error {
                print("Game Center authentication failed: \(error.localizedDescription)")
            } else {
                self?.isAuthenticated = true
                self?.syncGameCenter()
            }
        }
    }
    
    private func syncGameCenter() {
        guard isAuthenticated else { return }
        
        GKAchievement.loadAchievements { [weak self] gkAchievements, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Failed to load GC achievements: \(error.localizedDescription)")
                return
            }
            
            // Update local achievements with GC progress
            for achievement in self.cachedAchievements {
                if let gkAchievement = gkAchievements?.first(where: { $0.identifier == achievement.id }) {
                    self.updateProgress(
                        forId: achievement.id,
                        progress: Double(gkAchievement.percentComplete) / 100.0,
                        sync: false
                    )
                }
            }
        }
    }
    
    // MARK: - Achievement Management
    func updateProgress(
        forId id: String,
        progress: Double,
        sync: Bool = true
    ) {
        guard let index = cachedAchievements.firstIndex(where: { $0.id == id }) else { return }
        
        let achievement = cachedAchievements[index]
        let newProgress = min(1.0, max(progress, achievement.progress))
        
        if newProgress > achievement.progress {
            cachedAchievements[index].progress = newProgress
            
            if newProgress >= 1.0 && !achievement.isUnlocked {
                unlockAchievement(achievement)
            }
            
            if sync {
                syncProgress(id: id, progress: newProgress)
            }
            
            saveProgress()
        }
    }
    
    private func unlockAchievement(_ achievement: Achievement) {
        guard var achievement = cachedAchievements.first(where: { $0.id == achievement.id }),
              !achievement.isUnlocked else { return }
        
        achievement.isUnlocked = true
        achievement.unlockDate = Date()
        
        // Update cache
        if let index = cachedAchievements.firstIndex(where: { $0.id == achievement.id }) {
            cachedAchievements[index] = achievement
        }
        
        // Show notification
        if let scene = UIApplication.shared.keyWindow?.rootViewController?.view as? SKView,
           let currentScene = scene.scene {
            showUnlockNotification(achievement, in: currentScene)
        }
        
        // Track analytics
        analytics.trackEvent(.achievementUnlocked(name: achievement.title))
        
        // Save progress
        saveProgress()
    }
    
    private func syncProgress(id: String, progress: Double) {
        guard isAuthenticated else { return }
        
        let gkAchievement = GKAchievement(identifier: id)
        gkAchievement.percentComplete = Double(progress * 100.0)
        gkAchievement.showsCompletionBanner = false
        
        GKAchievement.report([gkAchievement]) { error in
            if let error = error {
                print("Failed to sync achievement: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Progress Persistence
    private func saveProgress() {
        let progress = cachedAchievements.map {
            [
                "id": $0.id,
                "progress": $0.progress,
                "unlocked": $0.isUnlocked,
                "date": $0.unlockDate?.timeIntervalSince1970 ?? 0
            ]
        }
        
        UserDefaults.standard.set(progress, forKey: "achievementProgress")
    }
    
    private func loadProgress() {
        guard let progress = UserDefaults.standard.array(forKey: "achievementProgress") as? [[String: Any]] else {
            return
        }
        
        for achievementProgress in progress {
            guard let id = achievementProgress["id"] as? String,
                  let progress = achievementProgress["progress"] as? Double,
                  let unlocked = achievementProgress["unlocked"] as? Bool else {
                continue
            }
            
            if let index = cachedAchievements.firstIndex(where: { $0.id == id }) {
                cachedAchievements[index].progress = progress
                cachedAchievements[index].isUnlocked = unlocked
                
                if unlocked,
                   let timestamp = achievementProgress["date"] as? TimeInterval {
                    cachedAchievements[index].unlockDate = Date(timeIntervalSince1970: timestamp)
                }
            }
        }
    }
    
    // MARK: - Notifications
    private func showUnlockNotification(_ achievement: Achievement, in scene: SKScene) {
        haptics.playPattern(.success)
        
        popupManager.showPopup(
            style: .achievement,
            title: "Achievement Unlocked!",
            message: "\(achievement.title)\n+\(achievement.points) points",
            buttons: [
                PopupButton(title: "Awesome!", style: .primary) {}
            ],
            in: scene
        )
    }
    
    // MARK: - Queries
    func getAchievement(id: String) -> Achievement? {
        return cachedAchievements.first { $0.id == id }
    }
    
    func getAchievements(category: Achievement.Category? = nil) -> [Achievement] {
        if let category = category {
            return cachedAchievements.filter { $0.category == category }
        }
        return cachedAchievements
    }
    
    func getUnlockedAchievements() -> [Achievement] {
        return cachedAchievements.filter { $0.isUnlocked }
    }
    
    func getLockedAchievements() -> [Achievement] {
        return cachedAchievements.filter { !$0.isUnlocked }
    }
    
    func getTotalPoints() -> Int {
        return cachedAchievements.filter { $0.isUnlocked }.reduce(0) { $0 + $1.points }
    }
    
    func getProgress() -> Double {
        let total = Double(cachedAchievements.count)
        let unlocked = Double(getUnlockedAchievements().count)
        return unlocked / total
    }
}

// MARK: - Convenience Methods
extension AchievementManager {
    func checkDuelAchievements(reactionTime: Double, isWin: Bool, streak: Int) {
        if isWin {
            updateProgress(forId: "first_win", progress: 1.0)
            updateProgress(forId: "duel_master", progress: Double(streak) / 100.0)
        }
        
        if reactionTime <= 0.5 {
            updateProgress(forId: "quick_draw", progress: 1.0)
        }
        
        if reactionTime <= 0.2 {
            updateProgress(forId: "impossible_draw", progress: 1.0)
        }
        
        if streak >= 5 {
            updateProgress(forId: "winning_streak", progress: 1.0)
        }
    }
    
    func checkCharacterAchievements(unlockedCount: Int) {
        updateProgress(
            forId: "character_collector",
            progress: Double(unlockedCount) / 5.0
        )
    }
}

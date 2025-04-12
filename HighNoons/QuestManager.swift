import Foundation

final class QuestManager {
    // MARK: - Properties
    static let shared = QuestManager()
    
    private let analytics = AnalyticsManager.shared
    private let playerStats = PlayerStats.shared
    private let notificationManager = NotificationManager.shared
    
    private var activeQuests: [Quest] = []
    private var completedQuests: [String: Date] = [:]
    private var lastRefreshDate: Date?
    
    // MARK: - Types
    struct Quest: Codable {
        let id: String
        let title: String
        let description: String
        let type: QuestType
        let requirement: Requirement
        let reward: Reward
        let duration: Duration
        var progress: Int
        var isCompleted: Bool
        var expiryDate: Date
        
        enum QuestType: String, Codable {
            case duel
            case character
            case social
            case achievement
            case special
        }
        
        enum Requirement: Codable {
            case wins(Int)
            case matches(Int)
            case perfectWins(Int)
            case characterUse(String, Int)
            case reactionTime(Double, Int)
            case achievementProgress(String, Double)
            case socialShare(Int)
            
            var description: String {
                switch self {
                case .wins(let count):
                    return "Win \(count) duels"
                case .matches(let count):
                    return "Complete \(count) matches"
                case .perfectWins(let count):
                    return "Win \(count) perfect duels"
                case .characterUse(let character, let count):
                    return "Win \(count) duels with \(character)"
                case .reactionTime(let time, let count):
                    return "React under \(String(format: "%.2f", time))s \(count) times"
                case .achievementProgress(let achievement, let progress):
                    return "Progress \(achievement) to \(Int(progress * 100))%"
                case .socialShare(let count):
                    return "Share \(count) replays"
                }
            }
            
            var target: Int {
                switch self {
                case .wins(let count): return count
                case .matches(let count): return count
                case .perfectWins(let count): return count
                case .characterUse(_, let count): return count
                case .reactionTime(_, let count): return count
                case .achievementProgress(_, let progress): return Int(progress * 100)
                case .socialShare(let count): return count
                }
            }
        }
        
        enum Reward: Codable {
            case coins(Int)
            case xp(Int)
            case character(String)
            case powerup(String)
            case special(String)
            
            var description: String {
                switch self {
                case .coins(let amount):
                    return "\(amount) coins"
                case .xp(let amount):
                    return "\(amount) XP"
                case .character(let name):
                    return "Character: \(name)"
                case .powerup(let name):
                    return "Power-up: \(name)"
                case .special(let desc):
                    return desc
                }
            }
        }
        
        enum Duration: String, Codable {
            case daily
            case weekly
            case special
            
            var hours: Int {
                switch self {
                case .daily: return 24
                case .weekly: return 168
                case .special: return 72
                }
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        loadQuests()
        checkForRefresh()
    }
    
    // MARK: - Quest Management
    private func generateQuests(for duration: Quest.Duration) -> [Quest] {
        let now = Date()
        let expiryDate = Calendar.current.date(
            byAdding: .hour,
            value: duration.hours,
            to: now
        ) ?? now
        
        switch duration {
        case .daily:
            return [
                Quest(
                    id: "daily_wins_\(now.timeIntervalSince1970)",
                    title: "Daily Duelist",
                    description: "Win duels today",
                    type: .duel,
                    requirement: .wins(3),
                    reward: .coins(100),
                    duration: .daily,
                    progress: 0,
                    isCompleted: false,
                    expiryDate: expiryDate
                ),
                Quest(
                    id: "daily_perfect_\(now.timeIntervalSince1970)",
                    title: "Perfect Shot",
                    description: "Achieve perfect reaction times",
                    type: .duel,
                    requirement: .reactionTime(0.5, 2),
                    reward: .xp(150),
                    duration: .daily,
                    progress: 0,
                    isCompleted: false,
                    expiryDate: expiryDate
                )
            ]
            
        case .weekly:
            return [
                Quest(
                    id: "weekly_matches_\(now.timeIntervalSince1970)",
                    title: "Weekly Warrior",
                    description: "Complete matches this week",
                    type: .duel,
                    requirement: .matches(20),
                    reward: .coins(500),
                    duration: .weekly,
                    progress: 0,
                    isCompleted: false,
                    expiryDate: expiryDate
                ),
                Quest(
                    id: "weekly_character_\(now.timeIntervalSince1970)",
                    title: "Character Mastery",
                    description: "Win with The Sheriff",
                    type: .character,
                    requirement: .characterUse("sheriff", 10),
                    reward: .powerup("quickdraw"),
                    duration: .weekly,
                    progress: 0,
                    isCompleted: false,
                    expiryDate: expiryDate
                )
            ]
            
        case .special:
            return [
                Quest(
                    id: "special_event_\(now.timeIntervalSince1970)",
                    title: "Special Event",
                    description: "Complete special challenges",
                    type: .special,
                    requirement: .perfectWins(5),
                    reward: .special("Exclusive Badge"),
                    duration: .special,
                    progress: 0,
                    isCompleted: false,
                    expiryDate: expiryDate
                )
            ]
        }
    }
    
    private func checkForRefresh() {
        let now = Date()
        
        // Check daily refresh
        if let lastRefresh = lastRefreshDate,
           !Calendar.current.isDate(lastRefresh, inSameDayAs: now) {
            refreshQuests()
        }
        
        // Remove expired quests
        activeQuests = activeQuests.filter { $0.expiryDate > now }
        
        // Schedule next refresh
        scheduleNextRefresh()
    }
    
    private func refreshQuests() {
        let now = Date()
        lastRefreshDate = now
        
        // Archive completed quests
        for quest in activeQuests where quest.isCompleted {
            completedQuests[quest.id] = now
        }
        
        // Remove expired quests
        activeQuests = activeQuests.filter { $0.expiryDate > now }
        
        // Add new daily quests
        activeQuests.append(contentsOf: generateQuests(for: .daily))
        
        // Add new weekly quests if needed
        if activeQuests.filter({ $0.duration == .weekly }).isEmpty {
            activeQuests.append(contentsOf: generateQuests(for: .weekly))
        }
        
        saveQuests()
        
        // Notify user
        notificationManager.scheduleNotification(
            title: "New Quests Available!",
            body: "New challenges await you in High Noons!",
            delay: 3600 // 1 hour
        )
    }
    
    // MARK: - Progress Tracking
    func updateProgress(for event: GameEvent) {
        for (index, quest) in activeQuests.enumerated() {
            guard !quest.isCompleted else { continue }
            
            var progress = quest.progress
            
            switch (quest.requirement, event) {
            case (.wins(let target), .duelWin):
                progress += 1
                if progress >= target {
                    completeQuest(at: index)
                }
                
            case (.matches(let target), .duelComplete):
                progress += 1
                if progress >= target {
                    completeQuest(at: index)
                }
                
            case (.perfectWins(let target), .perfectWin):
                progress += 1
                if progress >= target {
                    completeQuest(at: index)
                }
                
            case (.characterUse(let character, let target), .characterWin(let usedCharacter)):
                if character == usedCharacter {
                    progress += 1
                    if progress >= target {
                        completeQuest(at: index)
                    }
                }
                
            case (.reactionTime(let targetTime, let target), .reactionTime(let time)):
                if time <= targetTime {
                    progress += 1
                    if progress >= target {
                        completeQuest(at: index)
                    }
                }
                
            case (.socialShare(let target), .shareCompleted):
                progress += 1
                if progress >= target {
                    completeQuest(at: index)
                }
                
            default:
                continue
            }
            
            activeQuests[index].progress = progress
            saveQuests()
        }
    }
    
    private func completeQuest(at index: Int) {
        guard index < activeQuests.count else { return }
        
        activeQuests[index].isCompleted = true
        let quest = activeQuests[index]
        
        // Grant reward
        grantReward(quest.reward)
        
        // Track analytics
        analytics.trackEvent(.featureUsed(name: "quest_complete"))
        
        // Show notification
        if let scene = UIApplication.shared.keyWindow?.rootViewController?.view as? SKView,
           let currentScene = scene.scene {
            showCompletionNotification(quest, in: currentScene)
        }
        
        saveQuests()
    }
    
    // MARK: - Rewards
    private func grantReward(_ reward: Quest.Reward) {
        switch reward {
        case .coins(let amount):
            playerStats.addCoins(amount)
        case .xp(let amount):
            playerStats.addXP(amount)
        case .character(let id):
            CharacterManager.shared.unlockCharacter(id)
        case .powerup(let id):
            playerStats.addPowerup(id)
        case .special:
            // Handle special rewards
            break
        }
    }
    
    // MARK: - Persistence
    private func saveQuests() {
        let questData = try? JSONEncoder().encode(activeQuests)
        UserDefaults.standard.set(questData, forKey: "activeQuests")
        
        let completedData = try? JSONEncoder().encode(completedQuests)
        UserDefaults.standard.set(completedData, forKey: "completedQuests")
        
        UserDefaults.standard.set(lastRefreshDate, forKey: "questRefreshDate")
    }
    
    private func loadQuests() {
        if let data = UserDefaults.standard.data(forKey: "activeQuests"),
           let quests = try? JSONDecoder().decode([Quest].self, from: data) {
            activeQuests = quests
        }
        
        if let data = UserDefaults.standard.data(forKey: "completedQuests"),
           let completed = try? JSONDecoder().decode([String: Date].self, from: data) {
            completedQuests = completed
        }
        
        lastRefreshDate = UserDefaults.standard.object(forKey: "questRefreshDate") as? Date
    }
    
    // MARK: - Notifications
    private func showCompletionNotification(_ quest: Quest, in scene: SKScene) {
        PopupManager.shared.showPopup(
            style: .reward,
            title: "Quest Completed!",
            message: "\(quest.title)\nReward: \(quest.reward.description)",
            buttons: [
                PopupButton(title: "Collect", style: .primary) {}
            ],
            in: scene
        )
    }
    
    private func scheduleNextRefresh() {
        // Schedule next daily refresh
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: Date())
        ) else { return }
        
        notificationManager.scheduleNotification(
            title: "New Daily Quests",
            body: "New quests are available! Complete them for rewards!",
            date: tomorrow
        )
    }
}

// MARK: - Game Events
enum GameEvent {
    case duelWin
    case duelComplete
    case perfectWin
    case characterWin(String)
    case reactionTime(Double)
    case shareCompleted
}

// MARK: - Convenience Methods
extension QuestManager {
    func getActiveQuests(type: Quest.QuestType? = nil) -> [Quest] {
        if let type = type {
            return activeQuests.filter { $0.type == type }
        }
        return activeQuests
    }
    
    func getDailyQuests() -> [Quest] {
        return activeQuests.filter { $0.duration == .daily }
    }
    
    func getWeeklyQuests() -> [Quest] {
        return activeQuests.filter { $0.duration == .weekly }
    }
    
    func getSpecialQuests() -> [Quest] {
        return activeQuests.filter { $0.duration == .special }
    }
    
    func getCompletedQuests() -> [Quest] {
        return activeQuests.filter { $0.isCompleted }
    }
    
    func getQuestProgress() -> Double {
        let completed = Double(getCompletedQuests().count)
        let total = Double(activeQuests.count)
        return completed / total
    }
}

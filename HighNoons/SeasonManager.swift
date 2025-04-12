import Foundation
import SpriteKit

final class SeasonManager {
    // MARK: - Properties
    static let shared = SeasonManager()
    
    private let networkManager = NetworkManager.shared
    private let analytics = AnalyticsManager.shared
    private let notificationManager = NotificationManager.shared
    
    private var currentSeason: Season?
    private var seasonProgress: SeasonProgress?
    private var seasonRewards: [SeasonReward] = []
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct Season: Codable {
        let id: String
        let name: String
        let theme: Theme
        let startDate: Date
        let endDate: Date
        let levels: Int
        let features: [Feature]
        let challenges: [Challenge]
        
        struct Theme: Codable {
            let name: String
            let description: String
            let colors: Colors
            let assets: Assets
            let music: Music
            let weather: Weather
            
            struct Colors: Codable {
                let primary: String
                let secondary: String
                let accent: String
                let background: String
                
                func toSKColor() -> (primary: SKColor, secondary: SKColor, accent: SKColor, background: SKColor) {
                    return (
                        SKColor(hex: primary),
                        SKColor(hex: secondary),
                        SKColor(hex: accent),
                        SKColor(hex: background)
                    )
                }
            }
            
            struct Assets: Codable {
                let background: String
                let icons: [String: String]
                let particles: [String: String]
                let decorations: [String]
            }
            
            struct Music: Codable {
                let mainTheme: String
                let battleTheme: String
                let victoryTheme: String
                let ambientSounds: [String]
            }
            
            struct Weather: Codable {
                let types: [WeatherManager.WeatherType]
                let frequency: Double
                let intensity: Double
            }
        }
        
        struct Feature: Codable {
            let type: FeatureType
            let name: String
            let description: String
            let requirements: [Requirement]
            
            enum FeatureType: String, Codable {
                case gameMode
                case character
                case location
                case powerup
                case event
            }
            
            struct Requirement: Codable {
                let type: RequirementType
                let value: Int
                
                enum RequirementType: String, Codable {
                    case level
                    case wins
                    case rank
                    case special
                }
            }
        }
        
        struct Challenge: Codable {
            let id: String
            let name: String
            let description: String
            let requirement: Requirement
            let reward: SeasonReward
            let duration: TimeInterval
            
            enum Requirement: Codable {
                case wins(Int)
                case perfectWins(Int)
                case useCharacter(String, Int)
                case reactionTime(Double, Int)
                case special(String, Int)
                
                var description: String {
                    switch self {
                    case .wins(let count):
                        return "Win \(count) duels"
                    case .perfectWins(let count):
                        return "Win \(count) perfect duels"
                    case .useCharacter(let character, let count):
                        return "Win \(count) duels with \(character)"
                    case .reactionTime(let time, let count):
                        return "React under \(String(format: "%.2f", time))s \(count) times"
                    case .special(let desc, let count):
                        return "\(desc) \(count) times"
                    }
                }
            }
        }
    }
    
    struct SeasonProgress: Codable {
        let level: Int
        let experience: Int
        let requiredExperience: Int
        let completedChallenges: Set<String>
        let unlockedFeatures: Set<String>
        let statistics: Statistics
        
        struct Statistics: Codable {
            let wins: Int
            let perfectWins: Int
            let averageReactionTime: Double
            let favoriteCharacter: String
            let playtime: TimeInterval
        }
    }
    
    struct SeasonReward: Codable {
        let level: Int
        let type: RewardType
        let amount: Int
        let claimed: Bool
        
        enum RewardType: String, Codable {
            case coins
            case character
            case powerup
            case emote
            case badge
            case title
            case special
            
            var description: String {
                switch self {
                case .coins: return "Coins"
                case .character: return "Character"
                case .powerup: return "Power-up"
                case .emote: return "Emote"
                case .badge: return "Badge"
                case .title: return "Title"
                case .special: return "Special Reward"
                }
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
            withTimeInterval: 3600, // 1 hour
            repeats: true
        ) { [weak self] _ in
            self?.checkSeasonTransition()
        }
    }
    
    // MARK: - Season Management
    private func loadCurrentSeason() {
        Task {
            do {
                let response: SeasonResponse = try await networkManager.request(
                    endpoint: "seasons/current"
                )
                
                currentSeason = response.season
                seasonProgress = response.progress
                seasonRewards = response.rewards
                
                // Apply season theme
                applySeasonTheme()
                
                // Schedule end notification
                scheduleSeasonEndNotification()
                
                analytics.trackEvent(.featureUsed(name: "season_loaded"))
            } catch {
                print("Failed to load season: \(error.localizedDescription)")
            }
        }
    }
    
    private func checkSeasonTransition() {
        guard let season = currentSeason else { return }
        
        if Date() >= season.endDate {
            handleSeasonEnd()
        }
    }
    
    private func handleSeasonEnd() {
        Task {
            do {
                let rewards: [SeasonReward] = try await networkManager.request(
                    endpoint: "seasons/current/rewards"
                )
                
                // Grant final rewards
                for reward in rewards {
                    grantReward(reward)
                }
                
                // Load new season
                loadCurrentSeason()
                
                analytics.trackEvent(.featureUsed(name: "season_completed"))
            } catch {
                print("Failed to handle season end: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Theme Application
    private func applySeasonTheme() {
        guard let theme = currentSeason?.theme else { return }
        
        // Apply colors
        let colors = theme.colors.toSKColor()
        UIConfig.primaryColor = colors.primary
        UIConfig.secondaryColor = colors.secondary
        UIConfig.accentColor = colors.accent
        UIConfig.backgroundColor = colors.background
        
        // Apply music
        SoundtrackManager.shared.updateSeasonalTracks(
            main: theme.music.mainTheme,
            battle: theme.music.battleTheme,
            victory: theme.music.victoryTheme
        )
        
        // Apply weather
        WeatherManager.shared.updateSeasonalWeather(
            types: theme.weather.types,
            frequency: theme.weather.frequency,
            intensity: theme.weather.intensity
        )
    }
    
    // MARK: - Progress Management
    func addExperience(_ amount: Int) {
        guard var progress = seasonProgress else { return }
        
        progress.experience += amount
        
        // Check for level up
        while progress.experience >= progress.requiredExperience {
            progress.experience -= progress.requiredExperience
            progress.level += 1
            
            handleLevelUp(progress.level)
        }
        
        seasonProgress = progress
        saveProgress()
    }
    
    private func handleLevelUp(_ level: Int) {
        // Grant level rewards
        if let reward = seasonRewards.first(where: { $0.level == level }) {
            grantReward(reward)
        }
        
        // Unlock features
        if let season = currentSeason {
            for feature in season.features {
                if feature.requirements.allSatisfy({ requirement in
                    switch requirement.type {
                    case .level:
                        return level >= requirement.value
                    default:
                        return true
                    }
                }) {
                    unlockFeature(feature)
                }
            }
        }
        
        analytics.trackEvent(.featureUsed(name: "season_level_up"))
    }
    
    private func grantReward(_ reward: SeasonReward) {
        switch reward.type {
        case .coins:
            PlayerStats.shared.addCoins(reward.amount)
        case .character:
            CharacterManager.shared.unlockCharacter(String(reward.amount))
        case .powerup:
            PowerupManager.shared.addPowerup(String(reward.amount))
        case .emote:
            // Handle emote unlock
            break
        case .badge:
            // Handle badge unlock
            break
        case .title:
            // Handle title unlock
            break
        case .special:
            // Handle special reward
            break
        }
    }
    
    private func unlockFeature(_ feature: Season.Feature) {
        guard var progress = seasonProgress else { return }
        progress.unlockedFeatures.insert(feature.name)
        seasonProgress = progress
        saveProgress()
        
        analytics.trackEvent(.featureUsed(name: "season_feature_unlock"))
    }
    
    // MARK: - Challenge Management
    func completeChallenge(_ challengeId: String) {
        guard var progress = seasonProgress,
              !progress.completedChallenges.contains(challengeId),
              let challenge = currentSeason?.challenges.first(where: { $0.id == challengeId }) else {
            return
        }
        
        progress.completedChallenges.insert(challengeId)
        seasonProgress = progress
        
        // Grant reward
        grantReward(challenge.reward)
        
        saveProgress()
        analytics.trackEvent(.featureUsed(name: "season_challenge_complete"))
    }
    
    // MARK: - Persistence
    private func saveProgress() {
        guard let progress = seasonProgress else { return }
        
        Task {
            do {
                try await networkManager.request(
                    endpoint: "seasons/current/progress",
                    method: .post,
                    parameters: ["progress": progress]
                )
            } catch {
                print("Failed to save progress: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Notifications
    private func scheduleSeasonEndNotification() {
        guard let season = currentSeason else { return }
        
        // 1 day before
        notificationManager.scheduleNotification(
            title: "Season Ending Soon!",
            body: "Complete your season pass before the season ends!",
            date: season.endDate.addingTimeInterval(-86400)
        )
        
        // 1 hour before
        notificationManager.scheduleNotification(
            title: "Last Chance!",
            body: "Only 1 hour left in the current season!",
            date: season.endDate.addingTimeInterval(-3600)
        )
    }
    
    // MARK: - Queries
    func getCurrentSeason() -> Season? {
        return currentSeason
    }
    
    func getSeasonProgress() -> SeasonProgress? {
        return seasonProgress
    }
    
    func getAvailableChallenges() -> [Season.Challenge] {
        guard let season = currentSeason,
              let progress = seasonProgress else {
            return []
        }
        
        return season.challenges.filter {
            !progress.completedChallenges.contains($0.id)
        }
    }
    
    func getUnlockedFeatures() -> [Season.Feature] {
        guard let season = currentSeason,
              let progress = seasonProgress else {
            return []
        }
        
        return season.features.filter {
            progress.unlockedFeatures.contains($0.name)
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        currentSeason = nil
        seasonProgress = nil
        seasonRewards.removeAll()
    }
}

// MARK: - Network Models
private struct SeasonResponse: Codable {
    let season: SeasonManager.Season
    let progress: SeasonManager.SeasonProgress
    let rewards: [SeasonManager.SeasonReward]
}

// MARK: - SKColor Extension
private extension SKColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

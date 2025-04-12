import UIKit
import CoreGraphics

// MARK: - Game Configuration
enum GameConfig {
    // Game Settings
    static let defaultReactionTimeLimit: TimeInterval = 3.0
    static let earlyDrawPenaltyTime: TimeInterval = 0.5
    static let minimumRaisedAngle: Float = 60.0 // degrees
    static let matchmakingTimeout: TimeInterval = 30.0
    
    // Gameplay Balance
    static let baseXPPerWin = 100
    static let streakBonusMultiplier = 0.2 // 20% bonus per win streak
    static let maxWinStreak = 5
    static let rankThresholds = [
        0,      // Rookie
        1000,   // Deputy
        2500,   // Sheriff
        5000,   // Marshal
        10000,  // Legend
        25000   // High Noon Master
    ]
    
    // Tutorial
    static let tutorialSteps = 5
    static let tutorialTimeLimit: TimeInterval = 5.0
    
    // Matchmaking
    static let skillRangeInitial: Int = 200
    static let skillRangeIncrement: Int = 100
    static let maxSkillRange: Int = 1000
    static let matchmakingExpandInterval: TimeInterval = 5.0
    
    // Daily Rewards
    static let dailyRewardBase = 100
    static let dailyRewardMultiplier = 1.5
    static let maxDailyStreak = 7
    
    // Store
    static let characterUnlockLevels = [
        "sheriff": 1,
        "deputy": 5,
        "outlaw": 10,
        "marshal": 15,
        "legend": 20
    ]
}

// MARK: - UI Configuration
enum UIConfig {
    // Colors
    static let primaryColor = UIColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1.0)
    static let secondaryColor = UIColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1.0)
    static let accentColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
    static let backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
    
    // Fonts
    static let titleFont = "Western-Font"
    static let bodyFont = "Arial"
    static let titleFontSize: CGFloat = 48.0
    static let bodyFontSize: CGFloat = 24.0
    
    // Animations
    static let fadeInDuration: TimeInterval = 0.3
    static let fadeOutDuration: TimeInterval = 0.3
    static let scaleUpDuration: TimeInterval = 0.2
    static let scaleDownDuration: TimeInterval = 0.1
    
    // Layout
    static let standardSpacing: CGFloat = 20.0
    static let buttonHeight: CGFloat = 60.0
    static let cornerRadius: CGFloat = 10.0
    static let borderWidth: CGFloat = 2.0
}

// MARK: - Network Configuration
enum NetworkConfig {
    // API
    static let baseURL = "https://api.highnoons.com"
    static let apiVersion = "v1"
    static let timeoutInterval: TimeInterval = 30.0
    
    // WebSocket
    static let wsURL = "wss://ws.highnoons.com"
    static let wsReconnectInterval: TimeInterval = 5.0
    static let wsMaxReconnectAttempts = 5
    
    // Cache
    static let cacheDuration: TimeInterval = 3600 // 1 hour
    static let maxCacheSize = 50 * 1024 * 1024 // 50MB
}

// MARK: - Analytics Configuration
enum AnalyticsConfig {
    // Events
    static let maxEventParameters = 25
    static let maxUserProperties = 25
    
    // Session
    static let sessionTimeout: TimeInterval = 1800 // 30 minutes
    static let minimumSessionDuration: TimeInterval = 10.0
    
    // Sampling
    static let performanceSamplingRate = 0.1 // 10% of sessions
    static let errorSamplingRate = 1.0 // 100% of errors
}

// MARK: - Audio Configuration
enum AudioConfig {
    // Volume
    static let defaultMusicVolume: Float = 0.7
    static let defaultSFXVolume: Float = 1.0
    
    // Fade
    static let musicFadeInDuration: TimeInterval = 2.0
    static let musicFadeOutDuration: TimeInterval = 1.0
    
    // Categories
    static let musicCategory = "music"
    static let sfxCategory = "sfx"
    static let voiceCategory = "voice"
}

// MARK: - Notification Configuration
enum NotificationConfig {
    // Scheduling
    static let dailyNotificationHour = 9 // 9 AM
    static let challengeNotificationHour = 12 // 12 PM
    static let inactivityReminderDays = 3
    
    // Limits
    static let maxNotificationsPerDay = 5
    static let maxNotificationCategories = 4
}

// MARK: - Store Configuration
enum StoreConfig {
    // Products
    static let consumableProducts = [
        "coins.1000": 0.99,
        "coins.2500": 1.99,
        "coins.5000": 4.99
    ]
    
    static let nonConsumableProducts = [
        "noads": 4.99,
        "allcharacters": 9.99,
        "vippass": 19.99
    ]
    
    // Currency
    static let currencySymbol = "$"
    static let defaultCurrency = "USD"
}

// MARK: - Achievement Configuration
enum AchievementConfig {
    // IDs
    static let achievementPrefix = "com.highnoons.achievement."
    
    // Requirements
    static let winCountAchievements = [
        "novice": 10,
        "intermediate": 50,
        "expert": 100,
        "master": 500
    ]
    
    static let reactionTimeAchievements = [
        "quickdraw": 0.5,
        "lightning": 0.3,
        "impossible": 0.2
    ]
    
    // Rewards
    static let achievementXPRewards = [
        "novice": 100,
        "intermediate": 500,
        "expert": 1000,
        "master": 5000,
        "quickdraw": 200,
        "lightning": 1000,
        "impossible": 5000
    ]
}

// MARK: - Debug Configuration
enum DebugConfig {
    // Flags
    static let isDebugMode = false
    static let showFrameRate = false
    static let logNetworkCalls = false
    static let simulateLatency = false
    
    // Values
    static let simulatedLatency: TimeInterval = 0.2
    static let maxLogSize = 1024 * 1024 // 1MB
}

// MARK: - Convenience Extensions
extension UIColor {
    static let primaryColor = UIConfig.primaryColor
    static let secondaryColor = UIConfig.secondaryColor
    static let accentColor = UIConfig.accentColor
    static let backgroundColor = UIConfig.backgroundColor
}

extension TimeInterval {
    static let fadeIn = UIConfig.fadeInDuration
    static let fadeOut = UIConfig.fadeOutDuration
    static let scaleUp = UIConfig.scaleUpDuration
    static let scaleDown = UIConfig.scaleDownDuration
}

extension CGFloat {
    static let standardSpacing = UIConfig.standardSpacing
    static let buttonHeight = UIConfig.buttonHeight
    static let cornerRadius = UIConfig.cornerRadius
    static let borderWidth = UIConfig.borderWidth
}

// MARK: - Notification Names
extension Notification.Name {
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
    static let dailyRewardAvailable = Notification.Name("dailyRewardAvailable")
    static let playerLeveledUp = Notification.Name("playerLeveledUp")
    static let challengeCompleted = Notification.Name("challengeCompleted")
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
    static let premiumStatusChanged = Notification.Name("premiumStatusChanged")
}

// MARK: - UserDefaults Keys
extension UserDefaults {
    enum Keys {
        static let hasCompletedTutorial = "hasCompletedTutorial"
        static let lastDailyReward = "lastDailyReward"
        static let selectedCharacter = "selectedCharacter"
        static let musicVolume = "musicVolume"
        static let sfxVolume = "sfxVolume"
        static let hapticsFeedback = "hapticsFeedback"
        static let language = "language"
        static let pushNotifications = "pushNotifications"
    }
}

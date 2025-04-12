import Foundation
import AVFoundation

final class SettingsManager {
    // MARK: - Properties
    static let shared = SettingsManager()
    
    private let analytics = AnalyticsManager.shared
    private let defaults = UserDefaults.standard
    
    // MARK: - Setting Keys
    private enum SettingKey: String {
        // Audio
        case masterVolume
        case musicVolume
        case sfxVolume
        case voiceVolume
        case muteWhenInactive
        
        // Graphics
        case graphicsQuality
        case frameRate
        case particleEffects
        case showFPS
        case reducedMotion
        
        // Gameplay
        case sensitivity
        case vibration
        case autoAim
        case showHitMarkers
        case showDamageNumbers
        
        // Controls
        case controlScheme
        case invertY
        case tapToShoot
        case gestureControls
        case customControls
        
        // Interface
        case language
        case colorblindMode
        case fontSize
        case chatFilter
        case showPlayerNames
        
        // Notifications
        case pushNotifications
        case eventReminders
        case friendRequests
        case clanNotifications
        case dailyRewards
        
        // Privacy
        case shareGameplay
        case showOnline
        case allowSpectators
        case allowFriendRequests
        case showStats
        
        // Performance
        case lowPowerMode
        case preloadAssets
        case networkQuality
        case autoQualityAdjust
        case backgroundRefresh
    }
    
    // MARK: - Types
    enum GraphicsQuality: String, CaseIterable {
        case low
        case medium
        case high
        case ultra
        
        var particleLimit: Int {
            switch self {
            case .low: return 50
            case .medium: return 100
            case .high: return 200
            case .ultra: return 500
            }
        }
        
        var shadowQuality: Int {
            switch self {
            case .low: return 512
            case .medium: return 1024
            case .high: return 2048
            case .ultra: return 4096
            }
        }
    }
    
    enum FrameRate: Int, CaseIterable {
        case fps30 = 30
        case fps60 = 60
        case fps120 = 120
        case unlimited = 0
    }
    
    enum ColorblindMode: String, CaseIterable {
        case none
        case protanopia
        case deuteranopia
        case tritanopia
        
        var colorMapping: [String: String] {
            switch self {
            case .none: return [:]
            case .protanopia: return ["#FF0000": "#FFB800"]
            case .deuteranopia: return ["#00FF00": "#FFDB00"]
            case .tritanopia: return ["#0000FF": "#FF6A00"]
            }
        }
    }
    
    enum ControlScheme: String, CaseIterable {
        case classic
        case modern
        case custom
    }
    
    struct CustomControls: Codable {
        var shootButton: CGPoint
        var reloadButton: CGPoint
        var powerupButton: CGPoint
        var emoteWheel: CGPoint
        
        static let `default` = CustomControls(
            shootButton: CGPoint(x: 0.9, y: 0.3),
            reloadButton: CGPoint(x: 0.1, y: 0.3),
            powerupButton: CGPoint(x: 0.9, y: 0.7),
            emoteWheel: CGPoint(x: 0.1, y: 0.7)
        )
    }
    
    // MARK: - Audio Settings
    @SettingWrapper(key: .masterVolume, defaultValue: 1.0)
    var masterVolume: Float
    
    @SettingWrapper(key: .musicVolume, defaultValue: 0.8)
    var musicVolume: Float
    
    @SettingWrapper(key: .sfxVolume, defaultValue: 1.0)
    var sfxVolume: Float
    
    @SettingWrapper(key: .voiceVolume, defaultValue: 1.0)
    var voiceVolume: Float
    
    @SettingWrapper(key: .muteWhenInactive, defaultValue: true)
    var muteWhenInactive: Bool
    
    // MARK: - Graphics Settings
    @SettingWrapper(key: .graphicsQuality, defaultValue: GraphicsQuality.high)
    var graphicsQuality: GraphicsQuality
    
    @SettingWrapper(key: .frameRate, defaultValue: FrameRate.fps60)
    var frameRate: FrameRate
    
    @SettingWrapper(key: .particleEffects, defaultValue: true)
    var particleEffects: Bool
    
    @SettingWrapper(key: .showFPS, defaultValue: false)
    var showFPS: Bool
    
    @SettingWrapper(key: .reducedMotion, defaultValue: false)
    var reducedMotion: Bool
    
    // MARK: - Gameplay Settings
    @SettingWrapper(key: .sensitivity, defaultValue: 1.0)
    var sensitivity: Float
    
    @SettingWrapper(key: .vibration, defaultValue: true)
    var vibration: Bool
    
    @SettingWrapper(key: .autoAim, defaultValue: false)
    var autoAim: Bool
    
    @SettingWrapper(key: .showHitMarkers, defaultValue: true)
    var showHitMarkers: Bool
    
    @SettingWrapper(key: .showDamageNumbers, defaultValue: true)
    var showDamageNumbers: Bool
    
    // MARK: - Control Settings
    @SettingWrapper(key: .controlScheme, defaultValue: ControlScheme.classic)
    var controlScheme: ControlScheme
    
    @SettingWrapper(key: .invertY, defaultValue: false)
    var invertY: Bool
    
    @SettingWrapper(key: .tapToShoot, defaultValue: true)
    var tapToShoot: Bool
    
    @SettingWrapper(key: .gestureControls, defaultValue: true)
    var gestureControls: Bool
    
    // MARK: - Interface Settings
    @SettingWrapper(key: .language, defaultValue: "en")
    var language: String
    
    @SettingWrapper(key: .colorblindMode, defaultValue: ColorblindMode.none)
    var colorblindMode: ColorblindMode
    
    @SettingWrapper(key: .fontSize, defaultValue: 1.0)
    var fontSize: Float
    
    @SettingWrapper(key: .chatFilter, defaultValue: true)
    var chatFilter: Bool
    
    @SettingWrapper(key: .showPlayerNames, defaultValue: true)
    var showPlayerNames: Bool
    
    // MARK: - Notification Settings
    @SettingWrapper(key: .pushNotifications, defaultValue: true)
    var pushNotifications: Bool
    
    @SettingWrapper(key: .eventReminders, defaultValue: true)
    var eventReminders: Bool
    
    @SettingWrapper(key: .friendRequests, defaultValue: true)
    var friendRequests: Bool
    
    @SettingWrapper(key: .clanNotifications, defaultValue: true)
    var clanNotifications: Bool
    
    @SettingWrapper(key: .dailyRewards, defaultValue: true)
    var dailyRewards: Bool
    
    // MARK: - Privacy Settings
    @SettingWrapper(key: .shareGameplay, defaultValue: true)
    var shareGameplay: Bool
    
    @SettingWrapper(key: .showOnline, defaultValue: true)
    var showOnline: Bool
    
    @SettingWrapper(key: .allowSpectators, defaultValue: true)
    var allowSpectators: Bool
    
    @SettingWrapper(key: .allowFriendRequests, defaultValue: true)
    var allowFriendRequests: Bool
    
    @SettingWrapper(key: .showStats, defaultValue: true)
    var showStats: Bool
    
    // MARK: - Performance Settings
    @SettingWrapper(key: .lowPowerMode, defaultValue: false)
    var lowPowerMode: Bool
    
    @SettingWrapper(key: .preloadAssets, defaultValue: true)
    var preloadAssets: Bool
    
    @SettingWrapper(key: .networkQuality, defaultValue: "auto")
    var networkQuality: String
    
    @SettingWrapper(key: .autoQualityAdjust, defaultValue: true)
    var autoQualityAdjust: Bool
    
    @SettingWrapper(key: .backgroundRefresh, defaultValue: true)
    var backgroundRefresh: Bool
    
    // MARK: - Custom Controls
    private let customControlsKey = "customControls"
    var customControls: CustomControls {
        get {
            guard let data = defaults.data(forKey: customControlsKey),
                  let controls = try? JSONDecoder().decode(CustomControls.self, from: data) else {
                return CustomControls.default
            }
            return controls
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: customControlsKey)
                NotificationCenter.default.post(name: .controlsChanged, object: nil)
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        migrateSettingsIfNeeded()
        setupAudioSession()
    }
    
    // MARK: - Settings Management
    private func migrateSettingsIfNeeded() {
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let lastVersion = defaults.string(forKey: "lastSettingsVersion") ?? "0.0"
        
        if lastVersion != currentVersion {
            // Perform migrations
            defaults.set(currentVersion, forKey: "lastSettingsVersion")
        }
    }
    
    func resetToDefaults() {
        let keys = SettingKey.allCases.map { $0.rawValue }
        keys.forEach { defaults.removeObject(forKey: $0) }
        
        defaults.removeObject(forKey: customControlsKey)
        NotificationCenter.default.post(name: .settingsReset, object: nil)
        
        analytics.trackEvent(.featureUsed(name: "settings_reset"))
    }
    
    // MARK: - Audio Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Settings Application
    func applyGraphicsSettings() {
        ParticleManager.shared.setParticleLimit(graphicsQuality.particleLimit)
        
        if lowPowerMode {
            frameRate = .fps30
            particleEffects = false
        }
        
        NotificationCenter.default.post(name: .graphicsSettingsChanged, object: nil)
    }
    
    func applyAudioSettings() {
        AudioManager.shared.setMasterVolume(masterVolume)
        AudioManager.shared.setMusicVolume(musicVolume)
        AudioManager.shared.setSFXVolume(sfxVolume)
        AudioManager.shared.setVoiceVolume(voiceVolume)
        
        NotificationCenter.default.post(name: .audioSettingsChanged, object: nil)
    }
    
    func applyControlSettings() {
        HapticsManager.shared.setEnabled(vibration)
        
        NotificationCenter.default.post(name: .controlSettingsChanged, object: nil)
    }
    
    func applyInterfaceSettings() {
        TranslationManager.shared.setLanguage(language)
        
        NotificationCenter.default.post(name: .interfaceSettingsChanged, object: nil)
    }
    
    func applyNotificationSettings() {
        NotificationManager.shared.updateSettings(
            pushEnabled: pushNotifications,
            eventReminders: eventReminders,
            friendRequests: friendRequests,
            clanNotifications: clanNotifications,
            dailyRewards: dailyRewards
        )
        
        NotificationCenter.default.post(name: .notificationSettingsChanged, object: nil)
    }
}

// MARK: - Property Wrapper
@propertyWrapper
struct SettingWrapper<T: Codable> {
    private let key: SettingsManager.SettingKey
    private let defaultValue: T
    private let defaults = UserDefaults.standard
    
    init(key: SettingsManager.SettingKey, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    var wrappedValue: T {
        get {
            guard let data = defaults.object(forKey: key.rawValue) as? Data,
                  let value = try? JSONDecoder().decode(T.self, from: data) else {
                return defaultValue
            }
            return value
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                defaults.set(encoded, forKey: key.rawValue)
                NotificationCenter.default.post(
                    name: .settingChanged,
                    object: nil,
                    userInfo: ["key": key.rawValue]
                )
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let settingChanged = Notification.Name("settingChanged")
    static let settingsReset = Notification.Name("settingsReset")
    static let graphicsSettingsChanged = Notification.Name("graphicsSettingsChanged")
    static let audioSettingsChanged = Notification.Name("audioSettingsChanged")
    static let controlSettingsChanged = Notification.Name("controlSettingsChanged")
    static let controlsChanged = Notification.Name("controlsChanged")
    static let interfaceSettingsChanged = Notification.Name("interfaceSettingsChanged")
    static let notificationSettingsChanged = Notification.Name("notificationSettingsChanged")
}

// MARK: - SettingKey Extension
extension SettingsManager.SettingKey: CaseIterable {}

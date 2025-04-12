import Foundation

final class TranslationManager {
    // MARK: - Singleton
    static let shared = TranslationManager()
    private init() {
        currentLanguage = detectDeviceLanguage()
        loadCachedTranslations()
    }
    
    // MARK: - Properties
    private(set) var currentLanguage: String
    private var translations: [String: [String: String]] = [:] // [Language: [Key: Translation]]
    private let translationService: TranslationService
    
    // Default supported languages
    static let supportedLanguages: [String] = [
        "en",    // English
        "es",    // Spanish
        "ar",    // Arabic
        "zh",    // Chinese
        "fr",    // French
        "de",    // German
        "hi",    // Hindi
        "id",    // Indonesian
        "it",    // Italian
        "ja",    // Japanese
        "ko",    // Korean
        "pt",    // Portuguese
        "ru",    // Russian
        "tr",    // Turkish
        "vi"     // Vietnamese
    ]
    
    // MARK: - Translation Keys
    enum TranslationKey: String {
        // Menu
        case startGame = "key_start_game"
        case settings = "key_settings"
        case leaderboard = "key_leaderboard"
        
        // Gameplay
        case wait = "key_wait"
        case raise = "key_raise_phone"
        case draw = "key_draw"
        case victory = "key_victory"
        case defeat = "key_defeat"
        case reactionTime = "key_reaction_time"
        
        // Settings
        case sound = "key_sound"
        case music = "key_music"
        case vibration = "key_vibration"
        case sensitivity = "key_sensitivity"
        case language = "key_language"
        
        // Messages
        case connectionError = "key_connection_error"
        case tryAgain = "key_try_again"
        case matchmaking = "key_matchmaking"
        
        var defaultEnglish: String {
            switch self {
            case .startGame: return "Start Game"
            case .settings: return "Settings"
            case .leaderboard: return "Leaderboard"
            case .wait: return "Wait..."
            case .raise: return "Raise Your Phone"
            case .draw: return "DRAW!"
            case .victory: return "Victory!"
            case .defeat: return "Defeat!"
            case .reactionTime: return "Reaction Time"
            case .sound: return "Sound Effects"
            case .music: return "Background Music"
            case .vibration: return "Vibration"
            case .sensitivity: return "Sensitivity"
            case .language: return "Language"
            case .connectionError: return "Connection Error"
            case .tryAgain: return "Try Again"
            case .matchmaking: return "Finding Opponent..."
            }
        }
    }
    
    // MARK: - Language Detection
    private func detectDeviceLanguage() -> String {
        let preferredLanguage = Locale.preferredLanguages[0]
        let languageCode = String(preferredLanguage.prefix(2))
        
        return TranslationManager.supportedLanguages.contains(languageCode)
            ? languageCode
            : "en"
    }
    
    // MARK: - Translation Methods
    func translate(_ key: TranslationKey) async throws -> String {
        // Check cache first
        if let cached = translations[currentLanguage]?[key.rawValue] {
            return cached
        }
        
        // If not in cache and language is English, return default
        if currentLanguage == "en" {
            return key.defaultEnglish
        }
        
        // Otherwise, get AI translation
        do {
            let translation = try await translationService.translate(
                text: key.defaultEnglish,
                from: "en",
                to: currentLanguage
            )
            
            // Cache the result
            cacheTranslation(key: key.rawValue, translation: translation)
            return translation
            
        } catch {
            print("Translation failed: \(error.localizedDescription)")
            return key.defaultEnglish
        }
    }
    
    // MARK: - Language Switching
    func switchLanguage(to languageCode: String) async {
        guard TranslationManager.supportedLanguages.contains(languageCode) else {
            return
        }
        
        currentLanguage = languageCode
        UserDefaults.standard.set(languageCode, forKey: "selectedLanguage")
        
        // Notify observers of language change
        NotificationCenter.default.post(
            name: .languageDidChange,
            object: nil
        )
    }
    
    // MARK: - Cache Management
    private func loadCachedTranslations() {
        if let cached = UserDefaults.standard.dictionary(forKey: "cachedTranslations") as? [String: [String: String]] {
            translations = cached
        }
    }
    
    private func cacheTranslation(key: String, translation: String) {
        if translations[currentLanguage] == nil {
            translations[currentLanguage] = [:]
        }
        
        translations[currentLanguage]?[key] = translation
        
        // Save to UserDefaults
        UserDefaults.standard.set(translations, forKey: "cachedTranslations")
    }
    
    // MARK: - Batch Translation
    func preloadTranslations() async {
        guard currentLanguage != "en" else { return }
        
        for key in TranslationKey.allCases {
            if translations[currentLanguage]?[key.rawValue] == nil {
                _ = try? await translate(key)
            }
        }
    }
    
    // MARK: - Dynamic Text
    func translateDynamic(_ text: String) async throws -> String {
        guard currentLanguage != "en" else { return text }
        
        return try await translationService.translate(
            text: text,
            from: "en",
            to: currentLanguage
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - Convenience Extensions
extension String {
    func localized() async -> String {
        guard let key = TranslationManager.TranslationKey(rawValue: self) else {
            return self
        }
        return (try? await TranslationManager.shared.translate(key)) ?? self
    }
}

extension TranslationManager.TranslationKey: CaseIterable {}

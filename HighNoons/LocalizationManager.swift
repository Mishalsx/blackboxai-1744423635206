import Foundation

final class LocalizationManager {
    // MARK: - Properties
    static let shared = LocalizationManager()
    
    private let networkManager = NetworkManager.shared
    private let analytics = AnalyticsManager.shared
    
    private var currentLanguage: Language
    private var translations: [String: [String: String]] = [:]
    private var fallbackLanguage: Language = .english
    private var loadedFonts: [String: Bool] = [:]
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct Language: Codable, Equatable {
        let code: String
        let name: String
        let nativeName: String
        let direction: TextDirection
        let fontFamily: String?
        let dateFormat: String
        let timeFormat: String
        let numberFormat: NumberFormat
        
        enum TextDirection: String, Codable {
            case ltr
            case rtl
        }
        
        struct NumberFormat: Codable {
            let decimal: String
            let thousand: String
            let currency: String
        }
        
        static let english = Language(
            code: "en",
            name: "English",
            nativeName: "English",
            direction: .ltr,
            fontFamily: nil,
            dateFormat: "MM/dd/yyyy",
            timeFormat: "h:mm a",
            numberFormat: NumberFormat(
                decimal: ".",
                thousand: ",",
                currency: "$"
            )
        )
        
        static let spanish = Language(
            code: "es",
            name: "Spanish",
            nativeName: "Español",
            direction: .ltr,
            fontFamily: nil,
            dateFormat: "dd/MM/yyyy",
            timeFormat: "H:mm",
            numberFormat: NumberFormat(
                decimal: ",",
                thousand: ".",
                currency: "€"
            )
        )
        
        static let arabic = Language(
            code: "ar",
            name: "Arabic",
            nativeName: "العربية",
            direction: .rtl,
            fontFamily: "Cairo",
            dateFormat: "dd/MM/yyyy",
            timeFormat: "H:mm",
            numberFormat: NumberFormat(
                decimal: "٫",
                thousand: "٬",
                currency: "ر.س"
            )
        )
        
        static let japanese = Language(
            code: "ja",
            name: "Japanese",
            nativeName: "日本語",
            direction: .ltr,
            fontFamily: "Noto Sans JP",
            dateFormat: "yyyy/MM/dd",
            timeFormat: "H:mm",
            numberFormat: NumberFormat(
                decimal: ".",
                thousand: ",",
                currency: "¥"
            )
        )
    }
    
    struct LocalizedContent: Codable {
        let key: String
        let language: String
        let value: String
        let context: String?
        let tags: [String]
        let lastUpdated: Date
    }
    
    // MARK: - Initialization
    private init() {
        // Set initial language based on system locale
        let preferredLanguage = Locale.preferredLanguages[0]
        let languageCode = String(preferredLanguage.prefix(2))
        
        if let systemLanguage = supportedLanguages.first(where: { $0.code == languageCode }) {
            currentLanguage = systemLanguage
        } else {
            currentLanguage = .english
        }
        
        setupRefreshTimer()
        loadTranslations()
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 3600, // 1 hour
            repeats: true
        ) { [weak self] _ in
            self?.refreshTranslations()
        }
    }
    
    // MARK: - Language Management
    func setLanguage(_ language: Language) {
        guard language != currentLanguage else { return }
        
        currentLanguage = language
        loadTranslations()
        
        // Update app-wide language settings
        UserDefaults.standard.set([language.code], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Load language-specific font if needed
        if let fontFamily = language.fontFamily {
            loadFont(fontFamily)
        }
        
        // Notify observers
        NotificationCenter.default.post(name: .languageChanged, object: nil)
        
        analytics.trackEvent(.featureUsed(
            name: "language_changed",
            properties: ["language": language.code]
        ))
    }
    
    private func loadFont(_ fontFamily: String) {
        guard !loadedFonts[fontFamily, default: false] else { return }
        
        // Load font file
        if let fontURL = Bundle.main.url(forResource: fontFamily, withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
            loadedFonts[fontFamily] = true
        }
    }
    
    // MARK: - Translation Management
    private func loadTranslations() {
        Task {
            do {
                let response: [String: [String: String]] = try await networkManager.request(
                    endpoint: "translations/\(currentLanguage.code)"
                )
                
                translations = response
                
                // Load fallback translations if needed
                if currentLanguage != fallbackLanguage {
                    let fallback: [String: [String: String]] = try await networkManager.request(
                        endpoint: "translations/\(fallbackLanguage.code)"
                    )
                    
                    // Merge fallback translations
                    for (category, strings) in fallback {
                        if translations[category] == nil {
                            translations[category] = strings
                        }
                    }
                }
            } catch {
                print("Failed to load translations: \(error.localizedDescription)")
            }
        }
    }
    
    private func refreshTranslations() {
        loadTranslations()
    }
    
    // MARK: - Translation Methods
    func localize(
        _ key: String,
        category: String = "general",
        replacements: [String: String] = [:]
    ) -> String {
        var result = translations[category]?[key] ?? key
        
        // Apply replacements
        for (placeholder, value) in replacements {
            result = result.replacingOccurrences(of: "{\(placeholder)}", with: value)
        }
        
        return result
    }
    
    func localizeNumber(_ number: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.decimalSeparator = currentLanguage.numberFormat.decimal
        formatter.groupingSeparator = currentLanguage.numberFormat.thousand
        
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }
    
    func localizeCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = currentLanguage.numberFormat.currency
        formatter.decimalSeparator = currentLanguage.numberFormat.decimal
        formatter.groupingSeparator = currentLanguage.numberFormat.thousand
        
        return formatter.string(from: NSNumber(value: amount)) ?? String(amount)
    }
    
    func localizeDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = currentLanguage.dateFormat
        formatter.locale = Locale(identifier: currentLanguage.code)
        
        return formatter.string(from: date)
    }
    
    func localizeTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = currentLanguage.timeFormat
        formatter.locale = Locale(identifier: currentLanguage.code)
        
        return formatter.string(from: date)
    }
    
    // MARK: - Content Management
    func getLocalizedContent(
        _ key: String,
        category: String = "content"
    ) -> LocalizedContent? {
        Task {
            do {
                let content: LocalizedContent = try await networkManager.request(
                    endpoint: "content/\(category)/\(key)/\(currentLanguage.code)"
                )
                return content
            } catch {
                return nil
            }
        }
        return nil
    }
    
    // MARK: - Utility Methods
    var currentTextDirection: Language.TextDirection {
        return currentLanguage.direction
    }
    
    var isRightToLeft: Bool {
        return currentLanguage.direction == .rtl
    }
    
    var currentFontFamily: String? {
        return currentLanguage.fontFamily
    }
    
    // MARK: - Cleanup
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        translations.removeAll()
    }
}

// MARK: - Supported Languages
extension LocalizationManager {
    static let supportedLanguages: [Language] = [
        .english,
        .spanish,
        .arabic,
        .japanese
    ]
    
    func getLanguage(for code: String) -> Language? {
        return Self.supportedLanguages.first { $0.code == code }
    }
}

// MARK: - String Extension
extension String {
    var localized: String {
        return LocalizationManager.shared.localize(self)
    }
    
    func localized(with replacements: [String: String]) -> String {
        return LocalizationManager.shared.localize(self, replacements: replacements)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// MARK: - Convenience Methods
extension LocalizationManager {
    func getCurrentLanguage() -> Language {
        return currentLanguage
    }
    
    func getAvailableLanguages() -> [Language] {
        return Self.supportedLanguages
    }
    
    func hasTranslation(for key: String, in category: String = "general") -> Bool {
        return translations[category]?[key] != nil
    }
}

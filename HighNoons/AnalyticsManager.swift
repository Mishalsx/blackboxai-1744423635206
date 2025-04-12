import Foundation
import Firebase
import FirebaseAnalytics

final class AnalyticsManager {
    // MARK: - Properties
    static let shared = AnalyticsManager()
    
    private let isEnabled: Bool
    private let shouldTrackCrashes: Bool
    private let environment: Environment
    
    // MARK: - Types
    enum Environment {
        case development
        case staging
        case production
    }
    
    enum EventType {
        // Game Events
        case gameStart
        case gameEnd(result: String, reactionTime: Double)
        case tutorialComplete
        case levelUp(level: Int)
        case achievementUnlocked(name: String)
        
        // Store Events
        case storeOpen(category: String)
        case purchaseInitiated(productId: String)
        case purchaseComplete(productId: String, revenue: Double)
        case purchaseFailed(productId: String, error: String)
        
        // Feature Usage
        case featureUsed(name: String)
        case settingsChanged(setting: String, value: Any)
        case characterSelected(name: String)
        
        // Social Events
        case matchmakingStart
        case matchmakingComplete(timeSpent: Double)
        case matchmakingFailed(reason: String)
        
        // Performance Events
        case loadingTime(screen: String, duration: Double)
        case networkError(api: String, code: Int)
        case frameDrop(count: Int)
        
        var name: String {
            switch self {
            case .gameStart: return "game_start"
            case .gameEnd: return "game_end"
            case .tutorialComplete: return "tutorial_complete"
            case .levelUp: return "level_up"
            case .achievementUnlocked: return "achievement_unlocked"
            case .storeOpen: return "store_open"
            case .purchaseInitiated: return "purchase_initiated"
            case .purchaseComplete: return "purchase_complete"
            case .purchaseFailed: return "purchase_failed"
            case .featureUsed: return "feature_used"
            case .settingsChanged: return "settings_changed"
            case .characterSelected: return "character_selected"
            case .matchmakingStart: return "matchmaking_start"
            case .matchmakingComplete: return "matchmaking_complete"
            case .matchmakingFailed: return "matchmaking_failed"
            case .loadingTime: return "loading_time"
            case .networkError: return "network_error"
            case .frameDrop: return "frame_drop"
            }
        }
        
        var parameters: [String: Any] {
            switch self {
            case .gameEnd(let result, let reactionTime):
                return [
                    "result": result,
                    "reaction_time": reactionTime,
                    "timestamp": Date().timeIntervalSince1970
                ]
            case .levelUp(let level):
                return ["level": level]
            case .achievementUnlocked(let name):
                return ["achievement_name": name]
            case .storeOpen(let category):
                return ["category": category]
            case .purchaseInitiated(let productId):
                return ["product_id": productId]
            case .purchaseComplete(let productId, let revenue):
                return [
                    "product_id": productId,
                    "revenue": revenue
                ]
            case .purchaseFailed(let productId, let error):
                return [
                    "product_id": productId,
                    "error": error
                ]
            case .featureUsed(let name):
                return ["feature_name": name]
            case .settingsChanged(let setting, let value):
                return [
                    "setting": setting,
                    "value": String(describing: value)
                ]
            case .characterSelected(let name):
                return ["character_name": name]
            case .matchmakingComplete(let timeSpent):
                return ["time_spent": timeSpent]
            case .matchmakingFailed(let reason):
                return ["reason": reason]
            case .loadingTime(let screen, let duration):
                return [
                    "screen": screen,
                    "duration": duration
                ]
            case .networkError(let api, let code):
                return [
                    "api": api,
                    "code": code
                ]
            case .frameDrop(let count):
                return ["drop_count": count]
            default:
                return [:]
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        #if DEBUG
        self.environment = .development
        self.isEnabled = false
        self.shouldTrackCrashes = false
        #else
        self.environment = .production
        self.isEnabled = true
        self.shouldTrackCrashes = true
        #endif
        
        setupAnalytics()
    }
    
    private func setupAnalytics() {
        FirebaseApp.configure()
        
        if !isEnabled {
            Analytics.setAnalyticsCollectionEnabled(false)
            return
        }
        
        // Set default event parameters
        Analytics.setDefaultEventParameters([
            "environment": environment.rawValue,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ])
        
        // Setup crash reporting
        if shouldTrackCrashes {
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        }
    }
    
    // MARK: - Event Tracking
    func trackEvent(_ event: EventType) {
        guard isEnabled else { return }
        
        Analytics.logEvent(event.name, parameters: event.parameters)
        
        #if DEBUG
        print("📊 Analytics Event: \(event.name)")
        if !event.parameters.isEmpty {
            print("Parameters: \(event.parameters)")
        }
        #endif
    }
    
    // MARK: - User Properties
    func setUserProperty(_ value: String?, forName name: String) {
        guard isEnabled else { return }
        Analytics.setUserProperty(value, forName: name)
    }
    
    func setUserID(_ userID: String) {
        guard isEnabled else { return }
        Analytics.setUserID(userID)
    }
    
    // MARK: - Screen Tracking
    func trackScreen(_ screenName: String, className: String) {
        guard isEnabled else { return }
        
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: className
        ])
    }
    
    // MARK: - Performance Monitoring
    private var loadingTimers: [String: CFAbsoluteTime] = [:]
    
    func startLoadingTimer(for screen: String) {
        loadingTimers[screen] = CFAbsoluteTimeGetCurrent()
    }
    
    func stopLoadingTimer(for screen: String) {
        guard let startTime = loadingTimers[screen] else { return }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        trackEvent(.loadingTime(screen: screen, duration: duration))
        loadingTimers.removeValue(forKey: screen)
    }
    
    // MARK: - Error Tracking
    func trackError(_ error: Error, context: [String: Any]? = nil) {
        guard isEnabled else { return }
        
        var userInfo = [
            "timestamp": Date().timeIntervalSince1970,
            "error_description": error.localizedDescription
        ] as [String: Any]
        
        if let context = context {
            userInfo.merge(context) { current, _ in current }
        }
        
        Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
    }
    
    // MARK: - Game Analytics
    func trackGameSession(duration: TimeInterval, result: String, stats: [String: Any]) {
        guard isEnabled else { return }
        
        var parameters = stats
        parameters["duration"] = duration
        parameters["result"] = result
        
        Analytics.logEvent("game_session", parameters: parameters)
    }
    
    func trackTutorialStep(_ step: Int, timeSpent: TimeInterval) {
        guard isEnabled else { return }
        
        Analytics.logEvent("tutorial_step", parameters: [
            "step": step,
            "time_spent": timeSpent
        ])
    }
    
    // MARK: - Revenue Tracking
    func trackRevenue(amount: Double, currency: String, productID: String) {
        guard isEnabled else { return }
        
        Analytics.logEvent(AnalyticsEventPurchase, parameters: [
            AnalyticsParameterValue: amount,
            AnalyticsParameterCurrency: currency,
            AnalyticsParameterItemID: productID
        ])
    }
}

// MARK: - Environment Extension
extension AnalyticsManager.Environment: RawRepresentable {
    typealias RawValue = String
    
    init?(rawValue: String) {
        switch rawValue {
        case "development": self = .development
        case "staging": self = .staging
        case "production": self = .production
        default: return nil
        }
    }
    
    var rawValue: String {
        switch self {
        case .development: return "development"
        case .staging: return "staging"
        case .production: return "production"
        }
    }
}

// MARK: - Convenience Methods
extension AnalyticsManager {
    func trackAppOpen() {
        trackEvent(.featureUsed(name: "app_open"))
        setUserProperty(UIDevice.current.systemVersion, forName: "device_os_version")
    }
    
    func trackAppBackground() {
        trackEvent(.featureUsed(name: "app_background"))
    }
    
    func trackOnboardingComplete() {
        trackEvent(.featureUsed(name: "onboarding_complete"))
        setUserProperty("true", forName: "completed_onboarding")
    }
}

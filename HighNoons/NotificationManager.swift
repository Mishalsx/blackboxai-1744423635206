import UserNotifications
import Foundation

final class NotificationManager {
    // MARK: - Singleton
    static let shared = NotificationManager()
    private init() {
        BatchConfig.initialize()
        NotificationGroup.initializeAllGroups()
        ScheduleConfig.initialize()
    }
    
    // MARK: - Types
    enum NotificationGroup: String, CaseIterable {
        case gameplay
        case social
        case events
        case rewards
        
        var identifier: String {
            return "group.\(rawValue)"
        }
        
        var displayName: String {
            switch self {
            case .gameplay: return "Gameplay"
            case .social: return "Social"
            case .events: return "Events"
            case .rewards: return "Rewards"
            }
        }
        
        // Per-group settings keys
        private var settingsKeyPrefix: String {
            return "notifications.group.\(rawValue)"
        }
        
        var batchingEnabledKey: String {
            return "\(settingsKeyPrefix).batching_enabled"
        }
        
        var minBatchSizeKey: String {
            return "\(settingsKeyPrefix).min_batch_size"
        }
        
        var maxBatchSizeKey: String {
            return "\(settingsKeyPrefix).max_batch_size"
        }
        
        var batchDelayKey: String {
            return "\(settingsKeyPrefix).batch_delay"
        }
        
        // Group-specific settings
        var isBatchingEnabled: Bool {
            get { UserDefaults.standard.bool(forKey: batchingEnabledKey) }
            set { UserDefaults.standard.set(newValue, forKey: batchingEnabledKey) }
        }
        
        var minBatchSize: Int {
            get { UserDefaults.standard.integer(forKey: minBatchSizeKey) }
            set { UserDefaults.standard.set(newValue, forKey: minBatchSizeKey) }
        }
        
        var maxBatchSize: Int {
            get { UserDefaults.standard.integer(forKey: maxBatchSizeKey) }
            set { UserDefaults.standard.set(newValue, forKey: maxBatchSizeKey) }
        }
        
        var batchDelay: TimeInterval {
            get { UserDefaults.standard.double(forKey: batchDelayKey) }
            set { UserDefaults.standard.set(newValue, forKey: batchDelayKey) }
        }
        
        // Default values based on group type
        var defaultMinBatchSize: Int {
            switch self {
            case .gameplay: return 2
            case .social: return 3
            case .events: return 2
            case .rewards: return 3
            }
        }
        
        var defaultMaxBatchSize: Int {
            switch self {
            case .gameplay: return 3
            case .social: return 5
            case .events: return 3
            case .rewards: return 5
            }
        }
        
        var defaultBatchDelay: TimeInterval {
            switch self {
            case .gameplay: return 180  // 3 minutes
            case .social: return 600    // 10 minutes
            case .events: return 300    // 5 minutes
            case .rewards: return 600   // 10 minutes
            }
        }
        
        func resetToDefaults() {
            isBatchingEnabled = true
            minBatchSize = defaultMinBatchSize
            maxBatchSize = defaultMaxBatchSize
            batchDelay = defaultBatchDelay
        }
        
        static func initializeAllGroups() {
            for group in NotificationGroup.allCases {
                if !UserDefaults.standard.bool(forKey: "\(group.settingsKeyPrefix).initialized") {
                    group.resetToDefaults()
                    UserDefaults.standard.set(true, forKey: "\(group.settingsKeyPrefix).initialized")
                }
            }
        }
    }
    
    enum NotificationPriority: Int {
        case low = 0
        case medium = 1
        case high = 2
        case critical = 3
        
        var throttleInterval: TimeInterval {
            switch self {
            case .low: return 3600      // 1 hour
            case .medium: return 1800    // 30 minutes
            case .high: return 300       // 5 minutes
            case .critical: return 0     // No throttling
            }
        }
        
        var allowedPerHour: Int {
            switch self {
            case .low: return 2
            case .medium: return 5
            case .high: return 10
            case .critical: return Int.max
            }
        }
    }
    
    enum NotificationType {
        case dailyReward
        case challenge
        case inactivity
        case rankChange
        case achievement
        case tournament
        case friendActivity
        case clanEvent
        case battlePass
        
        var priority: NotificationPriority {
            switch self {
            case .dailyReward, .challenge:
                return .medium
            case .inactivity:
                return .low
            case .rankChange, .achievement:
                return .high
            case .tournament, .clanEvent:
                return .high
            case .friendActivity:
                return .low
            case .battlePass:
                return .medium
            }
        }
        
        var identifier: String {
            switch self {
            case .dailyReward: return "notification.dailyReward"
            case .challenge: return "notification.challenge"
            case .inactivity: return "notification.inactivity"
            case .rankChange: return "notification.rankChange"
            case .achievement: return "notification.achievement"
            case .tournament: return "notification.tournament"
            case .friendActivity: return "notification.friendActivity"
            case .clanEvent: return "notification.clanEvent"
            case .battlePass: return "notification.battlePass"
            }
        }
    }
    
    // MARK: - Properties
    private let translationManager = TranslationManager.shared
    private let center = UNUserNotificationCenter.current()
    private let analytics = AnalyticsManager.shared
    private let calendar = Calendar.current
    
    // MARK: - Scheduling Configuration
    private struct ScheduleConfig {
        // Keys for UserDefaults
        private static let keyPrefix = "notifications.schedule"
        static let quietHoursEnabledKey = "\(keyPrefix).quiet_hours.enabled"
        static let quietHoursStartKey = "\(keyPrefix).quiet_hours.start"
        static let quietHoursEndKey = "\(keyPrefix).quiet_hours.end"
        static let weekendQuietHoursKey = "\(keyPrefix).quiet_hours.weekend"
        static let priorityThresholdKey = "\(keyPrefix).priority_threshold"
        static let activeDaysKey = "\(keyPrefix).active_days"
        static let peakHoursStartKey = "\(keyPrefix).peak_hours.start"
        static let peakHoursEndKey = "\(keyPrefix).peak_hours.end"
        
        // Schedule Types
        enum Day: Int, CaseIterable {
            case sunday = 1
            case monday = 2
            case tuesday = 3
            case wednesday = 4
            case thursday = 5
            case friday = 6
            case saturday = 7
            
            var isWeekend: Bool {
                return self == .sunday || self == .saturday
            }
        }
        
        // Quiet Hours
        static var isQuietHoursEnabled: Bool {
            get { UserDefaults.standard.bool(forKey: quietHoursEnabledKey) }
            set { UserDefaults.standard.set(newValue, forKey: quietHoursEnabledKey) }
        }
        
        static var quietHoursStart: Int {
            get { UserDefaults.standard.integer(forKey: quietHoursStartKey) }
            set { UserDefaults.standard.set(newValue, forKey: quietHoursStartKey) }
        }
        
        static var quietHoursEnd: Int {
            get { UserDefaults.standard.integer(forKey: quietHoursEndKey) }
            set { UserDefaults.standard.set(newValue, forKey: quietHoursEndKey) }
        }
        
        static var hasWeekendQuietHours: Bool {
            get { UserDefaults.standard.bool(forKey: weekendQuietHoursKey) }
            set { UserDefaults.standard.set(newValue, forKey: weekendQuietHoursKey) }
        }
        
        // Priority Settings
        static var priorityThreshold: NotificationPriority {
            get {
                let rawValue = UserDefaults.standard.integer(forKey: priorityThresholdKey)
                return NotificationPriority(rawValue: rawValue) ?? .low
            }
            set { UserDefaults.standard.set(newValue.rawValue, forKey: priorityThresholdKey) }
        }
        
        // Active Days
        static var activeDays: Set<Day> {
            get {
                let rawValues = UserDefaults.standard.array(forKey: activeDaysKey) as? [Int] ?? []
                return Set(rawValues.compactMap { Day(rawValue: $0) })
            }
            set {
                UserDefaults.standard.set(Array(newValue).map { $0.rawValue }, forKey: activeDaysKey)
            }
        }
        
        // Peak Hours
        static var peakHoursStart: Int {
            get { UserDefaults.standard.integer(forKey: peakHoursStartKey) }
            set { UserDefaults.standard.set(newValue, forKey: peakHoursStartKey) }
        }
        
        static var peakHoursEnd: Int {
            get { UserDefaults.standard.integer(forKey: peakHoursEndKey) }
            set { UserDefaults.standard.set(newValue, forKey: peakHoursEndKey) }
        }
        
        static func resetToDefaults() {
            isQuietHoursEnabled = true
            quietHoursStart = 22 // 10 PM
            quietHoursEnd = 8    // 8 AM
            hasWeekendQuietHours = true
            priorityThreshold = .medium
            activeDays = Set(Day.allCases)
            peakHoursStart = 9  // 9 AM
            peakHoursEnd = 21   // 9 PM
        }
        
        static func initialize() {
            if !UserDefaults.standard.bool(forKey: "\(keyPrefix).initialized") {
                resetToDefaults()
                UserDefaults.standard.set(true, forKey: "\(keyPrefix).initialized")
            }
        }
    }
    
    // Batch Configuration
    private struct BatchConfig {
        // Default values
        static let defaultMinBatchSize = 3
        static let defaultMaxBatchSize = 5
        static let defaultBatchDelay: TimeInterval = 300 // 5 minutes
        static let defaultMaxBatchAge: TimeInterval = 3600 // 1 hour
        
        // Keys for UserDefaults
        private static let keyPrefix = "notifications.batch"
        static let enabledKey = "\(keyPrefix).enabled"
        static let minSizeKey = "\(keyPrefix).minSize"
        static let maxSizeKey = "\(keyPrefix).maxSize"
        static let delayKey = "\(keyPrefix).delay"
        static let maxAgeKey = "\(keyPrefix).maxAge"
        
        // Current values from settings
        static var isBatchingEnabled: Bool {
            get { UserDefaults.standard.bool(forKey: enabledKey) }
            set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
        }
        
        static var minBatchSize: Int {
            get { UserDefaults.standard.integer(forKey: minSizeKey) }
            set { UserDefaults.standard.set(newValue, forKey: minSizeKey) }
        }
        
        static var maxBatchSize: Int {
            get { UserDefaults.standard.integer(forKey: maxSizeKey) }
            set { UserDefaults.standard.set(newValue, forKey: maxSizeKey) }
        }
        
        static var batchDelay: TimeInterval {
            get { UserDefaults.standard.double(forKey: delayKey) }
            set { UserDefaults.standard.set(newValue, forKey: delayKey) }
        }
        
        static var maxBatchAge: TimeInterval {
            get { UserDefaults.standard.double(forKey: maxAgeKey) }
            set { UserDefaults.standard.set(newValue, forKey: maxAgeKey) }
        }
        
        static func resetToDefaults() {
            isBatchingEnabled = true
            minBatchSize = defaultMinBatchSize
            maxBatchSize = defaultMaxBatchSize
            batchDelay = defaultBatchDelay
            maxBatchAge = defaultMaxBatchAge
        }
        
        static func initialize() {
            if !UserDefaults.standard.bool(forKey: "\(keyPrefix).initialized") {
                resetToDefaults()
                UserDefaults.standard.set(true, forKey: "\(keyPrefix).initialized")
            }
        }
    }
    
    // Throttling
    private var lastNotificationTimes: [NotificationType: Date] = [:]
    private var notificationCounts: [NotificationPriority: Int] = [:]
    private var lastHourReset = Date()
    private var pendingNotifications: [(NotificationType, UNMutableNotificationContent, UNNotificationTrigger, Date)] = []
    private var batchTimer: Timer?
    
    // MARK: - Initialization
    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            return try await center.requestAuthorization(options: options)
        } catch {
            print("Failed to request notification authorization: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Notification Scheduling
    func scheduleDailyRewardNotification() async {
        let content = UNMutableNotificationContent()
        
        // Get localized strings
        content.title = await getLocalizedString("Your Daily Reward is Ready!")
        content.body = await getLocalizedString("Return to claim your rewards and maintain your streak!")
        content.sound = .default
        
        // Create trigger for next day at 9 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        scheduleNotification(
            type: .dailyReward,
            content: content,
            trigger: trigger
        )
    }
    
    func scheduleChallengeNotification(completionTime: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = await getLocalizedString("New Challenge Available!")
        content.body = await getLocalizedString("Take on new duels and earn special rewards!")
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: completionTime,
            repeats: false
        )
        
        scheduleNotification(
            type: .challenge,
            content: content,
            trigger: trigger
        )
    }
    
    func scheduleInactivityReminder(days: Int) async {
        let content = UNMutableNotificationContent()
        content.title = await getLocalizedString("Missing You, Gunslinger!")
        content.body = await getLocalizedString("Return to High Noons for new challenges and rewards!")
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(days * 24 * 60 * 60),
            repeats: false
        )
        
        scheduleNotification(
            type: .inactivity,
            content: content,
            trigger: trigger
        )
    }
    
    func sendRankChangeNotification(newRank: String) async {
        let content = UNMutableNotificationContent()
        content.title = await getLocalizedString("Rank Up!")
        content.body = await getLocalizedString("Congratulations! You've reached \(newRank)!")
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 1,
            repeats: false
        )
        
        scheduleNotification(
            type: .rankChange,
            content: content,
            trigger: trigger
        )
    }
    
    func sendAchievementNotification(achievement: PlayerStats.Achievement) async {
        let content = UNMutableNotificationContent()
        content.title = await getLocalizedString("Achievement Unlocked!")
        content.body = await getLocalizedString("You've earned: \(achievement.rawValue)")
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 1,
            repeats: false
        )
        
        scheduleNotification(
            type: .achievement,
            content: content,
            trigger: trigger
        )
    }
    
    // MARK: - Notification Management
    private func scheduleNotification(
        type: NotificationType,
        content: UNNotificationContent,
        trigger: UNNotificationTrigger
    ) {
        let priority = type.priority
        
        if priority == .low {
            handleLowPriorityNotification(type, content, trigger)
            return
        }
        
        if !shouldAllowNotification(type) {
            return
        }
        
        scheduleImmediateNotification(type, content, trigger)
    }
    
    private func handleLowPriorityNotification(
        _ type: NotificationType,
        _ content: UNNotificationContent,
        _ trigger: UNNotificationTrigger
    ) {
        let group = type.group
        
        // Skip batching if disabled for this group
        guard group.isBatchingEnabled else {
            scheduleImmediateNotification(type, content, trigger)
            return
        }
        
        if !shouldAllowNotification(type) {
            if let mutableContent = content as? UNMutableNotificationContent {
                let timestamp = Date()
                pendingNotifications.append((type, mutableContent, trigger, timestamp))
                
                // Clean up old notifications
                cleanupOldPendingNotifications()
                
                // Get group-specific notifications
                let groupNotifications = pendingNotifications.filter { $0.0.group == group }
                
                // If we have enough pending notifications for this group, schedule batch
                if groupNotifications.count >= group.minBatchSize {
                    scheduleBatchNotification(for: group)
                } else {
                    // Start batch timer if not already running
                    startBatchTimer(for: group)
                }
            }
            return
        }
        
        scheduleImmediateNotification(type, content, trigger)
    }
    
    private func scheduleImmediateNotification(
        _ type: NotificationType,
        _ content: UNNotificationContent,
        _ trigger: UNNotificationTrigger
    ) {
        // Update throttling state
        lastNotificationTimes[type] = Date()
        notificationCounts[type.priority, default: 0] += 1
        
        // Track analytics
        analytics.trackEvent(.featureUsed(
            name: "notification_scheduled",
            properties: [
                "type": type.identifier,
                "priority": type.priority.rawValue
            ]
        ))
        // Add group information
        var mutableContent = content
        mutableContent.threadIdentifier = type.group.identifier
        
        // Set notification category for grouping
        mutableContent.categoryIdentifier = type.group.rawValue
        // Remove existing notifications of same type
        center.removePendingNotificationRequests(
            withIdentifiers: [type.identifier]
        )
        
        // Create and schedule new notification
        let request = UNNotificationRequest(
            identifier: type.identifier,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    func removeAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }
    
    func removeNotifications(ofType type: NotificationType) {
        center.removePendingNotificationRequests(
            withIdentifiers: [type.identifier]
        )
    }
    
    // MARK: - Badge Management
    func updateBadgeCount(_ count: Int) {
        center.setBadgeCount(count)
    }
    
    func resetBadgeCount() {
        center.setBadgeCount(0)
    }
    
    // MARK: - Utility Methods
    private func getLocalizedString(_ text: String) async -> String {
        do {
            return try await translationManager.translateDynamic(text)
        } catch {
            print("Failed to translate notification text: \(error.localizedDescription)")
            return text
        }
    }
    
    // MARK: - Group Management
    func getNotificationGroups() async -> [NotificationGroup: Int] {
        var groupCounts: [NotificationGroup: Int] = [:]
        
        let requests = await center.pendingNotificationRequests()
        for request in requests {
            if let group = NotificationGroup(rawValue: request.content.categoryIdentifier) {
                groupCounts[group, default: 0] += 1
            }
        }
        
        return groupCounts
    }
    
    func enableGroup(_ group: NotificationGroup) {
        UserDefaults.standard.set(true, forKey: "notifications.\(group.rawValue).enabled")
    }
    
    func disableGroup(_ group: NotificationGroup) {
        UserDefaults.standard.set(false, forKey: "notifications.\(group.rawValue).enabled")
        
        // Remove pending notifications for this group
        Task {
            let requests = await center.pendingNotificationRequests()
            let identifiers = requests
                .filter { $0.content.categoryIdentifier == group.rawValue }
                .map { $0.identifier }
            
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    func isGroupEnabled(_ group: NotificationGroup) -> Bool {
        return UserDefaults.standard.bool(forKey: "notifications.\(group.rawValue).enabled")
    }
    
    // MARK: - Throttling
    private func shouldAllowNotification(_ type: NotificationType) -> Bool {
        let result: String
        defer { trackNotificationAttempt(type: type, result: result) }
        let priority = type.priority
        let now = Date()
        
        // Check quiet hours
        if ScheduleConfig.isQuietHoursEnabled && isInQuietHours(now) {
            // During quiet hours, only allow notifications above threshold
            guard priority.rawValue >= ScheduleConfig.priorityThreshold.rawValue else {
                print("Notification blocked: Quiet hours (priority too low)")
                result = "quiet_hours"
                return false
            }
        }
        
        // Reset counters if hour has passed
        if now.timeIntervalSince(lastHourReset) >= 3600 {
            notificationCounts.removeAll()
            lastHourReset = now
        }
        
        // Check hourly limit for priority
        let currentCount = notificationCounts[priority, default: 0]
        guard currentCount < priority.allowedPerHour else {
            if priority != .low {
                print("Notification throttled: Exceeded hourly limit for priority \(priority)")
            }
            result = "throttled"
            return false
        }
        
        // Check minimum interval between same type
        if let lastTime = lastNotificationTimes[type] {
            let interval = now.timeIntervalSince(lastTime)
            guard interval >= priority.throttleInterval else {
                if priority != .low {
                    print("Notification throttled: Too soon after last notification of type \(type)")
                }
                result = "throttled"
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Schedule Analytics
    struct ScheduleAnalytics {
        let deliveryStats: [NotificationPriority: DeliveryStats]
        let hourlyDistribution: [Int: Int]
        let dailyDistribution: [ScheduleConfig.Day: Int]
        let groupDistribution: [NotificationGroup: Int]
        
        struct DeliveryStats {
            let total: Int
            let delivered: Int
            let throttled: Int
            let quietHours: Int
            
            var deliveryRate: Double {
                return total > 0 ? Double(delivered) / Double(total) : 0
            }
        }
    }
    
    private var analyticsData: [String: Any] = [:] {
        didSet {
            // Persist analytics data
            UserDefaults.standard.set(analyticsData, forKey: "notifications.analytics")
        }
    }
    
    private func trackNotificationAttempt(
        type: NotificationType,
        result: String,
        date: Date = Date()
    ) {
        let hour = calendar.component(.hour, from: date)
        let day = ScheduleConfig.Day(rawValue: calendar.component(.weekday, from: date))!
        
        // Update counters
        analyticsData["total", default: 0] += 1
        analyticsData["by_priority.\(type.priority.rawValue).\(result)", default: 0] += 1
        analyticsData["by_hour.\(hour)", default: 0] += 1
        analyticsData["by_day.\(day.rawValue)", default: 0] += 1
        analyticsData["by_group.\(type.group.rawValue)", default: 0] += 1
        
        // Track in analytics service
        analytics.trackEvent(.featureUsed(
            name: "notification_attempt",
            properties: [
                "type": type.identifier,
                "priority": type.priority.rawValue,
                "group": type.group.rawValue,
                "result": result,
                "hour": hour,
                "day": day.rawValue
            ]
        ))
    }
    
    // MARK: - Schedule Optimization
    struct ScheduleOptimization {
        let quietHoursSuggestion: QuietHoursSuggestion?
        let peakHoursSuggestion: PeakHoursSuggestion?
        let priorityThresholdSuggestion: PriorityThresholdSuggestion?
        let activeDaysSuggestion: ActiveDaysSuggestion?
        
        struct QuietHoursSuggestion {
            let suggestedStart: Int
            let suggestedEnd: Int
            let currentDeliveryRate: Double
            let projectedDeliveryRate: Double
            let reason: String
        }
        
        struct PeakHoursSuggestion {
            let suggestedStart: Int
            let suggestedEnd: Int
            let currentEngagement: Double
            let projectedEngagement: Double
            let reason: String
        }
        
        struct PriorityThresholdSuggestion {
            let suggestedThreshold: NotificationPriority
            let currentThrottleRate: Double
            let projectedThrottleRate: Double
            let reason: String
        }
        
        struct ActiveDaysSuggestion {
            let suggestedDays: Set<ScheduleConfig.Day>
            let currentEngagement: Double
            let projectedEngagement: Double
            let reason: String
        }
    }
    
    func getScheduleOptimization(timeframe: TimeInterval = 86400 * 7) -> ScheduleOptimization {
        let analytics = getScheduleAnalytics(timeframe: timeframe)
        
        // Analyze quiet hours
        let quietHoursSuggestion = analyzeQuietHours(analytics)
        
        // Analyze peak hours
        let peakHoursSuggestion = analyzePeakHours(analytics)
        
        // Analyze priority threshold
        let priorityThresholdSuggestion = analyzePriorityThreshold(analytics)
        
        // Analyze active days
        let activeDaysSuggestion = analyzeActiveDays(analytics)
        
        return ScheduleOptimization(
            quietHoursSuggestion: quietHoursSuggestion,
            peakHoursSuggestion: peakHoursSuggestion,
            priorityThresholdSuggestion: priorityThresholdSuggestion,
            activeDaysSuggestion: activeDaysSuggestion
        )
    }
    
    private func analyzeQuietHours(_ analytics: ScheduleAnalytics) -> ScheduleOptimization.QuietHoursSuggestion? {
        var lowestEngagementStart = 0
        var lowestEngagementCount = Int.max
        
        // Find 8-hour window with lowest engagement
        for startHour in 0..<24 {
            var windowCount = 0
            for hour in 0..<8 {
                let checkHour = (startHour + hour) % 24
                windowCount += analytics.hourlyDistribution[checkHour, default: 0]
            }
            
            if windowCount < lowestEngagementCount {
                lowestEngagementCount = windowCount
                lowestEngagementStart = startHour
            }
        }
        
        let currentStart = ScheduleConfig.quietHoursStart
        let currentEnd = ScheduleConfig.quietHoursEnd
        
        // Only suggest changes if significantly different
        if abs(lowestEngagementStart - currentStart) >= 2 {
            let currentRate = calculateDeliveryRate(analytics, start: currentStart, end: currentEnd)
            let projectedRate = calculateDeliveryRate(analytics, start: lowestEngagementStart, end: (lowestEngagementStart + 8) % 24)
            
            if projectedRate > currentRate * 1.2 { // 20% improvement threshold
                return ScheduleOptimization.QuietHoursSuggestion(
                    suggestedStart: lowestEngagementStart,
                    suggestedEnd: (lowestEngagementStart + 8) % 24,
                    currentDeliveryRate: currentRate,
                    projectedDeliveryRate: projectedRate,
                    reason: "Adjusting quiet hours to \(lowestEngagementStart):00-\((lowestEngagementStart + 8) % 24):00 could improve delivery rate by \(Int((projectedRate/currentRate - 1) * 100))%"
                )
            }
        }
        
        return nil
    }
    
    private func analyzePeakHours(_ analytics: ScheduleAnalytics) -> ScheduleOptimization.PeakHoursSuggestion? {
        var highestEngagementStart = 0
        var highestEngagementCount = 0
        
        // Find 12-hour window with highest engagement
        for startHour in 0..<24 {
            var windowCount = 0
            for hour in 0..<12 {
                let checkHour = (startHour + hour) % 24
                windowCount += analytics.hourlyDistribution[checkHour, default: 0]
            }
            
            if windowCount > highestEngagementCount {
                highestEngagementCount = windowCount
                highestEngagementStart = startHour
            }
        }
        
        let currentStart = ScheduleConfig.peakHoursStart
        let currentEnd = ScheduleConfig.peakHoursEnd
        
        // Only suggest changes if significantly different
        if abs(highestEngagementStart - currentStart) >= 2 {
            let currentEngagement = calculateEngagementRate(analytics, start: currentStart, end: currentEnd)
            let projectedEngagement = calculateEngagementRate(analytics, start: highestEngagementStart, end: (highestEngagementStart + 12) % 24)
            
            if projectedEngagement > currentEngagement * 1.2 { // 20% improvement threshold
                return ScheduleOptimization.PeakHoursSuggestion(
                    suggestedStart: highestEngagementStart,
                    suggestedEnd: (highestEngagementStart + 12) % 24,
                    currentEngagement: currentEngagement,
                    projectedEngagement: projectedEngagement,
                    reason: "Adjusting peak hours to \(highestEngagementStart):00-\((highestEngagementStart + 12) % 24):00 could improve engagement by \(Int((projectedEngagement/currentEngagement - 1) * 100))%"
                )
            }
        }
        
        return nil
    }
    
    private func analyzePriorityThreshold(_ analytics: ScheduleAnalytics) -> ScheduleOptimization.PriorityThresholdSuggestion? {
        let currentThreshold = ScheduleConfig.priorityThreshold
        var bestThreshold = currentThreshold
        var bestThrottleRate = Double.infinity
        
        for priority in NotificationPriority.allCases {
            let stats = analytics.deliveryStats[priority, default: ScheduleAnalytics.DeliveryStats(total: 0, delivered: 0, throttled: 0, quietHours: 0)]
            let throttleRate = Double(stats.throttled + stats.quietHours) / Double(max(1, stats.total))
            
            if throttleRate < bestThrottleRate && throttleRate < 0.3 { // Aim for < 30% throttle rate
                bestThrottleRate = throttleRate
                bestThreshold = priority
            }
        }
        
        if bestThreshold != currentThreshold {
            let currentStats = analytics.deliveryStats[currentThreshold, default: ScheduleAnalytics.DeliveryStats(total: 0, delivered: 0, throttled: 0, quietHours: 0)]
            let currentThrottleRate = Double(currentStats.throttled + currentStats.quietHours) / Double(max(1, currentStats.total))
            
            return ScheduleOptimization.PriorityThresholdSuggestion(
                suggestedThreshold: bestThreshold,
                currentThrottleRate: currentThrottleRate,
                projectedThrottleRate: bestThrottleRate,
                reason: "Adjusting priority threshold to \(bestThreshold) could reduce throttling by \(Int((currentThrottleRate - bestThrottleRate) * 100))%"
            )
        }
        
        return nil
    }
    
    private func analyzeActiveDays(_ analytics: ScheduleAnalytics) -> ScheduleOptimization.ActiveDaysSuggestion? {
        let currentDays = ScheduleConfig.activeDays
        var suggestedDays = Set<ScheduleConfig.Day>()
        
        for day in ScheduleConfig.Day.allCases {
            let dayCount = analytics.dailyDistribution[day, default: 0]
            let averageCount = analytics.dailyDistribution.values.reduce(0, +) / analytics.dailyDistribution.count
            
            if dayCount >= averageCount / 2 { // Include days with at least 50% of average activity
                suggestedDays.insert(day)
            }
        }
        
        if suggestedDays != currentDays {
            let currentEngagement = calculateDailyEngagement(analytics, days: currentDays)
            let projectedEngagement = calculateDailyEngagement(analytics, days: suggestedDays)
            
            if projectedEngagement > currentEngagement * 1.1 { // 10% improvement threshold
                return ScheduleOptimization.ActiveDaysSuggestion(
                    suggestedDays: suggestedDays,
                    currentEngagement: currentEngagement,
                    projectedEngagement: projectedEngagement,
                    reason: "Adjusting active days could improve engagement by \(Int((projectedEngagement/currentEngagement - 1) * 100))%"
                )
            }
        }
        
        return nil
    }
    
    private func calculateDeliveryRate(_ analytics: ScheduleAnalytics, start: Int, end: Int) -> Double {
        var delivered = 0
        var total = 0
        
        for hour in 0..<24 {
            let count = analytics.hourlyDistribution[hour, default: 0]
            if isHourInRange(hour, start: start, end: end) {
                delivered += count
            }
            total += count
        }
        
        return Double(delivered) / Double(max(1, total))
    }
    
    private func calculateEngagementRate(_ analytics: ScheduleAnalytics, start: Int, end: Int) -> Double {
        var engagement = 0
        var total = 0
        
        for hour in 0..<24 {
            let count = analytics.hourlyDistribution[hour, default: 0]
            if isHourInRange(hour, start: start, end: end) {
                engagement += count
            }
            total += count
        }
        
        return Double(engagement) / Double(max(1, total))
    }
    
    private func calculateDailyEngagement(_ analytics: ScheduleAnalytics, days: Set<ScheduleConfig.Day>) -> Double {
        let totalCount = analytics.dailyDistribution.values.reduce(0, +)
        let activeCount = days.reduce(0) { $0 + analytics.dailyDistribution[$1, default: 0] }
        return Double(activeCount) / Double(max(1, totalCount))
    }
    
    private func isHourInRange(_ hour: Int, start: Int, end: Int) -> Bool {
        if start < end {
            return hour >= start && hour < end
        } else {
            return hour >= start || hour < end
        }
    }
    
    func getScheduleAnalytics(timeframe: TimeInterval = 86400 * 7) -> ScheduleAnalytics {
        var stats: [NotificationPriority: ScheduleAnalytics.DeliveryStats] = [:]
        var hourly: [Int: Int] = [:]
        var daily: [ScheduleConfig.Day: Int] = [:]
        var groups: [NotificationGroup: Int] = [:]
        
        // Process analytics data
        for priority in NotificationPriority.allCases {
            let total = analyticsData["by_priority.\(priority.rawValue).total"] as? Int ?? 0
            let delivered = analyticsData["by_priority.\(priority.rawValue).delivered"] as? Int ?? 0
            let throttled = analyticsData["by_priority.\(priority.rawValue).throttled"] as? Int ?? 0
            let quietHours = analyticsData["by_priority.\(priority.rawValue).quiet_hours"] as? Int ?? 0
            
            stats[priority] = ScheduleAnalytics.DeliveryStats(
                total: total,
                delivered: delivered,
                throttled: throttled,
                quietHours: quietHours
            )
        }
        
        // Hourly distribution
        for hour in 0..<24 {
            hourly[hour] = analyticsData["by_hour.\(hour)"] as? Int ?? 0
        }
        
        // Daily distribution
        for day in ScheduleConfig.Day.allCases {
            daily[day] = analyticsData["by_day.\(day.rawValue)"] as? Int ?? 0
        }
        
        // Group distribution
        for group in NotificationGroup.allCases {
            groups[group] = analyticsData["by_group.\(group.rawValue)"] as? Int ?? 0
        }
        
        return ScheduleAnalytics(
            deliveryStats: stats,
            hourlyDistribution: hourly,
            dailyDistribution: daily,
            groupDistribution: groups
        )
    }
    
    // MARK: - Schedule Preview
    struct SchedulePreview {
        struct TimeSlot {
            let hour: Int
            let isQuietHours: Bool
            let isPeakHours: Bool
            let allowedPriorities: Set<NotificationPriority>
            
            // Visualization helpers
            var status: Status {
                if !allowedPriorities.isEmpty {
                    return isPeakHours ? .peak : .active
                }
                return isQuietHours ? .quiet : .inactive
            }
            
            var timeString: String {
                let formatter = DateFormatter()
                formatter.dateFormat = "ha"
                let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
                return formatter.string(from: date)
            }
        }
        
        enum Status: String {
            case peak = "Peak Hours"
            case active = "Active"
            case quiet = "Quiet Hours"
            case inactive = "Inactive"
            
            var color: String {
                switch self {
                case .peak: return "#4CAF50"     // Green
                case .active: return "#2196F3"    // Blue
                case .quiet: return "#9E9E9E"     // Gray
                case .inactive: return "#F44336"  // Red
                }
            }
        }
        
        let day: ScheduleConfig.Day
        let isActive: Bool
        let timeSlots: [TimeSlot]
        
        // Visualization helpers
        var dayName: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            let date = Calendar.current.date(from: DateComponents(weekday: day.rawValue)) ?? Date()
            return formatter.string(from: date)
        }
        
        var statusSummary: String {
            let activeHours = timeSlots.filter { !$0.allowedPriorities.isEmpty }.count
            let peakHours = timeSlots.filter { $0.isPeakHours }.count
            let quietHours = timeSlots.filter { $0.isQuietHours }.count
            
            return """
                Active Hours: \(activeHours)
                Peak Hours: \(peakHours)
                Quiet Hours: \(quietHours)
                """
        }
    }
    
    func getSchedulePreview(for date: Date = Date()) -> SchedulePreview {
        let day = ScheduleConfig.Day(rawValue: calendar.component(.weekday, from: date))!
        let isActive = ScheduleConfig.activeDays.contains(day)
        
        var timeSlots: [SchedulePreview.TimeSlot] = []
        
        for hour in 0..<24 {
            let isQuietHours = isInQuietHours(hour: hour, day: day)
            let isPeakHours = isInPeakHours(hour: hour)
            
            var allowedPriorities: Set<NotificationPriority> = []
            
            if isActive {
                if isQuietHours {
                    // During quiet hours, only high priority notifications
                    allowedPriorities = Set(NotificationPriority.allCases.filter {
                        $0.rawValue >= ScheduleConfig.priorityThreshold.rawValue
                    })
                } else {
                    // During active hours, all priorities allowed
                    allowedPriorities = Set(NotificationPriority.allCases)
                }
                
                if !isPeakHours {
                    // Outside peak hours, remove low priority
                    allowedPriorities.remove(.low)
                }
            }
            
            timeSlots.append(SchedulePreview.TimeSlot(
                hour: hour,
                isQuietHours: isQuietHours,
                isPeakHours: isPeakHours,
                allowedPriorities: allowedPriorities
            ))
        }
        
        return SchedulePreview(
            day: day,
            isActive: isActive,
            timeSlots: timeSlots
        )
    }
    
    private func isInQuietHours(_ date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        let day = ScheduleConfig.Day(rawValue: calendar.component(.weekday, from: date))!
        return isInQuietHours(hour: hour, day: day)
    }
    
    private func isInQuietHours(hour: Int, day: ScheduleConfig.Day) -> Bool {
        // Skip if day is not active
        guard ScheduleConfig.activeDays.contains(day) else {
            return true // Treat inactive days as quiet hours
        }
        
        // Skip weekend check if weekend quiet hours are disabled
        if day.isWeekend && !ScheduleConfig.hasWeekendQuietHours {
            return false
        }
        
        let start = ScheduleConfig.quietHoursStart
        let end = ScheduleConfig.quietHoursEnd
        
        if start < end {
            // Simple range (e.g., 22:00 - 08:00)
            return hour >= start && hour < end
        } else {
            // Overnight range (e.g., 22:00 - 08:00)
            return hour >= start || hour < end
        }
    }
    
    private func isInPeakHours(hour: Int) -> Bool {
        let start = ScheduleConfig.peakHoursStart
        let end = ScheduleConfig.peakHoursEnd
        
        if start < end {
            return hour >= start && hour < end
        } else {
            return hour >= start || hour < end
        }
    }
    
    private func startBatchTimer(for group: NotificationGroup) {
        batchTimer?.invalidate()
        batchTimer = Timer.scheduledTimer(
            withTimeInterval: group.batchDelay,
            repeats: false
        ) { [weak self] _ in
            self?.scheduleBatchNotification(for: group)
        }
    }
    
    private func cleanupOldPendingNotifications() {
        let now = Date()
        pendingNotifications.removeAll { 
            now.timeIntervalSince($0.3) > BatchConfig.maxBatchAge
        }
    }
    
    private func scheduleBatchNotification() {
        guard !pendingNotifications.isEmpty else { return }
        
        batchTimer?.invalidate()
        batchTimer = nil
        
        // Group notifications by type
        let groupedNotifications = Dictionary(grouping: pendingNotifications) {
            $0.0.group
        }
        
        // Create batched notifications for each group
        for (group, notifications) in groupedNotifications {
            let content = UNMutableNotificationContent()
            content.threadIdentifier = group.identifier
            content.categoryIdentifier = group.rawValue
            
            if notifications.count == 1 {
                // Single notification, use original content
                let (_, notification, trigger, _) = notifications[0]
                scheduleImmediateNotification(notifications[0].0, notification, trigger)
                continue
            }
            
            // Multiple notifications, batch them
            content.title = await getLocalizedString("\(group.displayName) Updates")
            
            var bodyText = ""
            var userInfo: [String: Any] = [:]
            
            // Combine notification contents (limit to maxBatchSize)
            for (index, (type, notification, _, _)) in notifications.prefix(BatchConfig.maxBatchSize).enumerated() {
                if index > 0 { bodyText += "\n" }
                bodyText += "• \(notification.body)"
                
                if let notificationInfo = notification.userInfo as? [String: Any] {
                    userInfo["notification_\(type.identifier)"] = notificationInfo
                }
            }
            
            content.body = bodyText
            content.userInfo = userInfo
            content.sound = .default
            
            // Schedule the batched notification
            let request = UNNotificationRequest(
                identifier: "batched_\(group.identifier)_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Failed to schedule batched notification: \(error.localizedDescription)")
                }
            }
            
            // Track analytics
            analytics.trackEvent(.featureUsed(
                name: "notification_batched",
                properties: [
                    "group": group.rawValue,
                    "count": notifications.count,
                    "types": notifications.map { $0.0.identifier }
                ]
            ))
        }
        
        // Clear processed notifications
        pendingNotifications.removeAll()
    }
    
    // MARK: - Batch Preview
    struct BatchPreview {
        let groupId: String
        let title: String
        let notifications: [(title: String, body: String)]
        let totalCount: Int
        
        var hasMore: Bool {
            return totalCount > notifications.count
        }
    }
    
    func previewPendingBatches() -> [NotificationGroup: BatchPreview] {
        cleanupOldPendingNotifications()
        
        let groupedNotifications = Dictionary(grouping: pendingNotifications) {
            $0.0.group
        }
        
        return groupedNotifications.compactMapValues { notifications in
            guard notifications.count > 1 else { return nil }
            
            let previewItems = notifications.prefix(BatchConfig.maxBatchSize).map {
                (title: $0.1.title, body: $0.1.body)
            }
            
            return BatchPreview(
                groupId: notifications[0].0.group.identifier,
                title: "\(notifications[0].0.group.displayName) Updates",
                notifications: previewItems,
                totalCount: notifications.count
            )
        }
    }
    
    func cancelPendingBatch(for group: NotificationGroup) {
        pendingNotifications.removeAll { notification in
            notification.0.group == group
        }
        
        analytics.trackEvent(.featureUsed(
            name: "notification_batch_cancelled",
            properties: ["group": group.rawValue]
        ))
    }
    
    func forceBatchDelivery(for group: NotificationGroup) {
        let notifications = pendingNotifications.filter {
            $0.0.group == group
        }
        
        guard !notifications.isEmpty else { return }
        
        let content = createBatchContent(
            for: group,
            notifications: notifications
        )
        
        scheduleImmediateNotification(
            notifications[0].0,
            content,
            nil
        )
        
        // Remove delivered notifications
        pendingNotifications.removeAll {
            $0.0.group == group
        }
        
        analytics.trackEvent(.featureUsed(
            name: "notification_batch_forced",
            properties: ["group": group.rawValue]
        ))
    }
    
    private func createBatchContent(
        for group: NotificationGroup,
        notifications: [(NotificationType, UNMutableNotificationContent, UNNotificationTrigger, Date)]
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.threadIdentifier = group.identifier
        content.categoryIdentifier = group.rawValue
        content.title = "\(group.displayName) Updates"
        content.sound = .default
        
        var bodyText = ""
        var userInfo: [String: Any] = [:]
        
        for (index, (type, notification, _, _)) in notifications.prefix(BatchConfig.maxBatchSize).enumerated() {
            if index > 0 { bodyText += "\n" }
            bodyText += "• \(notification.body)"
            
            if let notificationInfo = notification.userInfo as? [String: Any] {
                userInfo["notification_\(type.identifier)"] = notificationInfo
            }
        }
        
        if notifications.count > BatchConfig.maxBatchSize {
            bodyText += "\n• And \(notifications.count - BatchConfig.maxBatchSize) more updates..."
        }
        
        content.body = bodyText
        content.userInfo = userInfo
        
        return content
    }
    
    // MARK: - Settings
    func checkNotificationSettings() async -> UNNotificationSettings {
        return await center.notificationSettings()
    }
    
    func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Batch Settings
    func setBatchingEnabled(_ enabled: Bool) {
        BatchConfig.isBatchingEnabled = enabled
        
        if !enabled {
            // Deliver all pending notifications immediately
            for group in NotificationGroup.allCases {
                forceBatchDelivery(for: group)
            }
        }
        
        analytics.trackEvent(.featureUsed(
            name: "notification_batching_toggled",
            properties: ["enabled": enabled]
        ))
        
        NotificationCenter.default.post(
            name: .notificationBatchSettingsChanged,
            object: nil
        )
    }
    
    func configureBatchSettings(
        minSize: Int? = nil,
        maxSize: Int? = nil,
        delay: TimeInterval? = nil,
        maxAge: TimeInterval? = nil
    ) {
        if let minSize = minSize {
            BatchConfig.minBatchSize = max(2, min(minSize, BatchConfig.maxBatchSize))
        }
        
        if let maxSize = maxSize {
            BatchConfig.maxBatchSize = max(BatchConfig.minBatchSize, maxSize)
        }
        
        if let delay = delay {
            BatchConfig.batchDelay = max(60, min(delay, 3600))
        }
        
        if let maxAge = maxAge {
            BatchConfig.maxBatchAge = max(3600, min(maxAge, 86400))
        }
        
        analytics.trackEvent(.featureUsed(
            name: "notification_batch_settings_updated",
            properties: [
                "minSize": BatchConfig.minBatchSize,
                "maxSize": BatchConfig.maxBatchSize,
                "delay": BatchConfig.batchDelay,
                "maxAge": BatchConfig.maxBatchAge
            ]
        ))
        
        NotificationCenter.default.post(
            name: .notificationBatchSettingsChanged,
            object: nil
        )
    }
    
    func resetBatchSettings() {
        BatchConfig.resetToDefaults()
        
        analytics.trackEvent(.featureUsed(
            name: "notification_batch_settings_reset"
        ))
        
        NotificationCenter.default.post(
            name: .notificationBatchSettingsChanged,
            object: nil
        )
    }
}

// MARK: - Convenience Methods
extension NotificationManager {
    func scheduleAllNotifications() async {
        await scheduleDailyRewardNotification()
        await scheduleInactivityReminder(days: 3)
    }
    
    func handleAppLaunch() {
        resetBadgeCount()
    }
    
    // MARK: - Additional Notification Types
    func scheduleTournamentNotification(
        tournamentId: String,
        startTime: Date,
        title: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = await getLocalizedString("Tournament Starting Soon!")
        content.body = await getLocalizedString("\(title) begins in 30 minutes!")
        content.sound = .default
        content.userInfo = ["tournamentId": tournamentId]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: startTime.timeIntervalSinceNow - 1800, // 30 minutes before
            repeats: false
        )
        
        scheduleNotification(
            type: .tournament,
            content: content,
            trigger: trigger
        )
    }
    
    func scheduleFriendActivityNotification(
        friendId: String,
        friendName: String,
        activity: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = await getLocalizedString("Friend Activity")
        content.body = await getLocalizedString("\(friendName) \(activity)")
        content.sound = .default
        content.userInfo = ["friendId": friendId]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 1,
            repeats: false
        )
        
        scheduleNotification(
            type: .friendActivity,
            content: content,
            trigger: trigger
        )
    }
    
    func scheduleClanEventNotification(
        clanId: String,
        eventName: String,
        startTime: Date
    ) async {
        let content = UNMutableNotificationContent()
        content.title = await getLocalizedString("Clan Event")
        content.body = await getLocalizedString("\(eventName) is starting soon!")
        content.sound = .default
        content.userInfo = ["clanId": clanId]
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: startTime.addingTimeInterval(-900) // 15 minutes before
            ),
            repeats: false
        )
        
        scheduleNotification(
            type: .clanEvent,
            content: content,
            trigger: trigger
        )
    }
    
    func scheduleBattlePassNotification(
        tier: Int,
        daysRemaining: Int
    ) async {
        let content = UNMutableNotificationContent()
        content.title = await getLocalizedString("Battle Pass Update")
        content.body = await getLocalizedString("You're close to tier \(tier)! Only \(daysRemaining) days left!")
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 86400, // 24 hours
            repeats: false
        )
        
        scheduleNotification(
            type: .battlePass,
            content: content,
            trigger: trigger
        )
    }

    func handleAppBackground() async {
        // Schedule inactivity reminder
        await scheduleInactivityReminder(days: 3)
        
        // Check for upcoming tournaments
        if let nextTournament = TournamentManager.shared.getNextTournament() {
            await scheduleTournamentNotification(
                tournamentId: nextTournament.id,
                startTime: nextTournament.startTime,
                title: nextTournament.title
            )
        }
        
        // Check battle pass progress
        if let battlePass = BattlePassManager.shared.getCurrentPass(),
           let progress = BattlePassManager.shared.getProgress() {
            let daysRemaining = Int(battlePass.endDate.timeIntervalSinceNow / 86400)
            if daysRemaining <= 7 {
                await scheduleBattlePassNotification(
                    tier: progress.currentTier + 1,
                    daysRemaining: daysRemaining
                )
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        let identifier = response.notification.request.identifier
        
        switch identifier {
        case NotificationType.dailyReward.identifier:
            NotificationCenter.default.post(name: .showDailyRewards, object: nil)
        case NotificationType.challenge.identifier:
            NotificationCenter.default.post(name: .showChallenges, object: nil)
        case NotificationType.tournament.identifier:
            if let tournamentId = response.notification.request.content.userInfo["tournamentId"] as? String {
                NotificationCenter.default.post(
                    name: .showTournament,
                    object: nil,
                    userInfo: ["tournamentId": tournamentId]
                )
            }
        case NotificationType.friendActivity.identifier:
            if let friendId = response.notification.request.content.userInfo["friendId"] as? String {
                NotificationCenter.default.post(
                    name: .showFriendProfile,
                    object: nil,
                    userInfo: ["friendId": friendId]
                )
            }
        case NotificationType.clanEvent.identifier:
            if let clanId = response.notification.request.content.userInfo["clanId"] as? String {
                NotificationCenter.default.post(
                    name: .showClanEvent,
                    object: nil,
                    userInfo: ["clanId": clanId]
                )
            }
        case NotificationType.battlePass.identifier:
            NotificationCenter.default.post(name: .showBattlePass, object: nil)
        default:
            break
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names
// MARK: - Notification Categories
extension NotificationManager {
    func registerNotificationCategories() {
        let categories: Set<UNNotificationCategory> = [
            UNNotificationCategory(
                identifier: NotificationGroup.gameplay.rawValue,
                actions: [],
                intentIdentifiers: [],
                options: .customDismissAction
            ),
            UNNotificationCategory(
                identifier: NotificationGroup.social.rawValue,
                actions: [
                    UNNotificationAction(
                        identifier: "action.respond",
                        title: "Respond",
                        options: .foreground
                    )
                ],
                intentIdentifiers: [],
                options: .customDismissAction
            ),
            UNNotificationCategory(
                identifier: NotificationGroup.events.rawValue,
                actions: [
                    UNNotificationAction(
                        identifier: "action.join",
                        title: "Join Now",
                        options: .foreground
                    )
                ],
                intentIdentifiers: [],
                options: .customDismissAction
            ),
            UNNotificationCategory(
                identifier: NotificationGroup.rewards.rawValue,
                actions: [
                    UNNotificationAction(
                        identifier: "action.claim",
                        title: "Claim",
                        options: .foreground
                    )
                ],
                intentIdentifiers: [],
                options: .customDismissAction
            )
        ]
        
        center.setNotificationCategories(categories)
    }
}

extension Notification.Name {
    static let showDailyRewards = Notification.Name("showDailyRewards")
    static let showChallenges = Notification.Name("showChallenges")
    static let showTournament = Notification.Name("showTournament")
    static let showFriendProfile = Notification.Name("showFriendProfile")
    static let showClanEvent = Notification.Name("showClanEvent")
    static let showBattlePass = Notification.Name("showBattlePass")
    static let notificationGroupStatusChanged = Notification.Name("notificationGroupStatusChanged")
    static let notificationBatchSettingsChanged = Notification.Name("notificationBatchSettingsChanged")
}

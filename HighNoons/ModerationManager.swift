import Foundation

final class ModerationManager {
    // MARK: - Properties
    static let shared = ModerationManager()
    
    private let networkManager = NetworkManager.shared
    private let analytics = AnalyticsManager.shared
    private let chatManager = ChatManager.shared
    
    private var activeReports: [Report] = []
    private var moderationHistory: [ModerationType: [ModerationAction]] = [:]
    private var wordFilter: WordFilter?
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct Report: Codable {
        let id: String
        let reporterId: String
        let targetId: String
        let type: ReportType
        let reason: ReportReason
        let description: String
        let evidence: [Evidence]
        let timestamp: Date
        let status: ReportStatus
        
        enum ReportType: String, Codable {
            case player
            case chat
            case clan
            case content
            case cheating
            case other
        }
        
        enum ReportReason: String, Codable {
            case inappropriate
            case harassment
            case cheating
            case spamming
            case offensive
            case impersonation
            case exploitation
            case other
            
            var description: String {
                switch self {
                case .inappropriate: return "Inappropriate Content"
                case .harassment: return "Harassment"
                case .cheating: return "Cheating"
                case .spamming: return "Spamming"
                case .offensive: return "Offensive Behavior"
                case .impersonation: return "Impersonation"
                case .exploitation: return "Exploitation"
                case .other: return "Other"
                }
            }
        }
        
        enum ReportStatus: String, Codable {
            case pending
            case investigating
            case resolved
            case rejected
        }
        
        struct Evidence: Codable {
            let type: EvidenceType
            let content: String
            
            enum EvidenceType: String, Codable {
                case screenshot
                case replay
                case chat
                case stats
                case custom
            }
        }
    }
    
    struct ModerationType: Codable, Hashable {
        let category: Category
        let severity: Severity
        let duration: Duration?
        
        enum Category: String, Codable {
            case warning
            case mute
            case ban
            case restriction
        }
        
        enum Severity: String, Codable {
            case low
            case medium
            case high
            case critical
            
            var defaultDuration: Duration {
                switch self {
                case .low: return .temporary(hours: 1)
                case .medium: return .temporary(hours: 24)
                case .high: return .temporary(hours: 168) // 1 week
                case .critical: return .permanent
                }
            }
        }
        
        enum Duration: Codable, Hashable {
            case temporary(hours: Int)
            case permanent
            
            var isExpired: Bool {
                switch self {
                case .temporary(let hours):
                    return Date().timeIntervalSince1970 > TimeInterval(hours * 3600)
                case .permanent:
                    return false
                }
            }
        }
    }
    
    struct ModerationAction: Codable {
        let id: String
        let type: ModerationType
        let targetId: String
        let reason: String
        let moderatorId: String
        let timestamp: Date
        let expiryDate: Date?
        let isActive: Bool
    }
    
    class WordFilter {
        private var bannedWords: Set<String>
        private var suspiciousWords: Set<String>
        private var whitelist: Set<String>
        
        init() {
            self.bannedWords = []
            self.suspiciousWords = []
            self.whitelist = []
            loadFilterLists()
        }
        
        private func loadFilterLists() {
            // Load filter lists from configuration
            if let path = Bundle.main.path(forResource: "WordFilter", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path) as? [String: [String]] {
                bannedWords = Set(dict["banned"] ?? [])
                suspiciousWords = Set(dict["suspicious"] ?? [])
                whitelist = Set(dict["whitelist"] ?? [])
            }
        }
        
        func filterText(_ text: String) -> (filtered: String, containsBanned: Bool) {
            let words = text.components(separatedBy: .whitespacesAndNewlines)
            var filtered = words
            var hasBanned = false
            
            for (index, word) in words.enumerated() {
                let lowercased = word.lowercased()
                if bannedWords.contains(lowercased) {
                    filtered[index] = String(repeating: "*", count: word.count)
                    hasBanned = true
                } else if suspiciousWords.contains(lowercased) && !whitelist.contains(lowercased) {
                    filtered[index] = String(repeating: "*", count: word.count)
                }
            }
            
            return (filtered.joined(separator: " "), hasBanned)
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupWordFilter()
        setupRefreshTimer()
        loadActiveReports()
    }
    
    private func setupWordFilter() {
        wordFilter = WordFilter()
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 300, // 5 minutes
            repeats: true
        ) { [weak self] _ in
            self?.refreshModeration()
        }
    }
    
    // MARK: - Reporting
    func submitReport(
        type: Report.ReportType,
        targetId: String,
        reason: Report.ReportReason,
        description: String,
        evidence: [Report.Evidence],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let report = Report(
            id: UUID().uuidString,
            reporterId: PlayerStats.shared.userId,
            targetId: targetId,
            type: type,
            reason: reason,
            description: description,
            evidence: evidence,
            timestamp: Date(),
            status: .pending
        )
        
        Task {
            do {
                try await networkManager.request(
                    endpoint: "moderation/reports",
                    method: .post,
                    parameters: ["report": report]
                )
                
                activeReports.append(report)
                
                analytics.trackEvent(.featureUsed(name: "report_submitted"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Content Moderation
    func moderateText(_ text: String) -> (filtered: String, isAllowed: Bool) {
        guard let filter = wordFilter else {
            return (text, true)
        }
        
        let (filtered, containsBanned) = filter.filterText(text)
        return (filtered, !containsBanned)
    }
    
    func moderateUsername(_ username: String) -> Bool {
        guard let filter = wordFilter else {
            return true
        }
        
        let (_, containsBanned) = filter.filterText(username)
        return !containsBanned
    }
    
    func moderateClanName(_ name: String) -> Bool {
        guard let filter = wordFilter else {
            return true
        }
        
        let (_, containsBanned) = filter.filterText(name)
        return !containsBanned
    }
    
    // MARK: - Moderation Actions
    func applyModeration(
        type: ModerationType,
        targetId: String,
        reason: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let action = ModerationAction(
            id: UUID().uuidString,
            type: type,
            targetId: targetId,
            reason: reason,
            moderatorId: PlayerStats.shared.userId,
            timestamp: Date(),
            expiryDate: type.duration.map {
                switch $0 {
                case .temporary(let hours):
                    return Date().addingTimeInterval(TimeInterval(hours * 3600))
                case .permanent:
                    return nil
                }
            },
            isActive: true
        )
        
        Task {
            do {
                try await networkManager.request(
                    endpoint: "moderation/actions",
                    method: .post,
                    parameters: ["action": action]
                )
                
                moderationHistory[type, default: []].append(action)
                
                analytics.trackEvent(.featureUsed(name: "moderation_applied"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func removeModeration(
        actionId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await networkManager.request(
                    endpoint: "moderation/actions/\(actionId)/remove",
                    method: .post
                )
                
                // Update local state
                for (type, actions) in moderationHistory {
                    if let index = actions.firstIndex(where: { $0.id == actionId }) {
                        var updatedActions = actions
                        updatedActions[index].isActive = false
                        moderationHistory[type] = updatedActions
                    }
                }
                
                analytics.trackEvent(.featureUsed(name: "moderation_removed"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Status Checks
    func isUserMuted(_ userId: String) -> Bool {
        return hasActiveModeration(userId, category: .mute)
    }
    
    func isUserBanned(_ userId: String) -> Bool {
        return hasActiveModeration(userId, category: .ban)
    }
    
    func isUserRestricted(_ userId: String) -> Bool {
        return hasActiveModeration(userId, category: .restriction)
    }
    
    private func hasActiveModeration(_ userId: String, category: ModerationType.Category) -> Bool {
        for (type, actions) in moderationHistory where type.category == category {
            if actions.contains(where: {
                $0.targetId == userId &&
                $0.isActive &&
                !type.duration.map { $0.isExpired } ?? false
            }) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Data Management
    private func loadActiveReports() {
        Task {
            do {
                let reports: [Report] = try await networkManager.request(
                    endpoint: "moderation/reports/active"
                )
                activeReports = reports
            } catch {
                print("Failed to load active reports: \(error.localizedDescription)")
            }
        }
    }
    
    private func refreshModeration() {
        // Remove expired moderations
        for (type, actions) in moderationHistory {
            moderationHistory[type] = actions.filter {
                $0.isActive && !type.duration.map { $0.isExpired } ?? true
            }
        }
        
        // Refresh active reports
        loadActiveReports()
    }
    
    // MARK: - Cleanup
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        activeReports.removeAll()
        moderationHistory.removeAll()
    }
}

// MARK: - Convenience Methods
extension ModerationManager {
    func getActiveReports() -> [Report] {
        return activeReports.filter { $0.status != .resolved }
    }
    
    func getUserModeration(_ userId: String) -> [ModerationType: [ModerationAction]] {
        var userModeration: [ModerationType: [ModerationAction]] = [:]
        
        for (type, actions) in moderationHistory {
            let userActions = actions.filter { $0.targetId == userId }
            if !userActions.isEmpty {
                userModeration[type] = userActions
            }
        }
        
        return userModeration
    }
    
    func getModerationType(for report: Report) -> ModerationType {
        switch (report.type, report.reason) {
        case (_, .cheating):
            return ModerationType(
                category: .ban,
                severity: .critical,
                duration: .permanent
            )
        case (_, .harassment), (_, .offensive):
            return ModerationType(
                category: .mute,
                severity: .high,
                duration: .temporary(hours: 168)
            )
        case (_, .spamming):
            return ModerationType(
                category: .mute,
                severity: .medium,
                duration: .temporary(hours: 24)
            )
        default:
            return ModerationType(
                category: .warning,
                severity: .low,
                duration: .temporary(hours: 1)
            )
        }
    }
}

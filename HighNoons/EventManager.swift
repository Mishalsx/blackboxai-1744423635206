import Foundation

final class EventManager {
    // MARK: - Properties
    static let shared = EventManager()
    
    private let networkManager = NetworkManager.shared
    private let analytics = AnalyticsManager.shared
    private let notificationManager = NotificationManager.shared
    
    private var activeEvents: [Event] = []
    private var eventProgress: [String: EventProgress] = [:]
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct Event: Codable {
        let id: String
        let name: String
        let description: String
        let type: EventType
        let startDate: Date
        let endDate: Date
        let rewards: [EventReward]
        let requirements: [Requirement]
        let features: [Feature]
        let metadata: [String: String]
        
        enum EventType: String, Codable {
            case seasonal
            case limitedTime
            case challenge
            case tournament
            case collaboration
            case special
            
            var displayName: String {
                switch self {
                case .seasonal: return "Seasonal Event"
                case .limitedTime: return "Limited Time Event"
                case .challenge: return "Challenge Event"
                case .tournament: return "Tournament Event"
                case .collaboration: return "Collaboration"
                case .special: return "Special Event"
                }
            }
        }
        
        struct EventReward: Codable {
            let tier: Int
            let points: Int
            let rewards: [Reward]
            
            struct Reward: Codable {
                let type: RewardType
                let amount: Int
                let id: String?
                
                enum RewardType: String, Codable {
                    case coins
                    case gems
                    case character
                    case outfit
                    case gunSkin
                    case emote
                    case effect
                    case title
                    case badge
                    case special
                }
            }
        }
        
        struct Requirement: Codable {
            let type: RequirementType
            let value: Int
            
            enum RequirementType: String, Codable {
                case level
                case rank
                case wins
                case characterUnlocked
                case battlePassTier
                case special
            }
        }
        
        struct Feature: Codable {
            let type: FeatureType
            let config: [String: Any]
            
            enum FeatureType: String, Codable {
                case gameMode
                case map
                case character
                case powerup
                case modifier
                case rules
                case special
            }
            
            private enum CodingKeys: String, CodingKey {
                case type
                case config
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                type = try container.decode(FeatureType.self, forKey: .type)
                config = try container.decode([String: String].self, forKey: .config)
                    .reduce(into: [String: Any]()) { $0[$1.key] = $1.value }
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(type, forKey: .type)
                try container.encode(config.reduce(into: [String: String]()) {
                    $0[$1.key] = String(describing: $1.value)
                }, forKey: .config)
            }
        }
    }
    
    struct EventProgress: Codable {
        let eventId: String
        var points: Int
        var completedTiers: Set<Int>
        var objectives: [String: Int]
        var lastUpdated: Date
        
        static func create(for eventId: String) -> EventProgress {
            return EventProgress(
                eventId: eventId,
                points: 0,
                completedTiers: [],
                objectives: [:],
                lastUpdated: Date()
            )
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupRefreshTimer()
        loadActiveEvents()
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 300, // 5 minutes
            repeats: true
        ) { [weak self] _ in
            self?.refreshEvents()
        }
    }
    
    // MARK: - Event Management
    private func loadActiveEvents() {
        Task {
            do {
                let events: [Event] = try await networkManager.request(
                    endpoint: "events/active"
                )
                
                activeEvents = events
                
                // Load progress for each event
                for event in events {
                    try await loadEventProgress(event.id)
                }
                
                // Schedule notifications
                scheduleEventNotifications(events)
                
                analytics.trackEvent(.featureUsed(name: "events_loaded"))
            } catch {
                print("Failed to load events: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadEventProgress(_ eventId: String) async throws {
        let progress: EventProgress = try await networkManager.request(
            endpoint: "events/\(eventId)/progress"
        )
        eventProgress[eventId] = progress
    }
    
    private func refreshEvents() {
        loadActiveEvents()
    }
    
    // MARK: - Progress Tracking
    func addEventPoints(
        _ points: Int,
        toEvent eventId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard var progress = eventProgress[eventId],
              let event = getEvent(eventId) else {
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }
        
        progress.points += points
        progress.lastUpdated = Date()
        
        // Check for new tier completions
        let newTiers = event.rewards.filter {
            !progress.completedTiers.contains($0.tier) &&
            progress.points >= $0.points
        }
        
        for tier in newTiers {
            progress.completedTiers.insert(tier.tier)
            grantEventRewards(tier.rewards)
        }
        
        eventProgress[eventId] = progress
        
        // Sync with server
        Task {
            do {
                try await networkManager.request(
                    endpoint: "events/\(eventId)/progress",
                    method: .post,
                    parameters: ["progress": progress]
                )
                
                analytics.trackEvent(.featureUsed(
                    name: "event_progress",
                    properties: ["points": points]
                ))
                
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func updateObjective(
        _ objectiveId: String,
        progress: Int,
        inEvent eventId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard var eventProgress = eventProgress[eventId] else {
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }
        
        eventProgress.objectives[objectiveId] = progress
        eventProgress.lastUpdated = Date()
        
        self.eventProgress[eventId] = eventProgress
        
        // Sync with server
        Task {
            do {
                try await networkManager.request(
                    endpoint: "events/\(eventId)/objectives/\(objectiveId)",
                    method: .post,
                    parameters: ["progress": progress]
                )
                
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Reward Management
    private func grantEventRewards(_ rewards: [Event.EventReward.Reward]) {
        for reward in rewards {
            switch reward.type {
            case .coins:
                PlayerStats.shared.addCoins(reward.amount)
            case .gems:
                PlayerStats.shared.addGems(reward.amount)
            case .character:
                if let id = reward.id {
                    CharacterManager.shared.unlockCharacter(id)
                }
            case .outfit, .gunSkin, .emote, .effect:
                if let id = reward.id {
                    CustomizationManager.shared.unlockItem(
                        id,
                        type: .init(rawValue: reward.type.rawValue)!
                    )
                }
            case .title:
                if let id = reward.id {
                    PlayerStats.shared.addTitle(id)
                }
            case .badge:
                if let id = reward.id {
                    PlayerStats.shared.addBadge(id)
                }
            case .special:
                handleSpecialReward(reward)
            }
        }
    }
    
    private func handleSpecialReward(_ reward: Event.EventReward.Reward) {
        // Handle special reward types
    }
    
    // MARK: - Notifications
    private func scheduleEventNotifications(_ events: [Event]) {
        for event in events {
            // Start notification
            if event.startDate > Date() {
                notificationManager.scheduleNotification(
                    title: "New Event Starting!",
                    body: "\(event.name) is about to begin!",
                    date: event.startDate.addingTimeInterval(-300) // 5 minutes before
                )
            }
            
            // End notification
            notificationManager.scheduleNotification(
                title: "Event Ending Soon!",
                body: "\(event.name) is ending soon! Complete your objectives!",
                date: event.endDate.addingTimeInterval(-3600) // 1 hour before
            )
        }
    }
    
    // MARK: - Queries
    func getActiveEvents(type: Event.EventType? = nil) -> [Event] {
        let now = Date()
        return activeEvents.filter {
            $0.startDate <= now &&
            $0.endDate > now &&
            (type == nil || $0.type == type)
        }
    }
    
    func getEvent(_ eventId: String) -> Event? {
        return activeEvents.first { $0.id == eventId }
    }
    
    func getEventProgress(_ eventId: String) -> EventProgress? {
        return eventProgress[eventId]
    }
    
    func getNextTier(for eventId: String) -> Event.EventReward? {
        guard let event = getEvent(eventId),
              let progress = eventProgress[eventId] else {
            return nil
        }
        
        return event.rewards.first {
            !progress.completedTiers.contains($0.tier)
        }
    }
    
    func isEventActive(_ eventId: String) -> Bool {
        guard let event = getEvent(eventId) else { return false }
        let now = Date()
        return event.startDate <= now && event.endDate > now
    }
    
    // MARK: - Cleanup
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        activeEvents.removeAll()
        eventProgress.removeAll()
    }
}

// MARK: - Convenience Methods
extension EventManager {
    func getUpcomingEvents() -> [Event] {
        let now = Date()
        return activeEvents.filter { $0.startDate > now }
    }
    
    func getEventTimeRemaining(_ eventId: String) -> TimeInterval? {
        guard let event = getEvent(eventId) else { return nil }
        return event.endDate.timeIntervalSince(Date())
    }
    
    func getEventCompletionPercentage(_ eventId: String) -> Double {
        guard let event = getEvent(eventId),
              let progress = eventProgress[eventId] else {
            return 0
        }
        
        let totalTiers = event.rewards.count
        let completedTiers = progress.completedTiers.count
        return Double(completedTiers) / Double(totalTiers)
    }
}

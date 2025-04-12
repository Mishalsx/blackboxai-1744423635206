import Foundation

final class BattlePassManager {
    // MARK: - Properties
    static let shared = BattlePassManager()
    
    private let analytics = AnalyticsManager.shared
    private let networkManager = NetworkManager.shared
    private let notificationManager = NotificationManager.shared
    
    private var currentPass: BattlePass?
    private var progress: BattlePassProgress?
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct BattlePass: Codable {
        let id: String
        let name: String
        let season: Int
        let startDate: Date
        let endDate: Date
        let tiers: [Tier]
        let premiumPrice: Int
        let features: [Feature]
        
        struct Tier: Codable {
            let level: Int
            let experienceRequired: Int
            let freeReward: Reward?
            let premiumReward: Reward
            let isBonus: Bool
            
            var totalExperienceRequired: Int {
                return level * experienceRequired
            }
        }
        
        struct Reward: Codable {
            let id: String
            let type: RewardType
            let amount: Int
            let rarity: Rarity
            
            enum RewardType: String, Codable {
                case coins
                case gems
                case character
                case outfit
                case gunSkin
                case emote
                case banner
                case title
                case powerup
                case booster
                case special
                
                var description: String {
                    switch self {
                    case .coins: return "Coins"
                    case .gems: return "Gems"
                    case .character: return "Character"
                    case .outfit: return "Outfit"
                    case .gunSkin: return "Gun Skin"
                    case .emote: return "Emote"
                    case .banner: return "Banner"
                    case .title: return "Title"
                    case .powerup: return "Power-up"
                    case .booster: return "XP Booster"
                    case .special: return "Special Reward"
                    }
                }
            }
            
            enum Rarity: String, Codable {
                case common
                case rare
                case epic
                case legendary
                case exclusive
            }
        }
        
        struct Feature: Codable {
            let type: FeatureType
            let description: String
            
            enum FeatureType: String, Codable {
                case xpBoost
                case challengeSlot
                case exclusiveQuests
                case specialEffects
                case nameColor
                case customLoadout
            }
        }
    }
    
    struct BattlePassProgress: Codable {
        let passId: String
        let isPremium: Bool
        let currentTier: Int
        let experience: Int
        let claimedRewards: Set<String>
        let boosterEndTime: Date?
        let completedChallenges: Set<String>
        
        var hasActiveBooster: Bool {
            guard let endTime = boosterEndTime else { return false }
            return Date() < endTime
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupRefreshTimer()
        loadCurrentPass()
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 3600, // 1 hour
            repeats: true
        ) { [weak self] _ in
            self?.checkPassExpiration()
        }
    }
    
    // MARK: - Battle Pass Management
    private func loadCurrentPass() {
        Task {
            do {
                let response: BattlePassResponse = try await networkManager.request(
                    endpoint: "battlepass/current"
                )
                
                currentPass = response.battlePass
                progress = response.progress
                
                if let pass = currentPass {
                    scheduleEndNotifications(for: pass)
                }
                
                analytics.trackEvent(.featureUsed(name: "battlepass_loaded"))
            } catch {
                print("Failed to load battle pass: \(error.localizedDescription)")
            }
        }
    }
    
    func purchasePremium(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let pass = currentPass,
              let progress = progress,
              !progress.isPremium else {
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }
        
        Task {
            do {
                try await networkManager.request(
                    endpoint: "battlepass/purchase",
                    method: .post,
                    parameters: ["pass_id": pass.id]
                )
                
                self.progress?.isPremium = true
                
                // Grant premium rewards for already completed tiers
                for tier in pass.tiers where tier.level <= progress.currentTier {
                    grantReward(tier.premiumReward)
                }
                
                analytics.trackEvent(.purchase(
                    item: "premium_battlepass",
                    price: pass.premiumPrice
                ))
                
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func addExperience(_ amount: Int) {
        guard var currentProgress = progress,
              let pass = currentPass else { return }
        
        let boostedAmount = currentProgress.hasActiveBooster ? amount * 2 : amount
        currentProgress.experience += boostedAmount
        
        // Check for tier ups
        while let nextTier = pass.tiers.first(where: { $0.level == currentProgress.currentTier + 1 }),
              currentProgress.experience >= nextTier.totalExperienceRequired {
            currentProgress.currentTier += 1
            handleTierUp(nextTier)
        }
        
        progress = currentProgress
        syncProgress()
    }
    
    private func handleTierUp(_ tier: BattlePass.Tier) {
        // Grant free reward
        if let freeReward = tier.freeReward {
            grantReward(freeReward)
        }
        
        // Grant premium reward if applicable
        if progress?.isPremium == true {
            grantReward(tier.premiumReward)
        }
        
        analytics.trackEvent(.featureUsed(
            name: "battlepass_tier_up",
            properties: ["tier": tier.level]
        ))
        
        // Show notification
        notificationManager.scheduleNotification(
            title: "Tier Up!",
            body: "You've reached Battle Pass tier \(tier.level)!",
            delay: 0
        )
    }
    
    private func grantReward(_ reward: BattlePass.Reward) {
        guard var currentProgress = progress else { return }
        
        // Check if already claimed
        guard !currentProgress.claimedRewards.contains(reward.id) else { return }
        
        // Grant reward based on type
        switch reward.type {
        case .coins:
            PlayerStats.shared.addCoins(reward.amount)
        case .gems:
            PlayerStats.shared.addGems(reward.amount)
        case .character:
            CharacterManager.shared.unlockCharacter(reward.id)
        case .outfit, .gunSkin, .emote, .banner:
            CustomizationManager.shared.unlockItem(reward.id, type: .init(rawValue: reward.type.rawValue)!)
        case .title:
            PlayerStats.shared.addTitle(reward.id)
        case .powerup:
            PowerupManager.shared.addPowerup(reward.id)
        case .booster:
            activateBooster(duration: TimeInterval(reward.amount))
        case .special:
            handleSpecialReward(reward)
        }
        
        currentProgress.claimedRewards.insert(reward.id)
        progress = currentProgress
        syncProgress()
    }
    
    private func activateBooster(duration: TimeInterval) {
        guard var currentProgress = progress else { return }
        
        let endTime = Date().addingTimeInterval(duration)
        currentProgress.boosterEndTime = endTime
        progress = currentProgress
        
        analytics.trackEvent(.featureUsed(name: "xp_booster_activated"))
    }
    
    private func handleSpecialReward(_ reward: BattlePass.Reward) {
        // Handle special rewards
    }
    
    // MARK: - Progress Syncing
    private func syncProgress() {
        guard let currentProgress = progress else { return }
        
        Task {
            do {
                try await networkManager.request(
                    endpoint: "battlepass/progress",
                    method: .post,
                    parameters: ["progress": currentProgress]
                )
            } catch {
                print("Failed to sync progress: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Notifications
    private func scheduleEndNotifications(for pass: BattlePass) {
        // 1 week before
        notificationManager.scheduleNotification(
            title: "Battle Pass Ending Soon",
            body: "Complete your Battle Pass before it ends in 1 week!",
            date: pass.endDate.addingTimeInterval(-604800)
        )
        
        // 1 day before
        notificationManager.scheduleNotification(
            title: "Last Day of Battle Pass",
            body: "Don't miss out on your remaining Battle Pass rewards!",
            date: pass.endDate.addingTimeInterval(-86400)
        )
    }
    
    private func checkPassExpiration() {
        guard let pass = currentPass,
              Date() >= pass.endDate else { return }
        
        loadCurrentPass()
    }
    
    // MARK: - Queries
    func getCurrentPass() -> BattlePass? {
        return currentPass
    }
    
    func getProgress() -> BattlePassProgress? {
        return progress
    }
    
    func getCurrentTier() -> BattlePass.Tier? {
        guard let pass = currentPass,
              let progress = progress else { return nil }
        
        return pass.tiers.first { $0.level == progress.currentTier }
    }
    
    func getNextTier() -> BattlePass.Tier? {
        guard let pass = currentPass,
              let progress = progress else { return nil }
        
        return pass.tiers.first { $0.level == progress.currentTier + 1 }
    }
    
    func getProgressToNextTier() -> Double {
        guard let pass = currentPass,
              let progress = progress,
              let nextTier = getNextTier() else { return 0 }
        
        let currentExp = Double(progress.experience)
        let required = Double(nextTier.totalExperienceRequired)
        
        return min(1.0, currentExp / required)
    }
    
    func isRewardClaimed(_ rewardId: String) -> Bool {
        return progress?.claimedRewards.contains(rewardId) ?? false
    }
    
    // MARK: - Cleanup
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        currentPass = nil
        progress = nil
    }
}

// MARK: - Network Models
private struct BattlePassResponse: Codable {
    let battlePass: BattlePassManager.BattlePass
    let progress: BattlePassManager.BattlePassProgress
}

// MARK: - Convenience Methods
extension BattlePassManager {
    func getRemainingTime() -> TimeInterval? {
        guard let pass = currentPass else { return nil }
        return pass.endDate.timeIntervalSince(Date())
    }
    
    func getUnclaimedRewards() -> [BattlePass.Reward] {
        guard let pass = currentPass,
              let progress = progress else { return [] }
        
        var rewards: [BattlePass.Reward] = []
        
        for tier in pass.tiers where tier.level <= progress.currentTier {
            if let freeReward = tier.freeReward,
               !progress.claimedRewards.contains(freeReward.id) {
                rewards.append(freeReward)
            }
            
            if progress.isPremium,
               !progress.claimedRewards.contains(tier.premiumReward.id) {
                rewards.append(tier.premiumReward)
            }
        }
        
        return rewards
    }
    
    func getCompletionPercentage() -> Double {
        guard let pass = currentPass,
              let progress = progress else { return 0 }
        
        return Double(progress.currentTier) / Double(pass.tiers.count)
    }
}

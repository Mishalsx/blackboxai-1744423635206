import Foundation

final class ReferralManager {
    // MARK: - Properties
    static let shared = ReferralManager()
    
    private let networkManager = NetworkManager.shared
    private let analytics = AnalyticsManager.shared
    private let playerStats = PlayerStats.shared
    
    private var referralCode: String?
    private var referralHistory: [ReferralRecord] = []
    private var referralRewards: [ReferralReward] = []
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct ReferralRecord: Codable {
        let id: String
        let referrerId: String
        let referredId: String
        let code: String
        let status: Status
        let milestones: [Milestone]
        let createdDate: Date
        
        enum Status: String, Codable {
            case pending
            case active
            case completed
            case expired
            
            var isValid: Bool {
                return self == .active || self == .completed
            }
        }
        
        struct Milestone: Codable {
            let type: MilestoneType
            let requirement: Int
            let progress: Int
            let completed: Bool
            let rewardClaimed: Bool
            
            enum MilestoneType: String, Codable {
                case level
                case wins
                case battlePass
                case purchase
                case playtime
                
                var description: String {
                    switch self {
                    case .level: return "Reach Level"
                    case .wins: return "Win Matches"
                    case .battlePass: return "Battle Pass Tier"
                    case .purchase: return "Make Purchase"
                    case .playtime: return "Play Time (hours)"
                    }
                }
            }
        }
    }
    
    struct ReferralReward: Codable {
        let id: String
        let type: RewardType
        let amount: Int
        let tier: Int
        let forReferrer: Bool
        
        enum RewardType: String, Codable {
            case coins
            case gems
            case character
            case outfit
            case booster
            case special
            
            var description: String {
                switch self {
                case .coins: return "Coins"
                case .gems: return "Gems"
                case .character: return "Character"
                case .outfit: return "Outfit"
                case .booster: return "XP Booster"
                case .special: return "Special Reward"
                }
            }
        }
    }
    
    struct ReferralStats: Codable {
        let totalReferrals: Int
        let activeReferrals: Int
        let completedReferrals: Int
        let totalRewardsEarned: Int
        let currentTier: Int
        let nextTierProgress: Double
    }
    
    // MARK: - Initialization
    private init() {
        setupRefreshTimer()
        loadReferralData()
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 3600, // 1 hour
            repeats: true
        ) { [weak self] _ in
            self?.refreshReferralData()
        }
    }
    
    // MARK: - Referral Management
    func generateReferralCode(completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let response: ReferralCodeResponse = try await networkManager.request(
                    endpoint: "referrals/code/generate",
                    method: .post
                )
                
                referralCode = response.code
                
                analytics.trackEvent(.featureUsed(name: "referral_code_generated"))
                completion(.success(response.code))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func submitReferralCode(
        _ code: String,
        completion: @escaping (Result<ReferralRecord, Error>) -> Void
    ) {
        Task {
            do {
                let record: ReferralRecord = try await networkManager.request(
                    endpoint: "referrals/submit",
                    method: .post,
                    parameters: ["code": code]
                )
                
                referralHistory.append(record)
                
                analytics.trackEvent(.featureUsed(name: "referral_code_submitted"))
                completion(.success(record))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func updateMilestoneProgress(
        _ milestone: ReferralRecord.Milestone,
        forReferral referralId: String,
        progress: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await networkManager.request(
                    endpoint: "referrals/\(referralId)/milestones/\(milestone.type.rawValue)",
                    method: .post,
                    parameters: ["progress": progress]
                )
                
                // Update local state
                if let index = referralHistory.firstIndex(where: { $0.id == referralId }),
                   let milestoneIndex = referralHistory[index].milestones.firstIndex(where: { $0.type == milestone.type }) {
                    var updatedRecord = referralHistory[index]
                    var updatedMilestone = updatedRecord.milestones[milestoneIndex]
                    updatedMilestone.progress = progress
                    updatedMilestone.completed = progress >= milestone.requirement
                    updatedRecord.milestones[milestoneIndex] = updatedMilestone
                    referralHistory[index] = updatedRecord
                }
                
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func claimMilestoneReward(
        _ milestone: ReferralRecord.Milestone,
        forReferral referralId: String,
        completion: @escaping (Result<ReferralReward, Error>) -> Void
    ) {
        guard milestone.completed && !milestone.rewardClaimed else {
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }
        
        Task {
            do {
                let reward: ReferralReward = try await networkManager.request(
                    endpoint: "referrals/\(referralId)/rewards/claim",
                    method: .post,
                    parameters: ["milestone_type": milestone.type.rawValue]
                )
                
                // Grant reward
                grantReward(reward)
                
                // Update local state
                if let index = referralHistory.firstIndex(where: { $0.id == referralId }),
                   let milestoneIndex = referralHistory[index].milestones.firstIndex(where: { $0.type == milestone.type }) {
                    var updatedRecord = referralHistory[index]
                    var updatedMilestone = updatedRecord.milestones[milestoneIndex]
                    updatedMilestone.rewardClaimed = true
                    updatedRecord.milestones[milestoneIndex] = updatedMilestone
                    referralHistory[index] = updatedRecord
                }
                
                analytics.trackEvent(.featureUsed(name: "referral_reward_claimed"))
                completion(.success(reward))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Data Management
    private func loadReferralData() {
        Task {
            do {
                // Load referral code
                if let response: ReferralCodeResponse = try? await networkManager.request(
                    endpoint: "referrals/code"
                ) {
                    referralCode = response.code
                }
                
                // Load referral history
                let history: [ReferralRecord] = try await networkManager.request(
                    endpoint: "referrals/history"
                )
                referralHistory = history
                
                // Load rewards
                let rewards: [ReferralReward] = try await networkManager.request(
                    endpoint: "referrals/rewards"
                )
                referralRewards = rewards
            } catch {
                print("Failed to load referral data: \(error.localizedDescription)")
            }
        }
    }
    
    private func refreshReferralData() {
        loadReferralData()
    }
    
    // MARK: - Reward Handling
    private func grantReward(_ reward: ReferralReward) {
        switch reward.type {
        case .coins:
            playerStats.addCoins(reward.amount)
        case .gems:
            playerStats.addGems(reward.amount)
        case .character:
            CharacterManager.shared.unlockCharacter(String(reward.amount))
        case .outfit:
            CustomizationManager.shared.unlockItem(
                String(reward.amount),
                type: .outfit
            )
        case .booster:
            // Handle booster activation
            break
        case .special:
            // Handle special rewards
            break
        }
    }
    
    // MARK: - Queries
    func getReferralCode() -> String? {
        return referralCode
    }
    
    func getReferralHistory() -> [ReferralRecord] {
        return referralHistory
    }
    
    func getActiveReferrals() -> [ReferralRecord] {
        return referralHistory.filter { $0.status.isValid }
    }
    
    func getReferralStats() -> ReferralStats {
        let active = referralHistory.filter { $0.status == .active }.count
        let completed = referralHistory.filter { $0.status == .completed }.count
        let totalRewards = referralRewards.count
        
        return ReferralStats(
            totalReferrals: referralHistory.count,
            activeReferrals: active,
            completedReferrals: completed,
            totalRewardsEarned: totalRewards,
            currentTier: calculateCurrentTier(),
            nextTierProgress: calculateNextTierProgress()
        )
    }
    
    private func calculateCurrentTier() -> Int {
        let completed = referralHistory.filter { $0.status == .completed }.count
        return completed / 5 // 5 referrals per tier
    }
    
    private func calculateNextTierProgress() -> Double {
        let completed = referralHistory.filter { $0.status == .completed }.count
        let currentTier = completed / 5
        let progress = completed % 5
        return Double(progress) / 5.0
    }
    
    // MARK: - Cleanup
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        referralCode = nil
        referralHistory.removeAll()
        referralRewards.removeAll()
    }
}

// MARK: - Network Models
private struct ReferralCodeResponse: Codable {
    let code: String
}

// MARK: - Convenience Methods
extension ReferralManager {
    func getPendingMilestones() -> [(ReferralRecord, ReferralRecord.Milestone)] {
        var pending: [(ReferralRecord, ReferralRecord.Milestone)] = []
        
        for record in referralHistory where record.status.isValid {
            for milestone in record.milestones where !milestone.completed {
                pending.append((record, milestone))
            }
        }
        
        return pending
    }
    
    func getUnclaimedRewards() -> [(ReferralRecord, ReferralRecord.Milestone)] {
        var unclaimed: [(ReferralRecord, ReferralRecord.Milestone)] = []
        
        for record in referralHistory where record.status.isValid {
            for milestone in record.milestones where milestone.completed && !milestone.rewardClaimed {
                unclaimed.append((record, milestone))
            }
        }
        
        return unclaimed
    }
    
    func getReferralLink() -> String {
        guard let code = referralCode else { return "" }
        return "https://highnoons.com/refer?code=\(code)"
    }
}

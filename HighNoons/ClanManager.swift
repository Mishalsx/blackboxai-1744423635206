import Foundation

final class ClanManager {
    // MARK: - Properties
    static let shared = ClanManager()
    
    private let networkManager = NetworkManager.shared
    private let analytics = AnalyticsManager.shared
    private let chatManager = ChatManager.shared
    
    private var currentClan: Clan?
    private var clanMembers: [ClanMember] = []
    private var clanWars: [ClanWar] = []
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct Clan: Codable {
        let id: String
        let name: String
        let tag: String
        let description: String
        let level: Int
        let experience: Int
        let requiredTrophies: Int
        let type: ClanType
        let region: String
        let createdDate: Date
        let badge: Badge
        let stats: Stats
        
        enum ClanType: String, Codable {
            case open
            case inviteOnly
            case closed
        }
        
        struct Badge: Codable {
            let id: String
            let name: String
            let imageUrl: String
        }
        
        struct Stats: Codable {
            let totalWins: Int
            let warWins: Int
            let trophies: Int
            let memberCount: Int
            let weeklyDonations: Int
            let ranking: Int?
        }
    }
    
    struct ClanMember: Codable {
        let userId: String
        let username: String
        let role: Role
        let trophies: Int
        let donations: Int
        let joinDate: Date
        let lastActive: Date
        let weeklyContribution: Int
        
        enum Role: String, Codable {
            case leader
            case coLeader
            case elder
            case member
            
            var canInvite: Bool {
                switch self {
                case .leader, .coLeader, .elder: return true
                case .member: return false
                }
            }
            
            var canPromote: Bool {
                switch self {
                case .leader, .coLeader: return true
                case .elder, .member: return false
                }
            }
        }
    }
    
    struct ClanWar: Codable {
        let id: String
        let opponent: Clan
        let startDate: Date
        let endDate: Date
        let status: Status
        let score: Score
        let rewards: [Reward]
        
        enum Status: String, Codable {
            case preparation
            case inProgress
            case completed
            case cancelled
        }
        
        struct Score: Codable {
            let ourScore: Int
            let opponentScore: Int
            var isWinning: Bool {
                return ourScore > opponentScore
            }
        }
        
        struct Reward: Codable {
            let type: RewardType
            let amount: Int
            
            enum RewardType: String, Codable {
                case coins
                case experience
                case clanPoints
                case specialBadge
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupRefreshTimer()
        loadCurrentClan()
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 300, // 5 minutes
            repeats: true
        ) { [weak self] _ in
            self?.refreshClanData()
        }
    }
    
    // MARK: - Clan Management
    func createClan(
        name: String,
        tag: String,
        description: String,
        type: Clan.ClanType,
        region: String,
        completion: @escaping (Result<Clan, Error>) -> Void
    ) {
        Task {
            do {
                let clan: Clan = try await networkManager.request(
                    endpoint: "clans/create",
                    method: .post,
                    parameters: [
                        "name": name,
                        "tag": tag,
                        "description": description,
                        "type": type.rawValue,
                        "region": region
                    ]
                )
                
                currentClan = clan
                analytics.trackEvent(.featureUsed(name: "clan_created"))
                completion(.success(clan))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func joinClan(
        _ clanId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await networkManager.request(
                    endpoint: "clans/\(clanId)/join",
                    method: .post
                )
                
                loadCurrentClan()
                analytics.trackEvent(.featureUsed(name: "clan_joined"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func leaveClan(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let clanId = currentClan?.id else {
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }
        
        Task {
            do {
                try await networkManager.request(
                    endpoint: "clans/\(clanId)/leave",
                    method: .post
                )
                
                currentClan = nil
                clanMembers.removeAll()
                analytics.trackEvent(.featureUsed(name: "clan_left"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Member Management
    func inviteMember(
        userId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let clanId = currentClan?.id else {
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }
        
        Task {
            do {
                try await networkManager.request(
                    endpoint: "clans/\(clanId)/invite",
                    method: .post,
                    parameters: ["user_id": userId]
                )
                
                analytics.trackEvent(.featureUsed(name: "clan_invite_sent"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func promoteMember(
        userId: String,
        toRole role: ClanMember.Role,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let clanId = currentClan?.id else {
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }
        
        Task {
            do {
                try await networkManager.request(
                    endpoint: "clans/\(clanId)/members/\(userId)/promote",
                    method: .post,
                    parameters: ["role": role.rawValue]
                )
                
                refreshClanData()
                analytics.trackEvent(.featureUsed(name: "clan_member_promoted"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func kickMember(
        userId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let clanId = currentClan?.id else {
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }
        
        Task {
            do {
                try await networkManager.request(
                    endpoint: "clans/\(clanId)/members/\(userId)/kick",
                    method: .post
                )
                
                refreshClanData()
                analytics.trackEvent(.featureUsed(name: "clan_member_kicked"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Clan Wars
    func startClanWar(completion: @escaping (Result<ClanWar, Error>) -> Void) {
        guard let clanId = currentClan?.id else {
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }
        
        Task {
            do {
                let war: ClanWar = try await networkManager.request(
                    endpoint: "clans/\(clanId)/wars/start",
                    method: .post
                )
                
                clanWars.append(war)
                analytics.trackEvent(.featureUsed(name: "clan_war_started"))
                completion(.success(war))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func submitWarResult(
        warId: String,
        score: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let clanId = currentClan?.id else {
            completion(.failure(NSError(domain: "", code: -1)))
            return
        }
        
        Task {
            do {
                try await networkManager.request(
                    endpoint: "clans/\(clanId)/wars/\(warId)/submit",
                    method: .post,
                    parameters: ["score": score]
                )
                
                refreshClanData()
                analytics.trackEvent(.featureUsed(name: "clan_war_result_submitted"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadCurrentClan() {
        Task {
            do {
                let response: ClanResponse = try await networkManager.request(
                    endpoint: "clans/current"
                )
                
                currentClan = response.clan
                clanMembers = response.members
                clanWars = response.wars
                
                // Join clan chat channel
                if let clanId = currentClan?.id {
                    chatManager.joinChannel("clan_\(clanId)") { message in
                        // Handle clan chat messages
                    }
                }
            } catch {
                print("Failed to load clan data: \(error.localizedDescription)")
            }
        }
    }
    
    private func refreshClanData() {
        loadCurrentClan()
    }
    
    // MARK: - Queries
    func getCurrentClan() -> Clan? {
        return currentClan
    }
    
    func getClanMembers() -> [ClanMember] {
        return clanMembers
    }
    
    func getActiveWar() -> ClanWar? {
        return clanWars.first { $0.status == .inProgress }
    }
    
    func getMemberRole(_ userId: String) -> ClanMember.Role? {
        return clanMembers.first { $0.userId == userId }?.role
    }
    
    // MARK: - Cleanup
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        
        if let clanId = currentClan?.id {
            chatManager.leaveChannel("clan_\(clanId)")
        }
        
        currentClan = nil
        clanMembers.removeAll()
        clanWars.removeAll()
    }
}

// MARK: - Network Models
private struct ClanResponse: Codable {
    let clan: ClanManager.Clan
    let members: [ClanManager.ClanMember]
    let wars: [ClanManager.ClanWar]
}

// MARK: - Convenience Methods
extension ClanManager {
    func getOnlineMembers() -> [ClanMember] {
        return clanMembers.filter {
            Date().timeIntervalSince($0.lastActive) < 300 // 5 minutes
        }
    }
    
    func getTopContributors() -> [ClanMember] {
        return clanMembers.sorted { $0.weeklyContribution > $1.weeklyContribution }
    }
    
    func getClanWarHistory() -> [ClanWar] {
        return clanWars.filter { $0.status == .completed }
            .sorted { $0.endDate > $1.endDate }
    }
}

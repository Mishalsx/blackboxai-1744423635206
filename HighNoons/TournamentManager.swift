import Foundation

final class TournamentManager {
    // MARK: - Properties
    static let shared = TournamentManager()
    
    private let networkManager = NetworkManager.shared
    private let analytics = AnalyticsManager.shared
    private let notificationManager = NotificationManager.shared
    
    private var activeTournaments: [Tournament] = []
    private var registeredTournaments: Set<String> = []
    private var tournamentMatches: [String: [TournamentMatch]] = [:]
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct Tournament: Codable {
        let id: String
        let name: String
        let description: String
        let type: TournamentType
        let status: Status
        let startDate: Date
        let endDate: Date
        let registrationEndDate: Date
        let playerCount: Int
        let maxPlayers: Int
        let entryFee: EntryFee
        let rewards: [Reward]
        let rules: Rules
        let brackets: [Bracket]
        
        enum TournamentType: String, Codable {
            case knockout
            case roundRobin
            case swiss
            case ladder
            case custom
        }
        
        enum Status: String, Codable {
            case upcoming
            case registration
            case inProgress
            case completed
            case cancelled
            
            var canRegister: Bool {
                return self == .upcoming || self == .registration
            }
        }
        
        struct EntryFee: Codable {
            let type: FeeType
            let amount: Int
            
            enum FeeType: String, Codable {
                case free
                case coins
                case tickets
                case special
            }
        }
        
        struct Reward: Codable {
            let rank: RankRange
            let rewards: [RewardItem]
            
            struct RankRange: Codable {
                let min: Int
                let max: Int
            }
            
            enum RewardItem: Codable {
                case coins(Int)
                case character(String)
                case title(String)
                case badge(String)
                case ticket(String)
                case special(String)
                
                var description: String {
                    switch self {
                    case .coins(let amount): return "\(amount) Coins"
                    case .character(let name): return "Character: \(name)"
                    case .title(let name): return "Title: \(name)"
                    case .badge(let name): return "Badge: \(name)"
                    case .ticket(let name): return "Ticket: \(name)"
                    case .special(let desc): return desc
                    }
                }
            }
        }
        
        struct Rules: Codable {
            let matchFormat: MatchFormat
            let scoreSystem: ScoreSystem
            let restrictions: [Restriction]
            
            enum MatchFormat: String, Codable {
                case bestOf1
                case bestOf3
                case bestOf5
                case custom
            }
            
            enum ScoreSystem: String, Codable {
                case standard
                case timeBonus
                case comboMultiplier
                case custom
            }
            
            enum Restriction: String, Codable {
                case levelMin(Int)
                case characterLocked
                case powerupsDisabled
                case customRules
            }
        }
        
        struct Bracket: Codable {
            let round: Int
            let matches: [TournamentMatch]
        }
    }
    
    struct TournamentMatch: Codable {
        let id: String
        let tournamentId: String
        let round: Int
        let player1: Player
        let player2: Player
        let status: Status
        let scheduledTime: Date?
        let result: MatchResult?
        
        struct Player: Codable {
            let userId: String
            let username: String
            let seed: Int
            let character: String?
        }
        
        enum Status: String, Codable {
            case scheduled
            case inProgress
            case completed
            case forfeited
        }
        
        struct MatchResult: Codable {
            let winnerId: String
            let score: Score
            let stats: Stats
            
            struct Score: Codable {
                let player1: Int
                let player2: Int
            }
            
            struct Stats: Codable {
                let duration: TimeInterval
                let reactionTimes: [Double]
                let accuracy: Double
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupRefreshTimer()
        loadActiveTournaments()
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 300, // 5 minutes
            repeats: true
        ) { [weak self] _ in
            self?.refreshTournaments()
        }
    }
    
    // MARK: - Tournament Management
    func registerForTournament(
        _ tournamentId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await networkManager.request(
                    endpoint: "tournaments/\(tournamentId)/register",
                    method: .post
                )
                
                registeredTournaments.insert(tournamentId)
                
                // Schedule reminder
                if let tournament = activeTournaments.first(where: { $0.id == tournamentId }) {
                    scheduleTournamentReminder(tournament)
                }
                
                analytics.trackEvent(.featureUsed(name: "tournament_registration"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func unregisterFromTournament(
        _ tournamentId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await networkManager.request(
                    endpoint: "tournaments/\(tournamentId)/unregister",
                    method: .post
                )
                
                registeredTournaments.remove(tournamentId)
                analytics.trackEvent(.featureUsed(name: "tournament_unregistration"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func submitMatchResult(
        matchId: String,
        result: TournamentMatch.MatchResult,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await networkManager.request(
                    endpoint: "tournaments/matches/\(matchId)/result",
                    method: .post,
                    parameters: ["result": result]
                )
                
                refreshTournaments()
                analytics.trackEvent(.featureUsed(name: "tournament_match_result"))
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadActiveTournaments() {
        Task {
            do {
                let tournaments: [Tournament] = try await networkManager.request(
                    endpoint: "tournaments/active"
                )
                
                activeTournaments = tournaments
                
                // Load matches for registered tournaments
                for tournamentId in registeredTournaments {
                    try await loadTournamentMatches(tournamentId)
                }
            } catch {
                print("Failed to load tournaments: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadTournamentMatches(_ tournamentId: String) async throws {
        let matches: [TournamentMatch] = try await networkManager.request(
            endpoint: "tournaments/\(tournamentId)/matches"
        )
        tournamentMatches[tournamentId] = matches
    }
    
    private func refreshTournaments() {
        loadActiveTournaments()
    }
    
    // MARK: - Notifications
    private func scheduleTournamentReminder(_ tournament: Tournament) {
        // Reminder 1 hour before
        notificationManager.scheduleNotification(
            title: "Tournament Starting Soon",
            body: "\(tournament.name) starts in 1 hour!",
            date: tournament.startDate.addingTimeInterval(-3600)
        )
        
        // Reminder 10 minutes before
        notificationManager.scheduleNotification(
            title: "Tournament Starting",
            body: "\(tournament.name) starts in 10 minutes!",
            date: tournament.startDate.addingTimeInterval(-600)
        )
    }
    
    // MARK: - Queries
    func getActiveTournaments() -> [Tournament] {
        return activeTournaments.filter { $0.status != .completed }
    }
    
    func getRegisteredTournaments() -> [Tournament] {
        return activeTournaments.filter { registeredTournaments.contains($0.id) }
    }
    
    func getTournamentMatches(_ tournamentId: String) -> [TournamentMatch] {
        return tournamentMatches[tournamentId] ?? []
    }
    
    func getUpcomingMatch() -> TournamentMatch? {
        for tournamentId in registeredTournaments {
            if let match = tournamentMatches[tournamentId]?.first(where: {
                $0.status == .scheduled &&
                ($0.player1.userId == PlayerStats.shared.userId ||
                 $0.player2.userId == PlayerStats.shared.userId)
            }) {
                return match
            }
        }
        return nil
    }
    
    func isRegistered(for tournamentId: String) -> Bool {
        return registeredTournaments.contains(tournamentId)
    }
    
    // MARK: - Cleanup
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        activeTournaments.removeAll()
        registeredTournaments.removeAll()
        tournamentMatches.removeAll()
    }
}

// MARK: - Convenience Methods
extension TournamentManager {
    func getAvailableTournaments() -> [Tournament] {
        return activeTournaments.filter { $0.status.canRegister }
    }
    
    func getCurrentTournaments() -> [Tournament] {
        return activeTournaments.filter { $0.status == .inProgress }
    }
    
    func getTournamentHistory() -> [Tournament] {
        return activeTournaments.filter { $0.status == .completed }
    }
    
    func getPlayerStats(tournamentId: String) -> TournamentPlayerStats? {
        guard let matches = tournamentMatches[tournamentId] else { return nil }
        
        let playerMatches = matches.filter {
            $0.player1.userId == PlayerStats.shared.userId ||
            $0.player2.userId == PlayerStats.shared.userId
        }
        
        let wins = playerMatches.filter {
            $0.result?.winnerId == PlayerStats.shared.userId
        }.count
        
        let losses = playerMatches.filter {
            $0.status == .completed && $0.result?.winnerId != PlayerStats.shared.userId
        }.count
        
        return TournamentPlayerStats(
            matches: playerMatches.count,
            wins: wins,
            losses: losses
        )
    }
}

// MARK: - Supporting Types
struct TournamentPlayerStats {
    let matches: Int
    let wins: Int
    let losses: Int
    
    var winRate: Double {
        guard matches > 0 else { return 0 }
        return Double(wins) / Double(matches)
    }
}

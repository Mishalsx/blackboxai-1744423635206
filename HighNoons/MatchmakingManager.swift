import GameKit
import Foundation

final class MatchmakingManager: NSObject {
    // MARK: - Types
    enum MatchState {
        case none
        case searching
        case connecting
        case connected
        case failed(Error)
    }
    
    enum MatchError: Error {
        case notAuthenticated
        case matchmakingCancelled
        case connectionFailed
        case invalidGameState
        case peerDisconnected
        case networkTimeout
    }
    
    // MARK: - Properties
    static let shared = MatchmakingManager()
    
    private let gameManager = GameManager.shared
    private var match: GKMatch?
    private var inviteHandler: ((Bool, GKInvite?) -> Void)?
    private var matchStartHandler: ((Bool) -> Void)?
    
    private(set) var currentState: MatchState = .none {
        didSet {
            NotificationCenter.default.post(
                name: .matchStateDidChange,
                object: nil,
                userInfo: ["state": currentState]
            )
        }
    }
    
    // Game session data
    private var isPlayerReady = false
    private var isOpponentReady = false
    private var playerReactionTime: TimeInterval = 0
    private var opponentReactionTime: TimeInterval = 0
    
    // MARK: - Initialization
    private override init() {
        super.init()
        authenticatePlayer()
    }
    
    // MARK: - Authentication
    private func authenticatePlayer() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            if let viewController = viewController {
                // Present authentication view controller
                NotificationCenter.default.post(
                    name: .presentGameCenterAuth,
                    object: viewController
                )
            } else if let error = error {
                print("GameCenter authentication failed: \(error.localizedDescription)")
                self?.currentState = .failed(error)
            } else {
                print("GameCenter authentication successful")
            }
        }
    }
    
    // MARK: - Matchmaking
    func startMatchmaking() async throws {
        guard GKLocalPlayer.local.isAuthenticated else {
            throw MatchError.notAuthenticated
        }
        
        currentState = .searching
        
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.inviteMessage = "Join me for a quick-draw duel!"
        
        do {
            let match = try await GKMatchmaker.shared().match(for: request)
            self.match = match
            match.delegate = self
            currentState = .connected
        } catch {
            currentState = .failed(error)
            throw MatchError.matchmakingCancelled
        }
    }
    
    func cancelMatchmaking() {
        GKMatchmaker.shared().cancel()
        match?.disconnect()
        match = nil
        currentState = .none
    }
    
    // MARK: - Game Communication
    private func sendGameData(_ data: MatchData) {
        guard let match = match else { return }
        
        do {
            let encodedData = try JSONEncoder().encode(data)
            try match.sendData(
                toAllPlayers: encodedData,
                with: .reliable
            )
        } catch {
            print("Failed to send game data: \(error.localizedDescription)")
        }
    }
    
    func sendPlayerReady() {
        isPlayerReady = true
        sendGameData(.ready)
        checkBothPlayersReady()
    }
    
    func sendReactionTime(_ time: TimeInterval) {
        playerReactionTime = time
        sendGameData(.reactionTime(time))
        checkDuelComplete()
    }
    
    private func checkBothPlayersReady() {
        guard isPlayerReady && isOpponentReady else { return }
        startDuel()
    }
    
    private func startDuel() {
        gameManager.startDuel()
    }
    
    private func checkDuelComplete() {
        guard playerReactionTime > 0 && opponentReactionTime > 0 else { return }
        
        let didWin = playerReactionTime < opponentReactionTime
        NotificationCenter.default.post(
            name: .duelComplete,
            object: nil,
            userInfo: [
                "didWin": didWin,
                "playerTime": playerReactionTime,
                "opponentTime": opponentReactionTime
            ]
        )
    }
    
    // MARK: - Bot Mode
    func startBotMatch() {
        currentState = .connected
        
        // Simulate opponent ready after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.isOpponentReady = true
            self?.checkBothPlayersReady()
        }
    }
    
    private func simulateBotReactionTime() {
        // Bot reaction time between 0.2 and 0.8 seconds
        let botTime = TimeInterval.random(in: 0.2...0.8)
        opponentReactionTime = botTime
        checkDuelComplete()
    }
}

// MARK: - GKMatchDelegate
extension MatchmakingManager: GKMatchDelegate {
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        do {
            let matchData = try JSONDecoder().decode(MatchData.self, from: data)
            handleMatchData(matchData)
        } catch {
            print("Failed to decode match data: \(error.localizedDescription)")
        }
    }
    
    private func handleMatchData(_ data: MatchData) {
        switch data {
        case .ready:
            isOpponentReady = true
            checkBothPlayersReady()
        case .reactionTime(let time):
            opponentReactionTime = time
            checkDuelComplete()
        }
    }
    
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        switch state {
        case .connected:
            print("Player connected: \(player.displayName)")
        case .disconnected:
            handleDisconnection()
        default:
            break
        }
    }
    
    private func handleDisconnection() {
        currentState = .failed(MatchError.peerDisconnected)
        match = nil
        
        // Optionally switch to bot mode
        startBotMatch()
    }
}

// MARK: - Match Data
private enum MatchData: Codable {
    case ready
    case reactionTime(TimeInterval)
}

// MARK: - Notifications
extension Notification.Name {
    static let matchStateDidChange = Notification.Name("matchStateDidChange")
    static let presentGameCenterAuth = Notification.Name("presentGameCenterAuth")
    static let duelComplete = Notification.Name("duelComplete")
}

// MARK: - Convenience Extensions
extension MatchmakingManager {
    var isConnected: Bool {
        if case .connected = currentState {
            return true
        }
        return false
    }
    
    var isInMatch: Bool {
        match != nil
    }
}

import Foundation
import SpriteKit

final class ReplayManager {
    // MARK: - Properties
    static let shared = ReplayManager()
    
    private let analytics = AnalyticsManager.shared
    private let networkManager = NetworkManager.shared
    private let shareManager = ShareManager.shared
    
    private var currentRecording: ReplayRecording?
    private var cachedReplays: [Replay] = []
    private var isRecording = false
    private var recordingTimer: Timer?
    
    // MARK: - Types
    struct Replay: Codable {
        let id: String
        let timestamp: Date
        let duration: TimeInterval
        let players: [Player]
        let events: [ReplayEvent]
        let result: MatchResult
        let metadata: Metadata
        
        struct Player: Codable {
            let userId: String
            let username: String
            let character: String
            let customization: [String: String]
            let stats: Stats
            
            struct Stats: Codable {
                let reactionTime: Double
                let accuracy: Double
                let rank: Int
            }
        }
        
        struct MatchResult: Codable {
            let winnerId: String
            let winType: WinType
            let reactionTimes: [String: Double]
            
            enum WinType: String, Codable {
                case normal
                case perfect
                case timeout
                case earlyDraw
                case disconnect
            }
        }
        
        struct Metadata: Codable {
            let gameVersion: String
            let seasonId: String?
            let tournamentId: String?
            let isRanked: Bool
            let tags: [String]
        }
    }
    
    enum ReplayEvent: Codable {
        case matchStart(timestamp: TimeInterval)
        case draw(timestamp: TimeInterval, playerId: String)
        case shot(timestamp: TimeInterval, playerId: String, position: CGPoint)
        case hit(timestamp: TimeInterval, playerId: String, damage: Int)
        case powerupUse(timestamp: TimeInterval, playerId: String, powerupId: String)
        case emote(timestamp: TimeInterval, playerId: String, emoteId: String)
        case matchEnd(timestamp: TimeInterval, winnerId: String)
        
        var timestamp: TimeInterval {
            switch self {
            case .matchStart(let time),
                 .draw(let time, _),
                 .shot(let time, _, _),
                 .hit(let time, _, _),
                 .powerupUse(let time, _, _),
                 .emote(let time, _, _),
                 .matchEnd(let time, _):
                return time
            }
        }
    }
    
    class ReplayRecording {
        var startTime: Date
        var events: [ReplayEvent]
        var players: [Replay.Player]
        
        init(players: [Replay.Player]) {
            self.startTime = Date()
            self.events = []
            self.players = players
        }
    }
    
    // MARK: - Recording
    func startRecording(players: [Replay.Player]) {
        guard !isRecording else { return }
        
        currentRecording = ReplayRecording(players: players)
        isRecording = true
        
        recordingTimer = Timer.scheduledTimer(
            withTimeInterval: 1/60,
            repeats: true
        ) { [weak self] _ in
            self?.updateRecording()
        }
        
        recordEvent(.matchStart(timestamp: 0))
    }
    
    func stopRecording(result: Replay.MatchResult) {
        guard let recording = currentRecording else { return }
        
        recordEvent(.matchEnd(
            timestamp: Date().timeIntervalSince(recording.startTime),
            winnerId: result.winnerId
        ))
        
        let replay = Replay(
            id: UUID().uuidString,
            timestamp: recording.startTime,
            duration: Date().timeIntervalSince(recording.startTime),
            players: recording.players,
            events: recording.events,
            result: result,
            metadata: createMetadata()
        )
        
        saveReplay(replay)
        
        currentRecording = nil
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        analytics.trackEvent(.featureUsed(name: "replay_recorded"))
    }
    
    func recordEvent(_ event: ReplayEvent) {
        guard isRecording,
              let recording = currentRecording else { return }
        
        recording.events.append(event)
    }
    
    private func updateRecording() {
        // Record continuous state if needed
    }
    
    // MARK: - Playback
    func playReplay(
        _ replay: Replay,
        in scene: SKScene,
        completion: @escaping () -> Void
    ) {
        // Setup scene for replay
        setupReplayScene(replay, in: scene)
        
        // Sort events by timestamp
        let sortedEvents = replay.events.sorted { $0.timestamp < $1.timestamp }
        
        // Play events sequentially
        for (index, event) in sortedEvents.enumerated() {
            let delay = event.timestamp
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.playEvent(event, in: scene)
                
                // Check if this is the last event
                if index == sortedEvents.count - 1 {
                    completion()
                }
            }
        }
        
        analytics.trackEvent(.featureUsed(name: "replay_watched"))
    }
    
    private func setupReplayScene(_ replay: Replay, in scene: SKScene) {
        // Reset scene state
        scene.removeAllChildren()
        
        // Add players
        for player in replay.players {
            addPlayerNode(for: player, to: scene)
        }
    }
    
    private func addPlayerNode(for player: Replay.Player, to scene: SKScene) {
        let node = SKSpriteNode(imageNamed: player.character)
        node.name = player.userId
        node.position = CGPoint(x: scene.size.width/2, y: scene.size.height/2)
        scene.addChild(node)
    }
    
    private func playEvent(_ event: ReplayEvent, in scene: SKScene) {
        switch event {
        case .matchStart:
            playMatchStartEvent(in: scene)
        case .draw(_, let playerId):
            playDrawEvent(playerId: playerId, in: scene)
        case .shot(_, let playerId, let position):
            playShotEvent(playerId: playerId, position: position, in: scene)
        case .hit(_, let playerId, let damage):
            playHitEvent(playerId: playerId, damage: damage, in: scene)
        case .powerupUse(_, let playerId, let powerupId):
            playPowerupEvent(playerId: playerId, powerupId: powerupId, in: scene)
        case .emote(_, let playerId, let emoteId):
            playEmoteEvent(playerId: playerId, emoteId: emoteId, in: scene)
        case .matchEnd(_, let winnerId):
            playMatchEndEvent(winnerId: winnerId, in: scene)
        }
    }
    
    private func playMatchStartEvent(in scene: SKScene) {
        // Animate match start
    }
    
    private func playDrawEvent(playerId: String, in scene: SKScene) {
        guard let player = scene.childNode(withName: playerId) else { return }
        // Animate draw
    }
    
    private func playShotEvent(playerId: String, position: CGPoint, in scene: SKScene) {
        guard let player = scene.childNode(withName: playerId) else { return }
        // Animate shot
    }
    
    private func playHitEvent(playerId: String, damage: Int, in scene: SKScene) {
        guard let player = scene.childNode(withName: playerId) else { return }
        // Animate hit
    }
    
    private func playPowerupEvent(playerId: String, powerupId: String, in scene: SKScene) {
        guard let player = scene.childNode(withName: playerId) else { return }
        // Animate powerup
    }
    
    private func playEmoteEvent(playerId: String, emoteId: String, in scene: SKScene) {
        guard let player = scene.childNode(withName: playerId) else { return }
        // Show emote
    }
    
    private func playMatchEndEvent(winnerId: String, in scene: SKScene) {
        guard let winner = scene.childNode(withName: winnerId) else { return }
        // Animate match end
    }
    
    // MARK: - Storage
    private func saveReplay(_ replay: Replay) {
        // Save locally
        cachedReplays.append(replay)
        if cachedReplays.count > 20 {
            cachedReplays.removeFirst()
        }
        
        // Upload to server
        Task {
            do {
                try await networkManager.request(
                    endpoint: "replays",
                    method: .post,
                    parameters: ["replay": replay]
                )
            } catch {
                print("Failed to upload replay: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchReplay(
        _ replayId: String,
        completion: @escaping (Result<Replay, Error>) -> Void
    ) {
        // Check cache first
        if let cached = cachedReplays.first(where: { $0.id == replayId }) {
            completion(.success(cached))
            return
        }
        
        // Fetch from server
        Task {
            do {
                let replay: Replay = try await networkManager.request(
                    endpoint: "replays/\(replayId)"
                )
                cachedReplays.append(replay)
                completion(.success(replay))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Sharing
    func shareReplay(
        _ replay: Replay,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        Task {
            do {
                let url: ShareURL = try await networkManager.request(
                    endpoint: "replays/\(replay.id)/share",
                    method: .post
                )
                
                shareManager.shareContent(
                    url.url,
                    message: "Check out my High Noons duel!"
                )
                
                analytics.trackEvent(.featureUsed(name: "replay_shared"))
                completion(.success(url.url))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Utilities
    private func createMetadata() -> Replay.Metadata {
        return Replay.Metadata(
            gameVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            seasonId: SeasonManager.shared.getCurrentSeason()?.id,
            tournamentId: TournamentManager.shared.getActiveTournaments().first?.id,
            isRanked: true,
            tags: []
        )
    }
    
    // MARK: - Cleanup
    func cleanup() {
        stopRecording(result: Replay.MatchResult(
            winnerId: "",
            winType: .disconnect,
            reactionTimes: [:]
        ))
        cachedReplays.removeAll()
    }
}

// MARK: - Network Models
private struct ShareURL: Codable {
    let url: URL
}

// MARK: - Convenience Methods
extension ReplayManager {
    func getRecentReplays() -> [Replay] {
        return cachedReplays.sorted { $0.timestamp > $1.timestamp }
    }
    
    func isRecordingAvailable() -> Bool {
        return !isRecording
    }
}

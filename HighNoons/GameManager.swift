import Foundation
import GameKit

/// Manages the core game state and coordinates between different components
final class GameManager {
    // MARK: - Singleton
    static let shared = GameManager()
    private init() {}
    
    // MARK: - Dependencies
    private let sensorManager = SensorManager.shared
    private let audioManager = AudioManager.shared
    
    // MARK: - Game States
    enum GameState {
        case menu
        case waiting      // Player is waiting to raise phone
        case ready       // Phone is raised, waiting for "DRAW!"
        case drawing     // "DRAW!" signal shown
        case complete    // Duel completed
    }
    
    // MARK: - Properties
    private(set) var currentState: GameState = .menu {
        didSet {
            stateDidChange(from: oldValue, to: currentState)
        }
    }
    
    private var drawTimer: Timer?
    private var reactionStartTime: TimeInterval = 0
    private var randomDrawDelay: TimeInterval {
        // Random delay between 2-5 seconds
        return TimeInterval.random(in: 2.0...5.0)
    }
    
    // MARK: - Game Control
    func startDuel() {
        currentState = .waiting
        sensorManager.startMonitoring { [weak self] isRaised in
            if isRaised {
                self?.handlePhoneRaised()
            }
        }
    }
    
    private func handlePhoneRaised() {
        currentState = .ready
        scheduleDrawSignal()
    }
    
    private func scheduleDrawSignal() {
        drawTimer = Timer.scheduledTimer(withTimeInterval: randomDrawDelay, repeats: false) { [weak self] _ in
            self?.showDrawSignal()
        }
    }
    
    private func showDrawSignal() {
        currentState = .drawing
        reactionStartTime = Date().timeIntervalSinceReferenceDate
        audioManager.playSound(.draw)
    }
    
    func handlePlayerShot() -> (didWin: Bool, reactionTime: TimeInterval)? {
        guard currentState == .drawing else {
            // Shot too early
            audioManager.playSound(.fail)
            endDuel(didWin: false)
            return nil
        }
        
        let reactionTime = Date().timeIntervalSinceReferenceDate - reactionStartTime
        audioManager.playSound(.gunshot)
        
        // Determine if player won based on reaction time
        let didWin = reactionTime < 1.0 // Adjust threshold as needed
        endDuel(didWin: didWin)
        
        return (didWin, reactionTime)
    }
    
    private func endDuel(didWin: Bool) {
        drawTimer?.invalidate()
        drawTimer = nil
        sensorManager.stopMonitoring()
        currentState = .complete
        
        // Play appropriate sound
        audioManager.playSound(didWin ? .victory : .defeat)
    }
    
    private func stateDidChange(from oldState: GameState, to newState: GameState) {
        NotificationCenter.default.post(
            name: .gameStateDidChange,
            object: nil,
            userInfo: ["oldState": oldState, "newState": newState]
        )
    }
    
    func reset() {
        drawTimer?.invalidate()
        drawTimer = nil
        sensorManager.stopMonitoring()
        currentState = .menu
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let gameStateDidChange = Notification.Name("gameStateDidChange")
}

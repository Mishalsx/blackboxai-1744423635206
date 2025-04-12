import UIKit
import CoreHaptics

final class HapticsManager {
    // MARK: - Properties
    static let shared = HapticsManager()
    
    private var engine: CHHapticEngine?
    private var engineNeedsStart = true
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    
    private var isHapticsEnabled = true
    private var isEngineAvailable: Bool {
        return CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }
    
    // MARK: - Types
    enum HapticPattern {
        case success
        case failure
        case warning
        case shot
        case impact
        case draw
        case reload
        case heartbeat
        case victory
        case defeat
        
        var pattern: [CHHapticEvent] {
            switch self {
            case .success:
                return [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                        ],
                        relativeTime: 0
                    )
                ]
                
            case .failure:
                return [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                        ],
                        relativeTime: 0
                    ),
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                        ],
                        relativeTime: 0.2
                    )
                ]
                
            case .warning:
                return [
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                        ],
                        relativeTime: 0,
                        duration: 0.5
                    )
                ]
                
            case .shot:
                return [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                        ],
                        relativeTime: 0
                    ),
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                        ],
                        relativeTime: 0.05,
                        duration: 0.1
                    )
                ]
                
            case .impact:
                return [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                        ],
                        relativeTime: 0
                    ),
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                        ],
                        relativeTime: 0.05,
                        duration: 0.2
                    )
                ]
                
            case .draw:
                return [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                        ],
                        relativeTime: 0
                    ),
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                        ],
                        relativeTime: 0.1,
                        duration: 0.3
                    )
                ]
                
            case .reload:
                return [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                        ],
                        relativeTime: 0
                    ),
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                        ],
                        relativeTime: 0.2
                    )
                ]
                
            case .heartbeat:
                return [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                        ],
                        relativeTime: 0
                    ),
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                        ],
                        relativeTime: 0.1
                    )
                ]
                
            case .victory:
                return [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                        ],
                        relativeTime: 0
                    ),
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                        ],
                        relativeTime: 0.1,
                        duration: 0.3
                    ),
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                        ],
                        relativeTime: 0.5
                    )
                ]
                
            case .defeat:
                return [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                        ],
                        relativeTime: 0
                    ),
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                        ],
                        relativeTime: 0.1,
                        duration: 0.5
                    )
                ]
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupHaptics()
    }
    
    private func setupHaptics() {
        guard isEngineAvailable else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            
            engine?.stoppedHandler = { [weak self] reason in
                self?.engineNeedsStart = true
            }
            
            engine?.resetHandler = { [weak self] in
                self?.engineNeedsStart = true
            }
            
        } catch {
            print("Failed to create haptic engine: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    func toggleHaptics(_ enabled: Bool) {
        isHapticsEnabled = enabled
    }
    
    func playPattern(_ pattern: HapticPattern) {
        guard isHapticsEnabled, isEngineAvailable else { return }
        
        do {
            if engineNeedsStart {
                try engine?.start()
                engineNeedsStart = false
            }
            
            let pattern = try CHHapticPattern(events: pattern.pattern, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
            
        } catch {
            print("Failed to play haptic pattern: \(error.localizedDescription)")
        }
    }
    
    func startContinuousPattern(_ pattern: HapticPattern, intensity: Float = 1.0) {
        guard isHapticsEnabled, isEngineAvailable else { return }
        
        do {
            if engineNeedsStart {
                try engine?.start()
                engineNeedsStart = false
            }
            
            let pattern = try CHHapticPattern(events: pattern.pattern, parameters: [])
            continuousPlayer = try engine?.makeAdvancedPlayer(with: pattern)
            try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
            
        } catch {
            print("Failed to start continuous haptic pattern: \(error.localizedDescription)")
        }
    }
    
    func stopContinuousPattern() {
        do {
            try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
            continuousPlayer = nil
        } catch {
            print("Failed to stop continuous haptic pattern: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Game-Specific Patterns
    func playDuelStart() {
        playPattern(.draw)
    }
    
    func playGunshot() {
        playPattern(.shot)
    }
    
    func playHit() {
        playPattern(.impact)
    }
    
    func playVictory() {
        playPattern(.victory)
    }
    
    func playDefeat() {
        playPattern(.defeat)
    }
    
    func startHeartbeat() {
        startContinuousPattern(.heartbeat)
    }
    
    func stopHeartbeat() {
        stopContinuousPattern()
    }
}

// MARK: - Legacy Support
extension HapticsManager {
    func playLegacyHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func playLegacyNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

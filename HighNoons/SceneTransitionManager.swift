import SpriteKit

final class SceneTransitionManager {
    // MARK: - Properties
    static let shared = SceneTransitionManager()
    
    private let analytics = AnalyticsManager.shared
    private let audioManager = AudioManager.shared
    private let haptics = HapticsManager.shared
    
    private var isTransitioning = false
    private weak var currentScene: SKScene?
    
    // MARK: - Types
    enum TransitionType {
        case fade
        case doorway
        case crossfade
        case slide(Direction)
        case reveal(Direction)
        case gunshot
        case custom(SKTransition)
        
        enum Direction {
            case left
            case right
            case up
            case down
        }
        
        var transition: SKTransition {
            switch self {
            case .fade:
                return SKTransition.fade(withDuration: 0.5)
            case .doorway:
                return SKTransition.doorsOpenHorizontal(withDuration: 0.5)
            case .crossfade:
                return SKTransition.crossFade(withDuration: 0.5)
            case .slide(let direction):
                switch direction {
                case .left:
                    return SKTransition.push(with: .left, duration: 0.5)
                case .right:
                    return SKTransition.push(with: .right, duration: 0.5)
                case .up:
                    return SKTransition.push(with: .up, duration: 0.5)
                case .down:
                    return SKTransition.push(with: .down, duration: 0.5)
                }
            case .reveal(let direction):
                switch direction {
                case .left:
                    return SKTransition.reveal(with: .left, duration: 0.5)
                case .right:
                    return SKTransition.reveal(with: .right, duration: 0.5)
                case .up:
                    return SKTransition.reveal(with: .up, duration: 0.5)
                case .down:
                    return SKTransition.reveal(with: .down, duration: 0.5)
                }
            case .gunshot:
                return createGunshotTransition()
            case .custom(let transition):
                return transition
            }
        }
    }
    
    enum TransitionEffect {
        case none
        case flash
        case shake
        case particles
        case custom(SKAction)
    }
    
    // MARK: - Scene Transitions
    func transition(
        to sceneType: SKScene.Type,
        size: CGSize,
        type: TransitionType = .fade,
        effect: TransitionEffect = .none,
        completion: (() -> Void)? = nil
    ) {
        guard !isTransitioning,
              let view = currentScene?.view else { return }
        
        isTransitioning = true
        
        // Track analytics
        analytics.trackEvent(.loadingTime(
            screen: String(describing: sceneType),
            duration: 0
        ))
        
        // Create new scene
        guard let newScene = sceneType.init(size: size) as? SKScene else {
            isTransitioning = false
            return
        }
        
        newScene.scaleMode = .aspectFill
        
        // Apply pre-transition effect
        applyEffect(effect) { [weak self] in
            // Perform transition
            let transition = type.transition
            view.presentScene(newScene, transition: transition) {
                self?.isTransitioning = false
                self?.currentScene = newScene
                completion?()
            }
        }
    }
    
    // MARK: - Custom Transitions
    private func createGunshotTransition() -> SKTransition {
        let transition = SKTransition.fade(withDuration: 0.3)
        
        // Play gunshot sound
        audioManager.playSound(.gunshot)
        
        // Add haptic feedback
        haptics.playPattern(.shot)
        
        return transition
    }
    
    // MARK: - Transition Effects
    private func applyEffect(_ effect: TransitionEffect, completion: @escaping () -> Void) {
        guard let scene = currentScene else {
            completion()
            return
        }
        
        switch effect {
        case .none:
            completion()
            
        case .flash:
            let flashNode = SKSpriteNode(color: .white, size: scene.size)
            flashNode.position = CGPoint(x: scene.size.width/2, y: scene.size.height/2)
            flashNode.zPosition = 1000
            flashNode.alpha = 0
            scene.addChild(flashNode)
            
            let flashAction = SKAction.sequence([
                SKAction.fadeAlpha(to: 1.0, duration: 0.1),
                SKAction.fadeAlpha(to: 0.0, duration: 0.1),
                SKAction.run {
                    flashNode.removeFromParent()
                    completion()
                }
            ])
            
            flashNode.run(flashAction)
            
        case .shake:
            let originalPosition = scene.position
            let shakeAction = SKAction.sequence([
                SKAction.repeat(
                    SKAction.sequence([
                        SKAction.moveBy(x: 10, y: 0, duration: 0.05),
                        SKAction.moveBy(x: -20, y: 0, duration: 0.05),
                        SKAction.moveBy(x: 10, y: 0, duration: 0.05)
                    ]),
                    count: 2
                ),
                SKAction.move(to: originalPosition, duration: 0.1),
                SKAction.run {
                    completion()
                }
            ])
            
            scene.run(shakeAction)
            
        case .particles:
            guard let emitter = SKEmitterNode(fileNamed: "TransitionParticle") else {
                completion()
                return
            }
            
            emitter.position = CGPoint(x: scene.size.width/2, y: scene.size.height/2)
            emitter.zPosition = 1000
            scene.addChild(emitter)
            
            let particleAction = SKAction.sequence([
                SKAction.wait(forDuration: 0.5),
                SKAction.run {
                    emitter.removeFromParent()
                    completion()
                }
            ])
            
            emitter.run(particleAction)
            
        case .custom(let action):
            scene.run(action) {
                completion()
            }
        }
    }
    
    // MARK: - Scene Management
    func setCurrentScene(_ scene: SKScene) {
        currentScene = scene
    }
    
    func getCurrentScene() -> SKScene? {
        return currentScene
    }
}

// MARK: - Convenience Methods
extension SceneTransitionManager {
    func transitionToGame(from scene: SKScene) {
        transition(
            to: DuelScene.self,
            size: scene.size,
            type: .gunshot,
            effect: .flash
        )
    }
    
    func transitionToMainMenu(from scene: SKScene) {
        transition(
            to: LandingScene.self,
            size: scene.size,
            type: .fade,
            effect: .none
        )
    }
    
    func transitionToResults(from scene: SKScene) {
        transition(
            to: ResultScene.self,
            size: scene.size,
            type: .crossfade,
            effect: .particles
        )
    }
    
    func transitionToStore(from scene: SKScene) {
        transition(
            to: StoreScene.self,
            size: scene.size,
            type: .doorway,
            effect: .none
        )
    }
}

// MARK: - Custom Transitions
extension SceneTransitionManager {
    static func createDustTransition(duration: TimeInterval) -> SKTransition {
        let transition = SKTransition.crossFade(withDuration: duration)
        // Add custom dust effect
        return transition
    }
    
    static func createSplitTransition(duration: TimeInterval) -> SKTransition {
        let transition = SKTransition.doorway(withDuration: duration)
        // Add custom split effect
        return transition
    }
}

// MARK: - Scene Protocol
protocol TransitionableScene: SKScene {
    func prepareForTransition()
    func didCompleteTransition()
}

extension TransitionableScene {
    func prepareForTransition() {
        // Default implementation
    }
    
    func didCompleteTransition() {
        // Default implementation
    }
}

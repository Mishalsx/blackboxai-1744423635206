import SpriteKit
import GameplayKit

class DuelScene: SKScene {
    // MARK: - Properties
    private let gameManager = GameManager.shared
    
    // Nodes
    private var backgroundNode: SKSpriteNode!
    private var playerNode: SKSpriteNode!
    private var opponentNode: SKSpriteNode!
    private var messageLabel: SKLabelNode!
    private var reactionTimeLabel: SKLabelNode!
    
    // Game state
    private var canShoot = false
    private var gameStarted = false
    
    // Visual constants
    private let messageFontSize: CGFloat = 48.0
    private let reactionTimeFontSize: CGFloat = 24.0
    
    // MARK: - Initialization
    override init(size: CGSize) {
        super.init(size: size)
        setupScene()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupScene()
    }
    
    // MARK: - Scene Setup
    private func setupScene() {
        setupBackground()
        setupCharacters()
        setupUI()
        observeGameState()
    }
    
    private func setupBackground() {
        // Create desert background
        backgroundNode = SKSpriteNode(color: .brown, size: size)
        backgroundNode.position = CGPoint(x: size.width/2, y: size.height/2)
        backgroundNode.zPosition = -1
        addChild(backgroundNode)
        
        // TODO: Load actual background texture
        // backgroundNode.texture = SKTexture(imageNamed: "desert_background")
    }
    
    private func setupCharacters() {
        // Setup player character
        playerNode = SKSpriteNode(color: .blue, size: CGSize(width: 100, height: 200))
        playerNode.position = CGPoint(x: size.width * 0.25, y: size.height * 0.3)
        addChild(playerNode)
        
        // Setup opponent character
        opponentNode = SKSpriteNode(color: .red, size: CGSize(width: 100, height: 200))
        opponentNode.position = CGPoint(x: size.width * 0.75, y: size.height * 0.3)
        addChild(opponentNode)
        
        // TODO: Load actual character textures and animations
    }
    
    private func setupUI() {
        // Setup message label
        messageLabel = SKLabelNode(fontNamed: "Western-Font") // TODO: Use actual western font
        messageLabel.fontSize = messageFontSize
        messageLabel.position = CGPoint(x: size.width/2, y: size.height * 0.7)
        messageLabel.zPosition = 1
        addChild(messageLabel)
        
        // Setup reaction time label
        reactionTimeLabel = SKLabelNode(fontNamed: "Arial")
        reactionTimeLabel.fontSize = reactionTimeFontSize
        reactionTimeLabel.position = CGPoint(x: size.width/2, y: size.height * 0.9)
        reactionTimeLabel.zPosition = 1
        reactionTimeLabel.isHidden = true
        addChild(reactionTimeLabel)
    }
    
    // MARK: - Game State Observation
    private func observeGameState() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGameStateChange(_:)),
            name: .gameStateDidChange,
            object: nil
        )
    }
    
    @objc private func handleGameStateChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let newState = userInfo["newState"] as? GameManager.GameState else {
            return
        }
        
        updateUI(for: newState)
    }
    
    private func updateUI(for state: GameManager.GameState) {
        switch state {
        case .menu:
            messageLabel.text = "Tap to Start"
            canShoot = false
        case .waiting:
            messageLabel.text = "Raise Your Phone"
            canShoot = false
        case .ready:
            messageLabel.text = "Wait..."
            canShoot = false
        case .drawing:
            showDrawSignal()
            canShoot = true
        case .complete:
            canShoot = false
        }
    }
    
    // MARK: - Game Actions
    private func showDrawSignal() {
        // Animate "DRAW!" message
        messageLabel.text = "DRAW!"
        messageLabel.setScale(0.1)
        
        let scaleAction = SKAction.scale(to: 1.5, duration: 0.2)
        let shrinkAction = SKAction.scale(to: 1.0, duration: 0.1)
        
        messageLabel.run(SKAction.sequence([scaleAction, shrinkAction]))
    }
    
    private func handleShot() {
        guard canShoot else { return }
        
        if let result = gameManager.handlePlayerShot() {
            showShotResult(didWin: result.didWin, reactionTime: result.reactionTime)
        }
    }
    
    private func showShotResult(didWin: Bool, reactionTime: TimeInterval) {
        // Show reaction time
        reactionTimeLabel.isHidden = false
        reactionTimeLabel.text = String(format: "Reaction Time: %.3f s", reactionTime)
        
        // Show result message
        messageLabel.text = didWin ? "You Win!" : "Too Slow!"
        
        // Play appropriate animation
        if didWin {
            playWinAnimation()
        } else {
            playLoseAnimation()
        }
    }
    
    // MARK: - Animations
    private func playWinAnimation() {
        // Opponent fall animation
        let fallRotation = SKAction.rotate(byAngle: .pi/2, duration: 0.5)
        let fallMove = SKAction.moveBy(x: 0, y: -100, duration: 0.5)
        opponentNode.run(SKAction.group([fallRotation, fallMove]))
        
        // Player victory animation
        let celebration = SKAction.sequence([
            SKAction.scale(by: 1.2, duration: 0.2),
            SKAction.scale(by: 1/1.2, duration: 0.2)
        ])
        playerNode.run(celebration)
    }
    
    private func playLoseAnimation() {
        // Player fall animation
        let fallRotation = SKAction.rotate(byAngle: -.pi/2, duration: 0.5)
        let fallMove = SKAction.moveBy(x: 0, y: -100, duration: 0.5)
        playerNode.run(SKAction.group([fallRotation, fallMove]))
        
        // Opponent victory animation
        let celebration = SKAction.sequence([
            SKAction.scale(by: 1.2, duration: 0.2),
            SKAction.scale(by: 1/1.2, duration: 0.2)
        ])
        opponentNode.run(celebration)
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !gameStarted {
            gameStarted = true
            gameManager.startDuel()
            return
        }
        
        handleShot()
    }
    
    // MARK: - Cleanup
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Scene Transitions
extension DuelScene {
    func transitionToMainMenu() {
        // TODO: Implement main menu transition
    }
    
    func transitionToResults() {
        // TODO: Implement results screen transition
    }
}

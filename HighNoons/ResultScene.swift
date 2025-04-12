import SpriteKit
import GameKit

class ResultScene: SKScene {
    // MARK: - Properties
    private let translationManager = TranslationManager.shared
    private let audioManager = AudioManager.shared
    private let adManager = AdManager.shared
    
    // Result Data
    private let didWin: Bool
    private let reactionTime: TimeInterval
    private let opponentTime: TimeInterval?
    private let xpGained: Int
    
    // Nodes
    private var resultLabel: SKLabelNode!
    private var statsContainer: SKNode!
    private var buttonsContainer: SKNode!
    private var confettiEmitter: SKEmitterNode?
    
    // MARK: - Initialization
    init(size: CGSize, didWin: Bool, reactionTime: TimeInterval, opponentTime: TimeInterval? = nil, xpGained: Int) {
        self.didWin = didWin
        self.reactionTime = reactionTime
        self.opponentTime = opponentTime
        self.xpGained = xpGained
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        setupScene()
        animateResults()
        playResultSound()
        
        // Show interstitial ad occasionally after matches
        if Bool.random(chance: 0.3) { // 30% chance
            showPostMatchAd()
        }
    }
    
    // MARK: - Setup
    private func setupScene() {
        setupBackground()
        setupResultLabel()
        setupStatsContainer()
        setupButtons()
        if didWin {
            setupConfetti()
        }
    }
    
    private func setupBackground() {
        let backgroundNode = SKSpriteNode(color: .brown, size: size)
        backgroundNode.position = CGPoint(x: size.width/2, y: size.height/2)
        backgroundNode.zPosition = -1
        addChild(backgroundNode)
        
        // Load result background
        loadBackgroundTexture()
    }
    
    private func loadBackgroundTexture() {
        let backgroundURL = didWin ?
            URL(string: "https://images.pexels.com/photos/sunset-victory.jpg")! :
            URL(string: "https://images.pexels.com/photos/desert-defeat.jpg")!
        
        URLSession.shared.dataTask(with: backgroundURL) { [weak self] data, _, _ in
            guard let data = data,
                  let image = UIImage(data: data),
                  let self = self else { return }
            
            DispatchQueue.main.async {
                let backgroundNode = SKSpriteNode(texture: SKTexture(image: image), size: self.size)
                backgroundNode.position = CGPoint(x: self.size.width/2, y: self.size.height/2)
                backgroundNode.zPosition = -1
                backgroundNode.alpha = 0
                self.addChild(backgroundNode)
                
                backgroundNode.run(SKAction.fadeIn(withDuration: 1.0))
            }
        }.resume()
    }
    
    private func setupResultLabel() {
        resultLabel = SKLabelNode(fontNamed: "Western-Font") // TODO: Use actual western font
        resultLabel.fontSize = 64
        resultLabel.position = CGPoint(x: size.width/2, y: size.height * 0.8)
        resultLabel.zPosition = 2
        resultLabel.alpha = 0
        addChild(resultLabel)
        
        // Set localized text
        Task {
            resultLabel.text = try? await translationManager.translate(
                didWin ? .victory : .defeat
            )
        }
    }
    
    private func setupStatsContainer() {
        statsContainer = SKNode()
        statsContainer.position = CGPoint(x: size.width/2, y: size.height * 0.6)
        statsContainer.zPosition = 2
        statsContainer.alpha = 0
        addChild(statsContainer)
        
        // Reaction Time
        let reactionLabel = createStatsLabel(
            text: String(format: "%.3fs", reactionTime),
            position: CGPoint(x: 0, y: 40)
        )
        statsContainer.addChild(reactionLabel)
        
        // Opponent Time (if available)
        if let opponentTime = opponentTime {
            let opponentLabel = createStatsLabel(
                text: String(format: "Opponent: %.3fs", opponentTime),
                position: CGPoint(x: 0, y: 0)
            )
            statsContainer.addChild(opponentLabel)
        }
        
        // XP Gained
        let xpLabel = createStatsLabel(
            text: "+\(xpGained) XP",
            position: CGPoint(x: 0, y: -40)
        )
        statsContainer.addChild(xpLabel)
    }
    
    private func createStatsLabel(text: String, position: CGPoint) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Arial")
        label.text = text
        label.fontSize = 32
        label.position = position
        return label
    }
    
    private func setupButtons() {
        buttonsContainer = SKNode()
        buttonsContainer.position = CGPoint(x: size.width/2, y: size.height * 0.3)
        buttonsContainer.zPosition = 2
        buttonsContainer.alpha = 0
        addChild(buttonsContainer)
        
        // Rematch Button
        let rematchButton = createButton(
            text: "Rematch",
            position: CGPoint(x: 0, y: 40),
            action: #selector(handleRematch)
        )
        buttonsContainer.addChild(rematchButton)
        
        // Main Menu Button
        let menuButton = createButton(
            text: "Main Menu",
            position: CGPoint(x: 0, y: -40),
            action: #selector(handleMainMenu)
        )
        buttonsContainer.addChild(menuButton)
        
        if !didWin {
            // Retry with Ad Button
            let retryButton = createButton(
                text: "Retry (Watch Ad)",
                position: CGPoint(x: 0, y: -120),
                action: #selector(handleRetryWithAd)
            )
            buttonsContainer.addChild(retryButton)
        }
    }
    
    private func createButton(text: String, position: CGPoint, action: Selector) -> SKNode {
        let button = SKNode()
        button.position = position
        
        // Button background
        let background = SKShapeNode(rectOf: CGSize(width: 200, height: 60), cornerRadius: 10)
        background.fillColor = .black
        background.alpha = 0.7
        background.strokeColor = .white
        background.lineWidth = 2
        button.addChild(background)
        
        // Button label
        let label = SKLabelNode(fontNamed: "Arial")
        label.text = text
        label.fontSize = 24
        label.verticalAlignmentMode = .center
        button.addChild(label)
        
        return button
    }
    
    private func setupConfetti() {
        if let confettiPath = Bundle.main.path(forResource: "ConfettiParticle", ofType: "sks"),
           let confetti = SKEmitterNode(fileNamed: confettiPath) {
            confetti.position = CGPoint(x: size.width/2, y: size.height)
            confetti.zPosition = 3
            addChild(confetti)
            confettiEmitter = confetti
        }
    }
    
    // MARK: - Animations
    private func animateResults() {
        // Fade in result label
        resultLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeIn(withDuration: 0.5)
        ]))
        
        // Fade in stats
        statsContainer.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.fadeIn(withDuration: 0.5)
        ]))
        
        // Fade in buttons
        buttonsContainer.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.fadeIn(withDuration: 0.5)
        ]))
    }
    
    // MARK: - Sound
    private func playResultSound() {
        audioManager.playSound(didWin ? .victory : .defeat)
    }
    
    // MARK: - Button Actions
    @objc private func handleRematch() {
        // Transition to DuelScene
        let transition = SKTransition.fade(withDuration: 1.0)
        if let scene = DuelScene(size: size) {
            scene.scaleMode = .aspectFill
            view?.presentScene(scene, transition: transition)
        }
    }
    
    @objc private func handleMainMenu() {
        // Transition to LandingScene
        let transition = SKTransition.fade(withDuration: 1.0)
        if let scene = LandingScene(size: size) {
            scene.scaleMode = .aspectFill
            view?.presentScene(scene, transition: transition)
        }
    }
    
    @objc private func handleRetryWithAd() {
        guard let viewController = view?.window?.rootViewController else { return }
        
        adManager.showRewardedForRetry(from: viewController) { [weak self] success in
            if success {
                // Transition to new duel
                self?.handleRematch()
            }
        }
    }
    
    // MARK: - Ads
    private func showPostMatchAd() {
        guard let viewController = view?.window?.rootViewController else { return }
        adManager.showInterstitialIfReady(from: viewController)
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        for node in nodes(at: location) {
            if let button = node.parent, button.parent == buttonsContainer {
                handleButtonTap(button)
            }
        }
    }
    
    private func handleButtonTap(_ button: SKNode) {
        // Scale animation
        let scaleUp = SKAction.scale(to: 1.1, duration: 0.1)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        button.run(SKAction.sequence([scaleUp, scaleDown]))
        
        // Play sound
        audioManager.playSound(.buttonPress)
    }
    
    // MARK: - Cleanup
    override func willMove(from view: SKView) {
        confettiEmitter?.removeFromParent()
        removeAllActions()
        removeAllChildren()
    }
}

// MARK: - Convenience Extensions
private extension Bool {
    static func random(chance: Double) -> Bool {
        return Double.random(in: 0...1) < chance
    }
}

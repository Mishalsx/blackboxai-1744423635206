import SpriteKit
import GameKit

class LandingScene: SKScene {
    // MARK: - Properties
    private let translationManager = TranslationManager.shared
    private let audioManager = AudioManager.shared
    
    // UI Nodes
    private var titleLabel: SKLabelNode!
    private var startButton: SKSpriteNode!
    private var settingsButton: SKSpriteNode!
    private var leaderboardButton: SKSpriteNode!
    private var backgroundNode: SKSpriteNode!
    private var characterNode: SKSpriteNode!
    
    // Visual Properties
    private let titleFontSize: CGFloat = 64.0
    private let buttonFontSize: CGFloat = 32.0
    private let buttonSpacing: CGFloat = 50.0
    
    // Animation Properties
    private let buttonScale: CGFloat = 1.1
    private let buttonAnimationDuration: TimeInterval = 0.2
    
    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        setupScene()
        startBackgroundMusic()
        animateSceneEntry()
    }
    
    // MARK: - Setup
    private func setupScene() {
        setupBackground()
        setupCharacter()
        setupTitle()
        setupButtons()
        setupParticles()
    }
    
    private func setupBackground() {
        backgroundNode = SKSpriteNode(color: .brown, size: size)
        backgroundNode.position = CGPoint(x: size.width/2, y: size.height/2)
        backgroundNode.zPosition = -1
        addChild(backgroundNode)
        
        // Load desert background
        loadBackgroundTexture()
    }
    
    private func loadBackgroundTexture() {
        // TODO: Replace with actual background URL
        let backgroundURL = URL(string: "https://images.pexels.com/photos/desert-sunset.jpg")!
        
        URLSession.shared.dataTask(with: backgroundURL) { [weak self] data, _, _ in
            guard let data = data,
                  let image = UIImage(data: data),
                  let self = self else { return }
            
            DispatchQueue.main.async {
                self.backgroundNode.texture = SKTexture(image: image)
                self.backgroundNode.run(SKAction.fadeIn(withDuration: 0.5))
            }
        }.resume()
    }
    
    private func setupCharacter() {
        characterNode = SKSpriteNode(color: .clear, size: CGSize(width: 200, height: 400))
        characterNode.position = CGPoint(x: size.width * 0.7, y: size.height * 0.4)
        characterNode.zPosition = 1
        addChild(characterNode)
        
        // Load character texture
        loadCharacterTexture()
    }
    
    private func loadCharacterTexture() {
        // TODO: Replace with actual character URL
        let characterURL = URL(string: "https://images.pexels.com/photos/cowboy-silhouette.png")!
        
        URLSession.shared.dataTask(with: characterURL) { [weak self] data, _, _ in
            guard let data = data,
                  let image = UIImage(data: data),
                  let self = self else { return }
            
            DispatchQueue.main.async {
                self.characterNode.texture = SKTexture(image: image)
                self.characterNode.run(SKAction.fadeIn(withDuration: 0.5))
                self.animateCharacter()
            }
        }.resume()
    }
    
    private func setupTitle() {
        titleLabel = SKLabelNode(fontNamed: "Western-Font") // TODO: Use actual western font
        titleLabel.fontSize = titleFontSize
        titleLabel.position = CGPoint(x: size.width * 0.3, y: size.height * 0.7)
        titleLabel.zPosition = 2
        addChild(titleLabel)
        
        // Set localized text
        Task {
            titleLabel.text = try? await translationManager.translate(.startGame)
        }
    }
    
    private func setupButtons() {
        // Start Button
        startButton = createButton(
            at: CGPoint(x: size.width * 0.3, y: size.height * 0.5),
            iconName: "play.circle.fill"
        )
        
        // Settings Button
        settingsButton = createButton(
            at: CGPoint(x: size.width * 0.3, y: size.height * 0.4),
            iconName: "gearshape.fill"
        )
        
        // Leaderboard Button
        leaderboardButton = createButton(
            at: CGPoint(x: size.width * 0.3, y: size.height * 0.3),
            iconName: "trophy.fill"
        )
    }
    
    private func createButton(at position: CGPoint, iconName: String) -> SKSpriteNode {
        let button = SKSpriteNode(color: .clear, size: CGSize(width: 200, height: 60))
        button.position = position
        button.zPosition = 2
        
        // Create button background
        let background = SKShapeNode(rectOf: button.size, cornerRadius: 10)
        background.fillColor = .black
        background.alpha = 0.7
        background.strokeColor = .white
        background.lineWidth = 2
        button.addChild(background)
        
        // Add icon
        if let iconTexture = createSFSymbol(iconName) {
            let icon = SKSpriteNode(texture: iconTexture)
            icon.size = CGSize(width: 30, height: 30)
            icon.position = CGPoint(x: -70, y: 0)
            button.addChild(icon)
        }
        
        addChild(button)
        return button
    }
    
    private func createSFSymbol(_ name: String) -> SKTexture? {
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        guard let image = UIImage(systemName: name, withConfiguration: config) else {
            return nil
        }
        return SKTexture(image: image)
    }
    
    private func setupParticles() {
        if let dustPath = Bundle.main.path(forResource: "DustParticle", ofType: "sks"),
           let dustParticles = SKEmitterNode(fileNamed: dustPath) {
            dustParticles.position = CGPoint(x: size.width/2, y: 0)
            dustParticles.zPosition = 3
            addChild(dustParticles)
        }
    }
    
    // MARK: - Animations
    private func animateSceneEntry() {
        // Fade in background
        backgroundNode.alpha = 0
        backgroundNode.run(SKAction.fadeIn(withDuration: 1.0))
        
        // Slide in title
        titleLabel.position.x = -200
        titleLabel.run(SKAction.moveTo(x: size.width * 0.3, duration: 1.0, timingMode: .easeOut))
        
        // Pop in buttons
        let buttons = [startButton, settingsButton, leaderboardButton]
        for (index, button) in buttons.enumerated() {
            button?.alpha = 0
            button?.setScale(0.5)
            button?.run(SKAction.sequence([
                SKAction.wait(forDuration: TimeInterval(index) * 0.2),
                SKAction.group([
                    SKAction.fadeIn(withDuration: 0.3),
                    SKAction.scale(to: 1.0, duration: 0.3)
                ])
            ]))
        }
    }
    
    private func animateCharacter() {
        let sway = SKAction.sequence([
            SKAction.rotate(byAngle: 0.05, duration: 1),
            SKAction.rotate(byAngle: -0.05, duration: 1)
        ])
        characterNode.run(SKAction.repeatForever(sway))
    }
    
    private func animateButtonPress(_ button: SKSpriteNode) {
        let scaleUp = SKAction.scale(to: buttonScale, duration: buttonAnimationDuration/2)
        let scaleDown = SKAction.scale(to: 1.0, duration: buttonAnimationDuration/2)
        
        button.run(SKAction.sequence([scaleUp, scaleDown]))
        audioManager.playSound(.buttonPress)
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if startButton.contains(location) {
            handleStartButton()
        } else if settingsButton.contains(location) {
            handleSettingsButton()
        } else if leaderboardButton.contains(location) {
            handleLeaderboardButton()
        }
    }
    
    private func handleStartButton() {
        animateButtonPress(startButton)
        
        // Transition to character selection
        let transition = SKTransition.doorway(withDuration: 1.0)
        if let scene = CharacterSelectionScene(size: size) {
            scene.scaleMode = .aspectFill
            view?.presentScene(scene, transition: transition)
        }
    }
    
    private func handleSettingsButton() {
        animateButtonPress(settingsButton)
        
        // Transition to settings
        let transition = SKTransition.doorsOpenHorizontal(withDuration: 1.0)
        if let scene = SettingsScene(size: size) {
            scene.scaleMode = .aspectFill
            view?.presentScene(scene, transition: transition)
        }
    }
    
    private func handleLeaderboardButton() {
        animateButtonPress(leaderboardButton)
        
        // Show Game Center leaderboard
        let gcViewController = GKGameCenterViewController(state: .leaderboards)
        gcViewController.gameCenterDelegate = self
        
        if let viewController = view?.window?.rootViewController {
            viewController.present(gcViewController, animated: true)
        }
    }
    
    // MARK: - Audio
    private func startBackgroundMusic() {
        audioManager.startBackgroundMusic()
    }
    
    // MARK: - Cleanup
    override func willMove(from view: SKView) {
        removeAllActions()
        removeAllChildren()
    }
}

// MARK: - GKGameCenterControllerDelegate
extension LandingScene: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}

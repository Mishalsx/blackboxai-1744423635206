import SpriteKit

class DailyRewardsScene: SKScene {
    // MARK: - Properties
    private let translationManager = TranslationManager.shared
    private let audioManager = AudioManager.shared
    private let playerStats = PlayerStats.shared
    private let particleManager = ParticleManager.shared
    
    private var rewardNodes: [SKNode] = []
    private var collectButton: SKSpriteNode!
    private var closeButton: SKSpriteNode!
    
    // Reward Configuration
    private let rewards: [(day: Int, xp: Int, special: String?)] = [
        (1, 100, nil),          // Day 1: 100 XP
        (2, 200, nil),          // Day 2: 200 XP
        (3, 300, "character"),  // Day 3: 300 XP + Character
        (4, 400, nil),          // Day 4: 400 XP
        (5, 500, nil),          // Day 5: 500 XP
        (6, 600, nil),          // Day 6: 600 XP
        (7, 1000, "premium")    // Day 7: 1000 XP + Premium Item
    ]
    
    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        setupScene()
        checkDailyReward()
    }
    
    // MARK: - Setup
    private func setupScene() {
        setupBackground()
        setupTitle()
        setupRewardGrid()
        setupButtons()
    }
    
    private func setupBackground() {
        let backgroundNode = SKSpriteNode(color: .brown, size: size)
        backgroundNode.position = CGPoint(x: size.width/2, y: size.height/2)
        backgroundNode.zPosition = -1
        addChild(backgroundNode)
        
        // Load western-themed background
        loadBackgroundTexture()
    }
    
    private func loadBackgroundTexture() {
        // TODO: Replace with actual background URL
        let backgroundURL = URL(string: "https://images.pexels.com/photos/saloon-rewards.jpg")!
        
        URLSession.shared.dataTask(with: backgroundURL) { [weak self] data, _, _ in
            guard let data = data,
                  let image = UIImage(data: data),
                  let self = self else { return }
            
            DispatchQueue.main.async {
                let backgroundNode = SKSpriteNode(texture: SKTexture(image: image), size: self.size)
                backgroundNode.position = CGPoint(x: self.size.width/2, y: self.size.height/2)
                backgroundNode.zPosition = -1
                self.addChild(backgroundNode)
            }
        }.resume()
    }
    
    private func setupTitle() {
        let titleLabel = SKLabelNode(fontNamed: "Western-Font") // TODO: Use actual western font
        titleLabel.fontSize = 48
        titleLabel.position = CGPoint(x: size.width/2, y: size.height * 0.9)
        titleLabel.zPosition = 2
        addChild(titleLabel)
        
        Task {
            titleLabel.text = try? await translationManager.translate(.dailyRewards)
        }
    }
    
    private func setupRewardGrid() {
        let gridWidth = CGFloat(4) // 4 columns
        let gridHeight = CGFloat(2) // 2 rows
        let spacing: CGFloat = 20
        let rewardSize = CGSize(width: 150, height: 150)
        
        for (index, reward) in rewards.enumerated() {
            let row = CGFloat(index / 4)
            let col = CGFloat(index % 4)
            
            let xPos = size.width * 0.2 + (rewardSize.width + spacing) * col
            let yPos = size.height * 0.6 - (rewardSize.height + spacing) * row
            
            let rewardNode = createRewardNode(
                day: reward.day,
                xp: reward.xp,
                special: reward.special,
                size: rewardSize,
                position: CGPoint(x: xPos, y: yPos)
            )
            
            rewardNodes.append(rewardNode)
            addChild(rewardNode)
        }
    }
    
    private func createRewardNode(day: Int, xp: Int, special: String?, size: CGSize, position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position
        
        // Background
        let background = SKShapeNode(rectOf: size, cornerRadius: 15)
        background.fillColor = .black
        background.alpha = 0.7
        background.strokeColor = .white
        background.lineWidth = 2
        container.addChild(background)
        
        // Day Label
        let dayLabel = SKLabelNode(fontNamed: "Western-Font")
        dayLabel.text = "Day \(day)"
        dayLabel.fontSize = 24
        dayLabel.position = CGPoint(x: 0, y: size.height * 0.25)
        container.addChild(dayLabel)
        
        // XP Label
        let xpLabel = SKLabelNode(fontNamed: "Arial")
        xpLabel.text = "\(xp) XP"
        xpLabel.fontSize = 20
        xpLabel.position = CGPoint(x: 0, y: 0)
        container.addChild(xpLabel)
        
        // Special Reward
        if let special = special {
            let specialLabel = SKLabelNode(fontNamed: "Arial")
            specialLabel.text = "+" + special
            specialLabel.fontSize = 18
            specialLabel.position = CGPoint(x: 0, y: -size.height * 0.25)
            container.addChild(specialLabel)
        }
        
        return container
    }
    
    private func setupButtons() {
        // Collect Button
        collectButton = createButton(
            text: "Collect",
            position: CGPoint(x: size.width * 0.6, y: size.height * 0.15)
        )
        
        // Close Button
        closeButton = createButton(
            text: "Close",
            position: CGPoint(x: size.width * 0.4, y: size.height * 0.15)
        )
    }
    
    private func createButton(text: String, position: CGPoint) -> SKSpriteNode {
        let button = SKSpriteNode(color: .clear, size: CGSize(width: 200, height: 60))
        button.position = position
        button.zPosition = 2
        
        let background = SKShapeNode(rectOf: button.size, cornerRadius: 10)
        background.fillColor = .black
        background.alpha = 0.7
        background.strokeColor = .white
        background.lineWidth = 2
        button.addChild(background)
        
        let label = SKLabelNode(fontNamed: "Arial")
        label.text = text
        label.fontSize = 24
        label.verticalAlignmentMode = .center
        button.addChild(label)
        
        addChild(button)
        return button
    }
    
    // MARK: - Daily Reward Logic
    private func checkDailyReward() {
        if let reward = playerStats.checkDailyReward() {
            highlightCurrentReward()
            enableCollection(reward)
        } else {
            disableCollection()
        }
    }
    
    private func highlightCurrentReward() {
        let currentStreak = playerStats.stats.currentStreak
        guard currentStreak <= rewardNodes.count else { return }
        
        let currentNode = rewardNodes[currentStreak - 1]
        let highlight = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.2)
        ])
        currentNode.run(SKAction.repeatForever(highlight))
    }
    
    private func enableCollection(_ reward: Int) {
        collectButton.alpha = 1.0
        collectButton.isUserInteractionEnabled = true
    }
    
    private func disableCollection() {
        collectButton.alpha = 0.5
        collectButton.isUserInteractionEnabled = false
    }
    
    private func collectReward() {
        guard let reward = playerStats.checkDailyReward() else { return }
        
        // Add XP
        playerStats.addXP(reward)
        
        // Show celebration
        showRewardCollection(reward)
        
        // Check for special rewards
        checkSpecialRewards()
        
        // Disable collection
        disableCollection()
    }
    
    private func showRewardCollection(_ amount: Int) {
        // XP popup
        let xpLabel = SKLabelNode(fontNamed: "Western-Font")
        xpLabel.text = "+\(amount) XP"
        xpLabel.fontSize = 48
        xpLabel.position = CGPoint(x: size.width/2, y: size.height/2)
        xpLabel.setScale(0.1)
        addChild(xpLabel)
        
        let sequence = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.5, duration: 0.3),
                SKAction.fadeIn(withDuration: 0.3)
            ]),
            SKAction.wait(forDuration: 1.0),
            SKAction.group([
                SKAction.scale(to: 0.1, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.removeFromParent()
        ])
        
        xpLabel.run(sequence)
        
        // Particle effects
        particleManager.addConfettiEffect(to: self, position: CGPoint(x: size.width/2, y: size.height/2))
        
        // Sound effect
        audioManager.playSound(.victory)
    }
    
    private func checkSpecialRewards() {
        let currentStreak = playerStats.stats.currentStreak
        if let special = rewards[currentStreak - 1].special {
            switch special {
            case "character":
                // Unlock new character
                playerStats.unlockCharacter(currentStreak)
            case "premium":
                // Grant premium item
                break
            default:
                break
            }
        }
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if collectButton.contains(location) && collectButton.isUserInteractionEnabled {
            collectReward()
        } else if closeButton.contains(location) {
            dismissScene()
        }
    }
    
    private func dismissScene() {
        // Return to previous scene
        let transition = SKTransition.fade(withDuration: 0.5)
        if let scene = LandingScene(size: size) {
            scene.scaleMode = .aspectFill
            view?.presentScene(scene, transition: transition)
        }
    }
    
    // MARK: - Cleanup
    override func willMove(from view: SKView) {
        removeAllActions()
        removeAllChildren()
    }
}

// MARK: - Translation Extension
extension TranslationManager.TranslationKey {
    static let dailyRewards = TranslationManager.TranslationKey(rawValue: "daily_rewards")
}

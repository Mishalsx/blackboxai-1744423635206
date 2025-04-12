import SpriteKit

class ChallengesScene: SKScene {
    // MARK: - Properties
    private let translationManager = TranslationManager.shared
    private let audioManager = AudioManager.shared
    private let playerStats = PlayerStats.shared
    private let particleManager = ParticleManager.shared
    
    private var dailyChallenges: [ChallengeNode] = []
    private var weeklyChallenges: [ChallengeNode] = []
    private var tabButtons: [SKSpriteNode] = []
    private var currentTab: ChallengeType = .daily
    
    // MARK: - Types
    enum ChallengeType {
        case daily
        case weekly
    }
    
    struct Challenge {
        let title: String
        let description: String
        let reward: Int
        let progress: Int
        let target: Int
        let type: ChallengeType
        var isCompleted: Bool {
            return progress >= target
        }
    }
    
    class ChallengeNode: SKNode {
        let challenge: Challenge
        var progressBar: SKShapeNode
        var progressLabel: SKLabelNode
        var rewardButton: SKSpriteNode
        
        init(challenge: Challenge, size: CGSize) {
            self.challenge = challenge
            
            // Create progress bar
            let barSize = CGSize(width: size.width * 0.8, height: 20)
            progressBar = SKShapeNode(rectOf: barSize, cornerRadius: 10)
            progressBar.fillColor = .gray
            progressBar.strokeColor = .white
            
            // Create progress label
            progressLabel = SKLabelNode(fontNamed: "Arial")
            progressLabel.fontSize = 16
            progressLabel.text = "\(challenge.progress)/\(challenge.target)"
            
            // Create reward button
            rewardButton = SKSpriteNode(color: .green, size: CGSize(width: 80, height: 40))
            rewardButton.isHidden = !challenge.isCompleted
            
            super.init()
            
            setupNode(size: size)
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupNode(size: CGSize) {
            // Background
            let background = SKShapeNode(rectOf: size, cornerRadius: 15)
            background.fillColor = .black
            background.alpha = 0.7
            background.strokeColor = .white
            addChild(background)
            
            // Title
            let titleLabel = SKLabelNode(fontNamed: "Western-Font")
            titleLabel.text = challenge.title
            titleLabel.fontSize = 24
            titleLabel.position = CGPoint(x: 0, y: size.height * 0.25)
            addChild(titleLabel)
            
            // Description
            let descLabel = SKLabelNode(fontNamed: "Arial")
            descLabel.text = challenge.description
            descLabel.fontSize = 18
            descLabel.position = CGPoint(x: 0, y: size.height * 0.1)
            addChild(descLabel)
            
            // Progress bar
            progressBar.position = CGPoint(x: 0, y: -size.height * 0.1)
            addChild(progressBar)
            
            // Progress label
            progressLabel.position = CGPoint(x: 0, y: -size.height * 0.1)
            addChild(progressLabel)
            
            // Reward button
            rewardButton.position = CGPoint(x: size.width * 0.35, y: 0)
            let rewardLabel = SKLabelNode(fontNamed: "Arial")
            rewardLabel.text = "+\(challenge.reward) XP"
            rewardLabel.fontSize = 16
            rewardLabel.verticalAlignmentMode = .center
            rewardButton.addChild(rewardLabel)
            addChild(rewardButton)
            
            updateProgress()
        }
        
        func updateProgress() {
            let progress = CGFloat(challenge.progress) / CGFloat(challenge.target)
            progressBar.xScale = max(0.05, progress)
            progressLabel.text = "\(challenge.progress)/\(challenge.target)"
            rewardButton.isHidden = !challenge.isCompleted
        }
    }
    
    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        setupScene()
        loadChallenges()
    }
    
    // MARK: - Setup
    private func setupScene() {
        setupBackground()
        setupTitle()
        setupTabs()
        setupScrollView()
    }
    
    private func setupBackground() {
        let backgroundNode = SKSpriteNode(color: .brown, size: size)
        backgroundNode.position = CGPoint(x: size.width/2, y: size.height/2)
        backgroundNode.zPosition = -1
        addChild(backgroundNode)
        
        // Add ambient dust effect
        particleManager.startAmbientEffects(in: self)
    }
    
    private func setupTitle() {
        let titleLabel = SKLabelNode(fontNamed: "Western-Font")
        titleLabel.fontSize = 48
        titleLabel.position = CGPoint(x: size.width/2, y: size.height * 0.9)
        titleLabel.zPosition = 2
        addChild(titleLabel)
        
        Task {
            titleLabel.text = try? await translationManager.translate(.challenges)
        }
    }
    
    private func setupTabs() {
        let tabWidth = size.width * 0.4
        let tabHeight: CGFloat = 50
        let spacing: CGFloat = 10
        
        // Daily Tab
        let dailyTab = createTabButton(
            title: "Daily",
            size: CGSize(width: tabWidth, height: tabHeight),
            position: CGPoint(x: size.width * 0.3, y: size.height * 0.8)
        )
        
        // Weekly Tab
        let weeklyTab = createTabButton(
            title: "Weekly",
            size: CGSize(width: tabWidth, height: tabHeight),
            position: CGPoint(x: size.width * 0.7, y: size.height * 0.8)
        )
        
        tabButtons = [dailyTab, weeklyTab]
        updateTabSelection()
    }
    
    private func createTabButton(title: String, size: CGSize, position: CGPoint) -> SKSpriteNode {
        let button = SKSpriteNode(color: .clear, size: size)
        button.position = position
        button.zPosition = 2
        
        let background = SKShapeNode(rectOf: size, cornerRadius: 10)
        background.fillColor = .black
        background.alpha = 0.7
        background.strokeColor = .white
        button.addChild(background)
        
        let label = SKLabelNode(fontNamed: "Arial")
        label.text = title
        label.fontSize = 24
        label.verticalAlignmentMode = .center
        button.addChild(label)
        
        addChild(button)
        return button
    }
    
    private func setupScrollView() {
        // Implement scrolling container for challenges
    }
    
    // MARK: - Challenge Management
    private func loadChallenges() {
        // Example challenges
        let dailyChallenges = [
            Challenge(
                title: "Quick Draw",
                description: "Win 3 duels with reaction time under 0.5s",
                reward: 200,
                progress: 1,
                target: 3,
                type: .daily
            ),
            Challenge(
                title: "Sharpshooter",
                description: "Win 5 duels",
                reward: 150,
                progress: 3,
                target: 5,
                type: .daily
            )
        ]
        
        let weeklyChallenges = [
            Challenge(
                title: "Gunslinger",
                description: "Win 20 duels",
                reward: 500,
                progress: 12,
                target: 20,
                type: .weekly
            ),
            Challenge(
                title: "Perfect Streak",
                description: "Win 10 duels in a row",
                reward: 1000,
                progress: 6,
                target: 10,
                type: .weekly
            )
        ]
        
        displayChallenges(dailyChallenges, type: .daily)
        displayChallenges(weeklyChallenges, type: .weekly)
    }
    
    private func displayChallenges(_ challenges: [Challenge], type: ChallengeType) {
        let challengeHeight: CGFloat = 150
        let spacing: CGFloat = 20
        
        for (index, challenge) in challenges.enumerated() {
            let node = ChallengeNode(
                challenge: challenge,
                size: CGSize(width: size.width * 0.9, height: challengeHeight)
            )
            
            node.position = CGPoint(
                x: size.width/2,
                y: size.height * 0.6 - (challengeHeight + spacing) * CGFloat(index)
            )
            
            node.isHidden = type != currentTab
            
            if type == .daily {
                dailyChallenges.append(node)
            } else {
                weeklyChallenges.append(node)
            }
            
            addChild(node)
        }
    }
    
    private func updateTabSelection() {
        tabButtons.forEach { button in
            button.alpha = 0.7
        }
        
        let selectedTab = currentTab == .daily ? tabButtons[0] : tabButtons[1]
        selectedTab.alpha = 1.0
        
        // Show/hide appropriate challenges
        dailyChallenges.forEach { $0.isHidden = currentTab != .daily }
        weeklyChallenges.forEach { $0.isHidden = currentTab != .weekly }
    }
    
    // MARK: - Reward Collection
    private func collectReward(_ challenge: Challenge) {
        // Add XP
        playerStats.addXP(challenge.reward)
        
        // Show celebration
        showRewardCollection(challenge.reward)
        
        // Update UI
        updateChallengeNodes()
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
        particleManager.addConfettiEffect(
            to: self,
            position: CGPoint(x: size.width/2, y: size.height/2)
        )
        
        // Sound effect
        audioManager.playSound(.victory)
    }
    
    private func updateChallengeNodes() {
        let challenges = currentTab == .daily ? dailyChallenges : weeklyChallenges
        challenges.forEach { $0.updateProgress() }
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Handle tab selection
        for (index, button) in tabButtons.enumerated() {
            if button.contains(location) {
                currentTab = index == 0 ? .daily : .weekly
                updateTabSelection()
                return
            }
        }
        
        // Handle reward collection
        let challenges = currentTab == .daily ? dailyChallenges : weeklyChallenges
        for node in challenges {
            if node.rewardButton.contains(location) && !node.rewardButton.isHidden {
                collectReward(node.challenge)
                return
            }
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
    static let challenges = TranslationManager.TranslationKey(rawValue: "challenges")
}

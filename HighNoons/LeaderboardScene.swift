import SpriteKit
import GameKit

class LeaderboardScene: SKScene {
    // MARK: - Properties
    private let translationManager = TranslationManager.shared
    private var leaderboardEntries: [LeaderboardEntry] = []
    private var loadingNode: SKNode?
    private var errorNode: SKNode?
    private var scrollNode: SKNode?
    private var lastContentOffset: CGFloat = 0
    
    // UI Constants
    private let entryHeight: CGFloat = 80
    private let entrySpacing: CGFloat = 10
    private let scrollSpeed: CGFloat = 0.5
    
    // MARK: - Types
    struct LeaderboardEntry {
        let rank: Int
        let playerName: String
        let score: Int
        let wins: Int
        let averageReactionTime: TimeInterval
        let isCurrentPlayer: Bool
    }
    
    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        setupScene()
        loadLeaderboardData()
    }
    
    // MARK: - Setup
    private func setupScene() {
        setupBackground()
        setupTitle()
        setupScrollContainer()
        setupLoadingIndicator()
        setupRefreshButton()
        setupBackButton()
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
        let backgroundURL = URL(string: "https://images.pexels.com/photos/saloon-interior.jpg")!
        
        URLSession.shared.dataTask(with: backgroundURL) { [weak self] data, _, _ in
            guard let data = data,
                  let image = UIImage(data: data),
                  let self = self else { return }
            
            DispatchQueue.main.async {
                let texture = SKTexture(image: image)
                let backgroundNode = SKSpriteNode(texture: texture, size: self.size)
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
        
        // Set localized text
        Task {
            titleLabel.text = try? await translationManager.translate(.leaderboard)
        }
    }
    
    private func setupScrollContainer() {
        let containerNode = SKNode()
        containerNode.position = CGPoint(x: 0, y: size.height * 0.8)
        containerNode.zPosition = 1
        addChild(containerNode)
        scrollNode = containerNode
    }
    
    private func setupLoadingIndicator() {
        loadingNode = createLoadingSpinner()
        loadingNode?.position = CGPoint(x: size.width/2, y: size.height/2)
        loadingNode?.zPosition = 3
        if let loadingNode = loadingNode {
            addChild(loadingNode)
        }
    }
    
    private func setupRefreshButton() {
        let refreshButton = SKSpriteNode(color: .clear, size: CGSize(width: 44, height: 44))
        refreshButton.position = CGPoint(x: size.width - 50, y: size.height - 50)
        refreshButton.zPosition = 2
        refreshButton.name = "refreshButton"
        
        // Add refresh icon
        if let iconTexture = createSFSymbol("arrow.clockwise") {
            let icon = SKSpriteNode(texture: iconTexture)
            icon.size = CGSize(width: 30, height: 30)
            refreshButton.addChild(icon)
        }
        
        addChild(refreshButton)
    }
    
    private func setupBackButton() {
        let backButton = SKSpriteNode(color: .clear, size: CGSize(width: 44, height: 44))
        backButton.position = CGPoint(x: 50, y: size.height - 50)
        backButton.zPosition = 2
        backButton.name = "backButton"
        
        // Add back icon
        if let iconTexture = createSFSymbol("chevron.left") {
            let icon = SKSpriteNode(texture: iconTexture)
            icon.size = CGSize(width: 30, height: 30)
            backButton.addChild(icon)
        }
        
        addChild(backButton)
    }
    
    // MARK: - Leaderboard Data
    private func loadLeaderboardData() {
        showLoading(true)
        
        // Try to load from Game Center first
        loadGameCenterLeaderboard { [weak self] success in
            if !success {
                // Fallback to local leaderboard
                self?.loadLocalLeaderboard()
            }
        }
    }
    
    private func loadGameCenterLeaderboard(completion: @escaping (Bool) -> Void) {
        guard GKLocalPlayer.local.isAuthenticated else {
            completion(false)
            return
        }
        
        let leaderboardRequest = GKLeaderboard()
        leaderboardRequest.timeScope = .allTime
        leaderboardRequest.playerScope = .global
        leaderboardRequest.range = NSRange(location: 1, length: 100)
        
        leaderboardRequest.loadScores { [weak self] scores, error in
            if let error = error {
                print("Failed to load Game Center scores: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let scores = scores else {
                completion(false)
                return
            }
            
            self?.processGameCenterScores(scores)
            completion(true)
        }
    }
    
    private func processGameCenterScores(_ scores: [GKScore]) {
        leaderboardEntries = scores.enumerated().map { index, score in
            LeaderboardEntry(
                rank: index + 1,
                playerName: score.player.displayName,
                score: Int(score.value),
                wins: Int(score.value), // Assuming score represents wins
                averageReactionTime: 0.5, // Default value
                isCurrentPlayer: score.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
            )
        }
        
        refreshLeaderboardDisplay()
    }
    
    private func loadLocalLeaderboard() {
        // Load from UserDefaults or local database
        // This is a placeholder implementation
        leaderboardEntries = [
            LeaderboardEntry(rank: 1, playerName: "Local Champion", score: 100, wins: 50, averageReactionTime: 0.3, isCurrentPlayer: false),
            LeaderboardEntry(rank: 2, playerName: "Quick Draw McGraw", score: 90, wins: 45, averageReactionTime: 0.35, isCurrentPlayer: false),
            LeaderboardEntry(rank: 3, playerName: "Desert Duelist", score: 80, wins: 40, averageReactionTime: 0.4, isCurrentPlayer: false)
        ]
        
        refreshLeaderboardDisplay()
    }
    
    // MARK: - UI Updates
    private func refreshLeaderboardDisplay() {
        guard let scrollNode = scrollNode else { return }
        
        // Remove existing entries
        scrollNode.removeAllChildren()
        
        // Add new entries
        for (index, entry) in leaderboardEntries.enumerated() {
            let entryNode = createLeaderboardEntryNode(entry)
            entryNode.position = CGPoint(
                x: size.width/2,
                y: -CGFloat(index) * (entryHeight + entrySpacing)
            )
            scrollNode.addChild(entryNode)
        }
        
        showLoading(false)
    }
    
    private func createLeaderboardEntryNode(_ entry: LeaderboardEntry) -> SKNode {
        let containerNode = SKNode()
        
        // Background
        let background = SKShapeNode(rectOf: CGSize(width: size.width * 0.9, height: entryHeight), cornerRadius: 10)
        background.fillColor = entry.isCurrentPlayer ? .yellow.withAlphaComponent(0.3) : .black.withAlphaComponent(0.7)
        background.strokeColor = .white
        background.lineWidth = 2
        containerNode.addChild(background)
        
        // Rank
        let rankLabel = SKLabelNode(fontNamed: "Arial-Bold")
        rankLabel.text = "#\(entry.rank)"
        rankLabel.fontSize = 24
        rankLabel.position = CGPoint(x: -size.width * 0.4, y: 0)
        containerNode.addChild(rankLabel)
        
        // Player Name
        let nameLabel = SKLabelNode(fontNamed: "Arial")
        nameLabel.text = entry.playerName
        nameLabel.fontSize = 20
        nameLabel.position = CGPoint(x: -size.width * 0.2, y: 0)
        containerNode.addChild(nameLabel)
        
        // Stats
        let statsLabel = SKLabelNode(fontNamed: "Arial")
        statsLabel.text = "Wins: \(entry.wins) | Avg: \(String(format: "%.3f", entry.averageReactionTime))s"
        statsLabel.fontSize = 18
        statsLabel.position = CGPoint(x: size.width * 0.2, y: 0)
        containerNode.addChild(statsLabel)
        
        return containerNode
    }
    
    private func showLoading(_ show: Bool) {
        loadingNode?.isHidden = !show
        scrollNode?.isHidden = show
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        for node in nodes {
            if node.name == "refreshButton" {
                handleRefresh()
            } else if node.name == "backButton" {
                handleBack()
            }
        }
    }
    
    private func handleRefresh() {
        loadLeaderboardData()
    }
    
    private func handleBack() {
        let transition = SKTransition.fade(withDuration: 0.5)
        if let scene = LandingScene(size: size) {
            scene.scaleMode = .aspectFill
            view?.presentScene(scene, transition: transition)
        }
    }
    
    // MARK: - Utilities
    private func createLoadingSpinner() -> SKNode {
        let container = SKNode()
        
        let circle = SKShapeNode(circleOfRadius: 20)
        circle.strokeColor = .white
        circle.lineWidth = 2
        container.addChild(circle)
        
        let rotateAction = SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: 1))
        container.run(rotateAction)
        
        return container
    }
    
    private func createSFSymbol(_ name: String) -> SKTexture? {
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        guard let image = UIImage(systemName: name, withConfiguration: config) else {
            return nil
        }
        return SKTexture(image: image)
    }
    
    // MARK: - Cleanup
    override func willMove(from view: SKView) {
        removeAllActions()
        removeAllChildren()
    }
}

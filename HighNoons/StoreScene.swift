import SpriteKit
import StoreKit

class StoreScene: SKScene {
    // MARK: - Properties
    private let translationManager = TranslationManager.shared
    private let audioManager = AudioManager.shared
    private let playerStats = PlayerStats.shared
    private let particleManager = ParticleManager.shared
    
    private var storeItems: [StoreItemNode] = []
    private var tabButtons: [SKSpriteNode] = []
    private var currentTab: StoreTab = .characters
    private var loadingSpinner: SKNode?
    
    // MARK: - Types
    enum StoreTab {
        case characters
        case powerups
        case premium
    }
    
    struct StoreItem {
        let id: String
        let title: String
        let description: String
        let price: String
        let type: StoreTab
        let imageURL: URL
        var isOwned: Bool
        var isSelected: Bool
        
        static var previewCharacters: [StoreItem] {
            return [
                StoreItem(
                    id: "character.sheriff",
                    title: "The Sheriff",
                    description: "Fastest gun in the West",
                    price: "1000",
                    type: .characters,
                    imageURL: URL(string: "https://example.com/sheriff.png")!,
                    isOwned: true,
                    isSelected: true
                ),
                StoreItem(
                    id: "character.outlaw",
                    title: "The Outlaw",
                    description: "Notorious gunslinger",
                    price: "2000",
                    type: .characters,
                    imageURL: URL(string: "https://example.com/outlaw.png")!,
                    isOwned: false,
                    isSelected: false
                )
            ]
        }
        
        static var previewPowerups: [StoreItem] {
            return [
                StoreItem(
                    id: "powerup.slowmo",
                    title: "Slow Motion",
                    description: "Slows down time during draw",
                    price: "500",
                    type: .powerups,
                    imageURL: URL(string: "https://example.com/slowmo.png")!,
                    isOwned: false,
                    isSelected: false
                ),
                StoreItem(
                    id: "powerup.quickdraw",
                    title: "Quick Draw Boost",
                    description: "Improves reaction time",
                    price: "750",
                    type: .powerups,
                    imageURL: URL(string: "https://example.com/quickdraw.png")!,
                    isOwned: false,
                    isSelected: false
                )
            ]
        }
        
        static var previewPremium: [StoreItem] {
            return [
                StoreItem(
                    id: "premium.coins.1000",
                    title: "1000 Coins",
                    description: "Bundle of coins",
                    price: "$0.99",
                    type: .premium,
                    imageURL: URL(string: "https://example.com/coins.png")!,
                    isOwned: false,
                    isSelected: false
                ),
                StoreItem(
                    id: "premium.noads",
                    title: "Remove Ads",
                    description: "Play without interruptions",
                    price: "$4.99",
                    type: .premium,
                    imageURL: URL(string: "https://example.com/noads.png")!,
                    isOwned: false,
                    isSelected: false
                )
            ]
        }
    }
    
    class StoreItemNode: SKNode {
        let item: StoreItem
        private var imageNode: SKSpriteNode
        private var purchaseButton: SKSpriteNode
        private var selectButton: SKSpriteNode
        
        init(item: StoreItem, size: CGSize) {
            self.item = item
            self.imageNode = SKSpriteNode(color: .gray, size: CGSize(width: 100, height: 100))
            self.purchaseButton = SKSpriteNode(color: .green, size: CGSize(width: 100, height: 40))
            self.selectButton = SKSpriteNode(color: .blue, size: CGSize(width: 100, height: 40))
            
            super.init()
            
            setupNode(size: size)
            loadImage()
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
            
            // Image
            imageNode.position = CGPoint(x: 0, y: size.height * 0.2)
            addChild(imageNode)
            
            // Title
            let titleLabel = SKLabelNode(fontNamed: "Western-Font")
            titleLabel.text = item.title
            titleLabel.fontSize = 24
            titleLabel.position = CGPoint(x: 0, y: -size.height * 0.1)
            addChild(titleLabel)
            
            // Description
            let descLabel = SKLabelNode(fontNamed: "Arial")
            descLabel.text = item.description
            descLabel.fontSize = 16
            descLabel.position = CGPoint(x: 0, y: -size.height * 0.2)
            addChild(descLabel)
            
            // Purchase/Select Button
            let button = item.isOwned ? selectButton : purchaseButton
            button.position = CGPoint(x: 0, y: -size.height * 0.35)
            
            let buttonLabel = SKLabelNode(fontNamed: "Arial")
            buttonLabel.text = item.isOwned ? (item.isSelected ? "Selected" : "Select") : item.price
            buttonLabel.fontSize = 18
            buttonLabel.verticalAlignmentMode = .center
            button.addChild(buttonLabel)
            
            addChild(button)
        }
        
        private func loadImage() {
            URLSession.shared.dataTask(with: item.imageURL) { [weak self] data, _, _ in
                guard let data = data,
                      let image = UIImage(data: data) else { return }
                
                DispatchQueue.main.async {
                    self?.imageNode.texture = SKTexture(image: image)
                }
            }.resume()
        }
        
        func updateState() {
            purchaseButton.isHidden = item.isOwned
            selectButton.isHidden = !item.isOwned
            
            if let label = selectButton.children.first as? SKLabelNode {
                label.text = item.isSelected ? "Selected" : "Select"
            }
        }
    }
    
    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        setupScene()
        loadStoreItems()
    }
    
    // MARK: - Setup
    private func setupScene() {
        setupBackground()
        setupTitle()
        setupTabs()
        setupLoadingSpinner()
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
            titleLabel.text = try? await translationManager.translate(.store)
        }
    }
    
    private func setupTabs() {
        let tabWidth = size.width * 0.3
        let tabHeight: CGFloat = 50
        let spacing: CGFloat = 10
        
        let tabs = ["Characters", "Power-ups", "Premium"]
        
        for (index, title) in tabs.enumerated() {
            let xPos = size.width * (0.25 + CGFloat(index) * 0.25)
            let button = createTabButton(
                title: title,
                size: CGSize(width: tabWidth, height: tabHeight),
                position: CGPoint(x: xPos, y: size.height * 0.8)
            )
            tabButtons.append(button)
        }
        
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
        label.fontSize = 20
        label.verticalAlignmentMode = .center
        button.addChild(label)
        
        addChild(button)
        return button
    }
    
    private func setupLoadingSpinner() {
        loadingSpinner = createLoadingSpinner()
        loadingSpinner?.position = CGPoint(x: size.width/2, y: size.height/2)
        loadingSpinner?.isHidden = true
        if let spinner = loadingSpinner {
            addChild(spinner)
        }
    }
    
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
    
    // MARK: - Store Management
    private func loadStoreItems() {
        showLoading(true)
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.displayItems(StoreItem.previewCharacters, type: .characters)
            self?.displayItems(StoreItem.previewPowerups, type: .powerups)
            self?.displayItems(StoreItem.previewPremium, type: .premium)
            self?.showLoading(false)
        }
    }
    
    private func displayItems(_ items: [StoreItem], type: StoreTab) {
        let itemWidth = size.width * 0.4
        let itemHeight: CGFloat = 300
        let spacing: CGFloat = 20
        
        for (index, item) in items.enumerated() {
            let row = CGFloat(index / 2)
            let col = CGFloat(index % 2)
            
            let xPos = size.width * 0.3 + (itemWidth + spacing) * col
            let yPos = size.height * 0.6 - (itemHeight + spacing) * row
            
            let node = StoreItemNode(
                item: item,
                size: CGSize(width: itemWidth, height: itemHeight)
            )
            node.position = CGPoint(x: xPos, y: yPos)
            node.isHidden = type != currentTab
            
            storeItems.append(node)
            addChild(node)
        }
    }
    
    private func updateTabSelection() {
        tabButtons.forEach { button in
            button.alpha = 0.7
        }
        
        let selectedIndex: Int
        switch currentTab {
        case .characters: selectedIndex = 0
        case .powerups: selectedIndex = 1
        case .premium: selectedIndex = 2
        }
        
        tabButtons[selectedIndex].alpha = 1.0
        
        storeItems.forEach { node in
            node.isHidden = node.item.type != currentTab
        }
    }
    
    private func showLoading(_ show: Bool) {
        loadingSpinner?.isHidden = !show
    }
    
    // MARK: - Purchase Handling
    private func handlePurchase(_ item: StoreItem) {
        showLoading(true)
        
        // Simulate purchase process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.showLoading(false)
            self?.completePurchase(item)
        }
    }
    
    private func completePurchase(_ item: StoreItem) {
        // Update item state
        if let index = storeItems.firstIndex(where: { $0.item.id == item.id }) {
            storeItems[index].item.isOwned = true
            storeItems[index].updateState()
        }
        
        // Show success animation
        showPurchaseSuccess()
        
        // Play sound
        audioManager.playSound(.victory)
    }
    
    private func showPurchaseSuccess() {
        let successLabel = SKLabelNode(fontNamed: "Western-Font")
        successLabel.text = "Purchase Successful!"
        successLabel.fontSize = 36
        successLabel.position = CGPoint(x: size.width/2, y: size.height/2)
        successLabel.setScale(0.1)
        addChild(successLabel)
        
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
        
        successLabel.run(sequence)
        
        // Add celebration effect
        particleManager.addConfettiEffect(
            to: self,
            position: CGPoint(x: size.width/2, y: size.height/2)
        )
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Handle tab selection
        for (index, button) in tabButtons.enumerated() {
            if button.contains(location) {
                currentTab = StoreTab.allCases[index]
                updateTabSelection()
                return
            }
        }
        
        // Handle item interaction
        for node in storeItems where !node.isHidden {
            if node.purchaseButton.contains(location) && !node.purchaseButton.isHidden {
                handlePurchase(node.item)
                return
            }
            
            if node.selectButton.contains(location) && !node.selectButton.isHidden {
                handleSelection(node.item)
                return
            }
        }
    }
    
    private func handleSelection(_ item: StoreItem) {
        // Update selection state
        storeItems.forEach { node in
            if node.item.type == item.type {
                node.item.isSelected = node.item.id == item.id
                node.updateState()
            }
        }
        
        // Play sound
        audioManager.playSound(.buttonPress)
    }
    
    // MARK: - Cleanup
    override func willMove(from view: SKView) {
        removeAllActions()
        removeAllChildren()
    }
}

// MARK: - Extensions
extension StoreScene.StoreTab: CaseIterable {
    static var allCases: [StoreScene.StoreTab] = [.characters, .powerups, .premium]
}

extension TranslationManager.TranslationKey {
    static let store = TranslationManager.TranslationKey(rawValue: "store")
}

import SpriteKit
import GameKit

class CharacterSelectionScene: SKScene {
    // MARK: - Properties
    private let translationManager = TranslationManager.shared
    private var characterNodes: [SKSpriteNode] = []
    private var selectedCharacterIndex: Int = 0
    private var confirmButton: SKSpriteNode!
    
    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        setupScene()
        startBackgroundMusic()
    }
    
    // MARK: - Setup
    private func setupScene() {
        setupBackground()
        setupCharacters()
        setupConfirmButton()
        setupTitle()
    }
    
    private func setupBackground() {
        let backgroundNode = SKSpriteNode(color: .brown, size: size)
        backgroundNode.position = CGPoint(x: size.width/2, y: size.height/2)
        backgroundNode.zPosition = -1
        addChild(backgroundNode)
        
        // Load background texture
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
                let backgroundNode = SKSpriteNode(texture: SKTexture(image: image), size: self.size)
                backgroundNode.position = CGPoint(x: self.size.width/2, y: self.size.height/2)
                backgroundNode.zPosition = -1
                self.addChild(backgroundNode)
            }
        }.resume()
    }
    
    private func setupCharacters() {
        let characterNames = ["cowboy", "sheriff", "outlaw"] // Placeholder names
        let characterPositions = [
            CGPoint(x: size.width * 0.3, y: size.height * 0.5),
            CGPoint(x: size.width * 0.5, y: size.height * 0.5),
            CGPoint(x: size.width * 0.7, y: size.height * 0.5)
        ]
        
        for (index, name) in characterNames.enumerated() {
            let characterNode = SKSpriteNode(color: .clear, size: CGSize(width: 100, height: 200))
            characterNode.position = characterPositions[index]
            characterNode.zPosition = 1
            addChild(characterNode)
            characterNodes.append(characterNode)
            
            // Load character texture
            loadCharacterTexture(for: characterNode, name: name)
        }
    }
    
    private func loadCharacterTexture(for node: SKSpriteNode, name: String) {
        // TODO: Replace with actual character URL
        let characterURL = URL(string: "https://images.pexels.com/photos/\(name).png")!
        
        URLSession.shared.dataTask(with: characterURL) { [weak self] data, _, _ in
            guard let data = data,
                  let image = UIImage(data: data),
                  let self = self else { return }
            
            DispatchQueue.main.async {
                node.texture = SKTexture(image: image)
                node.run(SKAction.fadeIn(withDuration: 0.5))
            }
        }.resume()
    }
    
    private func setupConfirmButton() {
        confirmButton = SKSpriteNode(color: .clear, size: CGSize(width: 200, height: 60))
        confirmButton.position = CGPoint(x: size.width / 2, y: size.height * 0.3)
        confirmButton.zPosition = 2
        
        // Create button background
        let background = SKShapeNode(rectOf: confirmButton.size, cornerRadius: 10)
        background.fillColor = .black
        background.alpha = 0.7
        background.strokeColor = .white
        background.lineWidth = 2
        confirmButton.addChild(background)
        
        // Add button label
        let buttonLabel = SKLabelNode(fontNamed: "Arial")
        buttonLabel.text = "Confirm Selection"
        buttonLabel.fontSize = 24
        buttonLabel.position = CGPoint(x: 0, y: 0)
        confirmButton.addChild(buttonLabel)
        
        addChild(confirmButton)
    }
    
    private func setupTitle() {
        let titleLabel = SKLabelNode(fontNamed: "Western-Font") // TODO: Use actual western font
        titleLabel.fontSize = 48
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.8)
        titleLabel.zPosition = 2
        addChild(titleLabel)
        
        // Set localized text
        Task {
            titleLabel.text = try? await translationManager.translate(.startGame)
        }
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if confirmButton.contains(location) {
            handleConfirmSelection()
        } else {
            handleCharacterSelection(at: location)
        }
    }
    
    private func handleCharacterSelection(at location: CGPoint) {
        for (index, characterNode) in characterNodes.enumerated() {
            if characterNode.contains(location) {
                selectedCharacterIndex = index
                highlightSelectedCharacter()
                break
            }
        }
    }
    
    private func highlightSelectedCharacter() {
        for (index, characterNode) in characterNodes.enumerated() {
            characterNode.color = (index == selectedCharacterIndex) ? .yellow : .clear
        }
    }
    
    private func handleConfirmSelection() {
        // Transition to DuelScene with selected character
        let transition = SKTransition.fade(withDuration: 1.0)
        if let scene = DuelScene(size: size) {
            scene.scaleMode = .aspectFill
            view?.presentScene(scene, transition: transition)
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

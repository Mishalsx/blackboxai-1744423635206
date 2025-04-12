import SpriteKit
import UIKit

class SettingsScene: SKScene {
    // MARK: - Properties
    private let translationManager = TranslationManager.shared
    private var soundToggle: SKSpriteNode!
    private var vibrationToggle: SKSpriteNode!
    private var sensitivitySlider: SKSpriteNode!
    private var languageSelector: SKSpriteNode!
    
    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        setupScene()
        startBackgroundMusic()
    }
    
    // MARK: - Setup
    private func setupScene() {
        setupBackground()
        setupTitle()
        setupToggles()
        setupSensitivitySlider()
        setupLanguageSelector()
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
    
    private func setupTitle() {
        let titleLabel = SKLabelNode(fontNamed: "Western-Font") // TODO: Use actual western font
        titleLabel.fontSize = 48
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.8)
        titleLabel.zPosition = 2
        addChild(titleLabel)
        
        // Set localized text
        Task {
            titleLabel.text = try? await translationManager.translate(.settings)
        }
    }
    
    private func setupToggles() {
        // Sound Toggle
        soundToggle = createToggle(at: CGPoint(x: size.width / 2, y: size.height * 0.6), label: "Sound")
        
        // Vibration Toggle
        vibrationToggle = createToggle(at: CGPoint(x: size.width / 2, y: size.height * 0.5), label: "Vibration")
    }
    
    private func createToggle(at position: CGPoint, label: String) -> SKSpriteNode {
        let toggleNode = SKSpriteNode(color: .clear, size: CGSize(width: 200, height: 60))
        toggleNode.position = position
        toggleNode.zPosition = 2
        
        // Create button background
        let background = SKShapeNode(rectOf: toggleNode.size, cornerRadius: 10)
        background.fillColor = .black
        background.alpha = 0.7
        background.strokeColor = .white
        background.lineWidth = 2
        toggleNode.addChild(background)
        
        // Add label
        let toggleLabel = SKLabelNode(fontNamed: "Arial")
        toggleLabel.text = label
        toggleLabel.fontSize = 24
        toggleLabel.position = CGPoint(x: 0, y: 0)
        toggleNode.addChild(toggleLabel)
        
        addChild(toggleNode)
        return toggleNode
    }
    
    private func setupSensitivitySlider() {
        // Create a slider node (placeholder)
        sensitivitySlider = SKSpriteNode(color: .gray, size: CGSize(width: 200, height: 20))
        sensitivitySlider.position = CGPoint(x: size.width / 2, y: size.height * 0.4)
        sensitivitySlider.zPosition = 2
        addChild(sensitivitySlider)
        
        // TODO: Implement actual slider functionality
    }
    
    private func setupLanguageSelector() {
        // Create a language selector node (placeholder)
        languageSelector = SKSpriteNode(color: .blue, size: CGSize(width: 200, height: 60))
        languageSelector.position = CGPoint(x: size.width / 2, y: size.height * 0.3)
        languageSelector.zPosition = 2
        addChild(languageSelector)
        
        // TODO: Implement actual language selection functionality
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if soundToggle.contains(location) {
            handleSoundToggle()
        } else if vibrationToggle.contains(location) {
            handleVibrationToggle()
        } else if sensitivitySlider.contains(location) {
            handleSensitivitySlider()
        } else if languageSelector.contains(location) {
            handleLanguageSelector()
        }
    }
    
    private func handleSoundToggle() {
        // TODO: Implement sound toggle functionality
        audioManager.toggleSound()
    }
    
    private func handleVibrationToggle() {
        // TODO: Implement vibration toggle functionality
    }
    
    private func handleSensitivitySlider() {
        // TODO: Implement sensitivity slider functionality
    }
    
    private func handleLanguageSelector() {
        // TODO: Implement language selection functionality
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

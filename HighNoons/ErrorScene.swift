import SpriteKit

class ErrorScene: SKScene {
    // MARK: - Properties
    private let translationManager = TranslationManager.shared
    private let audioManager = AudioManager.shared
    private let analytics = AnalyticsManager.shared
    private let haptics = HapticsManager.shared
    
    private let error: GameError
    private let previousScene: SKScene.Type
    
    private var containerNode: SKNode!
    private var retryButton: SKSpriteNode!
    private var supportButton: SKSpriteNode!
    
    // MARK: - Types
    enum GameError {
        case network(Error)
        case server(Int)
        case authentication
        case maintenance
        case deviceNotSupported
        case sensorUnavailable
        case storageError
        case gameCenter
        case custom(String)
        
        var title: String {
            switch self {
            case .network: return "Connection Error"
            case .server: return "Server Error"
            case .authentication: return "Authentication Failed"
            case .maintenance: return "Maintenance"
            case .deviceNotSupported: return "Device Not Supported"
            case .sensorUnavailable: return "Sensor Unavailable"
            case .storageError: return "Storage Error"
            case .gameCenter: return "Game Center Error"
            case .custom: return "Error"
            }
        }
        
        var message: String {
            switch self {
            case .network:
                return "Unable to connect to the server. Please check your internet connection and try again."
            case .server(let code):
                return "Server error occurred (Code: \(code)). Please try again later."
            case .authentication:
                return "Unable to authenticate. Please sign in and try again."
            case .maintenance:
                return "High Noons is currently under maintenance. Please try again later."
            case .deviceNotSupported:
                return "Your device does not support all required features for High Noons."
            case .sensorUnavailable:
                return "Unable to access motion sensors. Please ensure they are enabled in your device settings."
            case .storageError:
                return "Unable to save game data. Please ensure you have enough storage space."
            case .gameCenter:
                return "Unable to connect to Game Center. Please sign in to Game Center and try again."
            case .custom(let message):
                return message
            }
        }
        
        var canRetry: Bool {
            switch self {
            case .network, .server, .authentication, .gameCenter:
                return true
            case .maintenance, .deviceNotSupported, .sensorUnavailable, .storageError, .custom:
                return false
            }
        }
        
        var shouldShowSupport: Bool {
            switch self {
            case .deviceNotSupported, .sensorUnavailable, .storageError:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    init(size: CGSize, error: GameError, previousScene: SKScene.Type) {
        self.error = error
        self.previousScene = previousScene
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        setupScene()
        animateIn()
        logError()
        haptics.playPattern(.failure)
    }
    
    // MARK: - Setup
    private func setupScene() {
        setupBackground()
        setupContainer()
        setupErrorContent()
        setupButtons()
    }
    
    private func setupBackground() {
        let backgroundNode = SKSpriteNode(color: .black, size: size)
        backgroundNode.position = CGPoint(x: size.width/2, y: size.height/2)
        backgroundNode.alpha = 0.8
        backgroundNode.zPosition = -1
        addChild(backgroundNode)
    }
    
    private func setupContainer() {
        containerNode = SKNode()
        containerNode.position = CGPoint(x: size.width/2, y: size.height/2)
        containerNode.alpha = 0
        addChild(containerNode)
        
        // Container background
        let background = SKShapeNode(rectOf: CGSize(width: size.width * 0.8, height: size.height * 0.6), cornerRadius: 20)
        background.fillColor = UIConfig.backgroundColor
        background.strokeColor = UIConfig.primaryColor
        background.lineWidth = 2
        containerNode.addChild(background)
    }
    
    private func setupErrorContent() {
        // Error icon
        let iconNode = SKSpriteNode(imageNamed: "error_icon")
        iconNode.position = CGPoint(x: 0, y: size.height * 0.15)
        iconNode.setScale(0.5)
        containerNode.addChild(iconNode)
        
        // Title
        let titleLabel = SKLabelNode(fontNamed: UIConfig.titleFont)
        titleLabel.text = error.title
        titleLabel.fontSize = UIConfig.titleFontSize
        titleLabel.position = CGPoint(x: 0, y: size.height * 0.05)
        containerNode.addChild(titleLabel)
        
        // Message
        let messageLabel = SKLabelNode(fontNamed: UIConfig.bodyFont)
        messageLabel.text = error.message
        messageLabel.fontSize = UIConfig.bodyFontSize
        messageLabel.numberOfLines = 0
        messageLabel.preferredMaxLayoutWidth = size.width * 0.7
        messageLabel.position = CGPoint(x: 0, y: -size.height * 0.05)
        containerNode.addChild(messageLabel)
    }
    
    private func setupButtons() {
        let buttonSize = CGSize(width: 200, height: UIConfig.buttonHeight)
        let spacing: CGFloat = UIConfig.standardSpacing
        
        if error.canRetry {
            retryButton = createButton(
                text: "Retry",
                size: buttonSize,
                position: CGPoint(x: 0, y: -size.height * 0.2)
            )
            containerNode.addChild(retryButton)
        }
        
        if error.shouldShowSupport {
            supportButton = createButton(
                text: "Support",
                size: buttonSize,
                position: CGPoint(x: 0, y: -size.height * 0.2 - (error.canRetry ? spacing + buttonSize.height : 0))
            )
            containerNode.addChild(supportButton)
        }
    }
    
    private func createButton(text: String, size: CGSize, position: CGPoint) -> SKSpriteNode {
        let button = SKSpriteNode(color: .clear, size: size)
        button.position = position
        
        let background = SKShapeNode(rectOf: size, cornerRadius: UIConfig.cornerRadius)
        background.fillColor = UIConfig.primaryColor
        background.strokeColor = .white
        background.lineWidth = UIConfig.borderWidth
        button.addChild(background)
        
        let label = SKLabelNode(fontNamed: UIConfig.bodyFont)
        label.text = text
        label.fontSize = UIConfig.bodyFontSize
        label.verticalAlignmentMode = .center
        button.addChild(label)
        
        return button
    }
    
    // MARK: - Animations
    private func animateIn() {
        containerNode.setScale(0.5)
        containerNode.run(SKAction.group([
            SKAction.fadeIn(withDuration: UIConfig.fadeInDuration),
            SKAction.scale(to: 1.0, duration: UIConfig.fadeInDuration)
        ]))
    }
    
    private func animateOut(completion: @escaping () -> Void) {
        containerNode.run(SKAction.group([
            SKAction.fadeOut(withDuration: UIConfig.fadeOutDuration),
            SKAction.scale(to: 0.5, duration: UIConfig.fadeOutDuration)
        ])) {
            completion()
        }
    }
    
    // MARK: - Actions
    private func handleRetry() {
        animateOut { [weak self] in
            guard let self = self else { return }
            
            let transition = SKTransition.fade(withDuration: UIConfig.fadeOutDuration)
            if let scene = self.previousScene.init(size: self.size) as? SKScene {
                scene.scaleMode = .aspectFill
                self.view?.presentScene(scene, transition: transition)
            }
        }
    }
    
    private func handleSupport() {
        if let url = URL(string: "https://support.highnoons.com") {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Analytics
    private func logError() {
        analytics.trackEvent(.networkError(
            api: "game",
            code: error.analyticsCode
        ))
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if let retryButton = retryButton, retryButton.contains(location) {
            audioManager.playSound(.buttonPress)
            haptics.playPattern(.success)
            handleRetry()
        } else if let supportButton = supportButton, supportButton.contains(location) {
            audioManager.playSound(.buttonPress)
            haptics.playPattern(.success)
            handleSupport()
        }
    }
    
    // MARK: - Cleanup
    override func willMove(from view: SKView) {
        removeAllActions()
        removeAllChildren()
    }
}

// MARK: - Error Extension
private extension ErrorScene.GameError {
    var analyticsCode: Int {
        switch self {
        case .network: return 1001
        case .server(let code): return code
        case .authentication: return 1002
        case .maintenance: return 1003
        case .deviceNotSupported: return 1004
        case .sensorUnavailable: return 1005
        case .storageError: return 1006
        case .gameCenter: return 1007
        case .custom: return 1000
        }
    }
}

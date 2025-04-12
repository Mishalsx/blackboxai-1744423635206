import SpriteKit

final class PopupManager {
    // MARK: - Properties
    static let shared = PopupManager()
    
    private let audioManager = AudioManager.shared
    private let haptics = HapticsManager.shared
    
    private var currentPopup: PopupNode?
    private var queue: [PopupNode] = []
    private weak var currentScene: SKScene?
    
    // MARK: - Types
    enum PopupStyle {
        case alert
        case reward
        case achievement
        case levelUp
        case dailyReward
        case purchase
        case rateApp
        case custom(String)
        
        var backgroundColor: UIColor {
            switch self {
            case .alert: return .black.withAlphaComponent(0.9)
            case .reward, .achievement: return UIConfig.primaryColor.withAlphaComponent(0.9)
            case .levelUp: return UIConfig.accentColor.withAlphaComponent(0.9)
            case .dailyReward: return UIConfig.primaryColor.withAlphaComponent(0.9)
            case .purchase: return UIConfig.secondaryColor.withAlphaComponent(0.9)
            case .rateApp, .custom: return UIConfig.backgroundColor.withAlphaComponent(0.9)
            }
        }
        
        var icon: String {
            switch self {
            case .alert: return "icon_alert"
            case .reward: return "icon_reward"
            case .achievement: return "icon_achievement"
            case .levelUp: return "icon_levelup"
            case .dailyReward: return "icon_daily"
            case .purchase: return "icon_purchase"
            case .rateApp: return "icon_rate"
            case .custom(let name): return name
            }
        }
    }
    
    class PopupNode: SKNode {
        let style: PopupStyle
        let title: String
        let message: String
        let buttons: [PopupButton]
        var completion: (() -> Void)?
        
        private var containerNode: SKShapeNode!
        private var buttonNodes: [SKSpriteNode] = []
        
        init(style: PopupStyle, title: String, message: String, buttons: [PopupButton]) {
            self.style = style
            self.title = title
            self.message = message
            self.buttons = buttons
            super.init()
            
            setupPopup()
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupPopup() {
            // Background overlay
            let overlay = SKShapeNode(rectOf: UIScreen.main.bounds.size)
            overlay.fillColor = .black
            overlay.strokeColor = .clear
            overlay.alpha = 0.5
            overlay.zPosition = 998
            addChild(overlay)
            
            // Container
            let containerSize = CGSize(width: 300, height: 400)
            containerNode = SKShapeNode(rectOf: containerSize, cornerRadius: UIConfig.cornerRadius)
            containerNode.fillColor = style.backgroundColor
            containerNode.strokeColor = .white
            containerNode.lineWidth = UIConfig.borderWidth
            containerNode.zPosition = 999
            addChild(containerNode)
            
            // Icon
            let iconNode = SKSpriteNode(imageNamed: style.icon)
            iconNode.setScale(0.5)
            iconNode.position = CGPoint(x: 0, y: containerSize.height * 0.25)
            containerNode.addChild(iconNode)
            
            // Title
            let titleLabel = SKLabelNode(fontNamed: UIConfig.titleFont)
            titleLabel.text = title
            titleLabel.fontSize = UIConfig.titleFontSize
            titleLabel.position = CGPoint(x: 0, y: containerSize.height * 0.1)
            containerNode.addChild(titleLabel)
            
            // Message
            let messageLabel = SKLabelNode(fontNamed: UIConfig.bodyFont)
            messageLabel.text = message
            messageLabel.fontSize = UIConfig.bodyFontSize
            messageLabel.numberOfLines = 0
            messageLabel.preferredMaxLayoutWidth = containerSize.width * 0.8
            messageLabel.position = CGPoint(x: 0, y: 0)
            containerNode.addChild(messageLabel)
            
            // Buttons
            setupButtons(containerSize: containerSize)
        }
        
        private func setupButtons(containerSize: CGSize) {
            let buttonWidth = containerSize.width * 0.8
            let buttonHeight = UIConfig.buttonHeight
            let buttonSpacing = UIConfig.standardSpacing
            
            for (index, button) in buttons.enumerated() {
                let yPos = -containerSize.height * 0.3 + CGFloat(index) * (buttonHeight + buttonSpacing)
                let buttonNode = createButton(
                    text: button.title,
                    style: button.style,
                    size: CGSize(width: buttonWidth, height: buttonHeight),
                    position: CGPoint(x: 0, y: yPos)
                )
                containerNode.addChild(buttonNode)
                buttonNodes.append(buttonNode)
            }
        }
        
        private func createButton(text: String, style: PopupButton.Style, size: CGSize, position: CGPoint) -> SKSpriteNode {
            let button = SKSpriteNode(color: .clear, size: size)
            button.position = position
            
            let background = SKShapeNode(rectOf: size, cornerRadius: UIConfig.cornerRadius)
            background.fillColor = style.backgroundColor
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
        
        func handleTouch(_ location: CGPoint) -> Int? {
            for (index, button) in buttonNodes.enumerated() {
                if button.contains(location) {
                    return index
                }
            }
            return nil
        }
        
        func animateIn() {
            containerNode.setScale(0.5)
            containerNode.alpha = 0
            
            let scaleAction = SKAction.scale(to: 1.0, duration: UIConfig.fadeInDuration)
            let fadeAction = SKAction.fadeIn(withDuration: UIConfig.fadeInDuration)
            
            containerNode.run(SKAction.group([scaleAction, fadeAction]))
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let scaleAction = SKAction.scale(to: 0.5, duration: UIConfig.fadeOutDuration)
            let fadeAction = SKAction.fadeOut(withDuration: UIConfig.fadeOutDuration)
            
            containerNode.run(SKAction.group([scaleAction, fadeAction])) {
                completion()
            }
        }
    }
    
    struct PopupButton {
        let title: String
        let style: Style
        let action: () -> Void
        
        enum Style {
            case primary
            case secondary
            case destructive
            
            var backgroundColor: UIColor {
                switch self {
                case .primary: return UIConfig.primaryColor
                case .secondary: return UIConfig.secondaryColor
                case .destructive: return .red
                }
            }
        }
    }
    
    // MARK: - Public Methods
    func showPopup(
        style: PopupStyle,
        title: String,
        message: String,
        buttons: [PopupButton],
        in scene: SKScene,
        completion: (() -> Void)? = nil
    ) {
        let popup = PopupNode(style: style, title: title, message: message, buttons: buttons)
        popup.completion = completion
        
        if currentPopup != nil {
            queue.append(popup)
        } else {
            display(popup, in: scene)
        }
    }
    
    func dismissCurrentPopup() {
        guard let popup = currentPopup else { return }
        
        audioManager.playSound(.buttonPress)
        haptics.playPattern(.success)
        
        popup.animateOut { [weak self] in
            popup.removeFromParent()
            self?.currentPopup = nil
            self?.showNextPopup()
        }
    }
    
    // MARK: - Private Methods
    private func display(_ popup: PopupNode, in scene: SKScene) {
        currentScene = scene
        currentPopup = popup
        
        popup.position = CGPoint(x: scene.size.width/2, y: scene.size.height/2)
        scene.addChild(popup)
        
        audioManager.playSound(.popup)
        haptics.playPattern(.success)
        
        popup.animateIn()
    }
    
    private func showNextPopup() {
        guard let scene = currentScene, let nextPopup = queue.first else { return }
        
        queue.removeFirst()
        display(nextPopup, in: scene)
    }
    
    // MARK: - Touch Handling
    func handleTouch(_ location: CGPoint) -> Bool {
        guard let popup = currentPopup else { return false }
        
        if let buttonIndex = popup.handleTouch(location) {
            let button = popup.buttons[buttonIndex]
            
            audioManager.playSound(.buttonPress)
            haptics.playPattern(.success)
            
            button.action()
            dismissCurrentPopup()
            return true
        }
        
        return false
    }
}

// MARK: - Convenience Methods
extension PopupManager {
    func showAlert(
        title: String,
        message: String,
        in scene: SKScene,
        completion: (() -> Void)? = nil
    ) {
        showPopup(
            style: .alert,
            title: title,
            message: message,
            buttons: [
                PopupButton(title: "OK", style: .primary) {}
            ],
            in: scene,
            completion: completion
        )
    }
    
    func showReward(
        amount: Int,
        message: String,
        in scene: SKScene,
        completion: (() -> Void)? = nil
    ) {
        showPopup(
            style: .reward,
            title: "Reward!",
            message: "\(message)\n+\(amount) XP",
            buttons: [
                PopupButton(title: "Collect", style: .primary) {}
            ],
            in: scene,
            completion: completion
        )
    }
    
    func showAchievement(
        title: String,
        description: String,
        in scene: SKScene,
        completion: (() -> Void)? = nil
    ) {
        showPopup(
            style: .achievement,
            title: "Achievement Unlocked!",
            message: "\(title)\n\(description)",
            buttons: [
                PopupButton(title: "Awesome!", style: .primary) {}
            ],
            in: scene,
            completion: completion
        )
    }
}

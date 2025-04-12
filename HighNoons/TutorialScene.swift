import SpriteKit
import CoreMotion

class TutorialScene: SKScene {
    // MARK: - Properties
    private let translationManager = TranslationManager.shared
    private let audioManager = AudioManager.shared
    private let particleManager = ParticleManager.shared
    private let sensorManager = SensorManager.shared
    
    private var currentStep = 0
    private var tutorialSteps: [TutorialStep] = []
    private var demonstrationTimer: Timer?
    
    // UI Nodes
    private var instructionLabel: SKLabelNode!
    private var playerNode: SKSpriteNode!
    private var targetNode: SKSpriteNode!
    private var nextButton: SKSpriteNode!
    private var skipButton: SKSpriteNode!
    
    // Tutorial State
    private var canInteract = false
    private var isDemonstrating = false
    
    // MARK: - Types
    struct TutorialStep {
        let instruction: String
        let demonstration: (() -> Void)?
        let completion: (() -> Bool)?
        let duration: TimeInterval
    }
    
    // MARK: - Lifecycle
    override func didMove(to view: SKView) {
        setupScene()
        setupTutorialSteps()
        startTutorial()
    }
    
    // MARK: - Setup
    private func setupScene() {
        setupBackground()
        setupCharacters()
        setupUI()
        setupButtons()
    }
    
    private func setupBackground() {
        let backgroundNode = SKSpriteNode(color: .brown, size: size)
        backgroundNode.position = CGPoint(x: size.width/2, y: size.height/2)
        backgroundNode.zPosition = -1
        addChild(backgroundNode)
        
        // Add ambient dust effect
        particleManager.startAmbientEffects(in: self)
    }
    
    private func setupCharacters() {
        // Player character
        playerNode = SKSpriteNode(color: .blue, size: CGSize(width: 100, height: 200))
        playerNode.position = CGPoint(x: size.width * 0.25, y: size.height * 0.3)
        playerNode.zPosition = 1
        addChild(playerNode)
        
        // Target/opponent character
        targetNode = SKSpriteNode(color: .red, size: CGSize(width: 100, height: 200))
        targetNode.position = CGPoint(x: size.width * 0.75, y: size.height * 0.3)
        targetNode.zPosition = 1
        addChild(targetNode)
    }
    
    private func setupUI() {
        // Instruction label
        instructionLabel = SKLabelNode(fontNamed: "Western-Font") // TODO: Use actual western font
        instructionLabel.fontSize = 32
        instructionLabel.numberOfLines = 3
        instructionLabel.position = CGPoint(x: size.width/2, y: size.height * 0.8)
        instructionLabel.zPosition = 2
        addChild(instructionLabel)
    }
    
    private func setupButtons() {
        // Next button
        nextButton = createButton(
            text: "Next",
            position: CGPoint(x: size.width * 0.8, y: size.height * 0.1)
        )
        
        // Skip button
        skipButton = createButton(
            text: "Skip Tutorial",
            position: CGPoint(x: size.width * 0.2, y: size.height * 0.1)
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
    
    // MARK: - Tutorial Steps
    private func setupTutorialSteps() {
        tutorialSteps = [
            // Welcome
            TutorialStep(
                instruction: "Welcome to High Noons! Let's learn how to become a quick-draw champion.",
                demonstration: nil,
                completion: nil,
                duration: 3.0
            ),
            
            // Phone raising
            TutorialStep(
                instruction: "First, raise your phone upright like a holstered gun.",
                demonstration: demonstratePhoneRaising,
                completion: checkPhoneRaised,
                duration: 5.0
            ),
            
            // Waiting
            TutorialStep(
                instruction: "When the duel begins, wait for the 'DRAW!' signal.",
                demonstration: demonstrateWaiting,
                completion: nil,
                duration: 4.0
            ),
            
            // Quick draw
            TutorialStep(
                instruction: "When you see 'DRAW!', tap anywhere to shoot! The fastest draw wins.",
                demonstration: demonstrateQuickDraw,
                completion: checkPlayerShot,
                duration: 5.0
            ),
            
            // Timing
            TutorialStep(
                instruction: "But be careful! Shooting before the signal means instant defeat.",
                demonstration: demonstrateEarlyShot,
                completion: nil,
                duration: 4.0
            ),
            
            // Practice
            TutorialStep(
                instruction: "Let's practice! Raise your phone and wait for the signal.",
                demonstration: nil,
                completion: checkFullDuel,
                duration: 8.0
            )
        ]
    }
    
    // MARK: - Tutorial Flow
    private func startTutorial() {
        showCurrentStep()
    }
    
    private func showCurrentStep() {
        guard currentStep < tutorialSteps.count else {
            completeTutorial()
            return
        }
        
        let step = tutorialSteps[currentStep]
        
        // Update instruction
        Task {
            instructionLabel.text = try? await translationManager.translate(.custom(step.instruction))
        }
        
        // Start demonstration if available
        if let demo = step.demonstration {
            isDemonstrating = true
            demo()
        }
        
        // Set up completion check
        if let completion = step.completion {
            canInteract = true
            checkCompletion(completion)
        } else {
            // Auto-advance after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + step.duration) { [weak self] in
                self?.advanceStep()
            }
        }
    }
    
    private func checkCompletion(_ completion: @escaping () -> Bool) {
        demonstrationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            if completion() {
                timer.invalidate()
                self?.advanceStep()
            }
        }
    }
    
    private func advanceStep() {
        demonstrationTimer?.invalidate()
        demonstrationTimer = nil
        isDemonstrating = false
        canInteract = false
        currentStep += 1
        showCurrentStep()
    }
    
    private func completeTutorial() {
        // Transition to character selection
        let transition = SKTransition.fade(withDuration: 1.0)
        if let scene = CharacterSelectionScene(size: size) {
            scene.scaleMode = .aspectFill
            view?.presentScene(scene, transition: transition)
        }
    }
    
    // MARK: - Demonstrations
    private func demonstratePhoneRaising() {
        let raiseAction = SKAction.sequence([
            SKAction.moveBy(y: 50, duration: 1.0),
            SKAction.wait(forDuration: 1.0),
            SKAction.moveBy(y: -50, duration: 1.0)
        ])
        playerNode.run(raiseAction)
    }
    
    private func demonstrateWaiting() {
        let waitAction = SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in
                self?.showDrawSignal()
            }
        ])
        run(waitAction)
    }
    
    private func demonstrateQuickDraw() {
        let sequence = SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run { [weak self] in
                self?.showDrawSignal()
            },
            SKAction.wait(forDuration: 0.5),
            SKAction.run { [weak self] in
                self?.demonstrateShot()
            }
        ])
        run(sequence)
    }
    
    private func demonstrateEarlyShot() {
        let sequence = SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run { [weak self] in
                self?.demonstrateShot()
            },
            SKAction.wait(forDuration: 0.5),
            SKAction.run { [weak self] in
                self?.showFailure()
            }
        ])
        run(sequence)
    }
    
    // MARK: - Visual Effects
    private func showDrawSignal() {
        let drawLabel = SKLabelNode(fontNamed: "Western-Font")
        drawLabel.text = "DRAW!"
        drawLabel.fontSize = 64
        drawLabel.position = CGPoint(x: size.width/2, y: size.height * 0.6)
        drawLabel.setScale(0.1)
        addChild(drawLabel)
        
        let scaleAction = SKAction.sequence([
            SKAction.scale(to: 1.5, duration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.1),
            SKAction.wait(forDuration: 1.0),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ])
        
        drawLabel.run(scaleAction)
        audioManager.playSound(.draw)
    }
    
    private func demonstrateShot() {
        // Muzzle flash
        particleManager.addMuzzleFlashEffect(
            to: self,
            position: playerNode.position,
            rotation: 0
        )
        
        // Impact effect
        particleManager.addImpactEffect(
            to: self,
            position: targetNode.position
        )
        
        audioManager.playSound(.gunshot)
    }
    
    private func showFailure() {
        let failLabel = SKLabelNode(fontNamed: "Western-Font")
        failLabel.text = "Too Early!"
        failLabel.fontSize = 48
        failLabel.position = CGPoint(x: size.width/2, y: size.height * 0.6)
        failLabel.fontColor = .red
        addChild(failLabel)
        
        let sequence = SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ])
        
        failLabel.run(sequence)
        audioManager.playSound(.fail)
    }
    
    // MARK: - Completion Checks
    private func checkPhoneRaised() -> Bool {
        return sensorManager.isPhoneRaised()
    }
    
    private func checkPlayerShot() -> Bool {
        // Implemented in touch handling
        return false
    }
    
    private func checkFullDuel() -> Bool {
        // Implemented in touch handling
        return false
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if nextButton.contains(location) {
            advanceStep()
        } else if skipButton.contains(location) {
            completeTutorial()
        } else if canInteract {
            handleInteraction()
        }
    }
    
    private func handleInteraction() {
        // Handle based on current step
        switch currentStep {
        case 3: // Quick draw step
            demonstrateShot()
            advanceStep()
        case 5: // Practice step
            if isDemonstrating {
                showFailure()
            } else {
                demonstrateShot()
                advanceStep()
            }
        default:
            break
        }
    }
    
    // MARK: - Cleanup
    override func willMove(from view: SKView) {
        demonstrationTimer?.invalidate()
        removeAllActions()
        removeAllChildren()
    }
}

// MARK: - Translation Extension
extension TranslationManager.TranslationKey {
    static func custom(_ text: String) -> TranslationManager.TranslationKey {
        // Add custom translation key handling
        return .startGame // Placeholder
    }
}

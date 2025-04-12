import SpriteKit
import GameKit

class LoadingScene: SKScene {
    // MARK: - Properties
    private let translationManager = TranslationManager.shared
    private let audioManager = AudioManager.shared
    private let networkManager = NetworkManager.shared
    private let playerStats = PlayerStats.shared
    private let analytics = AnalyticsManager.shared
    
    private var loadingBar: SKShapeNode!
    private var loadingLabel: SKLabelNode!
    private var progressLabel: SKLabelNode!
    private var retryButton: SKSpriteNode!
    
    private var totalSteps = 7
    private var currentStep = 0
    private var isRetrying = false
    
    // Loading States
    private enum LoadingState {
        case checking
        case loading
        case error
        case complete
    }
    
    private var currentState: LoadingState = .checking {
        didSet {
            updateUI()
        }
    }
    
    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        analytics.startLoadingTimer(for: "loading_scene")
        setupScene()
        startLoading()
    }
    
    // MARK: - Setup
    private func setupScene() {
        setupBackground()
        setupLoadingBar()
        setupLabels()
        setupRetryButton()
    }
    
    private func setupBackground() {
        let backgroundNode = SKSpriteNode(color: .brown, size: size)
        backgroundNode.position = CGPoint(x: size.width/2, y: size.height/2)
        backgroundNode.zPosition = -1
        addChild(backgroundNode)
        
        // Add logo
        let logoNode = SKSpriteNode(imageNamed: "logo")
        logoNode.position = CGPoint(x: size.width/2, y: size.height * 0.7)
        logoNode.setScale(0.8)
        addChild(logoNode)
    }
    
    private func setupLoadingBar() {
        // Background bar
        let barWidth = size.width * 0.7
        let barHeight: CGFloat = 20
        let backgroundBar = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 10)
        backgroundBar.fillColor = .gray
        backgroundBar.strokeColor = .white
        backgroundBar.position = CGPoint(x: size.width/2, y: size.height * 0.4)
        backgroundBar.zPosition = 1
        addChild(backgroundBar)
        
        // Progress bar
        loadingBar = SKShapeNode(rectOf: CGSize(width: 0, height: barHeight), cornerRadius: 10)
        loadingBar.fillColor = .green
        loadingBar.strokeColor = .clear
        loadingBar.position = backgroundBar.position
        loadingBar.zPosition = 2
        addChild(loadingBar)
    }
    
    private func setupLabels() {
        // Loading label
        loadingLabel = SKLabelNode(fontNamed: "Western-Font")
        loadingLabel.fontSize = 32
        loadingLabel.position = CGPoint(x: size.width/2, y: size.height * 0.45)
        loadingLabel.zPosition = 2
        addChild(loadingLabel)
        
        // Progress label
        progressLabel = SKLabelNode(fontNamed: "Arial")
        progressLabel.fontSize = 24
        progressLabel.position = CGPoint(x: size.width/2, y: size.height * 0.35)
        progressLabel.zPosition = 2
        addChild(progressLabel)
    }
    
    private func setupRetryButton() {
        retryButton = SKSpriteNode(color: .clear, size: CGSize(width: 200, height: 60))
        retryButton.position = CGPoint(x: size.width/2, y: size.height * 0.3)
        retryButton.zPosition = 2
        
        let background = SKShapeNode(rectOf: retryButton.size, cornerRadius: 10)
        background.fillColor = .black
        background.alpha = 0.7
        background.strokeColor = .white
        retryButton.addChild(background)
        
        let label = SKLabelNode(fontNamed: "Arial")
        label.text = "Retry"
        label.fontSize = 24
        label.verticalAlignmentMode = .center
        retryButton.addChild(label)
        
        retryButton.isHidden = true
        addChild(retryButton)
    }
    
    // MARK: - Loading Process
    private func startLoading() {
        currentState = .checking
        checkNetworkConnection()
    }
    
    private func checkNetworkConnection() {
        if networkManager.isReachable() {
            currentState = .loading
            loadNextStep()
        } else {
            currentState = .error
            showError("No internet connection")
        }
    }
    
    private func loadNextStep() {
        currentStep += 1
        updateProgress()
        
        switch currentStep {
        case 1:
            loadTranslations()
        case 2:
            authenticateGameCenter()
        case 3:
            loadUserData()
        case 4:
            loadAudioAssets()
        case 5:
            loadGameAssets()
        case 6:
            loadPlayerPreferences()
        case 7:
            finishLoading()
        default:
            break
        }
    }
    
    private func updateProgress() {
        let progress = CGFloat(currentStep) / CGFloat(totalSteps)
        let barWidth = size.width * 0.7 * progress
        
        loadingBar.run(SKAction.resize(toWidth: barWidth, duration: 0.3))
        progressLabel.text = "\(Int(progress * 100))%"
    }
    
    // MARK: - Loading Steps
    private func loadTranslations() {
        Task {
            do {
                try await translationManager.loadTranslations()
                loadingLabel.text = try await translationManager.translate(.loading)
                loadNextStep()
            } catch {
                handleError(error)
            }
        }
    }
    
    private func authenticateGameCenter() {
        let localPlayer = GKLocalPlayer.local
        localPlayer.authenticateHandler = { [weak self] viewController, error in
            if let error = error {
                print("GameCenter authentication failed: \(error.localizedDescription)")
            }
            // Continue regardless of authentication result
            self?.loadNextStep()
        }
    }
    
    private func loadUserData() {
        Task {
            do {
                if let token = UserDefaults.standard.string(forKey: "authToken") {
                    networkManager.setAuthToken(token)
                    // Load user data
                }
                loadNextStep()
            } catch {
                handleError(error)
            }
        }
    }
    
    private func loadAudioAssets() {
        Task {
            do {
                try await audioManager.preloadSounds()
                loadNextStep()
            } catch {
                handleError(error)
            }
        }
    }
    
    private func loadGameAssets() {
        // Load textures, particles, etc.
        loadNextStep()
    }
    
    private func loadPlayerPreferences() {
        // Load settings and preferences
        loadNextStep()
    }
    
    private func finishLoading() {
        currentState = .complete
        analytics.stopLoadingTimer(for: "loading_scene")
        
        // Transition to appropriate scene
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.transitionToNextScene()
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) {
        currentState = .error
        showError(error.localizedDescription)
    }
    
    private func showError(_ message: String) {
        loadingLabel.text = "Error"
        progressLabel.text = message
        retryButton.isHidden = false
        
        analytics.trackEvent(.networkError(
            api: "loading",
            code: 0
        ))
    }
    
    // MARK: - Navigation
    private func transitionToNextScene() {
        let nextScene: SKScene
        
        if UserDefaults.standard.bool(forKey: "hasCompletedTutorial") {
            nextScene = LandingScene(size: size)
        } else {
            nextScene = TutorialScene(size: size)
        }
        
        let transition = SKTransition.fade(withDuration: 1.0)
        nextScene.scaleMode = .aspectFill
        view?.presentScene(nextScene, transition: transition)
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if !retryButton.isHidden && retryButton.contains(location) {
            retryButton.isHidden = true
            isRetrying = true
            currentStep = 0
            startLoading()
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
    static let loading = TranslationManager.TranslationKey(rawValue: "loading")
}

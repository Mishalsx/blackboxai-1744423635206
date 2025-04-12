import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    // MARK: - Properties
    private var skView: SKView!
    private let gameManager = GameManager.shared
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSKView()
        loadInitialScene()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Force portrait orientation for gameplay
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue,
                                forKey: "orientation")
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Setup
    private func setupSKView() {
        skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(skView)
        
        // Configure SKView
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false        // Set to true for debugging
        skView.showsNodeCount = false  // Set to true for debugging
        skView.showsPhysics = false    // Set to true for debugging
    }
    
    private func loadInitialScene() {
        guard let scene = DuelScene(size: view.bounds.size) else {
            fatalError("Failed to create DuelScene")
        }
        
        // Configure scene
        scene.scaleMode = .aspectFill
        
        // Present scene with transition
        let transition = SKTransition.fade(withDuration: 1.0)
        skView.presentScene(scene, transition: transition)
    }
    
    // MARK: - Scene Management
    func transitionToScene(_ scene: SKScene, withTransition transition: SKTransition? = nil) {
        // Configure scene
        scene.scaleMode = .aspectFill
        
        if let transition = transition {
            skView.presentScene(scene, transition: transition)
        } else {
            skView.presentScene(scene)
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: "An error occurred: \(error.localizedDescription)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: "OK",
            style: .default,
            handler: nil
        ))
        
        present(alert, animated: true)
    }
}

// MARK: - Scene Transitions
extension GameViewController {
    func showMainMenu() {
        // TODO: Implement main menu transition
    }
    
    func showCharacterSelection() {
        // TODO: Implement character selection transition
    }
    
    func showSettings() {
        // TODO: Implement settings transition
    }
    
    func showLeaderboard() {
        // TODO: Implement leaderboard transition
    }
}

// MARK: - Game State Observer
extension GameViewController {
    func observeGameState() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGameStateChange(_:)),
            name: .gameStateDidChange,
            object: nil
        )
    }
    
    @objc private func handleGameStateChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let oldState = userInfo["oldState"] as? GameManager.GameState,
              let newState = userInfo["newState"] as? GameManager.GameState else {
            return
        }
        
        // Handle state transitions
        switch newState {
        case .menu:
            showMainMenu()
        case .waiting:
            // Update UI for waiting state
            break
        case .ready:
            // Update UI for ready state
            break
        case .drawing:
            // Update UI for drawing state
            break
        case .complete:
            // Show results
            break
        }
    }
}

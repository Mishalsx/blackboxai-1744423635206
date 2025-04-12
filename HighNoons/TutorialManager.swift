import Foundation
import SpriteKit

final class TutorialManager {
    // MARK: - Properties
    static let shared = TutorialManager()
    
    private let analytics = AnalyticsManager.shared
    private let playerStats = PlayerStats.shared
    private let popupManager = PopupManager.shared
    private let haptics = HapticsManager.shared
    
    private var currentStep: TutorialStep?
    private var tutorialScene: TutorialScene?
    private var isCompleted = false
    
    // MARK: - Types
    enum TutorialStep: Int, CaseIterable {
        case welcome = 0
        case phonePosition
        case waitForSignal
        case drawTiming
        case practice
        case completion
        
        var title: String {
            switch self {
            case .welcome:
                return "Welcome to High Noons!"
            case .phonePosition:
                return "Phone Position"
            case .waitForSignal:
                return "Wait for Signal"
            case .drawTiming:
                return "Draw Timing"
            case .practice:
                return "Practice"
            case .completion:
                return "Ready for Action!"
            }
        }
        
        var instruction: String {
            switch self {
            case .welcome:
                return "Let's learn how to become the fastest gunslinger in the West!"
            case .phonePosition:
                return "Hold your phone upright like a holstered gun. This is your starting position."
            case .waitForSignal:
                return "When the duel begins, wait for the 'DRAW!' signal before making your move."
            case .drawTiming:
                return "When you see 'DRAW!', quickly tap anywhere to shoot! But be careful - shooting too early means instant defeat."
            case .practice:
                return "Let's practice! Get ready for your first duel..."
            case .completion:
                return "Great job! You're ready to take on other gunslingers. Good luck!"
            }
        }
        
        var requiresAction: Bool {
            switch self {
            case .welcome, .completion:
                return false
            case .phonePosition, .waitForSignal, .drawTiming, .practice:
                return true
            }
        }
        
        var demonstrationDuration: TimeInterval {
            switch self {
            case .welcome: return 3.0
            case .phonePosition: return 5.0
            case .waitForSignal: return 4.0
            case .drawTiming: return 5.0
            case .practice: return 8.0
            case .completion: return 3.0
            }
        }
    }
    
    struct TutorialProgress: Codable {
        var completedSteps: Set<Int>
        var hasCompletedTutorial: Bool
        
        static var empty: TutorialProgress {
            return TutorialProgress(completedSteps: [], hasCompletedTutorial: false)
        }
    }
    
    // MARK: - Tutorial Flow
    func startTutorial(in scene: TutorialScene) {
        tutorialScene = scene
        currentStep = .welcome
        isCompleted = false
        loadProgress()
        
        analytics.trackEvent(.featureUsed(name: "tutorial_start"))
        showCurrentStep()
    }
    
    func advanceToNextStep() {
        guard let currentStep = currentStep,
              let nextStep = TutorialStep(rawValue: currentStep.rawValue + 1) else {
            completeTutorial()
            return
        }
        
        markStepCompleted(currentStep)
        self.currentStep = nextStep
        showCurrentStep()
    }
    
    private func showCurrentStep() {
        guard let step = currentStep else { return }
        
        analytics.trackTutorialStep(step.rawValue, timeSpent: step.demonstrationDuration)
        
        tutorialScene?.updateInstructions(
            title: step.title,
            message: step.instruction
        )
        
        if step.requiresAction {
            startDemonstration(for: step)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.demonstrationDuration) { [weak self] in
                self?.advanceToNextStep()
            }
        }
    }
    
    private func startDemonstration(for step: TutorialStep) {
        switch step {
        case .phonePosition:
            demonstratePhonePosition()
        case .waitForSignal:
            demonstrateWaitingForSignal()
        case .drawTiming:
            demonstrateDrawTiming()
        case .practice:
            startPracticeRound()
        default:
            break
        }
    }
    
    // MARK: - Step Demonstrations
    private func demonstratePhonePosition() {
        tutorialScene?.demonstratePhonePosition { [weak self] success in
            if success {
                self?.haptics.playPattern(.success)
                self?.advanceToNextStep()
            }
        }
    }
    
    private func demonstrateWaitingForSignal() {
        tutorialScene?.demonstrateWaiting { [weak self] success in
            if success {
                self?.haptics.playPattern(.success)
                self?.advanceToNextStep()
            }
        }
    }
    
    private func demonstrateDrawTiming() {
        tutorialScene?.demonstrateDrawTiming { [weak self] success in
            if success {
                self?.haptics.playPattern(.success)
                self?.advanceToNextStep()
            } else {
                self?.haptics.playPattern(.failure)
                self?.showRetryPrompt()
            }
        }
    }
    
    private func startPracticeRound() {
        tutorialScene?.startPracticeRound { [weak self] result in
            switch result {
            case .success:
                self?.haptics.playPattern(.success)
                self?.showSuccessPrompt()
                self?.advanceToNextStep()
            case .failure:
                self?.haptics.playPattern(.failure)
                self?.showRetryPrompt()
            case .early:
                self?.haptics.playPattern(.warning)
                self?.showEarlyDrawPrompt()
            }
        }
    }
    
    // MARK: - Progress Management
    private func markStepCompleted(_ step: TutorialStep) {
        var progress = loadProgress()
        progress.completedSteps.insert(step.rawValue)
        saveProgress(progress)
    }
    
    private func completeTutorial() {
        var progress = loadProgress()
        progress.hasCompletedTutorial = true
        saveProgress(progress)
        
        isCompleted = true
        analytics.trackEvent(.tutorialComplete)
        
        showCompletionPrompt()
    }
    
    // MARK: - Progress Persistence
    private func loadProgress() -> TutorialProgress {
        guard let data = UserDefaults.standard.data(forKey: "tutorialProgress"),
              let progress = try? JSONDecoder().decode(TutorialProgress.self, from: data) else {
            return .empty
        }
        return progress
    }
    
    private func saveProgress(_ progress: TutorialProgress) {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: "tutorialProgress")
        }
    }
    
    // MARK: - Prompts
    private func showRetryPrompt() {
        guard let scene = tutorialScene else { return }
        
        popupManager.showPopup(
            style: .alert,
            title: "Try Again",
            message: "Don't worry! Practice makes perfect. Let's try that again.",
            buttons: [
                PopupButton(title: "Retry", style: .primary) { [weak self] in
                    self?.startDemonstration(for: self?.currentStep ?? .practice)
                }
            ],
            in: scene
        )
    }
    
    private func showEarlyDrawPrompt() {
        guard let scene = tutorialScene else { return }
        
        popupManager.showPopup(
            style: .alert,
            title: "Too Early!",
            message: "Remember to wait for the 'DRAW!' signal before shooting.",
            buttons: [
                PopupButton(title: "Try Again", style: .primary) { [weak self] in
                    self?.startDemonstration(for: self?.currentStep ?? .practice)
                }
            ],
            in: scene
        )
    }
    
    private func showSuccessPrompt() {
        guard let scene = tutorialScene else { return }
        
        popupManager.showPopup(
            style: .reward,
            title: "Great Shot!",
            message: "You're getting the hang of it!",
            buttons: [
                PopupButton(title: "Continue", style: .primary) {}
            ],
            in: scene
        )
    }
    
    private func showCompletionPrompt() {
        guard let scene = tutorialScene else { return }
        
        popupManager.showPopup(
            style: .achievement,
            title: "Tutorial Complete!",
            message: "You're ready for real duels. Good luck, gunslinger!",
            buttons: [
                PopupButton(title: "Let's Go!", style: .primary) { [weak self] in
                    self?.transitionToGame()
                }
            ],
            in: scene
        )
    }
    
    // MARK: - Navigation
    private func transitionToGame() {
        guard let scene = tutorialScene else { return }
        
        let transition = SKTransition.fade(withDuration: 1.0)
        if let gameScene = CharacterSelectionScene(size: scene.size) {
            gameScene.scaleMode = .aspectFill
            scene.view?.presentScene(gameScene, transition: transition)
        }
    }
    
    // MARK: - State Checks
    func hasTutorialBeenCompleted() -> Bool {
        return loadProgress().hasCompletedTutorial
    }
    
    func canSkipTutorial() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

// MARK: - Tutorial Result
enum TutorialResult {
    case success
    case failure
    case early
}

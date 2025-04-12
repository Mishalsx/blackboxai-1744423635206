import SpriteKit

final class CameraManager {
    // MARK: - Properties
    static let shared = CameraManager()
    
    private weak var camera: SKCameraNode?
    private weak var scene: SKScene?
    
    private var isShaking = false
    private var originalPosition: CGPoint = .zero
    private var currentZoom: CGFloat = 1.0
    
    // MARK: - Types
    enum ShakeIntensity {
        case light
        case medium
        case heavy
        case custom(CGFloat)
        
        var amplitude: CGFloat {
            switch self {
            case .light: return 5.0
            case .medium: return 10.0
            case .heavy: return 20.0
            case .custom(let value): return value
            }
        }
        
        var duration: TimeInterval {
            switch self {
            case .light: return 0.2
            case .medium: return 0.3
            case .heavy: return 0.5
            case .custom: return 0.3
            }
        }
    }
    
    enum ZoomEffect {
        case `in`(CGFloat)
        case out(CGFloat)
        case reset
        
        var scale: CGFloat {
            switch self {
            case .in(let factor): return factor
            case .out(let factor): return 1.0 / factor
            case .reset: return 1.0
            }
        }
    }
    
    enum TransitionEffect {
        case fadeIn
        case fadeOut
        case flash
        case blur
        case custom(SKAction)
        
        var action: SKAction {
            switch self {
            case .fadeIn:
                return SKAction.fadeIn(withDuration: 0.3)
            case .fadeOut:
                return SKAction.fadeOut(withDuration: 0.3)
            case .flash:
                return SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.1),
                    SKAction.fadeIn(withDuration: 0.1)
                ])
            case .blur:
                // Implement blur effect using SKEffectNode
                return SKAction.run {}
            case .custom(let action):
                return action
            }
        }
    }
    
    // MARK: - Setup
    func setup(with camera: SKCameraNode, in scene: SKScene) {
        self.camera = camera
        self.scene = scene
        self.originalPosition = camera.position
        
        // Setup initial camera state
        camera.setScale(1.0)
        scene.camera = camera
    }
    
    // MARK: - Camera Effects
    func shake(
        intensity: ShakeIntensity,
        completion: (() -> Void)? = nil
    ) {
        guard let camera = camera, !isShaking else { return }
        
        isShaking = true
        originalPosition = camera.position
        
        let shakeAction = createShakeAction(intensity: intensity)
        
        camera.run(shakeAction) { [weak self] in
            self?.isShaking = false
            self?.resetPosition()
            completion?()
        }
    }
    
    private func createShakeAction(intensity: ShakeIntensity) -> SKAction {
        let amplitude = intensity.amplitude
        let duration = intensity.duration
        let shakeCount = Int(duration * 10) // 10 shakes per second
        
        var actions: [SKAction] = []
        
        for _ in 0..<shakeCount {
            let randomX = CGFloat.random(in: -amplitude...amplitude)
            let randomY = CGFloat.random(in: -amplitude...amplitude)
            
            let moveAction = SKAction.moveBy(
                x: randomX,
                y: randomY,
                duration: duration / TimeInterval(shakeCount)
            )
            
            actions.append(moveAction)
            actions.append(moveAction.reversed())
        }
        
        return SKAction.sequence(actions)
    }
    
    func zoom(
        effect: ZoomEffect,
        duration: TimeInterval = 0.3,
        completion: (() -> Void)? = nil
    ) {
        guard let camera = camera else { return }
        
        let scale = effect.scale
        let zoomAction = SKAction.scale(to: scale, duration: duration)
        
        camera.run(zoomAction) {
            self.currentZoom = scale
            completion?()
        }
    }
    
    func applyEffect(
        _ effect: TransitionEffect,
        completion: (() -> Void)? = nil
    ) {
        guard let camera = camera else { return }
        
        camera.run(effect.action) {
            completion?()
        }
    }
    
    // MARK: - Camera Movement
    func panTo(
        position: CGPoint,
        duration: TimeInterval = 0.3,
        completion: (() -> Void)? = nil
    ) {
        guard let camera = camera else { return }
        
        let moveAction = SKAction.move(to: position, duration: duration)
        moveAction.timingMode = .easeInEaseOut
        
        camera.run(moveAction) {
            completion?()
        }
    }
    
    func follow(
        node: SKNode,
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0
    ) {
        guard let camera = camera else { return }
        
        let followAction = SKAction.run { [weak self] in
            guard let self = self else { return }
            let targetPosition = CGPoint(
                x: node.position.x + offsetX,
                y: node.position.y + offsetY
            )
            camera.position = targetPosition
        }
        
        camera.run(SKAction.repeatForever(followAction))
    }
    
    // MARK: - Camera Effects Combinations
    func dramaticReveal(completion: (() -> Void)? = nil) {
        zoom(effect: .out(2.0), duration: 0.5) { [weak self] in
            self?.zoom(effect: .in(2.0), duration: 0.3) {
                completion?()
            }
        }
    }
    
    func impactEffect(intensity: ShakeIntensity = .medium) {
        applyEffect(.flash) { [weak self] in
            self?.shake(intensity: intensity)
        }
    }
    
    func victoryEffect(completion: (() -> Void)? = nil) {
        zoom(effect: .out(1.2), duration: 0.5) { [weak self] in
            self?.shake(intensity: .light) {
                self?.zoom(effect: .reset, duration: 0.3) {
                    completion?()
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    func resetPosition() {
        guard let camera = camera else { return }
        camera.position = originalPosition
    }
    
    func resetZoom() {
        zoom(effect: .reset)
    }
    
    func stopAllEffects() {
        guard let camera = camera else { return }
        camera.removeAllActions()
        resetPosition()
        resetZoom()
    }
}

// MARK: - Convenience Methods
extension CameraManager {
    func quickShake() {
        shake(intensity: .light)
    }
    
    func hitEffect() {
        shake(intensity: .medium)
        applyEffect(.flash)
    }
    
    func defeatEffect() {
        shake(intensity: .heavy)
        applyEffect(.blur)
    }
}

// MARK: - SKEffectNode Extension
private extension SKEffectNode {
    func applyBlur(radius: CGFloat) {
        let blur = CIFilter(name: "CIGaussianBlur")
        blur?.setValue(radius, forKey: "inputRadius")
        filter = blur
    }
}

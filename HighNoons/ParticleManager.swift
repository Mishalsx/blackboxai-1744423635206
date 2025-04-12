import SpriteKit

final class ParticleManager {
    // MARK: - Singleton
    static let shared = ParticleManager()
    private init() {
        preloadParticles()
    }
    
    // MARK: - Types
    enum ParticleType {
        case confetti
        case dust
        case muzzleFlash
        case impact
        
        var filename: String {
            switch self {
            case .confetti: return "ConfettiParticle"
            case .dust: return "DustParticle"
            case .muzzleFlash: return "MuzzleFlashParticle"
            case .impact: return "ImpactParticle"
            }
        }
    }
    
    // MARK: - Properties
    private var cachedEmitters: [ParticleType: SKEmitterNode] = [:]
    
    // MARK: - Initialization
    private func preloadParticles() {
        ParticleType.allCases.forEach { type in
            if let emitter = loadEmitter(type) {
                cachedEmitters[type] = emitter
            }
        }
    }
    
    private func loadEmitter(_ type: ParticleType) -> SKEmitterNode? {
        guard let path = Bundle.main.path(forResource: type.filename, ofType: "sks"),
              let emitter = NSKeyedUnarchiver.unarchiveObject(
                withFile: path
              ) as? SKEmitterNode else {
            print("Failed to load particle effect: \(type.filename)")
            return nil
        }
        return emitter
    }
    
    // MARK: - Particle Creation
    func createEmitter(_ type: ParticleType) -> SKEmitterNode? {
        if let cached = cachedEmitters[type] {
            return cached.copy() as? SKEmitterNode
        }
        return loadEmitter(type)
    }
    
    // MARK: - Effect Methods
    func addConfettiEffect(to node: SKNode, position: CGPoint) {
        guard let emitter = createEmitter(.confetti) else { return }
        
        emitter.position = position
        emitter.zPosition = 100
        emitter.targetNode = node
        
        // Configure for celebration
        emitter.particleLifetime = 4
        emitter.numParticlesToEmit = 100
        emitter.particleBirthRate = 50
        
        node.addChild(emitter)
        
        // Remove after celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            emitter.removeFromParent()
        }
    }
    
    func addDustEffect(to node: SKNode, position: CGPoint) {
        guard let emitter = createEmitter(.dust) else { return }
        
        emitter.position = position
        emitter.zPosition = -1
        emitter.targetNode = node
        
        // Configure for ambient effect
        emitter.particleLifetime = 3
        emitter.particleBirthRate = 2
        emitter.particleAlpha = 0.3
        
        node.addChild(emitter)
    }
    
    func addMuzzleFlashEffect(to node: SKNode, position: CGPoint, rotation: CGFloat) {
        guard let emitter = createEmitter(.muzzleFlash) else { return }
        
        emitter.position = position
        emitter.zPosition = 50
        emitter.targetNode = node
        emitter.zRotation = rotation
        
        // Configure for quick flash
        emitter.particleLifetime = 0.1
        emitter.numParticlesToEmit = 20
        emitter.particleBirthRate = 200
        
        node.addChild(emitter)
        
        // Remove after flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            emitter.removeFromParent()
        }
    }
    
    func addImpactEffect(to node: SKNode, position: CGPoint) {
        guard let emitter = createEmitter(.impact) else { return }
        
        emitter.position = position
        emitter.zPosition = 50
        emitter.targetNode = node
        
        // Configure for impact
        emitter.particleLifetime = 0.3
        emitter.numParticlesToEmit = 30
        emitter.particleBirthRate = 100
        
        node.addChild(emitter)
        
        // Remove after impact
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            emitter.removeFromParent()
        }
    }
    
    // MARK: - Utility Methods
    func stopAllParticles(in node: SKNode) {
        node.children.forEach { child in
            if let emitter = child as? SKEmitterNode {
                emitter.removeFromParent()
            }
        }
    }
    
    func updateParticleSpeed(_ multiplier: CGFloat) {
        cachedEmitters.values.forEach { emitter in
            emitter.particleSpeed *= multiplier
            emitter.particleSpeedRange *= multiplier
        }
    }
    
    // MARK: - Performance Management
    func optimizeForLowPowerMode() {
        cachedEmitters.values.forEach { emitter in
            emitter.particleBirthRate *= 0.5
            emitter.particleLifetime *= 0.75
        }
    }
    
    func cleanup() {
        cachedEmitters.removeAll()
    }
}

// MARK: - ParticleType Extension
extension ParticleManager.ParticleType: CaseIterable {}

// MARK: - Usage Examples
extension ParticleManager {
    // Victory celebration
    func celebrateVictory(in scene: SKScene) {
        let positions = [
            CGPoint(x: scene.size.width * 0.25, y: scene.size.height * 0.75),
            CGPoint(x: scene.size.width * 0.75, y: scene.size.height * 0.75),
            CGPoint(x: scene.size.width * 0.5, y: scene.size.height * 0.5)
        ]
        
        positions.forEach { position in
            addConfettiEffect(to: scene, position: position)
        }
    }
    
    // Duel effects
    func showDuelEffects(in scene: SKScene, shooterPosition: CGPoint, targetPosition: CGPoint) {
        // Muzzle flash at shooter
        addMuzzleFlashEffect(
            to: scene,
            position: shooterPosition,
            rotation: atan2(
                targetPosition.y - shooterPosition.y,
                targetPosition.x - shooterPosition.x
            )
        )
        
        // Impact at target
        addImpactEffect(to: scene, position: targetPosition)
    }
    
    // Ambient effects
    func startAmbientEffects(in scene: SKScene) {
        // Add dust particles at different positions
        let positions = [
            CGPoint(x: scene.size.width * 0.25, y: 0),
            CGPoint(x: scene.size.width * 0.75, y: 0)
        ]
        
        positions.forEach { position in
            addDustEffect(to: scene, position: position)
        }
    }
}

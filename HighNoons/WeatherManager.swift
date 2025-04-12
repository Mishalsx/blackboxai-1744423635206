import SpriteKit

final class WeatherManager {
    // MARK: - Properties
    static let shared = WeatherManager()
    
    private let particleManager = ParticleManager.shared
    private var currentWeather: WeatherType?
    private var weatherNodes: [SKNode] = []
    private weak var currentScene: SKScene?
    
    // MARK: - Types
    enum WeatherType {
        case clear
        case dusty
        case windy
        case stormy
        case sunset
        case night
        
        var backgroundColor: SKColor {
            switch self {
            case .clear: return SKColor(red: 0.53, green: 0.81, blue: 0.98, alpha: 1.0)
            case .dusty: return SKColor(red: 0.85, green: 0.75, blue: 0.60, alpha: 1.0)
            case .windy: return SKColor(red: 0.70, green: 0.70, blue: 0.70, alpha: 1.0)
            case .stormy: return SKColor(red: 0.40, green: 0.40, blue: 0.45, alpha: 1.0)
            case .sunset: return SKColor(red: 0.95, green: 0.60, blue: 0.30, alpha: 1.0)
            case .night: return SKColor(red: 0.10, green: 0.12, blue: 0.25, alpha: 1.0)
            }
        }
        
        var ambientLightColor: SKColor {
            switch self {
            case .clear: return .white
            case .dusty: return SKColor(red: 1.0, green: 0.9, blue: 0.7, alpha: 1.0)
            case .windy: return SKColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
            case .stormy: return SKColor(red: 0.7, green: 0.7, blue: 0.8, alpha: 1.0)
            case .sunset: return SKColor(red: 1.0, green: 0.8, blue: 0.6, alpha: 1.0)
            case .night: return SKColor(red: 0.3, green: 0.3, blue: 0.5, alpha: 1.0)
            }
        }
        
        var particleFile: String? {
            switch self {
            case .clear: return nil
            case .dusty: return "DustParticle"
            case .windy: return "WindParticle"
            case .stormy: return "StormParticle"
            case .sunset: return "SunsetParticle"
            case .night: return "StarParticle"
            }
        }
    }
    
    // MARK: - Setup
    func setup(in scene: SKScene) {
        currentScene = scene
        setWeather(.clear, animated: false)
    }
    
    // MARK: - Weather Control
    func setWeather(
        _ type: WeatherType,
        animated: Bool = true,
        duration: TimeInterval = 1.0,
        completion: (() -> Void)? = nil
    ) {
        guard let scene = currentScene else { return }
        
        // Store new weather type
        let oldWeather = currentWeather
        currentWeather = type
        
        // Create new weather effects
        createWeatherEffects(type, in: scene)
        
        if animated {
            // Fade out old weather
            weatherNodes.forEach { node in
                node.run(SKAction.fadeOut(withDuration: duration/2))
            }
            
            // Change background color
            let colorize = SKAction.colorize(
                with: type.backgroundColor,
                colorBlendFactor: 1.0,
                duration: duration
            )
            scene.run(colorize)
            
            // Change ambient light
            if let lightNode = scene.childNode(withName: "ambientLight") as? SKLightNode {
                let lightColorize = SKAction.customAction(withDuration: duration) { node, elapsed in
                    let progress = elapsed / CGFloat(duration)
                    if let oldColor = oldWeather?.ambientLightColor {
                        lightNode.lightColor = SKColor(
                            red: oldColor.redComponent + (type.ambientLightColor.redComponent - oldColor.redComponent) * progress,
                            green: oldColor.greenComponent + (type.ambientLightColor.greenComponent - oldColor.greenComponent) * progress,
                            blue: oldColor.blueComponent + (type.ambientLightColor.blueComponent - oldColor.blueComponent) * progress,
                            alpha: 1.0
                        )
                    }
                }
                lightNode.run(lightColorize)
            }
            
            // Remove old weather nodes after fade
            DispatchQueue.main.asyncAfter(deadline: .now() + duration/2) {
                self.weatherNodes.forEach { $0.removeFromParent() }
                self.weatherNodes.removeAll()
                completion?()
            }
        } else {
            // Immediate change
            weatherNodes.forEach { $0.removeFromParent() }
            weatherNodes.removeAll()
            scene.color = type.backgroundColor
            if let lightNode = scene.childNode(withName: "ambientLight") as? SKLightNode {
                lightNode.lightColor = type.ambientLightColor
            }
            completion?()
        }
    }
    
    private func createWeatherEffects(_ type: WeatherType, in scene: SKScene) {
        guard let particleFile = type.particleFile else { return }
        
        // Create ambient light if needed
        if scene.childNode(withName: "ambientLight") == nil {
            let lightNode = SKLightNode()
            lightNode.name = "ambientLight"
            lightNode.categoryBitMask = 1
            lightNode.falloff = 1
            lightNode.ambientColor = type.ambientLightColor
            lightNode.lightColor = type.ambientLightColor
            scene.addChild(lightNode)
        }
        
        // Create particle effects
        switch type {
        case .dusty:
            addDustEffect(to: scene)
        case .windy:
            addWindEffect(to: scene)
        case .stormy:
            addStormEffect(to: scene)
        case .sunset:
            addSunsetEffect(to: scene)
        case .night:
            addNightEffect(to: scene)
        default:
            break
        }
    }
    
    // MARK: - Weather Effects
    private func addDustEffect(to scene: SKScene) {
        let positions = [
            CGPoint(x: scene.size.width * 0.25, y: 0),
            CGPoint(x: scene.size.width * 0.75, y: 0)
        ]
        
        positions.forEach { position in
            if let emitter = particleManager.createEmitter(.dust) {
                emitter.position = position
                emitter.particleAlpha = 0.3
                weatherNodes.append(emitter)
                scene.addChild(emitter)
            }
        }
    }
    
    private func addWindEffect(to scene: SKScene) {
        if let emitter = SKEmitterNode(fileNamed: "WindParticle") {
            emitter.position = CGPoint(x: -50, y: scene.size.height/2)
            emitter.particlePositionRange = CGVector(dx: 0, dy: scene.size.height)
            weatherNodes.append(emitter)
            scene.addChild(emitter)
        }
    }
    
    private func addStormEffect(to scene: SKScene) {
        // Lightning
        let lightning = SKSpriteNode(color: .white, size: scene.size)
        lightning.position = CGPoint(x: scene.size.width/2, y: scene.size.height/2)
        lightning.alpha = 0
        weatherNodes.append(lightning)
        scene.addChild(lightning)
        
        // Lightning flash action
        let flashAction = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.1),
            SKAction.fadeAlpha(to: 0, duration: 0.1),
            SKAction.wait(forDuration: Double.random(in: 3...8))
        ])
        lightning.run(SKAction.repeatForever(flashAction))
        
        // Rain
        if let emitter = SKEmitterNode(fileNamed: "StormParticle") {
            emitter.position = CGPoint(x: scene.size.width/2, y: scene.size.height + 50)
            weatherNodes.append(emitter)
            scene.addChild(emitter)
        }
    }
    
    private func addSunsetEffect(to scene: SKScene) {
        // Sun
        let sun = SKSpriteNode(color: .orange, size: CGSize(width: 100, height: 100))
        sun.position = CGPoint(x: scene.size.width * 0.8, y: scene.size.height * 0.8)
        weatherNodes.append(sun)
        scene.addChild(sun)
        
        // Rays
        if let emitter = SKEmitterNode(fileNamed: "SunsetParticle") {
            emitter.position = sun.position
            weatherNodes.append(emitter)
            scene.addChild(emitter)
        }
    }
    
    private func addNightEffect(to scene: SKScene) {
        // Stars
        if let emitter = SKEmitterNode(fileNamed: "StarParticle") {
            emitter.position = CGPoint(x: scene.size.width/2, y: scene.size.height/2)
            weatherNodes.append(emitter)
            scene.addChild(emitter)
        }
        
        // Moon
        let moon = SKSpriteNode(color: .white, size: CGSize(width: 80, height: 80))
        moon.position = CGPoint(x: scene.size.width * 0.8, y: scene.size.height * 0.8)
        weatherNodes.append(moon)
        scene.addChild(moon)
    }
    
    // MARK: - Weather Cycles
    func startDayCycle(duration: TimeInterval = 300) {
        let cycle = [
            WeatherType.clear,
            .dusty,
            .windy,
            .sunset,
            .night
        ]
        
        let intervalDuration = duration / TimeInterval(cycle.count)
        
        for (index, weather) in cycle.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + intervalDuration * Double(index)) {
                self.setWeather(weather, animated: true)
            }
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        weatherNodes.forEach { $0.removeFromParent() }
        weatherNodes.removeAll()
        currentWeather = nil
        currentScene = nil
    }
}

// MARK: - SKColor Extension
private extension SKColor {
    var redComponent: CGFloat {
        var r: CGFloat = 0
        getRed(&r, green: nil, blue: nil, alpha: nil)
        return r
    }
    
    var greenComponent: CGFloat {
        var g: CGFloat = 0
        getRed(nil, green: &g, blue: nil, alpha: nil)
        return g
    }
    
    var blueComponent: CGFloat {
        var b: CGFloat = 0
        getRed(nil, green: nil, blue: &b, alpha: nil)
        return b
    }
}

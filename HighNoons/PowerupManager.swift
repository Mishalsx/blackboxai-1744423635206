import Foundation
import SpriteKit

final class PowerupManager {
    // MARK: - Properties
    static let shared = PowerupManager()
    
    private let analytics = AnalyticsManager.shared
    private let playerStats = PlayerStats.shared
    private let haptics = HapticsManager.shared
    
    private var activePowerups: [ActivePowerup] = []
    private var powerupInventory: [String: Int] = [:]
    
    // MARK: - Types
    struct Powerup: Codable {
        let id: String
        let name: String
        let description: String
        let icon: String
        let type: PowerupType
        let duration: TimeInterval?
        let cooldown: TimeInterval
        let effect: Effect
        let rarity: Rarity
        
        enum PowerupType: String, Codable {
            case instant
            case duration
            case passive
        }
        
        enum Effect: Codable {
            case slowMotion(factor: Float)
            case quickDraw(bonus: Float)
            case extraLife
            case shield(strength: Float)
            case doublePoints
            case autoAim(accuracy: Float)
            case reactionBoost(factor: Float)
            
            var description: String {
                switch self {
                case .slowMotion(let factor):
                    return "Slows time by \(Int(factor * 100))%"
                case .quickDraw(let bonus):
                    return "Increases draw speed by \(Int(bonus * 100))%"
                case .extraLife:
                    return "Grants an extra life"
                case .shield(let strength):
                    return "Blocks \(Int(strength * 100))% damage"
                case .doublePoints:
                    return "Doubles points earned"
                case .autoAim(let accuracy):
                    return "Improves accuracy by \(Int(accuracy * 100))%"
                case .reactionBoost(let factor):
                    return "Boosts reaction time by \(Int(factor * 100))%"
                }
            }
        }
        
        enum Rarity: String, Codable {
            case common
            case rare
            case epic
            case legendary
            
            var color: SKColor {
                switch self {
                case .common: return .white
                case .rare: return .blue
                case .epic: return .purple
                case .legendary: return .orange
                }
            }
            
            var maxStack: Int {
                switch self {
                case .common: return 10
                case .rare: return 5
                case .epic: return 3
                case .legendary: return 1
                }
            }
        }
    }
    
    struct ActivePowerup {
        let powerup: Powerup
        let startTime: TimeInterval
        var remainingDuration: TimeInterval?
        var isActive: Bool = true
    }
    
    // MARK: - Initialization
    private init() {
        setupPowerups()
        loadInventory()
    }
    
    private func setupPowerups() {
        availablePowerups = [
            Powerup(
                id: "slow_motion",
                name: "Time Warp",
                description: "Slows down time for better accuracy",
                icon: "powerup_slowmo",
                type: .duration,
                duration: 5.0,
                cooldown: 30.0,
                effect: .slowMotion(factor: 0.5),
                rarity: .epic
            ),
            Powerup(
                id: "quick_draw",
                name: "Quick Draw",
                description: "Temporarily increases draw speed",
                icon: "powerup_quickdraw",
                type: .duration,
                duration: 3.0,
                cooldown: 20.0,
                effect: .quickDraw(bonus: 0.3),
                rarity: .rare
            ),
            Powerup(
                id: "extra_life",
                name: "Second Chance",
                description: "Survive one fatal shot",
                icon: "powerup_life",
                type: .instant,
                duration: nil,
                cooldown: 0.0,
                effect: .extraLife,
                rarity: .legendary
            ),
            Powerup(
                id: "shield",
                name: "Shield",
                description: "Reduces damage taken",
                icon: "powerup_shield",
                type: .duration,
                duration: 10.0,
                cooldown: 45.0,
                effect: .shield(strength: 0.5),
                rarity: .rare
            ),
            Powerup(
                id: "double_points",
                name: "Double Points",
                description: "Doubles points earned",
                icon: "powerup_points",
                type: .duration,
                duration: 30.0,
                cooldown: 60.0,
                effect: .doublePoints,
                rarity: .epic
            ),
            Powerup(
                id: "auto_aim",
                name: "Eagle Eye",
                description: "Improves accuracy",
                icon: "powerup_aim",
                type: .passive,
                duration: nil,
                cooldown: 0.0,
                effect: .autoAim(accuracy: 0.2),
                rarity: .common
            ),
            Powerup(
                id: "reaction_boost",
                name: "Lightning Reflexes",
                description: "Boosts reaction time",
                icon: "powerup_boost",
                type: .duration,
                duration: 15.0,
                cooldown: 40.0,
                effect: .reactionBoost(factor: 0.2),
                rarity: .epic
            )
        ]
    }
    
    // MARK: - Powerup Management
    func activatePowerup(
        _ id: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard let powerup = getPowerup(id),
              let count = powerupInventory[id],
              count > 0 else {
            completion?(false)
            return
        }
        
        // Check if already active
        if let active = activePowerups.first(where: { $0.powerup.id == id }),
           active.isActive {
            completion?(false)
            return
        }
        
        // Activate powerup
        let activePowerup = ActivePowerup(
            powerup: powerup,
            startTime: CACurrentMediaTime(),
            remainingDuration: powerup.duration,
            isActive: true
        )
        
        activePowerups.append(activePowerup)
        powerupInventory[id] = count - 1
        
        // Apply effects
        applyPowerupEffects(powerup)
        
        // Play feedback
        haptics.playPattern(.success)
        
        // Track analytics
        analytics.trackEvent(.featureUsed(name: "powerup_\(id)"))
        
        saveInventory()
        completion?(true)
    }
    
    func deactivatePowerup(_ id: String) {
        guard let index = activePowerups.firstIndex(where: { $0.powerup.id == id }) else {
            return
        }
        
        let powerup = activePowerups[index].powerup
        activePowerups.remove(at: index)
        
        // Remove effects
        removePowerupEffects(powerup)
    }
    
    func updatePowerups(deltaTime: TimeInterval) {
        for (index, var active) in activePowerups.enumerated() {
            guard active.isActive else { continue }
            
            if let duration = active.remainingDuration {
                active.remainingDuration = duration - deltaTime
                
                if active.remainingDuration ?? 0 <= 0 {
                    deactivatePowerup(active.powerup.id)
                } else {
                    activePowerups[index] = active
                }
            }
        }
    }
    
    // MARK: - Effects
    private func applyPowerupEffects(_ powerup: Powerup) {
        switch powerup.effect {
        case .slowMotion(let factor):
            applySloMoEffect(factor)
        case .quickDraw(let bonus):
            applyQuickDrawEffect(bonus)
        case .extraLife:
            applyExtraLifeEffect()
        case .shield(let strength):
            applyShieldEffect(strength)
        case .doublePoints:
            applyDoublePointsEffect()
        case .autoAim(let accuracy):
            applyAutoAimEffect(accuracy)
        case .reactionBoost(let factor):
            applyReactionBoostEffect(factor)
        }
    }
    
    private func removePowerupEffects(_ powerup: Powerup) {
        switch powerup.effect {
        case .slowMotion:
            removeSloMoEffect()
        case .quickDraw:
            removeQuickDrawEffect()
        case .extraLife:
            removeExtraLifeEffect()
        case .shield:
            removeShieldEffect()
        case .doublePoints:
            removeDoublePointsEffect()
        case .autoAim:
            removeAutoAimEffect()
        case .reactionBoost:
            removeReactionBoostEffect()
        }
    }
    
    // MARK: - Effect Implementations
    private func applySloMoEffect(_ factor: Float) {
        // Implement slow motion effect
    }
    
    private func applyQuickDrawEffect(_ bonus: Float) {
        // Implement quick draw effect
    }
    
    private func applyExtraLifeEffect() {
        // Implement extra life effect
    }
    
    private func applyShieldEffect(_ strength: Float) {
        // Implement shield effect
    }
    
    private func applyDoublePointsEffect() {
        // Implement double points effect
    }
    
    private func applyAutoAimEffect(_ accuracy: Float) {
        // Implement auto aim effect
    }
    
    private func applyReactionBoostEffect(_ factor: Float) {
        // Implement reaction boost effect
    }
    
    private func removeSloMoEffect() {
        // Remove slow motion effect
    }
    
    private func removeQuickDrawEffect() {
        // Remove quick draw effect
    }
    
    private func removeExtraLifeEffect() {
        // Remove extra life effect
    }
    
    private func removeShieldEffect() {
        // Remove shield effect
    }
    
    private func removeDoublePointsEffect() {
        // Remove double points effect
    }
    
    private func removeAutoAimEffect() {
        // Remove auto aim effect
    }
    
    private func removeReactionBoostEffect() {
        // Remove reaction boost effect
    }
    
    // MARK: - Inventory Management
    func addPowerup(_ id: String, count: Int = 1) {
        guard let powerup = getPowerup(id) else { return }
        
        let currentCount = powerupInventory[id] ?? 0
        let maxCount = powerup.rarity.maxStack
        
        powerupInventory[id] = min(currentCount + count, maxCount)
        saveInventory()
    }
    
    func removePowerup(_ id: String, count: Int = 1) {
        guard let currentCount = powerupInventory[id] else { return }
        
        powerupInventory[id] = max(0, currentCount - count)
        saveInventory()
    }
    
    func getPowerupCount(_ id: String) -> Int {
        return powerupInventory[id] ?? 0
    }
    
    // MARK: - Persistence
    private func saveInventory() {
        UserDefaults.standard.set(powerupInventory, forKey: "powerupInventory")
    }
    
    private func loadInventory() {
        if let inventory = UserDefaults.standard.dictionary(forKey: "powerupInventory") as? [String: Int] {
            powerupInventory = inventory
        }
    }
    
    // MARK: - Queries
    func getPowerup(_ id: String) -> Powerup? {
        return availablePowerups.first { $0.id == id }
    }
    
    func getActivePowerups() -> [ActivePowerup] {
        return activePowerups.filter { $0.isActive }
    }
    
    func isPowerupActive(_ id: String) -> Bool {
        return activePowerups.contains { $0.powerup.id == id && $0.isActive }
    }
    
    func getRemainingDuration(_ id: String) -> TimeInterval? {
        return activePowerups.first { $0.powerup.id == id && $0.isActive }?.remainingDuration
    }
}

// MARK: - Available Powerups
private extension PowerupManager {
    var availablePowerups: [Powerup] {
        get { return getPowerupsFromUserDefaults() }
        set { savePowerupsToUserDefaults(newValue) }
    }
    
    func getPowerupsFromUserDefaults() -> [Powerup] {
        guard let data = UserDefaults.standard.data(forKey: "availablePowerups"),
              let powerups = try? JSONDecoder().decode([Powerup].self, from: data) else {
            return []
        }
        return powerups
    }
    
    func savePowerupsToUserDefaults(_ powerups: [Powerup]) {
        if let data = try? JSONEncoder().encode(powerups) {
            UserDefaults.standard.set(data, forKey: "availablePowerups")
        }
    }
}

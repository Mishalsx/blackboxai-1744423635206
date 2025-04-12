import Foundation
import SpriteKit

final class CustomizationManager {
    // MARK: - Properties
    static let shared = CustomizationManager()
    
    private let analytics = AnalyticsManager.shared
    private let playerStats = PlayerStats.shared
    
    private var unlockedItems: [String: Set<String>] = [:]
    private var equippedItems: [String: String] = [:]
    private var favoritePresets: [CustomizationPreset] = []
    
    // MARK: - Types
    enum CustomizationType: String, CaseIterable {
        case outfit
        case holster
        case gunSkin
        case badge
        case title
        case emote
        case victoryPose
        case deathEffect
        case trail
        case background
        
        var displayName: String {
            switch self {
            case .outfit: return "Outfit"
            case .holster: return "Holster"
            case .gunSkin: return "Gun Skin"
            case .badge: return "Badge"
            case .title: return "Title"
            case .emote: return "Emote"
            case .victoryPose: return "Victory Pose"
            case .deathEffect: return "Death Effect"
            case .trail: return "Trail Effect"
            case .background: return "Background"
            }
        }
    }
    
    struct CustomizationItem: Codable {
        let id: String
        let type: CustomizationType
        let name: String
        let description: String
        let rarity: Rarity
        let previewImage: String
        let effects: [Effect]
        let requirements: [Requirement]
        let price: Price?
        
        enum Rarity: String, Codable {
            case common
            case rare
            case epic
            case legendary
            case exclusive
            
            var color: SKColor {
                switch self {
                case .common: return .white
                case .rare: return .blue
                case .epic: return .purple
                case .legendary: return .orange
                case .exclusive: return .red
                }
            }
        }
        
        enum Effect: Codable {
            case particle(String)
            case sound(String)
            case animation(String)
            case color(String)
            case custom(String)
        }
        
        struct Requirement: Codable {
            let type: RequirementType
            let value: String
            
            enum RequirementType: String, Codable {
                case level
                case achievement
                case season
                case event
                case purchase
            }
        }
        
        struct Price: Codable {
            let amount: Int
            let currency: Currency
            
            enum Currency: String, Codable {
                case coins
                case gems
                case tickets
                case special
            }
        }
    }
    
    struct CustomizationPreset: Codable {
        let id: String
        let name: String
        let items: [String: String] // [type: itemId]
        let createdAt: Date
        
        static func create(name: String, items: [String: String]) -> CustomizationPreset {
            return CustomizationPreset(
                id: UUID().uuidString,
                name: name,
                items: items,
                createdAt: Date()
            )
        }
    }
    
    // MARK: - Initialization
    private init() {
        loadCustomizationData()
    }
    
    // MARK: - Item Management
    func unlockItem(_ itemId: String, type: CustomizationType) {
        var items = unlockedItems[type.rawValue] ?? Set()
        items.insert(itemId)
        unlockedItems[type.rawValue] = items
        
        saveCustomizationData()
        analytics.trackEvent(.featureUsed(name: "customization_unlock"))
    }
    
    func equipItem(_ itemId: String, type: CustomizationType) {
        guard isItemUnlocked(itemId, type: type) else { return }
        
        equippedItems[type.rawValue] = itemId
        
        saveCustomizationData()
        analytics.trackEvent(.featureUsed(name: "customization_equip"))
        
        // Apply visual effects
        applyItemEffects(itemId, type: type)
    }
    
    func unequipItem(type: CustomizationType) {
        equippedItems.removeValue(forKey: type.rawValue)
        saveCustomizationData()
    }
    
    // MARK: - Preset Management
    func savePreset(_ preset: CustomizationPreset) {
        if let index = favoritePresets.firstIndex(where: { $0.id == preset.id }) {
            favoritePresets[index] = preset
        } else {
            favoritePresets.append(preset)
        }
        
        saveCustomizationData()
        analytics.trackEvent(.featureUsed(name: "customization_preset_save"))
    }
    
    func deletePreset(_ presetId: String) {
        favoritePresets.removeAll { $0.id == presetId }
        saveCustomizationData()
    }
    
    func applyPreset(_ preset: CustomizationPreset) {
        for (type, itemId) in preset.items {
            if let customType = CustomizationType(rawValue: type) {
                equipItem(itemId, type: customType)
            }
        }
        
        analytics.trackEvent(.featureUsed(name: "customization_preset_apply"))
    }
    
    // MARK: - Effect Application
    private func applyItemEffects(_ itemId: String, type: CustomizationType) {
        guard let item = getItem(itemId, type: type) else { return }
        
        for effect in item.effects {
            switch effect {
            case .particle(let name):
                applyParticleEffect(name)
            case .sound(let name):
                applySoundEffect(name)
            case .animation(let name):
                applyAnimationEffect(name)
            case .color(let hex):
                applyColorEffect(hex)
            case .custom(let data):
                applyCustomEffect(data)
            }
        }
    }
    
    private func applyParticleEffect(_ name: String) {
        guard let scene = getCurrentScene() else { return }
        ParticleManager.shared.addParticleEffect(name, to: scene)
    }
    
    private func applySoundEffect(_ name: String) {
        AudioManager.shared.playSound(.custom(name))
    }
    
    private func applyAnimationEffect(_ name: String) {
        guard let node = getPlayerNode() else { return }
        
        let animation = SKAction.sequence([
            SKAction.setTexture(SKTexture(imageNamed: name)),
            SKAction.wait(forDuration: 0.1)
        ])
        
        node.run(animation)
    }
    
    private func applyColorEffect(_ hex: String) {
        guard let node = getPlayerNode() else { return }
        node.color = SKColor(hex: hex)
        node.colorBlendFactor = 0.5
    }
    
    private func applyCustomEffect(_ data: String) {
        // Handle custom effects
    }
    
    // MARK: - Utility Methods
    private func getCurrentScene() -> SKScene? {
        return UIApplication.shared.windows
            .first?.rootViewController?.view as? SKView
    }
    
    private func getPlayerNode() -> SKSpriteNode? {
        return getCurrentScene()?.childNode(withName: "player") as? SKSpriteNode
    }
    
    func isItemUnlocked(_ itemId: String, type: CustomizationType) -> Bool {
        return unlockedItems[type.rawValue]?.contains(itemId) ?? false
    }
    
    func getEquippedItem(for type: CustomizationType) -> String? {
        return equippedItems[type.rawValue]
    }
    
    func getItem(_ itemId: String, type: CustomizationType) -> CustomizationItem? {
        // Fetch item data from catalog
        return nil
    }
    
    // MARK: - Data Persistence
    private func loadCustomizationData() {
        if let data = UserDefaults.standard.data(forKey: "unlockedItems"),
           let items = try? JSONDecoder().decode([String: Set<String>].self, from: data) {
            unlockedItems = items
        }
        
        if let data = UserDefaults.standard.data(forKey: "equippedItems"),
           let items = try? JSONDecoder().decode([String: String].self, from: data) {
            equippedItems = items
        }
        
        if let data = UserDefaults.standard.data(forKey: "customizationPresets"),
           let presets = try? JSONDecoder().decode([CustomizationPreset].self, from: data) {
            favoritePresets = presets
        }
    }
    
    private func saveCustomizationData() {
        if let data = try? JSONEncoder().encode(unlockedItems) {
            UserDefaults.standard.set(data, forKey: "unlockedItems")
        }
        
        if let data = try? JSONEncoder().encode(equippedItems) {
            UserDefaults.standard.set(data, forKey: "equippedItems")
        }
        
        if let data = try? JSONEncoder().encode(favoritePresets) {
            UserDefaults.standard.set(data, forKey: "customizationPresets")
        }
    }
}

// MARK: - Convenience Methods
extension CustomizationManager {
    func getUnlockedItems(type: CustomizationType) -> Set<String> {
        return unlockedItems[type.rawValue] ?? []
    }
    
    func getPresets() -> [CustomizationPreset] {
        return favoritePresets.sorted { $0.createdAt > $1.createdAt }
    }
    
    func createPresetFromCurrent(_ name: String) -> CustomizationPreset {
        return CustomizationPreset.create(name: name, items: equippedItems)
    }
    
    func resetCustomization() {
        equippedItems.removeAll()
        saveCustomizationData()
    }
}

// MARK: - SKColor Extension
private extension SKColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

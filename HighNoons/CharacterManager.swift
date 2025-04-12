import Foundation
import SpriteKit

final class CharacterManager {
    // MARK: - Properties
    static let shared = CharacterManager()
    
    private let playerStats = PlayerStats.shared
    private let analytics = AnalyticsManager.shared
    
    private(set) var selectedCharacter: Character
    private(set) var characters: [Character] = []
    
    // MARK: - Types
    struct Character: Codable {
        let id: String
        let name: String
        let description: String
        let unlockLevel: Int
        let unlockPrice: Int
        let attributes: Attributes
        let animations: Animations
        let specialAbility: SpecialAbility?
        var isUnlocked: Bool
        
        struct Attributes: Codable {
            let drawSpeed: Float      // 0-1, affects reaction time
            let accuracy: Float       // 0-1, affects hit probability
            let stability: Float      // 0-1, affects motion sensitivity
            let recovery: Float       // 0-1, affects reload speed
            let luck: Float          // 0-1, affects critical hits
        }
        
        struct Animations: Codable {
            let idle: String
            let draw: String
            let shoot: String
            let hit: String
            let victory: String
            let defeat: String
        }
        
        struct SpecialAbility: Codable {
            let name: String
            let description: String
            let cooldown: TimeInterval
            let effect: Effect
            
            enum Effect: String, Codable {
                case slowMotion
                case quickDraw
                case doubleShot
                case shield
                case revenge
            }
        }
        
        static var defaultCharacter: Character {
            return Character(
                id: "rookie",
                name: "The Rookie",
                description: "A fresh face in town, eager to prove their worth.",
                unlockLevel: 1,
                unlockPrice: 0,
                attributes: Attributes(
                    drawSpeed: 0.5,
                    accuracy: 0.5,
                    stability: 0.5,
                    recovery: 0.5,
                    luck: 0.5
                ),
                animations: Animations(
                    idle: "rookie_idle",
                    draw: "rookie_draw",
                    shoot: "rookie_shoot",
                    hit: "rookie_hit",
                    victory: "rookie_victory",
                    defeat: "rookie_defeat"
                ),
                specialAbility: nil,
                isUnlocked: true
            )
        }
    }
    
    // MARK: - Initialization
    private init() {
        selectedCharacter = Character.defaultCharacter
        setupCharacters()
        loadUnlockedCharacters()
    }
    
    private func setupCharacters() {
        characters = [
            Character(
                id: "sheriff",
                name: "The Sheriff",
                description: "Upholder of the law with lightning-fast reflexes.",
                unlockLevel: 5,
                unlockPrice: 1000,
                attributes: Attributes(
                    drawSpeed: 0.8,
                    accuracy: 0.7,
                    stability: 0.6,
                    recovery: 0.6,
                    luck: 0.5
                ),
                animations: Animations(
                    idle: "sheriff_idle",
                    draw: "sheriff_draw",
                    shoot: "sheriff_shoot",
                    hit: "sheriff_hit",
                    victory: "sheriff_victory",
                    defeat: "sheriff_defeat"
                ),
                specialAbility: SpecialAbility(
                    name: "Quick Draw",
                    description: "Temporarily increases draw speed",
                    cooldown: 30.0,
                    effect: .quickDraw
                ),
                isUnlocked: false
            ),
            
            Character(
                id: "outlaw",
                name: "The Outlaw",
                description: "A notorious gunslinger with deadly accuracy.",
                unlockLevel: 10,
                unlockPrice: 2000,
                attributes: Attributes(
                    drawSpeed: 0.7,
                    accuracy: 0.9,
                    stability: 0.5,
                    recovery: 0.7,
                    luck: 0.6
                ),
                animations: Animations(
                    idle: "outlaw_idle",
                    draw: "outlaw_draw",
                    shoot: "outlaw_shoot",
                    hit: "outlaw_hit",
                    victory: "outlaw_victory",
                    defeat: "outlaw_defeat"
                ),
                specialAbility: SpecialAbility(
                    name: "Double Shot",
                    description: "Fire two shots in quick succession",
                    cooldown: 45.0,
                    effect: .doubleShot
                ),
                isUnlocked: false
            ),
            
            Character(
                id: "marshal",
                name: "The Marshal",
                description: "A legendary lawman with unmatched skill.",
                unlockLevel: 20,
                unlockPrice: 5000,
                attributes: Attributes(
                    drawSpeed: 0.9,
                    accuracy: 0.8,
                    stability: 0.8,
                    recovery: 0.8,
                    luck: 0.7
                ),
                animations: Animations(
                    idle: "marshal_idle",
                    draw: "marshal_draw",
                    shoot: "marshal_shoot",
                    hit: "marshal_hit",
                    victory: "marshal_victory",
                    defeat: "marshal_defeat"
                ),
                specialAbility: SpecialAbility(
                    name: "Slow Motion",
                    description: "Briefly slows down time",
                    cooldown: 60.0,
                    effect: .slowMotion
                ),
                isUnlocked: false
            )
        ]
    }
    
    // MARK: - Character Management
    func selectCharacter(_ id: String) -> Bool {
        guard let character = characters.first(where: { $0.id == id && $0.isUnlocked }) else {
            return false
        }
        
        selectedCharacter = character
        saveSelectedCharacter()
        
        analytics.trackEvent(.characterSelected(name: character.name))
        return true
    }
    
    func unlockCharacter(_ id: String) -> Bool {
        guard let index = characters.firstIndex(where: { $0.id == id && !$0.isUnlocked }) else {
            return false
        }
        
        characters[index].isUnlocked = true
        saveUnlockedCharacters()
        
        analytics.trackEvent(.featureUsed(name: "character_unlock"))
        return true
    }
    
    func canUnlockCharacter(_ id: String) -> (canUnlock: Bool, reason: String?) {
        guard let character = characters.first(where: { $0.id == id }) else {
            return (false, "Character not found")
        }
        
        if character.isUnlocked {
            return (false, "Already unlocked")
        }
        
        if playerStats.stats.currentLevel < character.unlockLevel {
            return (false, "Reach level \(character.unlockLevel) to unlock")
        }
        
        if playerStats.stats.coins < character.unlockPrice {
            return (false, "Need \(character.unlockPrice) coins to unlock")
        }
        
        return (true, nil)
    }
    
    // MARK: - Character Loading
    private func loadUnlockedCharacters() {
        if let data = UserDefaults.standard.data(forKey: "unlockedCharacters"),
           let unlockedIds = try? JSONDecoder().decode([String].self, from: data) {
            for id in unlockedIds {
                if let index = characters.firstIndex(where: { $0.id == id }) {
                    characters[index].isUnlocked = true
                }
            }
        }
        
        loadSelectedCharacter()
    }
    
    private func loadSelectedCharacter() {
        if let selectedId = UserDefaults.standard.string(forKey: "selectedCharacter"),
           let character = characters.first(where: { $0.id == selectedId && $0.isUnlocked }) {
            selectedCharacter = character
        }
    }
    
    // MARK: - Character Saving
    private func saveUnlockedCharacters() {
        let unlockedIds = characters.filter { $0.isUnlocked }.map { $0.id }
        if let data = try? JSONEncoder().encode(unlockedIds) {
            UserDefaults.standard.set(data, forKey: "unlockedCharacters")
        }
    }
    
    private func saveSelectedCharacter() {
        UserDefaults.standard.set(selectedCharacter.id, forKey: "selectedCharacter")
    }
    
    // MARK: - Character Attributes
    func getCharacterSprite(_ character: Character, state: CharacterState = .idle) -> SKSpriteNode {
        let texture = SKTexture(imageNamed: getAnimationName(character, state: state))
        let sprite = SKSpriteNode(texture: texture)
        sprite.name = character.id
        return sprite
    }
    
    private func getAnimationName(_ character: Character, state: CharacterState) -> String {
        switch state {
        case .idle: return character.animations.idle
        case .draw: return character.animations.draw
        case .shoot: return character.animations.shoot
        case .hit: return character.animations.hit
        case .victory: return character.animations.victory
        case .defeat: return character.animations.defeat
        }
    }
    
    enum CharacterState {
        case idle
        case draw
        case shoot
        case hit
        case victory
        case defeat
    }
    
    // MARK: - Special Abilities
    func activateSpecialAbility() -> Bool {
        guard let ability = selectedCharacter.specialAbility else {
            return false
        }
        
        // Implement ability effects
        switch ability.effect {
        case .slowMotion:
            // Implement slow motion effect
            break
        case .quickDraw:
            // Implement quick draw effect
            break
        case .doubleShot:
            // Implement double shot effect
            break
        case .shield:
            // Implement shield effect
            break
        case .revenge:
            // Implement revenge effect
            break
        }
        
        analytics.trackEvent(.featureUsed(name: "special_ability_\(ability.effect.rawValue)"))
        return true
    }
}

// MARK: - Convenience Methods
extension CharacterManager {
    func getAvailableCharacters() -> [Character] {
        return characters.filter { $0.isUnlocked }
    }
    
    func getLockedCharacters() -> [Character] {
        return characters.filter { !$0.isUnlocked }
    }
    
    func getCharacterById(_ id: String) -> Character? {
        return characters.first { $0.id == id }
    }
    
    func getNextUnlockableCharacter() -> Character? {
        return getLockedCharacters()
            .sorted { $0.unlockLevel < $1.unlockLevel }
            .first
    }
}

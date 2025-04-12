import Foundation

enum BuildConfig {
    // MARK: - App Store
    static let appStoreID = "1234567890" // Replace with actual App Store ID
    static let bundleID = "com.highnoons.game"
    static let version = "1.0.0"
    static let build = "1"
    
    // MARK: - TestFlight
    static let testFlightGroup = "External Testers"
    static let testFlightDescription = """
    High Noons v\(version) (\(build))
    
    What's New:
    - Initial TestFlight release
    - Complete game implementation
    - Full tutorial system
    - Daily rewards
    - Multiple characters
    - Leaderboard integration
    
    Known Issues:
    - None reported
    
    Test Focus Areas:
    1. Core gameplay mechanics
    2. Device motion detection
    3. Multiplayer matchmaking
    4. Daily rewards system
    5. Tutorial flow
    6. In-app purchases
    7. Localization accuracy
    """
    
    // MARK: - Certificates
    enum CertificateType: String {
        case development = "Apple Development"
        case distribution = "Apple Distribution"
    }
    
    static let teamID = "ABCDEF1234" // Replace with actual Team ID
    static let profileName = "HighNoons_AppStore_Profile"
    
    // MARK: - App Store Assets
    static let appIcon = "AppIcon"
    static let launchScreen = "LaunchScreen"
    
    static let screenshots = [
        "6.5": ["iPhone 11 Pro Max", "iPhone 12 Pro Max", "iPhone 13 Pro Max"],
        "5.5": ["iPhone 8 Plus", "iPhone 7 Plus", "iPhone 6s Plus"],
        "iPad": ["iPad Pro (12.9-inch)", "iPad Pro (11-inch)"]
    ]
    
    static let appStoreMetadata = AppStoreMetadata(
        name: "High Noons",
        subtitle: "Fast-paced Western Duels",
        description: """
        Step into the world of High Noons, where quick reflexes and steady nerves determine who walks away victorious in intense one-on-one duels!
        
        FEATURES:
        • Unique motion-based gameplay
        • Multiple character choices
        • Daily rewards and challenges
        • Global leaderboards
        • Beautiful western-themed visuals
        • Immersive sound effects
        • Haptic feedback
        
        GAMEPLAY:
        Raise your phone like a holstered gun, wait for the "DRAW!" signal, and be the fastest to shoot! But be careful - shoot too early and you'll lose instantly.
        
        CHARACTERS:
        Choose from a variety of characters, each with their own unique style and animations:
        • The Sheriff - Balanced and reliable
        • The Deputy - Quick but inexperienced
        • The Outlaw - High risk, high reward
        • The Marshal - Steady and precise
        • The Legend - Master of the quick draw
        
        PROGRESSION:
        • Earn XP and level up
        • Unlock new characters
        • Complete daily challenges
        • Climb the global rankings
        • Earn achievements
        
        Download now and become the fastest gun in the West!
        """,
        keywords: [
            "western",
            "duel",
            "quick draw",
            "reaction",
            "multiplayer",
            "cowboy",
            "shooter",
            "arcade",
            "reflex",
            "action"
        ],
        supportURL: "https://highnoons.com/support",
        marketingURL: "https://highnoons.com",
        privacyPolicyURL: "https://highnoons.com/privacy"
    )
    
    // MARK: - In-App Purchases
    static let iapProducts = [
        IAPProduct(
            id: "noads",
            type: .nonConsumable,
            name: "Remove Ads",
            description: "Enjoy an ad-free experience",
            price: 4.99
        ),
        IAPProduct(
            id: "allcharacters",
            type: .nonConsumable,
            name: "All Characters Pack",
            description: "Unlock all current and future characters",
            price: 9.99
        ),
        IAPProduct(
            id: "vippass",
            type: .nonConsumable,
            name: "VIP Pass",
            description: "Remove ads and unlock all characters",
            price: 19.99
        ),
        IAPProduct(
            id: "coins.1000",
            type: .consumable,
            name: "1,000 Coins",
            description: "Small coin pack",
            price: 0.99
        ),
        IAPProduct(
            id: "coins.2500",
            type: .consumable,
            name: "2,500 Coins",
            description: "Medium coin pack",
            price: 1.99
        ),
        IAPProduct(
            id: "coins.5000",
            type: .consumable,
            name: "5,000 Coins",
            description: "Large coin pack",
            price: 4.99
        )
    ]
}

// MARK: - Supporting Types
struct AppStoreMetadata {
    let name: String
    let subtitle: String
    let description: String
    let keywords: [String]
    let supportURL: String
    let marketingURL: String
    let privacyPolicyURL: String
}

struct IAPProduct {
    enum ProductType {
        case consumable
        case nonConsumable
    }
    
    let id: String
    let type: ProductType
    let name: String
    let description: String
    let price: Double
}

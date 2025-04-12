import Foundation

enum PrivacyPolicy {
    static let version = "1.0.0"
    static let lastUpdated = "2024-01-20"
    
    static let fullText = """
    Privacy Policy for High Noons
    
    Last Updated: \(lastUpdated)
    Version: \(version)
    
    1. Introduction
    
    High Noons ("we," "our," or "us") respects your privacy and is committed to protecting your personal data. This privacy policy explains how we handle your data when you use our mobile game.
    
    2. Data We Collect
    
    We collect and process the following data:
    
    Essential Game Data:
    • Game progress and statistics
    • Device motion data (for gameplay mechanics)
    • Game settings and preferences
    
    Optional Features:
    • Game Center nickname and score (if leaderboard enabled)
    • Device language settings (for localization)
    
    Technical Data:
    • Device information (model, OS version)
    • App performance metrics
    • Crash reports
    
    3. How We Use Your Data
    
    We use your data to:
    • Provide core game functionality
    • Save your progress and settings
    • Maintain leaderboards
    • Improve game performance
    • Debug issues
    • Provide customer support
    
    4. Data Storage and Security
    
    • Game progress is stored locally on your device
    • Leaderboard data is stored securely via Apple Game Center
    • We implement industry-standard security measures
    
    5. Third-Party Services
    
    We use the following third-party services:
    • Apple Game Center (leaderboards)
    • AdMob/Unity Ads (advertising)
    • Analytics services (game performance)
    
    6. Children's Privacy
    
    We do not knowingly collect data from children under 13. If you are a parent/guardian and believe your child has provided personal information, please contact us.
    
    7. Your Rights
    
    You have the right to:
    • Access your data
    • Delete your data
    • Opt out of optional data collection
    • Disable analytics/advertising
    
    8. Data Deletion
    
    To delete your data:
    • Delete the app to remove local data
    • Contact us for Game Center data removal
    • Use device settings to reset advertising identifiers
    
    9. Changes to Privacy Policy
    
    We may update this policy. Significant changes will be notified in-app and require re-acceptance.
    
    10. Contact Information
    
    For privacy concerns:
    Email: privacy@highnoons.com
    Website: https://highnoons.com/privacy
    
    11. Legal Compliance
    
    This policy complies with:
    • Apple App Store guidelines
    • GDPR (EU users)
    • CCPA (California users)
    • COPPA (Children's privacy)
    
    12. California Privacy Rights
    
    California residents have additional rights under CCPA:
    • Right to know what personal information is collected
    • Right to delete personal information
    • Right to opt-out of data sale
    • Right to non-discrimination
    
    13. International Users
    
    Data processing complies with:
    • EU GDPR requirements
    • International data protection laws
    • Cross-border data transfer regulations
    
    14. Data Retention
    
    We retain data only as long as necessary:
    • Game progress: Until app deletion
    • Analytics: 90 days
    • Crash reports: 30 days
    
    15. Advertising
    
    For ad-supported features:
    • Non-personal data used for targeting
    • Option to purchase ad-free version
    • Advertising ID can be reset in device settings
    
    16. Updates and Notifications
    
    We may send:
    • Critical game updates
    • Privacy policy changes
    • Security alerts
    
    All notifications can be controlled in device settings.
    """
    
    static let shortDescription = """
    High Noons respects your privacy. We collect minimal data necessary for gameplay, including device motion for game mechanics and optional Game Center integration for leaderboards. You can play offline, opt out of optional features, and delete your data at any time. See our full privacy policy for details.
    """
    
    static let dataCollectionPoints = [
        DataCollectionPoint(
            feature: "Core Gameplay",
            dataTypes: ["Device motion", "Game progress"],
            purpose: "Essential game mechanics",
            storage: "Local device only",
            retention: "Until app deletion",
            optional: false
        ),
        DataCollectionPoint(
            feature: "Leaderboards",
            dataTypes: ["Game Center profile", "Scores"],
            purpose: "Global rankings",
            storage: "Apple Game Center",
            retention: "Until manual deletion",
            optional: true
        ),
        DataCollectionPoint(
            feature: "Analytics",
            dataTypes: ["Usage statistics", "Performance metrics"],
            purpose: "Game improvement",
            storage: "Secure cloud storage",
            retention: "90 days",
            optional: true
        ),
        DataCollectionPoint(
            feature: "Advertising",
            dataTypes: ["Ad interaction", "Device identifier"],
            purpose: "Ad delivery",
            storage: "Ad network servers",
            retention: "30 days",
            optional: true
        )
    ]
}

struct DataCollectionPoint {
    let feature: String
    let dataTypes: [String]
    let purpose: String
    let storage: String
    let retention: String
    let optional: Bool
}

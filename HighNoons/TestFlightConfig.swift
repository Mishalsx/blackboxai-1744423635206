import Foundation

enum TestFlightConfig {
    // MARK: - Testing Groups
    static let groups = [
        TestGroup(
            name: "Core Testers",
            description: "Internal team and primary testers",
            maxTesters: 25,
            features: [
                "All game features",
                "Debug menu access",
                "Analytics dashboard",
                "Crash reporting"
            ],
            buildAccess: "All builds"
        ),
        TestGroup(
            name: "External Testers",
            description: "Selected community members",
            maxTesters: 100,
            features: [
                "All game features",
                "Basic crash reporting",
                "Feedback form access"
            ],
            buildAccess: "Stable builds only"
        ),
        TestGroup(
            name: "Localization Testers",
            description: "Language-specific testing",
            maxTesters: 50,
            features: [
                "All game features",
                "Translation dashboard",
                "Language-specific feedback forms"
            ],
            buildAccess: "Localization builds"
        )
    ]
    
    // MARK: - Test Phases
    static let phases = [
        TestPhase(
            name: "Alpha",
            duration: 14,
            groups: ["Core Testers"],
            focusAreas: [
                "Core gameplay mechanics",
                "Basic UI functionality",
                "Performance baseline",
                "Critical bug identification"
            ],
            successCriteria: [
                "No crash reports",
                "Stable frame rate",
                "Basic gameplay loop working"
            ]
        ),
        TestPhase(
            name: "Closed Beta",
            duration: 21,
            groups: ["Core Testers", "External Testers"],
            focusAreas: [
                "Full gameplay experience",
                "Tutorial effectiveness",
                "User engagement metrics",
                "Network stability"
            ],
            successCriteria: [
                "Tutorial completion rate > 90%",
                "Session length > 5 minutes",
                "Day 1 retention > 40%"
            ]
        ),
        TestPhase(
            name: "Localization",
            duration: 14,
            groups: ["Localization Testers"],
            focusAreas: [
                "Translation accuracy",
                "Cultural appropriateness",
                "UI layout in all languages",
                "Special character handling"
            ],
            successCriteria: [
                "No text overflow issues",
                "All translations verified",
                "Cultural feedback addressed"
            ]
        ),
        TestPhase(
            name: "Open Beta",
            duration: 30,
            groups: ["Core Testers", "External Testers", "Localization Testers"],
            focusAreas: [
                "Scale testing",
                "Matchmaking efficiency",
                "Payment processing",
                "Final polish items"
            ],
            successCriteria: [
                "Server stability under load",
                "Payment success rate > 95%",
                "User satisfaction > 4.5/5"
            ]
        )
    ]
    
    // MARK: - Feedback Configuration
    static let feedbackConfig = FeedbackConfig(
        categories: [
            "Gameplay",
            "Performance",
            "UI/UX",
            "Audio",
            "Controls",
            "Tutorial",
            "Multiplayer",
            "Localization",
            "Store/IAP",
            "Other"
        ],
        priorityLevels: [
            "Critical",
            "High",
            "Medium",
            "Low",
            "Enhancement"
        ],
        requiredFields: [
            "Category",
            "Description",
            "Steps to Reproduce",
            "Expected Result",
            "Actual Result"
        ],
        attachmentTypes: [
            "Screenshot",
            "Video",
            "Device Logs"
        ]
    )
    
    // MARK: - Build Distribution
    static let buildConfig = BuildDistributionConfig(
        frequency: .weekly,
        notifyTesters: true,
        autoExpiration: 90,  // days
        requireUpdates: true,
        maxConcurrentVersions: 2
    )
    
    // MARK: - Testing Guidelines
    static let guidelines = """
    High Noons TestFlight Guidelines
    
    1. Getting Started:
    - Install TestFlight app
    - Accept email invitation
    - Download latest build
    - Review focus areas
    
    2. Testing Requirements:
    - Minimum 30 minutes daily play
    - Report all crashes
    - Complete feedback forms
    - Test on assigned devices
    
    3. Focus Areas:
    - Core gameplay mechanics
    - Device motion detection
    - Tutorial effectiveness
    - Multiplayer functionality
    - In-app purchases
    - Performance and stability
    
    4. Reporting Issues:
    - Use in-app feedback form
    - Include clear steps to reproduce
    - Attach screenshots/videos
    - Note device and OS version
    
    5. Communication:
    - Check TestFlight notes
    - Join Discord channel
    - Weekly feedback sessions
    - Report blocking issues immediately
    
    6. Confidentiality:
    - Do not share builds
    - No public screenshots/videos
    - Keep feedback private
    - Report security issues directly
    
    Thank you for helping make High Noons amazing!
    """
}

// MARK: - Supporting Types
struct TestGroup {
    let name: String
    let description: String
    let maxTesters: Int
    let features: [String]
    let buildAccess: String
}

struct TestPhase {
    let name: String
    let duration: Int  // days
    let groups: [String]
    let focusAreas: [String]
    let successCriteria: [String]
}

struct FeedbackConfig {
    let categories: [String]
    let priorityLevels: [String]
    let requiredFields: [String]
    let attachmentTypes: [String]
}

struct BuildDistributionConfig {
    enum Frequency {
        case daily
        case weekly
        case biweekly
        case monthly
    }
    
    let frequency: Frequency
    let notifyTesters: Bool
    let autoExpiration: Int  // days
    let requireUpdates: Bool
    let maxConcurrentVersions: Int
}

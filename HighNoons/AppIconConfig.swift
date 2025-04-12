import UIKit

enum AppIconConfig {
    // MARK: - Icon Design
    static let iconColors = IconColors(
        primary: UIColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1.0),    // Rustic orange
        secondary: UIColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1.0),  // Dark brown
        accent: UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0),     // Gold
        background: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)  // Dark background
    )
    
    static let iconElements = [
        IconElement(
            name: "revolver",
            position: CGPoint(x: 0.5, y: 0.5),  // Center
            size: CGSize(width: 0.7, height: 0.7),
            rotation: 45.0,  // 45-degree angle
            color: iconColors.primary,
            shadow: true
        ),
        IconElement(
            name: "star_badge",
            position: CGPoint(x: 0.5, y: 0.65),  // Below center
            size: CGSize(width: 0.4, height: 0.4),
            rotation: 0.0,
            color: iconColors.accent,
            shadow: true
        ),
        IconElement(
            name: "western_frame",
            position: CGPoint(x: 0.5, y: 0.5),  // Full frame
            size: CGSize(width: 0.95, height: 0.95),
            rotation: 0.0,
            color: iconColors.secondary,
            shadow: false
        )
    ]
    
    // MARK: - Icon Sizes
    static let requiredSizes: [IconSize] = [
        // iPhone
        IconSize(size: 60, scale: 2, idiom: "iphone"), // 120x120
        IconSize(size: 60, scale: 3, idiom: "iphone"), // 180x180
        
        // iPad
        IconSize(size: 76, scale: 1, idiom: "ipad"),   // 76x76
        IconSize(size: 76, scale: 2, idiom: "ipad"),   // 152x152
        IconSize(size: 83.5, scale: 2, idiom: "ipad"), // 167x167
        
        // App Store
        IconSize(size: 1024, scale: 1, idiom: "ios-marketing"), // 1024x1024
        
        // Settings, Spotlight
        IconSize(size: 29, scale: 2, idiom: "iphone"),  // 58x58
        IconSize(size: 29, scale: 3, idiom: "iphone"),  // 87x87
        IconSize(size: 40, scale: 2, idiom: "iphone"),  // 80x80
        IconSize(size: 40, scale: 3, idiom: "iphone"),  // 120x120
    ]
    
    // MARK: - Icon Metadata
    static let metadata = IconMetadata(
        displayName: "High Noons",
        bundleID: BuildConfig.bundleID,
        versionNumber: BuildConfig.version,
        buildNumber: BuildConfig.build,
        minimumOSVersion: "15.0",
        deviceFamilies: ["1", "2"]  // 1: iPhone, 2: iPad
    )
}

// MARK: - Supporting Types
struct IconColors {
    let primary: UIColor
    let secondary: UIColor
    let accent: UIColor
    let background: UIColor
}

struct IconElement {
    let name: String
    let position: CGPoint  // Normalized (0-1)
    let size: CGSize      // Normalized (0-1)
    let rotation: Double   // Degrees
    let color: UIColor
    let shadow: Bool
}

struct IconSize {
    let size: Double
    let scale: Int
    let idiom: String
    
    var scaledSize: Int {
        return Int(size * Double(scale))
    }
    
    var filename: String {
        return "AppIcon-\(Int(size))x\(Int(size))@\(scale)x"
    }
}

struct IconMetadata {
    let displayName: String
    let bundleID: String
    let versionNumber: String
    let buildNumber: String
    let minimumOSVersion: String
    let deviceFamilies: [String]
}

// MARK: - Icon Generation
extension AppIconConfig {
    static func generateIconSet() {
        // Implementation would:
        // 1. Create icon canvas for each required size
        // 2. Draw background gradient
        // 3. Draw each icon element with proper scaling
        // 4. Apply effects (shadows, glows)
        // 5. Export to PNG files
        // 6. Generate Contents.json for asset catalog
    }
    
    static func generateContentsJSON() -> String {
        // Generate Contents.json for asset catalog
        let images = requiredSizes.map { size in
            """
            {
              "size": "\(size.size)x\(size.size)",
              "idiom": "\(size.idiom)",
              "filename": "\(size.filename).png",
              "scale": "\(size.scale)x"
            }
            """
        }.joined(separator: ",\n")
        
        return """
        {
          "images": [
            \(images)
          ],
          "info": {
            "version": 1,
            "author": "High Noons"
          }
        }
        """
    }
}

// MARK: - Design Guidelines
extension AppIconConfig {
    static let designGuidelines = """
    High Noons App Icon Design Guidelines:
    
    1. Core Elements:
    - Centered revolver silhouette
    - Sheriff's badge accent
    - Western-style decorative frame
    
    2. Color Palette:
    - Primary: Rustic orange (#CC6633)
    - Secondary: Dark brown (#663322)
    - Accent: Gold (#FFCC00)
    - Background: Deep charcoal (#1A1A1A)
    
    3. Design Principles:
    - Bold, recognizable silhouette
    - Clean, uncluttered composition
    - Western/frontier aesthetic
    - Professional finish with subtle effects
    
    4. Technical Requirements:
    - Scales well to all required sizes
    - Clear at smallest sizes (58x58)
    - No text or small details
    - Follows Apple Human Interface Guidelines
    
    5. Effects:
    - Subtle gradient background
    - Light drop shadows
    - Metallic finish on badge
    - Slight texture on frame
    
    6. Testing:
    - Verify visibility on light/dark backgrounds
    - Check all required sizes
    - Test on actual devices
    - Compare with competitor icons
    """
}

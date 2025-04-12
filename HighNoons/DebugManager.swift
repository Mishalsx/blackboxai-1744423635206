import Foundation
import SpriteKit

final class DebugManager {
    // MARK: - Properties
    static let shared = DebugManager()
    
    private let analytics = AnalyticsManager.shared
    private let networkManager = NetworkManager.shared
    
    private var isDebugMode = false
    private var debugOverlay: DebugOverlay?
    private var debugLogs: [DebugLog] = []
    private var performanceMetrics: PerformanceMetrics?
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct DebugOverlay {
        weak var node: SKNode?
        var labels: [String: SKLabelNode] = [:]
        var graphs: [String: [CGPoint]] = [:]
        
        mutating func updateLabel(_ key: String, value: String) {
            if let label = labels[key] {
                label.text = "\(key): \(value)"
            } else {
                let label = SKLabelNode(text: "\(key): \(value)")
                label.fontSize = 12
                label.fontName = "Courier"
                labels[key] = label
                
                // Position label
                let count = labels.count
                label.position = CGPoint(x: 10, y: CGFloat(count) * 15)
                node?.addChild(label)
            }
        }
        
        mutating func updateGraph(_ key: String, value: CGFloat) {
            var points = graphs[key] ?? []
            points.append(CGPoint(x: CGFloat(points.count), y: value))
            
            // Keep last 100 points
            if points.count > 100 {
                points.removeFirst()
            }
            
            graphs[key] = points
            drawGraph(key, points: points)
        }
        
        private func drawGraph(_ key: String, points: [CGPoint]) {
            // Remove old graph
            node?.childNode(withName: "graph_\(key)")?.removeFromParent()
            
            // Create new graph
            let path = CGMutablePath()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            
            let shape = SKShapeNode(path: path)
            shape.name = "graph_\(key)"
            shape.strokeColor = .green
            shape.lineWidth = 1
            
            node?.addChild(shape)
        }
    }
    
    struct DebugLog: Codable {
        let timestamp: Date
        let level: Level
        let category: Category
        let message: String
        let file: String
        let function: String
        let line: Int
        
        enum Level: String, Codable {
            case debug
            case info
            case warning
            case error
            case critical
            
            var color: SKColor {
                switch self {
                case .debug: return .white
                case .info: return .blue
                case .warning: return .yellow
                case .error: return .red
                case .critical: return .purple
                }
            }
        }
        
        enum Category: String, Codable {
            case network
            case performance
            case gameplay
            case ui
            case audio
            case input
            case system
        }
    }
    
    struct PerformanceMetrics: Codable {
        var fps: Double = 0
        var cpu: Double = 0
        var memory: Double = 0
        var drawCalls: Int = 0
        var nodeCount: Int = 0
        var networkLatency: Double = 0
        
        mutating func update(with metrics: PerformanceMetrics) {
            fps = metrics.fps
            cpu = metrics.cpu
            memory = metrics.memory
            drawCalls = metrics.drawCalls
            nodeCount = metrics.nodeCount
            networkLatency = metrics.networkLatency
        }
    }
    
    // MARK: - Initialization
    private init() {
        #if DEBUG
        isDebugMode = true
        setupDebugMode()
        #endif
    }
    
    private func setupDebugMode() {
        setupRefreshTimer()
        setupDebugGestures()
        loadDebugSettings()
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            self?.updatePerformanceMetrics()
        }
    }
    
    private func setupDebugGestures() {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleDebugTap))
        gesture.numberOfTapsRequired = 3
        UIApplication.shared.windows.first?.addGestureRecognizer(gesture)
    }
    
    // MARK: - Debug Controls
    func enableDebugMode() {
        isDebugMode = true
        setupDebugMode()
        analytics.trackEvent(.featureUsed(name: "debug_mode_enabled"))
    }
    
    func disableDebugMode() {
        isDebugMode = false
        cleanup()
        analytics.trackEvent(.featureUsed(name: "debug_mode_disabled"))
    }
    
    func toggleDebugOverlay(in scene: SKScene) {
        if debugOverlay == nil {
            let overlayNode = SKNode()
            scene.addChild(overlayNode)
            debugOverlay = DebugOverlay(node: overlayNode)
        } else {
            debugOverlay?.node?.removeFromParent()
            debugOverlay = nil
        }
    }
    
    // MARK: - Logging
    func log(
        _ message: String,
        level: DebugLog.Level = .debug,
        category: DebugLog.Category,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isDebugMode else { return }
        
        let log = DebugLog(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line
        )
        
        debugLogs.append(log)
        
        // Keep last 1000 logs
        if debugLogs.count > 1000 {
            debugLogs.removeFirst()
        }
        
        // Update overlay if visible
        if let overlay = debugOverlay {
            var updatedOverlay = overlay
            updatedOverlay.updateLabel("LastLog", value: "\(log.level.rawValue): \(message)")
        }
        
        // Log to console in debug builds
        #if DEBUG
        print("[\(log.level.rawValue)][\(log.category.rawValue)] \(message)")
        #endif
    }
    
    // MARK: - Performance Monitoring
    private func updatePerformanceMetrics() {
        guard isDebugMode else { return }
        
        var metrics = PerformanceMetrics()
        
        // Update FPS
        if let view = UIApplication.shared.windows.first?.rootViewController?.view as? SKView {
            metrics.fps = Double(view.fps)
        }
        
        // Update CPU usage
        metrics.cpu = ProcessInfo.processInfo.thermalState == .critical ? 100 : 50
        
        // Update memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            metrics.memory = Double(info.resident_size) / 1024.0 / 1024.0
        }
        
        // Update network latency
        Task {
            do {
                let start = Date()
                _ = try await networkManager.request(endpoint: "ping")
                metrics.networkLatency = Date().timeIntervalSince(start) * 1000
            } catch {
                metrics.networkLatency = -1
            }
        }
        
        // Update scene metrics
        if let scene = (UIApplication.shared.windows.first?.rootViewController?.view as? SKView)?.scene {
            metrics.nodeCount = scene.children.count
        }
        
        performanceMetrics = metrics
        
        // Update overlay if visible
        if let overlay = debugOverlay {
            var updatedOverlay = overlay
            updatedOverlay.updateLabel("FPS", value: String(format: "%.1f", metrics.fps))
            updatedOverlay.updateLabel("CPU", value: String(format: "%.1f%%", metrics.cpu))
            updatedOverlay.updateLabel("Memory", value: String(format: "%.1f MB", metrics.memory))
            updatedOverlay.updateLabel("Nodes", value: "\(metrics.nodeCount)")
            updatedOverlay.updateLabel("Latency", value: String(format: "%.1f ms", metrics.networkLatency))
            
            updatedOverlay.updateGraph("FPS", value: CGFloat(metrics.fps))
            updatedOverlay.updateGraph("Memory", value: CGFloat(metrics.memory))
        }
    }
    
    // MARK: - Debug Tools
    func simulateNetworkCondition(_ condition: NetworkCondition) {
        guard isDebugMode else { return }
        
        switch condition {
        case .perfect:
            NetworkConfig.latency = 0
            NetworkConfig.packetLoss = 0
        case .good:
            NetworkConfig.latency = 50
            NetworkConfig.packetLoss = 0.01
        case .poor:
            NetworkConfig.latency = 200
            NetworkConfig.packetLoss = 0.05
        case .terrible:
            NetworkConfig.latency = 500
            NetworkConfig.packetLoss = 0.1
        }
        
        log("Network condition set to \(condition)", category: .network)
    }
    
    func simulateMemoryWarning() {
        guard isDebugMode else { return }
        
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        log("Simulated memory warning", category: .system)
    }
    
    func crashApp() {
        guard isDebugMode else { return }
        
        fatalError("Deliberate crash triggered by debug tools")
    }
    
    // MARK: - Settings
    private func loadDebugSettings() {
        // Load debug settings from file or defaults
    }
    
    private func saveDebugSettings() {
        // Save current debug settings
    }
    
    // MARK: - Gesture Handling
    @objc private func handleDebugTap() {
        guard isDebugMode else { return }
        
        if let scene = (UIApplication.shared.windows.first?.rootViewController?.view as? SKView)?.scene {
            toggleDebugOverlay(in: scene)
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        debugOverlay?.node?.removeFromParent()
        debugOverlay = nil
        debugLogs.removeAll()
        performanceMetrics = nil
    }
}

// MARK: - Supporting Types
extension DebugManager {
    enum NetworkCondition {
        case perfect
        case good
        case poor
        case terrible
    }
}

// MARK: - Network Configuration
private struct NetworkConfig {
    static var latency: TimeInterval = 0
    static var packetLoss: Double = 0
}

// MARK: - Convenience Methods
extension DebugManager {
    func getLogs(
        level: DebugLog.Level? = nil,
        category: DebugLog.Category? = nil
    ) -> [DebugLog] {
        return debugLogs.filter {
            (level == nil || $0.level == level) &&
            (category == nil || $0.category == category)
        }
    }
    
    func clearLogs() {
        debugLogs.removeAll()
    }
    
    func getPerformanceMetrics() -> PerformanceMetrics? {
        return performanceMetrics
    }
    
    var isDebugging: Bool {
        return isDebugMode
    }
}

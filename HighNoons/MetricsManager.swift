import Foundation
import CoreTelephony
import SystemConfiguration

final class MetricsManager {
    // MARK: - Properties
    static let shared = MetricsManager()
    
    private let networkManager = NetworkManager.shared
    private let analytics = AnalyticsManager.shared
    
    private var sessionMetrics: SessionMetrics?
    private var performanceMetrics: [String: [DataPoint]] = [:]
    private var networkQuality: NetworkQuality = .unknown
    private var refreshTimer: Timer?
    
    // MARK: - Types
    struct SessionMetrics: Codable {
        let sessionId: String
        let startTime: Date
        var duration: TimeInterval
        var events: [MetricEvent]
        var crashes: [CrashReport]
        var networkStats: NetworkStats
        var performanceStats: PerformanceStats
        var userStats: UserStats
        
        struct MetricEvent: Codable {
            let timestamp: Date
            let type: EventType
            let data: [String: String]
            
            enum EventType: String, Codable {
                case screenView
                case action
                case error
                case milestone
                case transaction
                case custom
            }
        }
        
        struct CrashReport: Codable {
            let timestamp: Date
            let type: String
            let reason: String
            let stackTrace: String
            let deviceInfo: DeviceInfo
            let appState: [String: String]
        }
        
        struct NetworkStats: Codable {
            var requestCount: Int
            var totalDataSent: Int64
            var totalDataReceived: Int64
            var averageLatency: Double
            var errorCount: Int
            var connectionType: String
            
            mutating func update(with metrics: NetworkMetrics) {
                requestCount += metrics.requestCount
                totalDataSent += metrics.dataSent
                totalDataReceived += metrics.dataReceived
                averageLatency = (averageLatency + metrics.latency) / 2
                errorCount += metrics.errorCount
            }
        }
        
        struct PerformanceStats: Codable {
            var averageFPS: Double
            var minFPS: Double
            var maxFPS: Double
            var frameDrops: Int
            var memoryUsage: Double
            var cpuUsage: Double
            var gpuUsage: Double
            var batteryLevel: Double
            
            mutating func update(with metrics: PerformanceMetrics) {
                averageFPS = (averageFPS + metrics.fps) / 2
                minFPS = min(minFPS, metrics.fps)
                maxFPS = max(maxFPS, metrics.fps)
                frameDrops += metrics.frameDrops
                memoryUsage = metrics.memoryUsage
                cpuUsage = metrics.cpuUsage
                gpuUsage = metrics.gpuUsage
                batteryLevel = metrics.batteryLevel
            }
        }
        
        struct UserStats: Codable {
            var screenTime: [String: TimeInterval]
            var actions: [String: Int]
            var features: [String: Int]
            var preferences: [String: String]
            
            mutating func recordScreenTime(_ screen: String, duration: TimeInterval) {
                screenTime[screen, default: 0] += duration
            }
            
            mutating func recordAction(_ action: String) {
                actions[action, default: 0] += 1
            }
            
            mutating func recordFeatureUse(_ feature: String) {
                features[feature, default: 0] += 1
            }
        }
    }
    
    struct DataPoint: Codable {
        let timestamp: Date
        let value: Double
    }
    
    struct NetworkMetrics: Codable {
        let requestCount: Int
        let dataSent: Int64
        let dataReceived: Int64
        let latency: Double
        let errorCount: Int
    }
    
    struct PerformanceMetrics: Codable {
        let fps: Double
        let frameDrops: Int
        let memoryUsage: Double
        let cpuUsage: Double
        let gpuUsage: Double
        let batteryLevel: Double
    }
    
    struct DeviceInfo: Codable {
        let model: String
        let systemVersion: String
        let batteryLevel: Float
        let memoryTotal: UInt64
        let memoryAvailable: UInt64
        let diskTotal: Int64
        let diskAvailable: Int64
        let processorCount: Int
        let locale: String
        let timezone: String
    }
    
    enum NetworkQuality {
        case unknown
        case poor
        case fair
        case good
        case excellent
        
        var threshold: Double {
            switch self {
            case .unknown: return 0
            case .poor: return 200
            case .fair: return 100
            case .good: return 50
            case .excellent: return 20
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupRefreshTimer()
        startSession()
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    // MARK: - Session Management
    private func startSession() {
        sessionMetrics = SessionMetrics(
            sessionId: UUID().uuidString,
            startTime: Date(),
            duration: 0,
            events: [],
            crashes: [],
            networkStats: SessionMetrics.NetworkStats(
                requestCount: 0,
                totalDataSent: 0,
                totalDataReceived: 0,
                averageLatency: 0,
                errorCount: 0,
                connectionType: getCurrentConnectionType()
            ),
            performanceStats: SessionMetrics.PerformanceStats(
                averageFPS: 60,
                minFPS: 60,
                maxFPS: 60,
                frameDrops: 0,
                memoryUsage: 0,
                cpuUsage: 0,
                gpuUsage: 0,
                batteryLevel: UIDevice.current.batteryLevel
            ),
            userStats: SessionMetrics.UserStats(
                screenTime: [:],
                actions: [:],
                features: [:],
                preferences: [:]
            )
        )
        
        UIDevice.current.isBatteryMonitoringEnabled = true
    }
    
    // MARK: - Metric Recording
    func recordEvent(
        type: SessionMetrics.MetricEvent.EventType,
        data: [String: String]
    ) {
        let event = SessionMetrics.MetricEvent(
            timestamp: Date(),
            type: type,
            data: data
        )
        
        sessionMetrics?.events.append(event)
    }
    
    func recordCrash(
        type: String,
        reason: String,
        stackTrace: String
    ) {
        let crash = SessionMetrics.CrashReport(
            timestamp: Date(),
            type: type,
            reason: reason,
            stackTrace: stackTrace,
            deviceInfo: collectDeviceInfo(),
            appState: collectAppState()
        )
        
        sessionMetrics?.crashes.append(crash)
        syncMetrics()
    }
    
    func recordNetworkMetrics(_ metrics: NetworkMetrics) {
        sessionMetrics?.networkStats.update(with: metrics)
        
        // Update network quality
        updateNetworkQuality(latency: metrics.latency)
    }
    
    func recordPerformanceMetrics(_ metrics: PerformanceMetrics) {
        sessionMetrics?.performanceStats.update(with: metrics)
        
        // Record data points for trending
        recordDataPoint("fps", value: metrics.fps)
        recordDataPoint("memory", value: metrics.memoryUsage)
        recordDataPoint("cpu", value: metrics.cpuUsage)
    }
    
    private func recordDataPoint(_ metric: String, value: Double) {
        let point = DataPoint(timestamp: Date(), value: value)
        performanceMetrics[metric, default: []].append(point)
        
        // Keep last 100 points
        if performanceMetrics[metric]?.count ?? 0 > 100 {
            performanceMetrics[metric]?.removeFirst()
        }
    }
    
    // MARK: - Metric Updates
    private func updateMetrics() {
        sessionMetrics?.duration = Date().timeIntervalSince(sessionMetrics?.startTime ?? Date())
        
        // Update performance metrics
        let metrics = collectPerformanceMetrics()
        recordPerformanceMetrics(metrics)
        
        // Check for significant changes
        checkPerformanceThresholds()
    }
    
    private func updateNetworkQuality(latency: Double) {
        let newQuality: NetworkQuality
        
        switch latency {
        case 0..<20:
            newQuality = .excellent
        case 20..<50:
            newQuality = .good
        case 50..<100:
            newQuality = .fair
        default:
            newQuality = .poor
        }
        
        if newQuality != networkQuality {
            networkQuality = newQuality
            NotificationCenter.default.post(
                name: .networkQualityChanged,
                object: nil,
                userInfo: ["quality": newQuality]
            )
        }
    }
    
    // MARK: - Data Collection
    private func collectDeviceInfo() -> DeviceInfo {
        let device = UIDevice.current
        let processInfo = ProcessInfo.processInfo
        
        return DeviceInfo(
            model: device.model,
            systemVersion: device.systemVersion,
            batteryLevel: device.batteryLevel,
            memoryTotal: processInfo.physicalMemory,
            memoryAvailable: processInfo.physicalMemory - processInfo.physicalMemory,
            diskTotal: getDiskSpace().total,
            diskAvailable: getDiskSpace().available,
            processorCount: processInfo.processorCount,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier
        )
    }
    
    private func collectAppState() -> [String: String] {
        // Collect relevant app state information
        return [
            "screen": UIApplication.shared.windows.first?.rootViewController?.description ?? "unknown",
            "memoryWarning": UIApplication.shared.performanceState.description,
            "backgroundTime": "\(UIApplication.shared.backgroundTimeRemaining)"
        ]
    }
    
    private func collectPerformanceMetrics() -> PerformanceMetrics {
        return PerformanceMetrics(
            fps: getFPS(),
            frameDrops: getFrameDrops(),
            memoryUsage: getMemoryUsage(),
            cpuUsage: getCPUUsage(),
            gpuUsage: getGPUUsage(),
            batteryLevel: Double(UIDevice.current.batteryLevel)
        )
    }
    
    // MARK: - Utility Methods
    private func getCurrentConnectionType() -> String {
        let reachability = SCNetworkReachabilityCreateWithName(nil, "www.apple.com")
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability!, &flags)
        
        let isReachable = flags.contains(.reachable)
        let isWWAN = flags.contains(.isWWAN)
        
        if !isReachable {
            return "offline"
        } else if isWWAN {
            let info = CTTelephonyNetworkInfo()
            if let carrier = info.serviceSubscriberCellularProviders?.values.first {
                return carrier.currentRadioAccessTechnology ?? "cellular"
            }
            return "cellular"
        } else {
            return "wifi"
        }
    }
    
    private func getDiskSpace() -> (total: Int64, available: Int64) {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            return (
                total: Int64(values.volumeTotalCapacity ?? 0),
                available: Int64(values.volumeAvailableCapacity ?? 0)
            )
        } catch {
            return (0, 0)
        }
    }
    
    private func getFPS() -> Double {
        // Get current FPS from display link or game loop
        return 60.0
    }
    
    private func getFrameDrops() -> Int {
        // Get frame drop count from display link or game loop
        return 0
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Double(info.resident_size) / 1024.0 / 1024.0 : 0
    }
    
    private func getCPUUsage() -> Double {
        // Get CPU usage from process info
        return 0.0
    }
    
    private func getGPUUsage() -> Double {
        // Get GPU usage from Metal performance metrics
        return 0.0
    }
    
    // MARK: - Thresholds
    private func checkPerformanceThresholds() {
        guard let stats = sessionMetrics?.performanceStats else { return }
        
        // Check FPS
        if stats.averageFPS < 30 {
            NotificationCenter.default.post(name: .lowFPSDetected, object: nil)
        }
        
        // Check memory
        if stats.memoryUsage > 1000 { // 1GB
            NotificationCenter.default.post(name: .highMemoryUsageDetected, object: nil)
        }
        
        // Check battery
        if stats.batteryLevel < 0.2 {
            NotificationCenter.default.post(name: .lowBatteryDetected, object: nil)
        }
    }
    
    // MARK: - Data Syncing
    private func syncMetrics() {
        guard let metrics = sessionMetrics else { return }
        
        Task {
            do {
                try await networkManager.request(
                    endpoint: "metrics/sync",
                    method: .post,
                    parameters: ["metrics": metrics]
                )
            } catch {
                print("Failed to sync metrics: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        UIDevice.current.isBatteryMonitoringEnabled = false
        syncMetrics()
        sessionMetrics = nil
        performanceMetrics.removeAll()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let networkQualityChanged = Notification.Name("networkQualityChanged")
    static let lowFPSDetected = Notification.Name("lowFPSDetected")
    static let highMemoryUsageDetected = Notification.Name("highMemoryUsageDetected")
    static let lowBatteryDetected = Notification.Name("lowBatteryDetected")
}

// MARK: - Convenience Methods
extension MetricsManager {
    func getCurrentNetworkQuality() -> NetworkQuality {
        return networkQuality
    }
    
    func getMetricHistory(_ metric: String) -> [DataPoint] {
        return performanceMetrics[metric] ?? []
    }
    
    func getSessionDuration() -> TimeInterval {
        return sessionMetrics?.duration ?? 0
    }
    
    func getAverageFPS() -> Double {
        return sessionMetrics?.performanceStats.averageFPS ?? 0
    }
}

import Foundation
import SpriteKit
import MetricKit

final class PerformanceManager {
    // MARK: - Properties
    static let shared = PerformanceManager()
    
    private let analytics = AnalyticsManager.shared
    private let maxFrameTime: TimeInterval = 1.0 / 60.0 // Target 60 FPS
    private let samplingInterval: TimeInterval = 1.0
    
    private var frameTimeHistory: [TimeInterval] = []
    private var lastFrameTime: TimeInterval = 0
    private var frameCount: Int = 0
    private var droppedFrames: Int = 0
    
    private var memoryWarningCount: Int = 0
    private var lastMemoryWarning: Date?
    
    private var isMonitoring = false
    private var monitoringTimer: Timer?
    
    // MARK: - Types
    struct PerformanceMetrics {
        var fps: Double
        var averageFrameTime: TimeInterval
        var droppedFrames: Int
        var memoryUsage: UInt64
        var cpuUsage: Double
        var thermalState: ProcessInfo.ThermalState
        
        static var empty: PerformanceMetrics {
            return PerformanceMetrics(
                fps: 0,
                averageFrameTime: 0,
                droppedFrames: 0,
                memoryUsage: 0,
                cpuUsage: 0,
                thermalState: .nominal
            )
        }
    }
    
    enum PerformanceIssue {
        case lowFPS
        case highMemory
        case thermalThrottling
        case frequentDrops
        
        var threshold: Double {
            switch self {
            case .lowFPS: return 45.0 // FPS
            case .highMemory: return 0.8 // 80% of available memory
            case .thermalThrottling: return 0.0 // Any thermal throttling
            case .frequentDrops: return 5.0 // Drops per second
            }
        }
    }
    
    // MARK: - Initialization
    private override init() {
        setupMetricKit()
        setupNotifications()
    }
    
    private func setupMetricKit() {
        if #available(iOS 13.0, *) {
            MXMetricManager.shared.add(self)
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackgroundTransition),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    // MARK: - Monitoring
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        resetMetrics()
        
        monitoringTimer = Timer.scheduledTimer(
            withTimeInterval: samplingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkPerformance()
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func resetMetrics() {
        frameTimeHistory.removeAll()
        frameCount = 0
        droppedFrames = 0
        lastFrameTime = CACurrentMediaTime()
    }
    
    // MARK: - Frame Timing
    func recordFrame() {
        guard isMonitoring else { return }
        
        let currentTime = CACurrentMediaTime()
        let frameTime = currentTime - lastFrameTime
        
        frameTimeHistory.append(frameTime)
        if frameTimeHistory.count > 60 {
            frameTimeHistory.removeFirst()
        }
        
        if frameTime > maxFrameTime * 1.5 {
            droppedFrames += 1
        }
        
        frameCount += 1
        lastFrameTime = currentTime
    }
    
    // MARK: - Performance Checks
    private func checkPerformance() {
        let metrics = getCurrentMetrics()
        
        // Check for performance issues
        var issues: [PerformanceIssue] = []
        
        if metrics.fps < PerformanceIssue.lowFPS.threshold {
            issues.append(.lowFPS)
        }
        
        if metrics.droppedFrames > Int(PerformanceIssue.frequentDrops.threshold) {
            issues.append(.frequentDrops)
        }
        
        if metrics.thermalState != .nominal {
            issues.append(.thermalThrottling)
        }
        
        if !issues.isEmpty {
            handlePerformanceIssues(issues, metrics: metrics)
        }
        
        // Log metrics
        logMetrics(metrics)
        
        // Reset frame counting
        frameCount = 0
        droppedFrames = 0
    }
    
    private func getCurrentMetrics() -> PerformanceMetrics {
        let fps = Double(frameCount) / samplingInterval
        let averageFrameTime = frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
        
        return PerformanceMetrics(
            fps: fps,
            averageFrameTime: averageFrameTime,
            droppedFrames: droppedFrames,
            memoryUsage: getMemoryUsage(),
            cpuUsage: getCPUUsage(),
            thermalState: ProcessInfo.processInfo.thermalState
        )
    }
    
    // MARK: - System Metrics
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
    
    private func getCPUUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let threadResult = task_threads(mach_task_self_, &threadList, &threadCount)
        
        if threadResult == KERN_SUCCESS, let threadList = threadList {
            for index in 0..<threadCount {
                var threadInfo = thread_basic_info()
                var count = mach_msg_type_number_t(THREAD_BASIC_INFO_COUNT)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadList[Int(index)],
                                  thread_flavor_t(THREAD_BASIC_INFO),
                                  $0,
                                  &count)
                    }
                }
                
                if infoResult == KERN_SUCCESS {
                    totalUsageOfCPU += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE)
                }
            }
            
            vm_deallocate(mach_task_self_,
                         vm_address_t(UInt(bitPattern: threadList)),
                         vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride))
        }
        
        return totalUsageOfCPU
    }
    
    // MARK: - Issue Handling
    private func handlePerformanceIssues(_ issues: [PerformanceIssue], metrics: PerformanceMetrics) {
        // Log issues
        analytics.trackEvent(.frameDrop(count: metrics.droppedFrames))
        
        // Apply optimizations
        for issue in issues {
            switch issue {
            case .lowFPS:
                applyLowFPSOptimizations()
            case .highMemory:
                applyMemoryOptimizations()
            case .thermalThrottling:
                applyThermalOptimizations()
            case .frequentDrops:
                applyDropOptimizations()
            }
        }
    }
    
    private func applyLowFPSOptimizations() {
        // Reduce particle effects
        ParticleManager.shared.reduceParticleCount()
        
        // Simplify animations
        // Reduce draw calls
    }
    
    private func applyMemoryOptimizations() {
        // Clear caches
        // Release unused resources
        // Reduce texture quality
    }
    
    private func applyThermalOptimizations() {
        // Reduce update frequency
        // Disable intensive features
        // Lower graphics quality
    }
    
    private func applyDropOptimizations() {
        // Optimize render pipeline
        // Reduce background processes
        // Simplify physics
    }
    
    // MARK: - Logging
    private func logMetrics(_ metrics: PerformanceMetrics) {
        #if DEBUG
        print("Performance Metrics:")
        print("FPS: \(metrics.fps)")
        print("Frame Time: \(metrics.averageFrameTime)")
        print("Dropped Frames: \(metrics.droppedFrames)")
        print("Memory Usage: \(metrics.memoryUsage)")
        print("CPU Usage: \(metrics.cpuUsage)")
        print("Thermal State: \(metrics.thermalState)")
        #endif
        
        analytics.trackEvent(.loadingTime(
            screen: "performance",
            duration: metrics.averageFrameTime
        ))
    }
    
    // MARK: - Notifications
    @objc private func handleMemoryWarning() {
        memoryWarningCount += 1
        lastMemoryWarning = Date()
        
        applyMemoryOptimizations()
        
        analytics.trackEvent(.featureUsed(name: "memory_warning"))
    }
    
    @objc private func handleBackgroundTransition() {
        stopMonitoring()
    }
}

// MARK: - MetricKit Integration
@available(iOS 13.0, *)
extension PerformanceManager: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        // Process MetricKit payloads
        for payload in payloads {
            if let metrics = payload.animationMetrics {
                analytics.trackEvent(.loadingTime(
                    screen: "animation_metrics",
                    duration: metrics.scrollHitchTime.averageValue
                ))
            }
        }
    }
}

// MARK: - ParticleManager Extension
private extension ParticleManager {
    func reduceParticleCount() {
        // Implement particle reduction logic
    }
}

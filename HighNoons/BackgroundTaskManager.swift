import Foundation
import BackgroundTasks

final class BackgroundTaskManager {
    // MARK: - Properties
    static let shared = BackgroundTaskManager()
    
    private let analytics = AnalyticsManager.shared
    private let networkManager = NetworkManager.shared
    private let settings = SettingsManager.shared
    
    private var backgroundTasks: [String: BGTask] = [:]
    private var pendingOperations: [BackgroundOperation] = []
    private var isProcessing = false
    
    // MARK: - Task Identifiers
    private enum TaskIdentifier {
        static let refresh = "com.highnoons.refresh"
        static let sync = "com.highnoons.sync"
        static let cleanup = "com.highnoons.cleanup"
        static let prefetch = "com.highnoons.prefetch"
        static let maintenance = "com.highnoons.maintenance"
    }
    
    // MARK: - Types
    struct BackgroundOperation: Codable {
        let id: String
        let type: OperationType
        let priority: Priority
        let data: [String: String]
        let createdAt: Date
        let retryCount: Int
        let lastError: String?
        
        enum OperationType: String, Codable {
            case dataSyncing
            case resourcePrefetch
            case cacheCleanup
            case stateRefresh
            case assetDownload
            case dataBackup
            case systemMaintenance
            
            var maxRetries: Int {
                switch self {
                case .dataSyncing: return 3
                case .resourcePrefetch: return 2
                case .cacheCleanup: return 1
                case .stateRefresh: return 3
                case .assetDownload: return 5
                case .dataBackup: return 3
                case .systemMaintenance: return 2
                }
            }
            
            var timeout: TimeInterval {
                switch self {
                case .dataSyncing: return 30
                case .resourcePrefetch: return 180
                case .cacheCleanup: return 60
                case .stateRefresh: return 30
                case .assetDownload: return 300
                case .dataBackup: return 120
                case .systemMaintenance: return 180
                }
            }
        }
        
        enum Priority: Int, Codable {
            case low = 0
            case medium = 1
            case high = 2
            case critical = 3
        }
        
        static func create(
            type: OperationType,
            priority: Priority = .medium,
            data: [String: String] = [:]
        ) -> BackgroundOperation {
            return BackgroundOperation(
                id: UUID().uuidString,
                type: type,
                priority: priority,
                data: data,
                createdAt: Date(),
                retryCount: 0,
                lastError: nil
            )
        }
    }
    
    // MARK: - Initialization
    private init() {
        registerBackgroundTasks()
    }
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifier.refresh,
            using: nil
        ) { task in
            self.handleRefreshTask(task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifier.sync,
            using: nil
        ) { task in
            self.handleSyncTask(task as! BGProcessingTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifier.cleanup,
            using: nil
        ) { task in
            self.handleCleanupTask(task as! BGProcessingTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifier.prefetch,
            using: nil
        ) { task in
            self.handlePrefetchTask(task as! BGProcessingTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifier.maintenance,
            using: nil
        ) { task in
            self.handleMaintenanceTask(task as! BGProcessingTask)
        }
    }
    
    // MARK: - Task Scheduling
    func scheduleBackgroundTasks() {
        guard settings.backgroundRefresh else { return }
        
        scheduleRefreshTask()
        scheduleSyncTask()
        scheduleCleanupTask()
        schedulePrefetchTask()
        scheduleMaintenanceTask()
    }
    
    private func scheduleRefreshTask() {
        let request = BGAppRefreshTaskRequest(identifier: TaskIdentifier.refresh)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule refresh task: \(error.localizedDescription)")
        }
    }
    
    private func scheduleSyncTask() {
        let request = BGProcessingTaskRequest(identifier: TaskIdentifier.sync)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule sync task: \(error.localizedDescription)")
        }
    }
    
    private func scheduleCleanupTask() {
        let request = BGProcessingTaskRequest(identifier: TaskIdentifier.cleanup)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule cleanup task: \(error.localizedDescription)")
        }
    }
    
    private func schedulePrefetchTask() {
        let request = BGProcessingTaskRequest(identifier: TaskIdentifier.prefetch)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60 * 60) // 2 hours
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule prefetch task: \(error.localizedDescription)")
        }
    }
    
    private func scheduleMaintenanceTask() {
        let request = BGProcessingTaskRequest(identifier: TaskIdentifier.maintenance)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60) // 4 hours
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule maintenance task: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Task Handling
    private func handleRefreshTask(_ task: BGAppRefreshTask) {
        scheduleRefreshTask() // Schedule next refresh
        
        task.expirationHandler = {
            self.cancelOperations(type: .stateRefresh)
        }
        
        let operation = BackgroundOperation.create(
            type: .stateRefresh,
            priority: .high
        )
        
        addOperation(operation)
        
        processOperations { success in
            task.setTaskCompleted(success: success)
        }
    }
    
    private func handleSyncTask(_ task: BGProcessingTask) {
        scheduleSyncTask() // Schedule next sync
        
        task.expirationHandler = {
            self.cancelOperations(type: .dataSyncing)
        }
        
        let operation = BackgroundOperation.create(
            type: .dataSyncing,
            priority: .medium
        )
        
        addOperation(operation)
        
        processOperations { success in
            task.setTaskCompleted(success: success)
        }
    }
    
    private func handleCleanupTask(_ task: BGProcessingTask) {
        scheduleCleanupTask() // Schedule next cleanup
        
        task.expirationHandler = {
            self.cancelOperations(type: .cacheCleanup)
        }
        
        let operation = BackgroundOperation.create(
            type: .cacheCleanup,
            priority: .low
        )
        
        addOperation(operation)
        
        processOperations { success in
            task.setTaskCompleted(success: success)
        }
    }
    
    private func handlePrefetchTask(_ task: BGProcessingTask) {
        schedulePrefetchTask() // Schedule next prefetch
        
        task.expirationHandler = {
            self.cancelOperations(type: .resourcePrefetch)
        }
        
        let operation = BackgroundOperation.create(
            type: .resourcePrefetch,
            priority: .low
        )
        
        addOperation(operation)
        
        processOperations { success in
            task.setTaskCompleted(success: success)
        }
    }
    
    private func handleMaintenanceTask(_ task: BGProcessingTask) {
        scheduleMaintenanceTask() // Schedule next maintenance
        
        task.expirationHandler = {
            self.cancelOperations(type: .systemMaintenance)
        }
        
        let operation = BackgroundOperation.create(
            type: .systemMaintenance,
            priority: .low
        )
        
        addOperation(operation)
        
        processOperations { success in
            task.setTaskCompleted(success: success)
        }
    }
    
    // MARK: - Operation Management
    func addOperation(_ operation: BackgroundOperation) {
        pendingOperations.append(operation)
        pendingOperations.sort { $0.priority.rawValue > $1.priority.rawValue }
        
        if !isProcessing {
            processOperations()
        }
    }
    
    private func processOperations(completion: ((Bool) -> Void)? = nil) {
        guard !isProcessing, let operation = pendingOperations.first else {
            completion?(true)
            return
        }
        
        isProcessing = true
        
        performOperation(operation) { [weak self] success in
            guard let self = self else { return }
            
            self.isProcessing = false
            
            if success {
                self.pendingOperations.removeFirst()
                self.processOperations(completion: completion)
            } else if operation.retryCount < operation.type.maxRetries {
                // Retry operation
                var retryOperation = operation
                retryOperation.retryCount += 1
                self.pendingOperations[0] = retryOperation
                self.processOperations(completion: completion)
            } else {
                // Operation failed after max retries
                self.pendingOperations.removeFirst()
                self.processOperations(completion: completion)
            }
        }
    }
    
    private func performOperation(
        _ operation: BackgroundOperation,
        completion: @escaping (Bool) -> Void
    ) {
        switch operation.type {
        case .dataSyncing:
            performDataSync(completion: completion)
        case .resourcePrefetch:
            performResourcePrefetch(completion: completion)
        case .cacheCleanup:
            performCacheCleanup(completion: completion)
        case .stateRefresh:
            performStateRefresh(completion: completion)
        case .assetDownload:
            performAssetDownload(operation.data, completion: completion)
        case .dataBackup:
            performDataBackup(completion: completion)
        case .systemMaintenance:
            performSystemMaintenance(completion: completion)
        }
    }
    
    private func cancelOperations(type: BackgroundOperation.OperationType? = nil) {
        if let type = type {
            pendingOperations.removeAll { $0.type == type }
        } else {
            pendingOperations.removeAll()
        }
        isProcessing = false
    }
    
    // MARK: - Operation Implementation
    private func performDataSync(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // Sync player stats
                try await networkManager.request(
                    endpoint: "sync/stats",
                    method: .post,
                    parameters: ["stats": PlayerStats.shared]
                )
                
                // Sync settings
                try await networkManager.request(
                    endpoint: "sync/settings",
                    method: .post,
                    parameters: ["settings": settings]
                )
                
                analytics.trackEvent(.featureUsed(name: "background_sync"))
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
    
    private func performResourcePrefetch(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let resources: [String] = try await networkManager.request(
                    endpoint: "resources/required"
                )
                
                for resource in resources {
                    try await networkManager.request(
                        endpoint: "resources/\(resource)"
                    )
                }
                
                analytics.trackEvent(.featureUsed(name: "resource_prefetch"))
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
    
    private func performCacheCleanup(completion: @escaping (Bool) -> Void) {
        // Clear old caches
        let fileManager = FileManager.default
        let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        
        do {
            let resourceKeys = Set<URLResourceKey>([.creationDateKey])
            let enumerator = fileManager.enumerator(
                at: cacheURL,
                includingPropertiesForKeys: Array(resourceKeys)
            )
            
            while let fileURL = enumerator?.nextObject() as? URL {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                if let creationDate = resourceValues.creationDate,
                   creationDate < Date(timeIntervalSinceNow: -7 * 24 * 60 * 60) { // 7 days
                    try fileManager.removeItem(at: fileURL)
                }
            }
            
            analytics.trackEvent(.featureUsed(name: "cache_cleanup"))
            completion(true)
        } catch {
            completion(false)
        }
    }
    
    private func performStateRefresh(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // Refresh game state
                try await networkManager.request(endpoint: "state/refresh")
                
                analytics.trackEvent(.featureUsed(name: "state_refresh"))
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
    
    private func performAssetDownload(
        _ data: [String: String],
        completion: @escaping (Bool) -> Void
    ) {
        guard let assetUrl = data["url"] else {
            completion(false)
            return
        }
        
        Task {
            do {
                let data: Data = try await networkManager.request(
                    endpoint: assetUrl
                )
                
                // Save asset data
                let fileManager = FileManager.default
                let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let assetURL = documentsURL.appendingPathComponent(UUID().uuidString)
                try data.write(to: assetURL)
                
                analytics.trackEvent(.featureUsed(name: "asset_download"))
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
    
    private func performDataBackup(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // Backup user data
                let backup = try JSONEncoder().encode(PlayerStats.shared)
                
                try await networkManager.request(
                    endpoint: "backup",
                    method: .post,
                    parameters: ["data": backup]
                )
                
                analytics.trackEvent(.featureUsed(name: "data_backup"))
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
    
    private func performSystemMaintenance(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // Perform system checks
                try await networkManager.request(endpoint: "system/maintenance")
                
                analytics.trackEvent(.featureUsed(name: "system_maintenance"))
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        cancelOperations()
        BGTaskScheduler.shared.cancelAllTaskRequests()
    }
}

// MARK: - Convenience Methods
extension BackgroundTaskManager {
    func getPendingOperations() -> [BackgroundOperation] {
        return pendingOperations
    }
    
    func cancelOperation(_ operationId: String) {
        pendingOperations.removeAll { $0.id == operationId }
    }
    
    var isRunningBackgroundTask: Bool {
        return isProcessing
    }
}

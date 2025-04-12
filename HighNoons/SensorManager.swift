import CoreMotion
import Foundation

/// Manages device motion detection for determining when phone is raised
final class SensorManager {
    // MARK: - Singleton
    static let shared = SensorManager()
    private init() {}
    
    // MARK: - Properties
    private let motionManager = CMMotionManager()
    private var phoneRaisedHandler: ((Bool) -> Void)?
    
    // Threshold values for determining if phone is raised
    private let pitchThreshold: Double = -0.5  // Adjust as needed
    private let updateInterval: TimeInterval = 1.0/60.0  // 60Hz updates
    
    // MARK: - Monitoring Control
    func startMonitoring(handler: @escaping (Bool) -> Void) {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            // Fall back to bot mode
            simulateDeviceMotion(handler: handler)
            return
        }
        
        phoneRaisedHandler = handler
        motionManager.deviceMotionUpdateInterval = updateInterval
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            if let error = error {
                print("Motion update error: \(error.localizedDescription)")
                return
            }
            
            self?.processMotionData(motion)
        }
    }
    
    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        phoneRaisedHandler = nil
    }
    
    // MARK: - Motion Processing
    private func processMotionData(_ motion: CMDeviceMotion?) {
        guard let motion = motion else { return }
        
        // Use pitch to determine if phone is raised
        let pitch = motion.attitude.pitch
        let isRaised = pitch < pitchThreshold
        
        phoneRaisedHandler?(isRaised)
    }
    
    // MARK: - Bot Mode Simulation
    private func simulateDeviceMotion(handler: @escaping (Bool) -> Void) {
        // Simulate phone being raised after random delay
        DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 1...3)) {
            handler(true)
        }
    }
    
    // MARK: - Calibration
    func calibrate() {
        // TODO: Add calibration logic to adjust thresholds based on device orientation
        // This would help improve accuracy across different devices and user holding positions
    }
}

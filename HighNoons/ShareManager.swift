import UIKit
import Social
import Photos
import AVFoundation

final class ShareManager {
    // MARK: - Properties
    static let shared = ShareManager()
    
    private let analytics = AnalyticsManager.shared
    private let replayManager = ReplayManager.shared
    
    // MARK: - Types
    enum ShareType {
        case score(Int)
        case achievement(String)
        case replay(String)
        case screenshot
        case customMessage(String)
    }
    
    enum ShareError: Error {
        case noContent
        case replayNotFound
        case screenshotFailed
        case recordingFailed
        case exportFailed
        case noPermission
    }
    
    // MARK: - Sharing Methods
    func share(
        _ type: ShareType,
        from viewController: UIViewController,
        completion: ((Result<Bool, ShareError>) -> Void)? = nil
    ) {
        switch type {
        case .score(let score):
            shareScore(score, from: viewController, completion: completion)
        case .achievement(let name):
            shareAchievement(name, from: viewController, completion: completion)
        case .replay(let replayId):
            shareReplay(replayId, from: viewController, completion: completion)
        case .screenshot:
            shareScreenshot(from: viewController, completion: completion)
        case .customMessage(let message):
            shareCustomMessage(message, from: viewController, completion: completion)
        }
    }
    
    // MARK: - Score Sharing
    private func shareScore(
        _ score: Int,
        from viewController: UIViewController,
        completion: ((Result<Bool, ShareError>) -> Void)?
    ) {
        let message = "I just scored \(score) points in High Noons! Can you beat my score? 🤠"
        let url = URL(string: "https://highnoons.com/download")!
        
        let items: [Any] = [
            message,
            url
        ]
        
        presentShareSheet(items, from: viewController) { result in
            self.analytics.trackEvent(.featureUsed(name: "share_score"))
            completion?(result)
        }
    }
    
    // MARK: - Achievement Sharing
    private func shareAchievement(
        _ name: String,
        from viewController: UIViewController,
        completion: ((Result<Bool, ShareError>) -> Void)?
    ) {
        let message = "I just unlocked the '\(name)' achievement in High Noons! 🎯"
        let url = URL(string: "https://highnoons.com/download")!
        
        let items: [Any] = [
            message,
            url
        ]
        
        presentShareSheet(items, from: viewController) { result in
            self.analytics.trackEvent(.featureUsed(name: "share_achievement"))
            completion?(result)
        }
    }
    
    // MARK: - Replay Sharing
    private func shareReplay(
        _ replayId: String,
        from viewController: UIViewController,
        completion: ((Result<Bool, ShareError>) -> Void)?
    ) {
        Task {
            do {
                let replay = try await replayManager.fetchReplay(id: replayId)
                let replayURL = try await generateReplayVideo(replay)
                
                let message = "Check out my epic duel in High Noons! ⚔️"
                
                DispatchQueue.main.async {
                    let items: [Any] = [
                        message,
                        replayURL
                    ]
                    
                    self.presentShareSheet(items, from: viewController) { result in
                        self.analytics.trackEvent(.featureUsed(name: "share_replay"))
                        completion?(result)
                    }
                }
            } catch {
                completion?(.failure(.replayNotFound))
            }
        }
    }
    
    private func generateReplayVideo(_ replay: ReplayManager.ReplayRecording) async throws -> URL {
        // Create temporary URL for video
        let tempDir = FileManager.default.temporaryDirectory
        let videoURL = tempDir.appendingPathComponent("\(replay.id).mp4")
        
        // Video settings
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1080,
            AVVideoHeightKey: 1920
        ]
        
        guard let writer = try? AVAssetWriter(url: videoURL, fileType: .mp4) else {
            throw ShareError.recordingFailed
        }
        
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        writer.add(input)
        
        // Start recording session
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        // Record frames
        // TODO: Implement frame recording from replay data
        
        // Finish recording
        writer.finishWriting {
            // Cleanup
        }
        
        return videoURL
    }
    
    // MARK: - Screenshot Sharing
    private func shareScreenshot(
        from viewController: UIViewController,
        completion: ((Result<Bool, ShareError>) -> Void)?
    ) {
        guard let screenshot = takeScreenshot() else {
            completion?(.failure(.screenshotFailed))
            return
        }
        
        let message = "Playing High Noons! 🎮"
        
        let items: [Any] = [
            message,
            screenshot
        ]
        
        presentShareSheet(items, from: viewController) { result in
            self.analytics.trackEvent(.featureUsed(name: "share_screenshot"))
            completion?(result)
        }
    }
    
    private func takeScreenshot() -> UIImage? {
        guard let window = UIApplication.shared.windows.first else { return nil }
        
        let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
        return renderer.image { context in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }
    
    // MARK: - Custom Message Sharing
    private func shareCustomMessage(
        _ message: String,
        from viewController: UIViewController,
        completion: ((Result<Bool, ShareError>) -> Void)?
    ) {
        let items: [Any] = [message]
        
        presentShareSheet(items, from: viewController) { result in
            self.analytics.trackEvent(.featureUsed(name: "share_custom"))
            completion?(result)
        }
    }
    
    // MARK: - Share Sheet
    private func presentShareSheet(
        _ items: [Any],
        from viewController: UIViewController,
        completion: ((Result<Bool, ShareError>) -> Void)?
    ) {
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Exclude certain activities
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks,
            .saveToCameraRoll
        ]
        
        // iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0,
                height: 0
            )
        }
        
        activityVC.completionWithItemsHandler = { _, completed, _, error in
            if let error = error {
                completion?(.failure(.exportFailed))
            } else {
                completion?(.success(completed))
            }
        }
        
        viewController.present(activityVC, animated: true)
    }
    
    // MARK: - Permissions
    private func checkPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus()
        
        if status == .notDetermined {
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
        
        return status == .authorized
    }
}

// MARK: - Convenience Methods
extension ShareManager {
    func shareHighScore(_ score: Int, from viewController: UIViewController) {
        share(.score(score), from: viewController) { result in
            switch result {
            case .success(true):
                print("Score shared successfully")
            case .success(false):
                print("Share cancelled")
            case .failure(let error):
                print("Share failed: \(error)")
            }
        }
    }
    
    func shareLastReplay(from viewController: UIViewController) {
        let recordings = replayManager.loadLocalRecordings()
        if let lastReplay = recordings.last {
            share(.replay(lastReplay.id), from: viewController)
        }
    }
}

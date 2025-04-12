import Foundation
import GoogleMobileAds
import UnityAds

final class AdManager: NSObject {
    // MARK: - Types
    enum AdProvider {
        case admob
        case unityAds
    }
    
    enum AdType {
        case interstitial
        case rewarded
    }
    
    enum AdError: Error {
        case notInitialized
        case loadFailed(String)
        case notReady
        case rewardNotEarned
    }
    
    // MARK: - Properties
    static let shared = AdManager()
    
    private var provider: AdProvider = .admob
    private var isInitialized = false
    private var interstitialAd: GADInterstitialAd?
    private var rewardedAd: GADRewardedAd?
    
    // Configuration
    private let adMobAppID = "ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY" // Replace with actual ID
    private let interstitialAdID = "ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ" // Replace with actual ID
    private let rewardedAdID = "ca-app-pub-XXXXXXXXXXXXXXXX/WWWWWWWWWW" // Replace with actual ID
    private let unityGameID = "1234567" // Replace with actual ID
    private let testMode = true
    
    // Callbacks
    private var rewardCompletion: ((Result<Int, AdError>) -> Void)?
    
    // MARK: - Initialization
    private override init() {
        super.init()
    }
    
    func initialize() {
        switch provider {
        case .admob:
            initializeAdMob()
        case .unityAds:
            initializeUnityAds()
        }
    }
    
    private func initializeAdMob() {
        GADMobileAds.sharedInstance().start { [weak self] status in
            self?.isInitialized = true
            print("AdMob initialization complete with status: \(status)")
            
            // Pre-load ads
            self?.loadInterstitialAd()
            self?.loadRewardedAd()
        }
    }
    
    private func initializeUnityAds() {
        UnityAds.initialize(unityGameID, testMode: testMode) { [weak self] status in
            self?.isInitialized = true
            print("Unity Ads initialization complete with status: \(status)")
        }
    }
    
    // MARK: - Ad Loading
    private func loadInterstitialAd() {
        switch provider {
        case .admob:
            loadAdMobInterstitial()
        case .unityAds:
            // Unity Ads loads automatically
            break
        }
    }
    
    private func loadAdMobInterstitial() {
        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: interstitialAdID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad: \(error.localizedDescription)")
                return
            }
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
        }
    }
    
    private func loadRewardedAd() {
        switch provider {
        case .admob:
            loadAdMobRewarded()
        case .unityAds:
            // Unity Ads loads automatically
            break
        }
    }
    
    private func loadAdMobRewarded() {
        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: rewardedAdID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load rewarded ad: \(error.localizedDescription)")
                return
            }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
        }
    }
    
    // MARK: - Ad Presentation
    func showInterstitial(from viewController: UIViewController) {
        guard isInitialized else {
            print("Ad Manager not initialized")
            return
        }
        
        switch provider {
        case .admob:
            showAdMobInterstitial(from: viewController)
        case .unityAds:
            showUnityInterstitial(from: viewController)
        }
    }
    
    private func showAdMobInterstitial(from viewController: UIViewController) {
        if let ad = interstitialAd {
            ad.present(fromRootViewController: viewController)
        } else {
            print("Interstitial ad not ready")
            loadInterstitialAd()
        }
    }
    
    private func showUnityInterstitial(from viewController: UIViewController) {
        UnityAds.show(viewController, placementId: "interstitial") { error in
            if let error = error {
                print("Failed to show Unity interstitial: \(error.localizedDescription)")
            }
        }
    }
    
    func showRewarded(from viewController: UIViewController, completion: @escaping (Result<Int, AdError>) -> Void) {
        guard isInitialized else {
            completion(.failure(.notInitialized))
            return
        }
        
        rewardCompletion = completion
        
        switch provider {
        case .admob:
            showAdMobRewarded(from: viewController)
        case .unityAds:
            showUnityRewarded(from: viewController)
        }
    }
    
    private func showAdMobRewarded(from viewController: UIViewController) {
        if let ad = rewardedAd {
            ad.present(fromRootViewController: viewController) { [weak self] in
                // Reward the user
                self?.rewardCompletion?(.success(10)) // Example reward amount
            }
        } else {
            rewardCompletion?(.failure(.notReady))
            loadRewardedAd()
        }
    }
    
    private func showUnityRewarded(from viewController: UIViewController) {
        UnityAds.show(viewController, placementId: "rewardedVideo") { [weak self] error in
            if let error = error {
                self?.rewardCompletion?(.failure(.loadFailed(error.localizedDescription)))
            } else {
                self?.rewardCompletion?(.success(10)) // Example reward amount
            }
        }
    }
}

// MARK: - GADFullScreenContentDelegate
extension AdManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        // Load the next ad
        if ad is GADInterstitialAd {
            loadInterstitialAd()
        } else if ad is GADRewardedAd {
            loadRewardedAd()
        }
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Ad failed to present: \(error.localizedDescription)")
        
        if ad is GADRewardedAd {
            rewardCompletion?(.failure(.loadFailed(error.localizedDescription)))
        }
    }
}

// MARK: - Unity Ads Delegate
extension AdManager: UnityAdsDelegate {
    func unityAdsReady(_ placementId: String) {
        print("Unity Ads ready for placement: \(placementId)")
    }
    
    func unityAdsDidError(_ error: UnityAdsError, withMessage message: String) {
        print("Unity Ads error: \(message)")
    }
    
    func unityAdsDidStart(_ placementId: String) {
        print("Unity Ads started for placement: \(placementId)")
    }
    
    func unityAdsDidFinish(_ placementId: String, with state: UnityAdsFinishState) {
        if placementId == "rewardedVideo" {
            switch state {
            case .completed:
                rewardCompletion?(.success(10)) // Example reward amount
            case .skipped:
                rewardCompletion?(.failure(.rewardNotEarned))
            case .error:
                rewardCompletion?(.failure(.loadFailed("Unity Ads finish error")))
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Convenience Methods
extension AdManager {
    func showInterstitialIfReady(from viewController: UIViewController) {
        // Show interstitial with 30% probability
        if Double.random(in: 0...1) < 0.3 {
            showInterstitial(from: viewController)
        }
    }
    
    func showRewardedForRetry(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        showRewarded(from: viewController) { result in
            switch result {
            case .success:
                completion(true)
            case .failure:
                completion(false)
            }
        }
    }
}

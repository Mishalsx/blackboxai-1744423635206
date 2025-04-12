import AVFoundation
import Foundation

final class AudioManager {
    // MARK: - Singleton
    static let shared = AudioManager()
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Sound Types
    enum SoundType {
        case draw
        case gunshot
        case victory
        case defeat
        case fail
        case background
        
        var filename: String {
            switch self {
            case .draw: return "draw"
            case .gunshot: return "gunshot"
            case .victory: return "victory"
            case .defeat: return "defeat"
            case .fail: return "fail"
            case .background: return "background_music"
            }
        }
        
        var fileExtension: String {
            switch self {
            case .background: return "mp3"
            default: return "wav"
            }
        }
    }
    
    // MARK: - Properties
    private var audioPlayers: [SoundType: AVAudioPlayer] = [:]
    private var backgroundMusicPlayer: AVAudioPlayer?
    
    // Settings
    private(set) var isSoundEnabled = true
    private(set) var backgroundMusicVolume: Float = 0.5
    private(set) var soundEffectsVolume: Float = 1.0
    
    // MARK: - Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sound Control
    func playSound(_ type: SoundType) {
        guard isSoundEnabled else { return }
        
        if let player = audioPlayers[type] {
            player.currentTime = 0
            player.play()
        } else {
            loadAndPlaySound(type)
        }
    }
    
    private func loadAndPlaySound(_ type: SoundType) {
        guard let soundURL = Bundle.main.url(
            forResource: type.filename,
            withExtension: type.fileExtension
        ) else {
            print("Failed to find sound file: \(type.filename).\(type.fileExtension)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: soundURL)
            player.volume = type == .background ? backgroundMusicVolume : soundEffectsVolume
            player.prepareToPlay()
            
            if type == .background {
                player.numberOfLoops = -1 // Infinite loop
                backgroundMusicPlayer = player
            } else {
                audioPlayers[type] = player
            }
            
            player.play()
        } catch {
            print("Failed to load sound: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Background Music
    func startBackgroundMusic() {
        guard isSoundEnabled else { return }
        
        if let player = backgroundMusicPlayer {
            if !player.isPlaying {
                player.play()
            }
        } else {
            loadAndPlaySound(.background)
        }
    }
    
    func stopBackgroundMusic() {
        backgroundMusicPlayer?.stop()
    }
    
    func pauseBackgroundMusic() {
        backgroundMusicPlayer?.pause()
    }
    
    func resumeBackgroundMusic() {
        guard isSoundEnabled else { return }
        backgroundMusicPlayer?.play()
    }
    
    // MARK: - Settings
    func toggleSound() {
        isSoundEnabled.toggle()
        if !isSoundEnabled {
            stopAllAudio()
        } else {
            startBackgroundMusic()
        }
    }
    
    func setBackgroundMusicVolume(_ volume: Float) {
        backgroundMusicVolume = max(0, min(1, volume))
        backgroundMusicPlayer?.volume = backgroundMusicVolume
    }
    
    func setSoundEffectsVolume(_ volume: Float) {
        soundEffectsVolume = max(0, min(1, volume))
        audioPlayers.values.forEach { $0.volume = soundEffectsVolume }
    }
    
    // MARK: - Cleanup
    private func stopAllAudio() {
        backgroundMusicPlayer?.stop()
        audioPlayers.values.forEach { $0.stop() }
    }
    
    func preloadSounds() {
        // Preload all sound effects
        [SoundType.draw, .gunshot, .victory, .defeat, .fail, .background].forEach { type in
            guard let soundURL = Bundle.main.url(
                forResource: type.filename,
                withExtension: type.fileExtension
            ) else { return }
            
            do {
                let player = try AVAudioPlayer(contentsOf: soundURL)
                player.prepareToPlay()
                if type == .background {
                    backgroundMusicPlayer = player
                } else {
                    audioPlayers[type] = player
                }
            } catch {
                print("Failed to preload sound \(type.filename): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Error Recovery
    func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Audio session interrupted, pause playback
            pauseBackgroundMusic()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                // Interruption ended, resume playback
                resumeBackgroundMusic()
            }
        @unknown default:
            break
        }
    }
}

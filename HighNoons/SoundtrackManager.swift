import AVFoundation
import GameKit

final class SoundtrackManager {
    // MARK: - Properties
    static let shared = SoundtrackManager()
    
    private let audioManager = AudioManager.shared
    private var currentTrack: Track?
    private var ambientPlayers: [String: AVAudioPlayer] = [:]
    private var musicPlayer: AVAudioPlayer?
    private var crossFadePlayer: AVAudioPlayer?
    
    private var isEnabled = true
    private var musicVolume: Float = 0.7
    private var ambientVolume: Float = 0.3
    
    // MARK: - Types
    enum Track: String {
        case mainMenu = "main_theme"
        case duel = "duel_theme"
        case victory = "victory_theme"
        case defeat = "defeat_theme"
        case store = "store_theme"
        case tutorial = "tutorial_theme"
        
        var filename: String { return rawValue }
        var looping: Bool {
            switch self {
            case .victory, .defeat: return false
            default: return true
            }
        }
        
        var volume: Float {
            switch self {
            case .mainMenu: return 0.7
            case .duel: return 0.8
            case .victory: return 1.0
            case .defeat: return 0.6
            case .store: return 0.5
            case .tutorial: return 0.6
            }
        }
        
        var ambientSounds: [AmbientSound] {
            switch self {
            case .mainMenu:
                return [.wind, .crickets]
            case .duel:
                return [.wind, .heartbeat]
            case .victory:
                return [.crowd]
            case .defeat:
                return [.wind]
            case .store:
                return [.chatter]
            case .tutorial:
                return [.wind]
            }
        }
    }
    
    enum AmbientSound: String {
        case wind = "ambient_wind"
        case crickets = "ambient_crickets"
        case chatter = "ambient_chatter"
        case heartbeat = "ambient_heartbeat"
        case crowd = "ambient_crowd"
        case rain = "ambient_rain"
        case thunder = "ambient_thunder"
        
        var filename: String { return rawValue }
        var baseVolume: Float {
            switch self {
            case .wind: return 0.3
            case .crickets: return 0.2
            case .chatter: return 0.15
            case .heartbeat: return 0.4
            case .crowd: return 0.25
            case .rain: return 0.3
            case .thunder: return 0.5
            }
        }
    }
    
    // MARK: - Initialization
    private override init() {
        setupAudioSession()
        loadSettings()
    }
    
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
    
    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "musicEnabled")
        musicVolume = UserDefaults.standard.float(forKey: "musicVolume")
        ambientVolume = UserDefaults.standard.float(forKey: "ambientVolume")
    }
    
    // MARK: - Track Management
    func playTrack(_ track: Track, fadeIn: TimeInterval = 2.0) {
        guard isEnabled else { return }
        
        // Don't restart if same track is playing
        if currentTrack == track { return }
        
        // Prepare new track
        guard let url = Bundle.main.url(forResource: track.filename, withExtension: "mp3"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return
        }
        
        player.numberOfLoops = track.looping ? -1 : 0
        player.volume = 0
        player.prepareToPlay()
        
        // Fade out current track
        if let currentPlayer = musicPlayer {
            crossFadePlayer = currentPlayer
            fadeOut(crossFadePlayer, duration: fadeIn)
        }
        
        // Start new track
        musicPlayer = player
        currentTrack = track
        player.play()
        fadeIn(player, duration: fadeIn, targetVolume: track.volume * musicVolume)
        
        // Setup ambient sounds
        updateAmbientSounds(for: track)
    }
    
    func stopTrack(fadeOut: TimeInterval = 2.0) {
        guard let player = musicPlayer else { return }
        self.fadeOut(player, duration: fadeOut)
        currentTrack = nil
        stopAllAmbientSounds(fadeOut: fadeOut)
    }
    
    // MARK: - Ambient Sounds
    private func updateAmbientSounds(for track: Track) {
        // Stop current ambient sounds that aren't needed
        let newSounds = Set(track.ambientSounds)
        let currentSounds = Set(ambientPlayers.keys.compactMap { AmbientSound(rawValue: $0) })
        
        // Remove unnecessary sounds
        for sound in currentSounds where !newSounds.contains(sound) {
            stopAmbientSound(sound)
        }
        
        // Add new sounds
        for sound in newSounds where !currentSounds.contains(sound) {
            playAmbientSound(sound)
        }
    }
    
    private func playAmbientSound(_ sound: AmbientSound) {
        guard let url = Bundle.main.url(forResource: sound.filename, withExtension: "mp3"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return
        }
        
        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        player.play()
        
        ambientPlayers[sound.rawValue] = player
        fadeIn(player, duration: 2.0, targetVolume: sound.baseVolume * ambientVolume)
    }
    
    private func stopAmbientSound(_ sound: AmbientSound) {
        guard let player = ambientPlayers[sound.rawValue] else { return }
        fadeOut(player, duration: 2.0)
        ambientPlayers.removeValue(forKey: sound.rawValue)
    }
    
    private func stopAllAmbientSounds(fadeOut duration: TimeInterval) {
        for player in ambientPlayers.values {
            self.fadeOut(player, duration: duration)
        }
        ambientPlayers.removeAll()
    }
    
    // MARK: - Volume Control
    func setMusicVolume(_ volume: Float) {
        musicVolume = max(0, min(1, volume))
        UserDefaults.standard.set(musicVolume, forKey: "musicVolume")
        
        if let player = musicPlayer, let track = currentTrack {
            player.volume = track.volume * musicVolume
        }
    }
    
    func setAmbientVolume(_ volume: Float) {
        ambientVolume = max(0, min(1, volume))
        UserDefaults.standard.set(ambientVolume, forKey: "ambientVolume")
        
        for (soundName, player) in ambientPlayers {
            if let sound = AmbientSound(rawValue: soundName) {
                player.volume = sound.baseVolume * ambientVolume
            }
        }
    }
    
    // MARK: - Fading
    private func fadeIn(_ player: AVAudioPlayer, duration: TimeInterval, targetVolume: Float) {
        let steps = 20
        let stepDuration = duration / TimeInterval(steps)
        let volumeStep = targetVolume / Float(steps)
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                player.volume = volumeStep * Float(i)
            }
        }
    }
    
    private func fadeOut(_ player: AVAudioPlayer, duration: TimeInterval) {
        let steps = 20
        let stepDuration = duration / TimeInterval(steps)
        let startVolume = player.volume
        let volumeStep = startVolume / Float(steps)
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                player.volume = startVolume - (volumeStep * Float(i))
                
                if i == steps {
                    player.stop()
                }
            }
        }
    }
    
    // MARK: - Dynamic Effects
    func intensifyCurrentTrack() {
        guard let track = currentTrack, let player = musicPlayer else { return }
        
        // Increase volume and tempo
        let targetVolume = min(1.0, track.volume * musicVolume * 1.3)
        player.rate = 1.1
        
        fadeIn(player, duration: 1.0, targetVolume: targetVolume)
    }
    
    func normalizeCurrentTrack() {
        guard let track = currentTrack, let player = musicPlayer else { return }
        
        // Restore normal volume and tempo
        player.rate = 1.0
        fadeIn(player, duration: 1.0, targetVolume: track.volume * musicVolume)
    }
    
    // MARK: - State Management
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "musicEnabled")
        
        if !enabled {
            stopTrack(fadeOut: 1.0)
        }
    }
    
    func cleanup() {
        stopTrack(fadeOut: 0.5)
        musicPlayer = nil
        crossFadePlayer = nil
        ambientPlayers.removeAll()
    }
}

// MARK: - Weather Integration
extension SoundtrackManager {
    func updateForWeather(_ weather: WeatherManager.WeatherType) {
        switch weather {
        case .stormy:
            playAmbientSound(.rain)
            playAmbientSound(.thunder)
        case .windy:
            stopAmbientSound(.rain)
            stopAmbientSound(.thunder)
            playAmbientSound(.wind)
        default:
            stopAmbientSound(.rain)
            stopAmbientSound(.thunder)
            stopAmbientSound(.wind)
        }
    }
}

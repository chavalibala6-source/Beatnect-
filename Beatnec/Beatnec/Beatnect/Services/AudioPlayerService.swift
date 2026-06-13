import Foundation
import AVFoundation
import MediaPlayer
import Combine

class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()
    
    private var player: AVPlayer?
    private var playerItemContext = 0
    private var timeObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var tracks: [Track] = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(tracks) {
                UserDefaults.standard.set(encoded, forKey: "gmp_cached_tracks")
            }
        }
    }
    @Published var currentTrackIndex: Int?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isShuffleEnabled = false
    @Published var isRepeatEnabled = false
    
    var currentTrack: Track? {
        guard let index = currentTrackIndex, index < tracks.count else { return nil }
        return tracks[index]
    }
    
    private override init() {
        // Load cached tracks from UserDefaults if available
        let cached: [Track]
        if let data = UserDefaults.standard.data(forKey: "gmp_cached_tracks"),
           let decoded = try? JSONDecoder().decode([Track].self, from: data) {
            cached = decoded
        } else {
            cached = []
        }
        self.tracks = cached
        
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
        setupNotifications()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up AVAudioSession: \(error)")
        }
    }
    
    func setPlaylist(tracks: [Track], startAtIndex index: Int) {
        self.tracks = tracks
        playTrack(at: index)
    }
    
    func playTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        
        // Remove current time observer
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        currentTrackIndex = index
        guard let track = currentTrack else { return }
        
        guard let url = URL(string: track.url) else { return }
        let playerItem = AVPlayerItem(url: url)
        
        // Add KVO for status and duration
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: &playerItemContext)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.duration), options: [.old, .new], context: &playerItemContext)
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        // Set up time observer
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            self.updateNowPlayingPlaybackInfo()
        }
        
        play()
        updateNowPlayingMetadata()
    }
    
    func play() {
        player?.play()
        isPlaying = true
        updateNowPlayingPlaybackInfo()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingPlaybackInfo()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func nextTrack() {
        guard !tracks.isEmpty else { return }
        if isShuffleEnabled {
            let randomIndex = Int.random(in: 0..<tracks.count)
            playTrack(at: randomIndex)
        } else {
            guard let currentIndex = currentTrackIndex else { return }
            let nextIndex = (currentIndex + 1) % tracks.count
            playTrack(at: nextIndex)
        }
    }
    
    func previousTrack() {
        guard !tracks.isEmpty else { return }
        if isShuffleEnabled {
            let randomIndex = Int.random(in: 0..<tracks.count)
            playTrack(at: randomIndex)
        } else {
            guard let currentIndex = currentTrackIndex else { return }
            let prevIndex = (currentIndex - 1 + tracks.count) % tracks.count
            playTrack(at: prevIndex)
        }
    }
    
    func toggleShuffle() {
        isShuffleEnabled.toggle()
    }
    
    func toggleRepeat() {
        isRepeatEnabled.toggle()
    }
    
    func seek(to seconds: Double) {
        let targetTime = CMTime(seconds: seconds, preferredTimescale: 1000)
        player?.seek(to: targetTime) { [weak self] _ in
            self?.currentTime = seconds
            self?.updateNowPlayingPlaybackInfo()
        }
    }
    
    // MARK: - Now Playing Info Center
    
    private func updateNowPlayingMetadata() {
        guard let track = currentTrack else { return }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.displayName
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.displayArtist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.displayAlbum
        
        // Load artwork asynchronously
        if let url = track.fullArtworkUrl {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    DispatchQueue.main.async {
                        var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        currentInfo[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                    }
                }
            }.resume()
        } else {
            // Placeholder default artwork if none is available
            if let image = UIImage(systemName: "music.note") {
                let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 300, height: 300)) { _ in image }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingPlaybackInfo() {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - MPRemoteCommandCenter Controls
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: positionEvent.positionTime)
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.changeShuffleModeCommand.isEnabled = true
        commandCenter.changeShuffleModeCommand.addTarget { [weak self] event in
            guard let self = self,
                  let shuffleEvent = event as? MPChangeShuffleModeCommandEvent else {
                return .commandFailed
            }
            self.isShuffleEnabled = shuffleEvent.shuffleType != .off
            return .success
        }
        
        commandCenter.changeRepeatModeCommand.isEnabled = true
        commandCenter.changeRepeatModeCommand.addTarget { [weak self] event in
            guard let self = self,
                  let repeatEvent = event as? MPChangeRepeatModeCommandEvent else {
                return .commandFailed
            }
            self.isRepeatEnabled = repeatEvent.repeatType != .off
            return .success
        }
    }
    
    // MARK: - Notification Selectors
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemDidPlayToEndTime),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: nil)
    }
    
    @objc private func playerItemDidPlayToEndTime(notification: Notification) {
        if isRepeatEnabled {
            seek(to: 0)
            play()
        } else {
            nextTrack()
        }
    }
    
    // MARK: - KVO Observer
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if keyPath == #keyPath(AVPlayerItem.status) {
            if let statusNumber = change?[.newKey] as? NSNumber {
                let status = AVPlayerItem.Status(rawValue: statusNumber.intValue)
                if status == .failed {
                    print("AVPlayerItem failed to load: \(String(describing: player?.currentItem?.error))")
                    pause()
                }
            }
        } else if keyPath == #keyPath(AVPlayerItem.duration) {
            if let newDuration = player?.currentItem?.duration {
                let seconds = CMTimeGetSeconds(newDuration)
                if !seconds.isNaN {
                    self.duration = seconds
                    self.updateNowPlayingPlaybackInfo()
                }
            }
        }
    }
}

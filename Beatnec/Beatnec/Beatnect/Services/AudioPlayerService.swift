import Foundation
import AVFoundation
import MediaPlayer
import MediaToolbox
import Combine
import Accelerate

// MARK: - Spectrum Analyzer
final class SpectrumAnalyzer: ObservableObject {
    @Published var magnitudes: [Float] = Array(repeating: 0, count: 40)

    private let bandCount = 40
    private let bufferSize: AVAudioFrameCount = 2048
    private var isInstalled = false

    func install(on engine: AVAudioEngine) {
        guard !isInstalled else { return }
        let mixer = engine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        isInstalled = true
        mixer.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.process(buffer)
        }
    }

    func remove(from engine: AVAudioEngine) {
        guard isInstalled else { return }
        engine.mainMixerNode.removeTap(onBus: 0)
        isInstalled = false
        DispatchQueue.main.async {
            self.magnitudes = Array(repeating: 0, count: self.bandCount)
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount >= 64 else { return }

        let log2n = UInt(log2(Double(frameCount)))
        let fftSize = 1 << log2n
        let half = fftSize / 2

        var windowed = [Float](repeating: 0, count: fftSize)
        var window   = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(data, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var split = DSPSplitComplex(realp: &real, imagp: &imag)

        windowed.withUnsafeBytes {
            let ptr = $0.bindMemory(to: DSPComplex.self)
            vDSP_ctoz(ptr.baseAddress!, 2, &split, 1, vDSP_Length(half))
        }

        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return }
        defer { vDSP_destroy_fftsetup(setup) }
        vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))

        var mags   = [Float](repeating: 0, count: half)
        var scaled = [Float](repeating: 0, count: half)
        vDSP_zvabs(&split, 1, &mags, 1, vDSP_Length(half))
        var scale = 2.0 / Float(fftSize)
        vDSP_vsmul(&mags, 1, &scale, &scaled, 1, vDSP_Length(half))

        var bands = [Float](repeating: 0, count: bandCount)
        for i in 0..<bandCount {
            let lo = Int(pow(Double(half), Double(i)     / Double(bandCount)))
            let hi = Int(pow(Double(half), Double(i + 1) / Double(bandCount)))
            let slice = scaled[max(0, lo)..<min(hi + 1, half)]
            bands[i] = slice.max() ?? 0
        }

        let minDB: Float = -70
        let maxDB: Float = -10
        let norm = bands.map { v -> Float in
            let db = 20 * log10(max(v, 1e-9))
            return min(max((db - minDB) / (maxDB - minDB), 0), 1)
        }

        DispatchQueue.main.async { self.magnitudes = norm }
    }
}

// MARK: - Metering Target (CADisplayLink helper)
final class MeteringTarget: NSObject {
    let callback: () -> Void
    init(_ callback: @escaping () -> Void) { self.callback = callback }
    @objc func tick() { callback() }
}

// MARK: - Audio Player Service
class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()

    // Engine (kept alive for SpectrumAnalyzer tap if needed)
    let engine = AVAudioEngine()
    private let silentNode = AVAudioPlayerNode()

    // AVPlayer for instant streaming
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var itemEndObserver: NSObjectProtocol?

    // Metering via MTAudioProcessingTap
    private var meterLevels: [Float] = Array(repeating: 0, count: 40)
    private let meterQueue = DispatchQueue(label: "com.beatnect.meter", qos: .userInteractive)
    private var currentMix: AVAudioMix?

    // Prefetch
    private var prefetchTask: URLSessionDownloadTask?
    private var prefetchedTrackURL: URL?
    private var prefetchedFileURL: URL?

    // Guard against rapid track changes
    private var isTransitioning = false

    @Published var tracks: [Track] = [] {
        didSet {
            if let e = try? JSONEncoder().encode(tracks) {
                UserDefaults.standard.set(e, forKey: "gmp_cached_tracks")
            }
        }
    }
    @Published var libraryTracks: [Track] = [] {
        didSet {
            if let e = try? JSONEncoder().encode(libraryTracks) {
                UserDefaults.standard.set(e, forKey: "gmp_cached_library_tracks")
            }
        }
    }
    @Published var currentTrackIndex: Int?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isShuffleEnabled = false
    @Published var isRepeatEnabled = false
    @Published var isAutoPlayEnabled = true

    var currentTrack: Track? {
        guard let i = currentTrackIndex, i < tracks.count else { return nil }
        return tracks[i]
    }

    // MARK: - Init
    private override init() {
        if let d = UserDefaults.standard.data(forKey: "gmp_cached_tracks"),
           let v = try? JSONDecoder().decode([Track].self, from: d) {
            tracks = v
        } else { tracks = [] }

        if let d = UserDefaults.standard.data(forKey: "gmp_cached_library_tracks"),
           let v = try? JSONDecoder().decode([Track].self, from: d) {
            libraryTracks = v
        } else { libraryTracks = [] }

        super.init()
        setupAudioSession()
        setupEngine()
        setupRemoteCommandCenter()
    }

    // MARK: - Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("AudioSession error: \(error)") }
    }

    private func setupEngine() {
        engine.attach(silentNode)
        engine.connect(silentNode, to: engine.mainMixerNode, format: nil)
        engine.prepare()
        do { try engine.start() } catch { print("Engine error: \(error)") }
    }

    // MARK: - Playlist
    func setPlaylist(tracks: [Track], startAtIndex index: Int) {
        self.tracks = tracks
        playTrack(at: index)
    }

    func playTrack(at index: Int) {
        guard index >= 0, index < tracks.count else { return }
        guard !isTransitioning else { return }
        isTransitioning = true
        defer { isTransitioning = false }

        currentTrackIndex = index
        guard let track = currentTrack,
              let url = URL(string: track.url) else { return }

        stopCurrentPlayback()

        // Use prefetched file if available for this URL
        if let cached = prefetchedFileURL,
           let cachedURL = prefetchedTrackURL,
           cachedURL == url {
            prefetchedFileURL  = nil
            prefetchedTrackURL = nil
            startPlayer(url: cached)
        } else {
            startPlayer(url: url)
        }

        updateNowPlayingMetadata()
        prefetchNextTrack()
    }

    // MARK: - AVPlayer
    private func startPlayer(url: URL) {
        let item = AVPlayerItem(url: url)
        playerItem = item

        // Install metering tap
        if let mix = buildMeteringMix(for: item) {
            item.audioMix = mix
            currentMix = mix
        }

        if player == nil {
            player = AVPlayer(playerItem: item)
            player?.automaticallyWaitsToMinimizeStalling = false
        } else {
            player?.replaceCurrentItem(with: item)
        }

        // Periodic time observer
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, self.isPlaying else { return }
            self.currentTime = time.seconds
            if let d = self.playerItem?.duration,
               d.isNumeric, d.seconds > 0 {
                self.duration = d.seconds
            }
            self.updateNowPlayingPlaybackInfo()
        }

        // End observer
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.handleTrackFinished()
        }

        player?.play()
        isPlaying = true
        updateNowPlayingPlaybackInfo()
    }

    private func stopCurrentPlayback() {
        if let t = timeObserver {
            player?.removeTimeObserver(t)
            timeObserver = nil
        }
        if let obs = itemEndObserver {
            NotificationCenter.default.removeObserver(obs)
            itemEndObserver = nil
        }
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        playerItem = nil
        currentMix = nil
        isPlaying  = false
        currentTime = 0
        duration    = 0
        meterQueue.async { self.meterLevels = Array(repeating: 0, count: 40) }
    }

    private func handleTrackFinished() {
        if isRepeatEnabled {
            player?.seek(to: .zero)
            player?.play()
        } else {
            nextTrack(isAuto: true)
        }
    }

    // MARK: - MTAudioProcessingTap Metering
    private func buildMeteringMix(for item: AVPlayerItem) -> AVAudioMix? {
        // Wait for tracks to load
        let asset = item.asset
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            // Asset tracks not loaded yet — load them async
            asset.loadTracks(withMediaType: .audio) { [weak self, weak item] tracks, _ in
                guard let self,
                      let item,
                      let track = tracks?.first else { return }
                DispatchQueue.main.async {
                    if let mix = self.buildMeteringMixWith(track: track) {
                        item.audioMix = mix
                        self.currentMix = mix
                    }
                }
            }
            return nil
        }
        return buildMeteringMixWith(track: audioTrack)
    }

    private func buildMeteringMixWith(track: AVAssetTrack) -> AVAudioMix? {
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(
                Unmanaged.passRetained(self).toOpaque()
            ),
            init: { tap, clientInfo, tapStorageOut in
                tapStorageOut.pointee = clientInfo
            },
            finalize: { tap in
                let ptr = MTAudioProcessingTapGetStorage(tap);                Unmanaged<AudioPlayerService>.fromOpaque(ptr).release()
            },
            prepare: { _, _, _ in },
            unprepare: { _ in },
            process: { tap, numFrames, flags, bufferList, numFramesOut, flagsOut in
                guard MTAudioProcessingTapGetSourceAudio(
                    tap,
                    numFrames,
                    bufferList,
                    flagsOut,
                    nil,
                    numFramesOut
                ) == noErr else { return }

                let ptr = MTAudioProcessingTapGetStorage(tap)
                let service = Unmanaged<AudioPlayerService>
                    .fromOpaque(ptr)
                    .takeUnretainedValue()

                service.processMeterData(bufferList, frames: Int(numFrames))
            }
        )

        var tap: MTAudioProcessingTap?

        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tap
        )

        guard status == noErr, let tap else {
            return nil
        }

        let params = AVMutableAudioMixInputParameters(track: track)
        params.audioTapProcessor = tap

        let mix = AVMutableAudioMix()
        mix.inputParameters = [params]
        return mix
    }

    private func processMeterData(
        _ bufferList: UnsafeMutablePointer<AudioBufferList>,
        frames: Int
    ) {
        let abl = UnsafeMutableAudioBufferListPointer(bufferList)
        guard let buf = abl.first,
              let data = buf.mData,
              frames > 0 else { return }

        let samples = UnsafeBufferPointer(
            start: data.bindMemory(to: Float.self, capacity: frames),
            count: frames
        )
        let arr = Array(samples)
        let bandCount = 40
        let bandSize  = max(1, frames / bandCount)
        var bands = [Float](repeating: 0, count: bandCount)

        for i in 0..<bandCount {
            let start = i * bandSize
            let end   = min(start + bandSize, frames)
            guard start < end else { continue }
            var rms: Float = 0
            vDSP_rmsqv(Array(arr[start..<end]), 1, &rms, vDSP_Length(end - start))
            let db = 20 * log10(max(rms, 1e-9))
            let minDB: Float = -60; let maxDB: Float = 0
            bands[i] = min(max((db - minDB) / (maxDB - minDB), 0), 1)
        }

        meterQueue.async { self.meterLevels = bands }
    }

    func currentMeterLevels() -> [Float] {
        meterQueue.sync { meterLevels }
    }

    // MARK: - Prefetch
    private func prefetchNextTrack() {
        prefetchTask?.cancel()
        prefetchTask      = nil
        prefetchedTrackURL = nil
        prefetchedFileURL  = nil

        guard !isShuffleEnabled,
              let idx = currentTrackIndex,
              idx + 1 < tracks.count else { return }

        let next = tracks[idx + 1]
        guard let url = URL(string: next.url) else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("prefetch_next.mp3")

        prefetchedTrackURL = url
        let task = URLSession.shared.downloadTask(with: url) { [weak self] location, _, error in
            guard let self, error == nil, let location else { return }
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.moveItem(at: location, to: tempURL)
            DispatchQueue.main.async { self.prefetchedFileURL = tempURL }
        }
        prefetchTask = task
        task.resume()
    }

    // MARK: - Controls
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

    func togglePlayPause() { isPlaying ? pause() : play() }

    func nextTrack(isAuto: Bool = false) {
        guard !tracks.isEmpty else { return }
        
        let currentIndex = currentTrackIndex ?? 0
        let next = isShuffleEnabled
            ? Int.random(in: 0..<tracks.count)
            : currentIndex + 1
            
        if next < tracks.count {
            playTrack(at: next)
        } else {
            // Reached end of current tracks
            if isAutoPlayEnabled, let currentTrack = currentTrack {
                // Find next album from libraryTracks
                var uniqueAlbums: [(album: String, artist: String)] = []
                for t in libraryTracks {
                    if !uniqueAlbums.contains(where: { $0.album == t.displayAlbum && $0.artist == t.displayArtist }) {
                        uniqueAlbums.append((album: t.displayAlbum, artist: t.displayArtist))
                    }
                }
                
                if let currentAlbumIndex = uniqueAlbums.firstIndex(where: { $0.album == currentTrack.displayAlbum && $0.artist == currentTrack.displayArtist }) {
                    let nextAlbumIndex = (currentAlbumIndex + 1) % uniqueAlbums.count
                    let nextAlbumInfo = uniqueAlbums[nextAlbumIndex]
                    
                    let nextAlbumTracks = libraryTracks.filter { $0.displayAlbum == nextAlbumInfo.album && $0.displayArtist == nextAlbumInfo.artist }
                    if !nextAlbumTracks.isEmpty {
                        self.tracks.append(contentsOf: nextAlbumTracks)
                        playTrack(at: next)
                        return
                    }
                }
                
                // Fallback: random track
                if let randomTrack = libraryTracks.randomElement() {
                    let randomAlbumTracks = libraryTracks.filter { $0.displayAlbum == randomTrack.displayAlbum && $0.displayArtist == randomTrack.displayArtist }
                    let tracksToAdd = randomAlbumTracks.isEmpty ? [randomTrack] : randomAlbumTracks
                    self.tracks.append(contentsOf: tracksToAdd)
                    playTrack(at: next)
                }
            } else if isRepeatEnabled {
                playTrack(at: 0)
            } else {
                pause()
            }
        }
    }

    func previousTrack() {
        guard !tracks.isEmpty else { return }
        if currentTime > 3 {
            player?.seek(to: .zero)
            currentTime = 0
            return
        }
        
        let currentIndex = currentTrackIndex ?? 0
        let prev = isShuffleEnabled
            ? Int.random(in: 0..<tracks.count)
            : currentIndex - 1
            
        if prev >= 0 {
            playTrack(at: prev)
        } else {
            // Reached beginning, go to previous album if autoplay is on
            if isAutoPlayEnabled, let currentTrack = currentTrack {
                var uniqueAlbums: [(album: String, artist: String)] = []
                for t in libraryTracks {
                    if !uniqueAlbums.contains(where: { $0.album == t.displayAlbum && $0.artist == t.displayArtist }) {
                        uniqueAlbums.append((album: t.displayAlbum, artist: t.displayArtist))
                    }
                }
                
                if let currentAlbumIndex = uniqueAlbums.firstIndex(where: { $0.album == currentTrack.displayAlbum && $0.artist == currentTrack.displayArtist }) {
                    let prevAlbumIndex = (currentAlbumIndex - 1 + uniqueAlbums.count) % uniqueAlbums.count
                    let prevAlbumInfo = uniqueAlbums[prevAlbumIndex]
                    
                    let prevAlbumTracks = libraryTracks.filter { $0.displayAlbum == prevAlbumInfo.album && $0.displayArtist == prevAlbumInfo.artist }
                    if !prevAlbumTracks.isEmpty {
                        setPlaylist(tracks: prevAlbumTracks, startAtIndex: prevAlbumTracks.count - 1)
                        return
                    }
                }
            }
            // Fallback
            playTrack(at: tracks.count - 1)
        }
    }

    func toggleShuffle() { isShuffleEnabled.toggle() }
    func toggleRepeat()  { isRepeatEnabled.toggle() }
    func toggleAutoPlay() { isAutoPlayEnabled.toggle() }
    func seek(to seconds: Double) {
        let target = CMTime(seconds: seconds, preferredTimescale: 1000)
        player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
        updateNowPlayingPlaybackInfo()
    }

    // MARK: - Now Playing
    private func updateNowPlayingMetadata() {
        guard let track = currentTrack else { return }
        let info: [String: Any] = [
            MPMediaItemPropertyTitle:      track.displayName,
            MPMediaItemPropertyArtist:     track.displayArtist,
            MPMediaItemPropertyAlbumTitle: track.displayAlbum
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        if let url = track.fullArtworkUrl {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data, let img = UIImage(data: data) else { return }
                let art = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
                DispatchQueue.main.async {
                    var cur = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    cur[MPMediaItemPropertyArtwork] = art
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = cur
                }
            }.resume()
        }
    }

    private func updateNowPlayingPlaybackInfo() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration]        = duration
        info[MPNowPlayingInfoPropertyPlaybackRate]       = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo  = info
    }

    // MARK: - Remote Commands
    private func setupRemoteCommandCenter() {
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.addTarget            { [weak self] _ in self?.play();            return .success }
        cc.pauseCommand.addTarget           { [weak self] _ in self?.pause();           return .success }
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        cc.nextTrackCommand.addTarget       { [weak self] _ in self?.nextTrack();       return .success }
        cc.previousTrackCommand.addTarget   { [weak self] _ in self?.previousTrack();   return .success }
        cc.changePlaybackPositionCommand.addTarget { [weak self] e in
            if let ev = e as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: ev.positionTime)
            }
            return .success
        }
        [cc.playCommand, cc.pauseCommand, cc.togglePlayPauseCommand,
         cc.nextTrackCommand, cc.previousTrackCommand,
         cc.changePlaybackPositionCommand].forEach { $0.isEnabled = true }
    }
}

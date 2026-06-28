import SwiftUI
import UniformTypeIdentifiers

// MARK: - UTType for Track drag

extension UTType {
    static let beatnectTrack = UTType(exportedAs: "com.beatnect.track")
}

// MARK: - Track: Transferable (for drag & drop)

struct TrackTransferable: Transferable, Codable {
    let trackID: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .beatnectTrack)
    }
}

// MARK: - Sidebar Selection

enum LibrarySection: String, CaseIterable, Identifiable {
    case songs     = "Songs"
    case albums    = "Albums"
    case artists   = "Artists"
    case playlists = "Playlists"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .songs:     return "music.note"
        case .albums:    return "square.stack"
        case .artists:   return "person.2"
        case .playlists: return "music.note.list"
        }
    }
}

// MARK: - iPad Library View

struct iPadLibraryView: View {
    @ObservedObject var playerService: AudioPlayerService
    @StateObject private var store = PlaylistStore.shared
    @Binding var isShowingPlayerDetail: Bool
    @Binding var selectedSection: LibrarySection
    @Binding var selectedPlaylist: Playlist?
    @Binding var showNewPlaylistAlert: Bool
    
    @EnvironmentObject var themeManager: ThemeManager
    
    @Binding var searchText: String
    @State private var sortColumn: SongColumn = .title
    @State private var sortAscending: Bool = true
    @State private var newPlaylistName = ""
    @State private var dropTargetPlaylist: UUID? = nil
    @State private var scrollToTopTrigger = false
    
    // Columns definition
    enum SongColumn: String, CaseIterable {
        case title  = "Title"
        case artist = "Artist"
        case album  = "Album"
        case duration = "Time"
    }
    
    var filteredTracks: [Track] {
        let base: [Track]
        if selectedSection == .playlists, let pl = selectedPlaylist {
            base = store.tracks(for: pl, allTracks: playerService.libraryTracks)
        } else {
            base = playerService.libraryTracks
        }
        let searched = searchText.isEmpty ? base : base.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.displayArtist.localizedCaseInsensitiveContains(searchText) ||
            $0.displayAlbum.localizedCaseInsensitiveContains(searchText)
        }
        return searched.sorted {
            let lhs: String
            let rhs: String
            switch sortColumn {
            case .title:    lhs = $0.displayName;   rhs = $1.displayName
            case .artist:   lhs = $0.displayArtist; rhs = $1.displayArtist
            case .album:    lhs = $0.displayAlbum;  rhs = $1.displayAlbum
            case .duration: return sortAscending ? true : false
            }
            return sortAscending
            ? lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            : lhs.localizedCaseInsensitiveCompare(rhs) == .orderedDescending
        }
    }

    private var contentBottomInset: CGFloat { 72 }
    
    var body: some View {
        contentArea
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.backgroundColor.ignoresSafeArea())
        .alert("New Playlist", isPresented: $showNewPlaylistAlert) {
            TextField("Playlist Name", text: $newPlaylistName)
            Button("Create") {
                if !newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty {
                    store.createPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                }
            }
            Button("Cancel", role: .cancel) { newPlaylistName = "" }
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App title + theme toggle
            HStack(alignment: .center) {
                Text("Beatnect")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                // Theme toggle button
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        themeManager.isDarkMode.toggle()
                    }
                }) {
                    Image(systemName: themeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.isDarkMode ? Color(red: 0.85, green: 0.72, blue: 0.2) : .indigo)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.08))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Library sections
            Text("Library")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            
            ForEach([LibrarySection.songs, .albums, .artists]) { section in
                sidebarRow(section: section, isSelected: selectedSection == section && selectedPlaylist == nil)
                    .onTapGesture {
                        if selectedSection == section && selectedPlaylist == nil {
                            scrollToTopTrigger.toggle()
                        }
                        selectedSection = section
                        selectedPlaylist = nil
                    }
            }
            
            Divider().padding(.vertical, 12).opacity(0.3)
            
            // Playlists header
            HStack {
                Text("Playlists")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { showNewPlaylistAlert = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            // Playlists list (also drop targets)
            ScrollView {
                LazyVStack(spacing: 2) {
                    if store.playlists.isEmpty {
                        Text("No playlists yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }
                    ForEach(store.playlists) { playlist in
                        playlistRow(playlist: playlist)
                    }
                }
            }
            
            Spacer()
            
            // Theme label at bottom
            HStack(spacing: 6) {
                Image(systemName: themeManager.isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(themeManager.isDarkMode ? "Dark Mode" : "Light Mode")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 210)
        .background(themeManager.secondaryBackgroundColor.opacity(themeManager.isDarkMode ? 0.95 : 1.0))
    }

    private func sidebarRow(section: LibrarySection, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: section.icon)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? Color.accentColor : .secondary)
                .frame(width: 20)
            Text(section.rawValue)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                .padding(.horizontal, 8)
        )
    }
    
    private func playlistRow(playlist: Playlist) -> some View {
        let isSelected = selectedPlaylist?.id == playlist.id
        let isDropTarget = dropTargetPlaylist == playlist.id
        
        return HStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 13))
                .foregroundColor(isSelected ? Color.accentColor : .secondary)
                .frame(width: 20)
            Text(playlist.name)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
            Spacer()
            Text("\(playlist.trackIDs.count)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDropTarget
                      ? Color.blue.opacity(0.3)
                      : (isSelected ? Color.accentColor.opacity(0.12) : Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isDropTarget ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 1.5)
                )
                .padding(.horizontal, 8)
        )
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedSection = .playlists
            selectedPlaylist = playlist
        }
        // Drop target for dragged tracks
        .dropDestination(for: TrackTransferable.self) { items, _ in
            for item in items {
                if let track = playerService.libraryTracks.first(where: { $0.id == item.trackID }) {
                    store.addTrack(track, to: playlist)
                }
            }
            dropTargetPlaylist = nil
            return true
        } isTargeted: { targeted in
            dropTargetPlaylist = targeted ? playlist.id : nil
        }
    }
    
    // MARK: - Content Area
    
    @ViewBuilder
    private var contentArea: some View {
        Group {
            switch selectedSection {
            case .songs:
                songsTable
            case .albums:
                albumsGrid
            case .artists:
                artistsList
            case .playlists:
                if let pl = selectedPlaylist {
                    playlistDetail(pl)
                } else {
                    playlistsOverview
                }
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                contentToolbar
                Divider().opacity(0.3)
            }
            .background(.ultraThinMaterial)
        }
    }
    
    private var contentToolbar: some View {
        HStack(spacing: 16) {
            // Section title
            Text(selectedSection == .playlists
                 ? (selectedPlaylist?.name ?? "Playlists")
                 : selectedSection.rawValue)
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(.primary)
            
            if selectedSection == .songs || selectedSection == .playlists {
                Text("· \(filteredTracks.count) songs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Library Menu
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LibrarySection.allCases) { section in
                        Button(action: {
                            selectedSection = section
                            if section != .playlists {
                                selectedPlaylist = nil
                            }
                        }) {
                            Text(section.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(selectedSection == section && selectedPlaylist == nil ? themeManager.primaryTextColor : themeManager.primaryTextColor.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedSection == section && selectedPlaylist == nil ? Color.accentColor.opacity(themeManager.isDarkMode ? 0.3 : 0.15) : Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Divider().frame(height: 16).background(themeManager.primaryTextColor.opacity(0.2))
                    
                    Button(action: {
                        selectedSection = .playlists
                        selectedPlaylist = nil
                    }) {
                        Text("All Playlists")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedSection == .playlists && selectedPlaylist == nil ? themeManager.primaryTextColor : themeManager.primaryTextColor.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedSection == .playlists && selectedPlaylist == nil ? Color.accentColor.opacity(themeManager.isDarkMode ? 0.3 : 0.15) : Color.clear)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    ForEach(store.playlists) { playlist in
                        Button(action: {
                            selectedSection = .playlists
                            selectedPlaylist = playlist
                        }) {
                            Text(playlist.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(selectedPlaylist?.id == playlist.id ? themeManager.primaryTextColor : themeManager.primaryTextColor.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedPlaylist?.id == playlist.id ? Color.accentColor.opacity(themeManager.isDarkMode ? 0.3 : 0.15) : Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
    
    // MARK: - Songs Table
    
    private var songsTable: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                Text("#").font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary).frame(width: 40, alignment: .center)
                columnHeader(.title,  width: nil)
                columnHeader(.artist, width: 180)
                columnHeader(.album,  width: 200)
                columnHeader(.duration, width: 60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.03))
            
            Divider().opacity(0.2)
            
            ScrollViewReader { proxy in
                ScrollView {
                    Color.clear.frame(height: 1).id("top")
                    LazyVStack(spacing: 0) {
                    ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { idx, track in
                        SongTableRow(
                            track: track,
                            index: idx + 1,
                            isCurrent: playerService.currentTrack?.id == track.id,
                            isPlaying: playerService.isPlaying && playerService.currentTrack?.id == track.id
                        )
                        .draggable(TrackTransferable(trackID: track.id))
                        .onTapGesture(count: 2) {
                            if let globalIdx = playerService.libraryTracks.firstIndex(where: { $0.id == track.id }) {
                                playerService.setPlaylist(tracks: playerService.libraryTracks, startAtIndex: globalIdx)
                            }
                        }
                        
                        Divider().opacity(0.08).padding(.leading, 52)
                    }
                }
                .padding(.bottom, playerService.currentTrack != nil ? 90 : 16)
                .onChange(of: scrollToTopTrigger) { _ in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
        }
    }
}
    
    private func columnHeader(_ col: SongColumn, width: CGFloat?) -> some View {
        Button(action: {
            if sortColumn == col { sortAscending.toggle() }
            else { sortColumn = col; sortAscending = true }
        }) {
            HStack(spacing: 4) {
                Text(col.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(sortColumn == col ? .primary : .secondary)
                if sortColumn == col {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: width, alignment: .leading)
        .padding(.horizontal, 4)
    }
    
    // MARK: - Albums Grid
    
    private var albumsGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear.frame(height: 1).id("top")
                LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 160), spacing: 24)
                ],
                spacing: 24
            ){
                ForEach(albums) { album in
                    AppleMusicAlbumCard(
                        album: album,
                        isCurrent: album.tracks.contains {
                            $0.id == playerService.currentTrack?.id
                        },
                        isPlaying:
                            playerService.isPlaying &&
                        album.tracks.contains {
                            $0.id == playerService.currentTrack?.id
                        }
                    )
                    .onTapGesture {
                        if let firstTrack = album.tracks.first,
                           let globalIndex = playerService.libraryTracks.firstIndex(
                            where: { $0.id == firstTrack.id }
                           ) {
                            playerService.setPlaylist(
                                tracks: playerService.libraryTracks,
                                startAtIndex: globalIndex
                            )
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, contentBottomInset)
            .onChange(of: scrollToTopTrigger) { _ in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
    }
}
    
    // MARK: - Artists List
    
    private var artistsList: some View {
        let artistGroups = Dictionary(grouping: playerService.libraryTracks) { $0.displayArtist }
        let sorted = artistGroups.keys.sorted()
        
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sorted, id: \.self) { artist in
                    let tracks = artistGroups[artist] ?? []
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(artist)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("\(tracks.count) songs")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let idx = playerService.libraryTracks.firstIndex(where: { $0.displayArtist == artist }) {
                            playerService.setPlaylist(tracks: tracks, startAtIndex: 0)
                        }
                    }
                    Divider().opacity(0.1).padding(.leading, 72)
                }
            }
            .padding(.bottom, contentBottomInset)
        }
    }
    
    // MARK: - Playlists Overview
    
    private var playlistsOverview: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                // New playlist card
                Button(action: { showNewPlaylistAlert = true }) {
                    VStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("New Playlist")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [6]))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                ForEach(store.playlists) { pl in
                    PlaylistCard(playlist: pl, allTracks: playerService.libraryTracks)
                        .onTapGesture {
                            selectedPlaylist = pl
                        }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Playlist Detail
    
    private func playlistDetail(_ playlist: Playlist) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { selectedPlaylist = nil }) {
                    Label("Playlists", systemImage: "chevron.left")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                Spacer()
                Button(action: { store.deletePlaylist(at: IndexSet([store.playlists.firstIndex(where: { $0.id == playlist.id }) ?? 0])); selectedPlaylist = nil }) {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            Divider().opacity(0.2)
            
            if filteredTracks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Drag songs here to add them")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .dropDestination(for: TrackTransferable.self) { items, _ in
                    for item in items {
                        if let track = playerService.libraryTracks.first(where: { $0.id == item.trackID }) {
                            store.addTrack(track, to: playlist)
                        }
                    }
                    return true
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { idx, track in
                            HStack {
                                SongTableRow(
                                    track: track,
                                    index: idx + 1,
                                    isCurrent: playerService.currentTrack?.id == track.id,
                                    isPlaying: playerService.isPlaying && playerService.currentTrack?.id == track.id
                                )
                                .onTapGesture(count: 2) {
                                    let pl = store.tracks(for: playlist, allTracks: playerService.libraryTracks)
                                    playerService.setPlaylist(tracks: pl, startAtIndex: idx)
                                }
                                
                                Button(action: { store.removeTrack(id: track.id, from: playlist) }) {
                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red.opacity(0.7))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.trailing, 16)
                            }
                            Divider().opacity(0.08).padding(.leading, 52)
                        }
                    }
                    .padding(.bottom, contentBottomInset)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var albums: [Album] {
        var dict = [String: Album]()
        
        for track in playerService.libraryTracks {
            let albumName = track.displayAlbum
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            if var album = dict[albumName] {
                album.tracks.append(track)
                dict[albumName] = album
            } else {
                dict[albumName] = Album(
                    name: track.displayAlbum,
                    artist: track.displayArtist,
                    artworkUrl: track.fullArtworkUrl,
                    tracks: [track]
                )
            }
        }
        
        let allAlbums = dict.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        
        if searchText.isEmpty {
            return allAlbums
        }
        return allAlbums.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.artist.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Song Table Row
    
    struct SongTableRow: View {
        let track: Track
        let index: Int
        let isCurrent: Bool
        let isPlaying: Bool
        
        @EnvironmentObject var themeManager: ThemeManager
        @State private var isHovered = false
        
        var body: some View {
            HStack(spacing: 0) {
                // Index / playing indicator
                Group {
                    if isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.65, green: 0.8, blue: 0.22))
                    } else {
                        Text("\(index)")
                            .font(.system(size: 13))
                            .foregroundColor(isCurrent ? Color(red: 0.65, green: 0.8, blue: 0.22) : .secondary)
                    }
                }
                .frame(width: 40, alignment: .center)
                
                // Artwork
                Group {
                    if let url = track.fullArtworkUrl {
                        CachedAsyncImage(url: url) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 36, height: 36)
                            .cornerRadius(6)
                            .clipped()
                    } else {
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                            .frame(width: 36, height: 36)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(6)
                    }
                }
                .padding(.trailing, 10)
                
                // Title + artist (flex)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.displayName)
                        .font(.system(size: 14, weight: isCurrent ? .semibold : .regular))
                        .foregroundColor(isCurrent ? themeManager.accentColor : .primary)
                        .lineLimit(1)
                    Text(track.displayArtist)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Artist column
                Text(track.displayArtist)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 180, alignment: .leading)
                    .padding(.horizontal, 4)
                
                // Album column
                Text(track.displayAlbum)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 200, alignment: .leading)
                    .padding(.horizontal, 4)
                
                // Duration column (placeholder — duration not in model)
                Image(systemName: "ellipsis")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
            .onHover { isHovered = $0 }
            .contentShape(Rectangle())
        }
    }
    
    // MARK: - Playlist Card
    
    struct PlaylistCard: View {
        let playlist: Playlist
        let allTracks: [Track]
        
        var firstArtwork: URL? {
            playlist.trackIDs.compactMap { id in
                allTracks.first { $0.id == id }?.fullArtworkUrl
            }.first
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Group {
                    if let url = firstArtwork {
                        CachedAsyncImage(url: url) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { Color.gray.opacity(0.3) }
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .cornerRadius(10)
                            .clipped()
                    } else {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(10)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text("\(playlist.trackIDs.count) songs")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }
    
    // MARK: - Horizontal Album Shelf (Apple Music style)
    
    struct HorizontalAlbumShelf: View {
        let title: String
        let albums: [Album]
        let currentTrack: Track?
        let isPlaying: Bool
        @ObservedObject var playerService: AudioPlayerService
        
        @State private var scrollOffset: CGFloat = 0
        @State private var scrollProxy: ScrollViewProxy? = nil
        @State private var currentPage: Int = 0
        
        private let cardWidth: CGFloat = 220
        private let cardSpacing: CGFloat = 16
        private let visibleCards: Int = 5
        
        var maxPage: Int {
            max(0, albums.count - visibleCards)
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                
                // ── Section Header ────────────────────────────────────────────
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    
                    // Left / Right arrows
                    HStack(spacing: 4) {
                        arrowButton(direction: .left)
                        arrowButton(direction: .right)
                    }
                }
                .padding(.horizontal, 20)
                
                // ── Horizontal Scroll ─────────────────────────────────────────
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: cardSpacing) {
                            ForEach(Array(albums.enumerated()), id: \.element.id) { idx, album in
                                AppleMusicAlbumCard(
                                    album: album,
                                    isCurrent: album.tracks.contains { $0.id == currentTrack?.id },
                                    isPlaying: isPlaying && album.tracks.contains { $0.id == currentTrack?.id }
                                )
                                .frame(width: cardWidth)
                                .id(idx)
                                .onTapGesture {
                                    if let firstTrack = album.tracks.first,
                                       let globalIdx = playerService.libraryTracks.firstIndex(where: { $0.id == firstTrack.id }) {
                                        playerService.setPlaylist(tracks: playerService.libraryTracks, startAtIndex: globalIdx)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .onAppear { scrollProxy = proxy }
                    .onChange(of: currentPage) { page in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            proxy.scrollTo(page, anchor: .leading)
                        }
                    }
                }
            }
        }
        
        // MARK: Arrow button
        
        private enum Direction { case left, right }
        
        private func arrowButton(direction: Direction) -> some View {
            let disabled = direction == .left ? currentPage == 0 : currentPage >= maxPage
            return Button(action: {
                if direction == .left {
                    currentPage = max(0, currentPage - visibleCards)
                } else {
                    currentPage = min(maxPage, currentPage + visibleCards)
                }
            }) {
                Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(disabled ? Color.primary.opacity(0.2) : Color.primary.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(disabled ? Color.primary.opacity(0.05) : Color.primary.opacity(0.1))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(disabled ? 0.06 : 0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(disabled)
            .animation(.easeInOut(duration: 0.15), value: disabled)
        }
    }
    
    // MARK: - Apple Music Album Card
    
    struct AppleMusicAlbumCard: View {
        let album: Album
        let isCurrent: Bool
        let isPlaying: Bool
        
        @State private var isHovered = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                
                // Artwork square
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let url = album.artworkUrl {
                            CachedAsyncImage(url: url) { img in
                                img.resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.07))
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 36))
                                            .foregroundColor(.secondary)
                                    )
                            }
                        } else {
                            Rectangle()
                                .fill(Color.white.opacity(0.07))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 36))
                                        .foregroundColor(.secondary)
                                )
                        }
                    }
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isCurrent
                                ? Color(red: 0.65, green: 0.8, blue: 0.22).opacity(0.6)
                                : Color.primary.opacity(isHovered ? 0.18 : 0.08),
                                lineWidth: isCurrent ? 2 : 1
                            )
                    )
                    .shadow(color: .black.opacity(isHovered ? 0.5 : 0.25), radius: isHovered ? 16 : 8, x: 0, y: 6)
                    .scaleEffect(isHovered ? 1.03 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                    
                    // Now playing badge
                    if isPlaying {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 10))
                            Text("Playing")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.65, green: 0.8, blue: 0.22))
                        )
                        .padding(8)
                    }
                }
                
                // Title
                //.foregroundColor(
                //isCurrent
                //? Color(red: 0.65, green: 0.8, blue: 0.22)
               // : .primary
                Text(album.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Artist + track count
                //Text(album.artist)
                    //.font(.system(size: 12))
                  //  .foregroundColor(.secondary)
                   // .lineLimit(1)
                   // .truncationMode(.tail)
                  //  .frame(height: 16, alignment: .leading)
                
                Text("\(album.tracks.count) songs")
                    .font(.caption)
                    .foregroundColor(Color.secondary.opacity(0.6))
                    .frame(height: 14, alignment: .leading)
            }
            .onHover { isHovered = $0 }
            .contentShape(Rectangle())
        }
    }
}

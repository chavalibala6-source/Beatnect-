# Beatnect 🚗🎵
### Native CarPlay Audio Client for the Notepad/Music Flask Backend

Beatnect is a native iOS client built with SwiftUI and the CarPlay framework. It enables direct access, streaming, and full dashboard integration for the music library hosted on your Flask backend.

---

## 🌟 Key Features
- **CarPlay Integration**: Conforms to `CPTemplateApplicationSceneDelegate` and uses native CarPlay templates (`CPListTemplate`, `CPListItem`) to list, select, and control tracks directly on your car screen or CarPlay simulator.
- **Background Audio Session**: Fully configures background playback categories so audio continues to stream when the device is locked or the app is closed.
- **Lock Screen & Media Key Controls**: Integrates with `MPRemoteCommandCenter` and `MPNowPlayingInfoCenter` for steer wheel play/pause/skip and rich artwork metadata updates.
- **Dynamic Server Address Configuration**: Includes an in-app settings sheet on the iPhone to set the Flask backend's IP address (e.g. `http://192.168.1.100:5001`).

---

## 📁 Project Structure
- `BeatnectApp.swift`: SwiftUI main application entry point.
- `CarPlaySceneDelegate.swift`: Dedicated CarPlay life-cycle manager using the CarPlay framework.
- `Models/Track.swift`: Codable data model matching the Flask `/music_tracks` JSON structure.
- `Services/APIService.swift`: Handles networking and dynamic server configurations via UserDefaults.
- `Services/AudioPlayerService.swift`: Core AVPlayer wrapper managing media controls, audio sessions, and now-playing metadata.
- `Views/MainPlayerView.swift`: Beautiful SwiftUI view for the iPhone client with album rotation, sliders, and form configs.
- `Views/TrackRowView.swift`: Sub-components for listings and live Random-Capsule playback visualizers.
- `Info.plist`: Declares the required `CPTemplateApplicationSceneSessionRoleApplication` capabilities and background audio keys.

---

## 🛠 Setup & Compilation Guide (on macOS with Xcode)

Follow these steps to load and compile the project on your Mac:

### 1. Create a New Xcode Project
Since you are cloning this directory directly, you can easily set up the project files in Xcode:
1. Open **Xcode** on your Mac.
2. Select **Create a new Xcode project**.
3. Choose **iOS App** under application, name it **Beatnect**, set Interface to **SwiftUI**, and Language to **Swift**.
4. Save the project inside this cloned directory (or replace the auto-generated template source folder with the `Beatnect/` folder from this repo).
5. Drag the `Beatnect/` folder files into your Xcode Project Navigator.

### 2. Configure Capabilities
To allow background audio playback:
1. Select the **Beatnect** project root in the Project Navigator.
2. Select the **Beatnect** target, then click **Signing & Capabilities**.
3. Click **+ Capability** and add **Background Modes**.
4. Check **Audio, AirPlay, and Picture in Picture**.

### 3. Testing with the CarPlay Simulator
You do not need a physical CarPlay dashboard to test!
1. Select an iPhone Simulator in Xcode (e.g. iPhone 15) and click **Run** (Cmd + R).
2. Once the simulator starts, click on the **Simulator Menu Bar** at the top.
3. Go to **I/O** -> **External Displays** -> **CarPlay** (or **Hardware** -> **CarPlay** depending on simulator version).
4. A separate window representing the CarPlay dashboard will pop up, showing the **Beatnect** app on the main CarPlay grid!
5. Open Beatnect on the CarPlay screen, make sure your Flask server address is configured on the iPhone app, and click play.

### 4. Entitlements for App Store Production
*Note: If you plan to distribute your app on the App Store with CarPlay capabilities:*
- Go to [developer.apple.com/carplay](https://developer.apple.com/carplay/) and request the **CarPlay Audio App Entitlement**.
- Once approved, add the CarPlay entitlement key to your project's `.entitlements` file in Xcode.

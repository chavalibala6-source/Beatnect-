import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    init() {
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? false
    }
    
    // MARK: - Color Properties
    
    var backgroundColor: Color {
        isDarkMode ? Color.black : Color.white
    }

    
    var secondaryBackgroundColor: Color {
        isDarkMode ? Color(red: 0.08, green: 0.08, blue: 0.09) : Color(red: 0.96, green: 0.96, blue: 0.96)
    }
    
    var tertiaryBackgroundColor: Color {
        isDarkMode ? Color(red: 0.12, green: 0.12, blue: 0.13) : Color(red: 0.93, green: 0.93, blue: 0.93)
    }
    
    var primaryTextColor: Color {
        isDarkMode ? Color.white : Color.black
    }
    
    var secondaryTextColor: Color {
        isDarkMode ? Color.secondary : Color(UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0))
    }
    
    // Card backgrounds for album/track cards
    var cardBackgroundColor: Color {
        isDarkMode ? Color(red: 0.08, green: 0.08, blue: 0.09) : Color.white
    }
    
    // Subtle overlay/hover color
    var overlayColor: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }
    
    // Material background for glass-morphism
    var materialOpacity: Double {
        isDarkMode ? 0.1 : 0.08
    }
    
    // Border colors
    var borderColor: Color {
        isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }
    
    var accentBorderColor: Color {
        isDarkMode ? Color(red: 0.65, green: 0.8, blue: 0.22).opacity(0.3) : Color(red: 0.65, green: 0.8, blue: 0.22).opacity(0.2)
    }
    
    // Shadow colors
    var shadowColor: Color {
        isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.1)
    }
    
    var accentColor: Color {
        Color(red: 0.65, green: 0.8, blue: 0.22)
    }
    
    var artistColor: Color {
        Color(red: 0.72, green: 0.62, blue: 0.16)
    }
}

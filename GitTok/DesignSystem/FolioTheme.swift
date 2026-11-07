import SwiftUI
import GitTokCore

enum Folio {
    static let paper = Color(red: 246/255, green: 242/255, blue: 233/255)
    static let surface = Color(red: 250/255, green: 248/255, blue: 241/255)
    static let ink = Color(red: 39/255, green: 43/255, blue: 40/255)
    static let secondary = Color(red: 91/255, green: 93/255, blue: 84/255)
    static let rule = Color(red: 221/255, green: 223/255, blue: 210/255)
    static let accent = Color(red: 187/255, green: 86/255, blue: 47/255)
    static let accentText = Color(red: 166/255, green: 74/255, blue: 40/255)
    static let accentLight = Color(red: 244/255, green: 227/255, blue: 214/255)
    static let olive = Color(red: 49/255, green: 58/255, blue: 48/255)
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font { .custom("Georgia", size: size, relativeTo: style) }
    static func tint(for kind: String) -> Color {
        switch kind {
        case "frontend": Color(red: 234/255, green: 229/255, blue: 252/255)
        case "backend": Color(red: 214/255, green: 238/255, blue: 232/255)
        case "cli": Color(red: 240/255, green: 226/255, blue: 199/255)
        case "library": Color(red: 242/255, green: 222/255, blue: 212/255)
        default: accentLight
        }
    }
}

import AppKit
import SwiftUI
import WorkplaceCore

extension Workplace {
    var label: String {
        switch self {
        case .office: "🏢 Office"
        case .home: "🏠 Home"
        }
    }

    var symbol: String {
        switch self {
        case .office: "building.2"
        case .home: "house"
        }
    }
}

extension Pace {
    /// Nil when on track: the icon stays monochrome like the rest of the menu bar.
    var tint: NSColor? {
        switch self {
        case .onTrack: nil
        case .tight: .systemOrange
        case .behind: .systemRed
        case .done: .systemGreen
        }
    }

    var color: Color? { tint.map(Color.init(nsColor:)) }
}

extension NSImage {
    /// An SF Symbol for the menu bar; tinted symbols opt out of template rendering to keep their color.
    static func menuBarSymbol(_ name: String, tint: NSColor?) -> NSImage {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
        guard let tint, let tinted = image.withSymbolConfiguration(.init(paletteColors: [tint])) else { return image }
        tinted.isTemplate = false
        return tinted
    }
}

extension URL {
    /// The path with the home folder shortened to `~`.
    var displayPath: String { (path as NSString).abbreviatingWithTildeInPath }
}

/// The UI is in English regardless of the system language.
let english = Locale(identifier: "en_US")

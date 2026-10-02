//
//  Theme.swift
//  Notes
//
//  Color themes. Dark is the free default; the others come with Pro.
//

import SwiftUI

struct Palette {
    let background: Color
    let text: Color
    let secondaryText: Color
    let caret: Color
    let buttonForeground: Color
    let buttonBackground: Color
    let buttonHover: Color
    let colorScheme: ColorScheme
}

enum AppTheme: String, CaseIterable, Identifiable {
    case dark
    case darkSepia
    case midnight
    case light

    static let storageKey = "theme"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .dark: "Dark"
        case .darkSepia: "Dark Sepia"
        case .midnight: "Midnight"
        case .light: "Light"
        }
    }

    var requiresPro: Bool { self != .dark }

    var palette: Palette {
        switch self {
        case .dark:
            Palette(background: Color(red: 0.06, green: 0.07, blue: 0.06),
                    text: Color(red: 0.72, green: 0.72, blue: 0.73),
                    secondaryText: Color(red: 0.47, green: 0.47, blue: 0.52),
                    caret: .orange,
                    buttonForeground: .white,
                    buttonBackground: Color(red: 0.08, green: 0.08, blue: 0.08),
                    buttonHover: Color(red: 0.1, green: 0.1, blue: 0.12),
                    colorScheme: .dark)
        case .darkSepia:
            Palette(background: Color(red: 0.106, green: 0.086, blue: 0.067),
                    text: Color(red: 0.84, green: 0.78, blue: 0.65),
                    secondaryText: Color(red: 0.54, green: 0.48, blue: 0.38),
                    caret: Color(red: 0.91, green: 0.53, blue: 0.23),
                    buttonForeground: Color(red: 0.92, green: 0.86, blue: 0.75),
                    buttonBackground: Color(red: 0.14, green: 0.11, blue: 0.086),
                    buttonHover: Color(red: 0.17, green: 0.14, blue: 0.105),
                    colorScheme: .dark)
        case .midnight:
            Palette(background: Color(red: 0.047, green: 0.067, blue: 0.11),
                    text: Color(red: 0.765, green: 0.8, blue: 0.867),
                    secondaryText: Color(red: 0.4, green: 0.447, blue: 0.55),
                    caret: .orange,
                    buttonForeground: .white,
                    buttonBackground: Color(red: 0.07, green: 0.1, blue: 0.16),
                    buttonHover: Color(red: 0.094, green: 0.133, blue: 0.227),
                    colorScheme: .dark)
        case .light:
            Palette(background: Color(red: 0.965, green: 0.957, blue: 0.937),
                    text: Color(red: 0.165, green: 0.165, blue: 0.165),
                    secondaryText: Color(red: 0.557, green: 0.55, blue: 0.525),
                    caret: Color(red: 0.886, green: 0.44, blue: 0.1),
                    buttonForeground: Color(red: 0.165, green: 0.165, blue: 0.165),
                    buttonBackground: Color(red: 0.925, green: 0.914, blue: 0.886),
                    buttonHover: Color(red: 0.894, green: 0.878, blue: 0.847),
                    colorScheme: .light)
        }
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = AppTheme.dark.palette
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

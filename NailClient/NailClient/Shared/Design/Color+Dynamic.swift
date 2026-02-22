//
//  Color+Dynamic.swift
//  NailClient
//

import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    static func dynamic(light: Color, dark: Color) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            }
        )
    }

    static func dynamic(lightHex: UInt32, darkHex: UInt32, alpha: Double = 1.0) -> Color {
        .dynamic(
            light: Color(hex: lightHex, alpha: alpha),
            dark: Color(hex: darkHex, alpha: alpha)
        )
    }
}

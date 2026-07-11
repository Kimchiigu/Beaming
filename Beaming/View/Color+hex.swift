//
//  Color+hex.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

extension Color {
    /// Convenience initializer for hex strings like "FAF7B8" or "#FAF7B8".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255

        self.init(red: r, green: g, blue: b)
    }
}

//
//  Theme.swift
//  Beaming
//
//  Hi-fi design tokens, gradients, and reusable styles.
//

import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

/// Brand palette extracted from the Figma hi-fi.
enum BeamingPalette {
    static let green = Color(hex: 0x2C755D)   // primary brand
    static let blue = Color(hex: 0x0093EC)    // create accent
    static let yellow = Color(hex: 0xFFCC00)  // gradient end
    static let pink = Color(hex: 0xFF7889)    // secondary

    // Card icon chips
    static let micChip = Color(hex: 0xFFD9DD)
    static let netChip = Color(hex: 0xC3E7FF)
    static let greenTint = Color(hex: 0x94F2CF)

    /// The light-green gradient used on the "Beaming!" wordmark (#6BBF9B → #A3D5A0).
    static var wordmark: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x6BBF9B), Color(hex: 0xA3D5A0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Secondary tint — soft light-green fill (#94F2CF @ 20%).
    static var secondary: Color { greenTint.opacity(0.2) }

    /// Decorative background blob gradient (light-green → blue), kept soft.
    static var blob: LinearGradient {
        LinearGradient(
            colors: [greenTint.opacity(0.7), blue.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Calibration waveform bar gradient (green → blue).
    static var waveform: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xD1EFCB), netChip],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Soft blob shape for background decoration

struct BlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: rect.width * 0.42, height: rect.height * 0.42)
        )
        return path
    }
}

// MARK: - Reusable card style

extension View {
    /// White rounded card with the hi-fi soft drop shadow.
    func beamingCard(cornerRadius: CGFloat = 20, shadow: Bool = true) -> some View {
        self
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: shadow ? .black.opacity(0.1) : .clear, radius: 10, x: 0, y: 1)
    }
}

// MARK: - Primary pill button (green Liquid-Glass approximation)

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = BeamingPalette.green

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(tint)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: configuration.isPressed ? 4 : 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Liquid Glass icon button (iOS 26+)

struct GlassIconButton: View {
    let systemName: String
    var tint: Color = .primary
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .glassEffect(in: Circle())
        }
    }
}

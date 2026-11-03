import SwiftUI
import UIKit

// MARK: - Palette

/// The app is built around one idea: the TV's Ambilight is the only light in
/// the room. Everything is near-black, and colour arrives as glow.
enum Palette {
    static let ink          = Color(hex: 0x07080A)
    static let surface      = Color(hex: 0x111318)
    static let raised       = Color(hex: 0x181B22)
    static let hairline     = Color(hex: 0x252A34)

    static let text         = Color(hex: 0xF3F5F9)
    static let textMuted    = Color(hex: 0x7E8797)
    static let textFaint    = Color(hex: 0x545B68)

    static let ember        = Color(hex: 0xFF5A3C)
    static let emberDim     = Color(hex: 0x8A2E1E)
    static let mint         = Color(hex: 0x3DD9B0)
    static let iris         = Color(hex: 0x8E7DFF)
    static let sun          = Color(hex: 0xFFC24B)
    static let sky          = Color(hex: 0x3FA9FF)

    static let red          = Color(hex: 0xF2493F)
    static let green        = Color(hex: 0x37C978)
    static let yellow       = Color(hex: 0xF2C33D)
    static let blue         = Color(hex: 0x3B7BF0)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Type

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default).monospaced()
    }
}

// MARK: - Surfaces

struct CardBackground: ViewModifier {
    var radius: CGFloat = 26
    var glow: Color? = nil

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    }
                    .shadow(
                        color: (glow ?? .black).opacity(glow == nil ? 0.35 : 0.22),
                        radius: glow == nil ? 18 : 28,
                        y: glow == nil ? 10 : 0
                    )
            }
    }
}

extension View {
    func card(radius: CGFloat = 26, glow: Color? = nil) -> some View {
        modifier(CardBackground(radius: radius, glow: glow))
    }
}

// MARK: - Haptics

enum Haptics {
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let selection = UISelectionFeedbackGenerator()

    static func key() {
        soft.prepare()
        soft.impactOccurred(intensity: 0.55)
    }

    static func confirm() {
        rigid.prepare()
        rigid.impactOccurred(intensity: 0.9)
    }

    static func tick() {
        selection.selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func failure() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Key styles

/// A remote key: flat, dark, tight radius, with an ember wash when held down.
struct KeyStyle: ButtonStyle {
    var tint: Color = Palette.text
    var fill: Color = Palette.raised
    var height: CGFloat = 52
    var radius: CGFloat = 16
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.label(13, weight: .bold))
            .foregroundStyle(isActive ? Palette.ink : tint)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(isActive ? tint : fill)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                isActive ? .clear : Palette.hairline,
                                lineWidth: 1
                            )
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.key() }
            }
    }
}

/// Round key for the D-pad and media transport.
struct RoundKeyStyle: ButtonStyle {
    var tint: Color = Palette.text
    var fill: Color = Palette.raised
    var diameter: CGFloat = 62
    var glow: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(18, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: diameter, height: diameter)
            .background {
                Circle()
                    .fill(fill)
                    .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: 1) }
                    .shadow(
                        color: (glow ?? .clear).opacity(configuration.isPressed ? 0.55 : 0.28),
                        radius: configuration.isPressed ? 18 : 10
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.65), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.key() }
            }
    }
}

// MARK: - Small pieces

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.label(10, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(Palette.textFaint)
    }
}

struct StatusDot: View {
    var colour: Color
    var pulsing: Bool = false

    @State private var on = false

    var body: some View {
        Circle()
            .fill(colour)
            .frame(width: 7, height: 7)
            .shadow(color: colour.opacity(0.9), radius: 6)
            .scaleEffect(pulsing && on ? 1.35 : 1)
            .animation(
                pulsing ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : .default,
                value: on
            )
            .onAppear { on = true }
    }
}

struct ErrorBanner: View {
    let message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Palette.ember)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.textMuted)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.ember.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Palette.ember.opacity(0.35), lineWidth: 1)
                }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

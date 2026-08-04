import SwiftUI

nonisolated extension ShapeStyle where Self == Color {
    /// Positive state: road/exit open, usable alternative, verified information.
    static var a56Open: Color { Color("AccentColor") }

    /// Asset-backed compatibility aliases keep every closure in one visual state.
    static var a56Ramp: Color { Color("A56Issue") }
    static var a56Block: Color { Color("A56Issue") }
}

/// Shared card treatment: surface fill plus an optional faint accent wash.
/// The wash is kept subtle so cards stay readable in Dark Mode.
private struct A56SurfaceModifier: ViewModifier {
    var accent: Color?
    var radius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.a56Surface)
                    .overlay {
                        if let accent {
                            LinearGradient(
                                colors: [
                                    accent.opacity(reduceTransparency ? 0.12 : 0.16),
                                    accent.opacity(0.025)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                accent?.opacity(0.13) ?? Color.a56Shadow.opacity(0.09),
                                lineWidth: 0.75
                            )
                    }
                    .shadow(
                        color: (accent ?? Color.a56Shadow).opacity(0.075),
                        radius: 12,
                        y: 5
                    )
            }
    }
}

extension View {
    func a56Surface(accent: Color? = nil, radius: CGFloat = 20) -> some View {
        modifier(A56SurfaceModifier(accent: accent, radius: radius))
    }
}

/// Press feedback for custom borderless controls.
struct A56PressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

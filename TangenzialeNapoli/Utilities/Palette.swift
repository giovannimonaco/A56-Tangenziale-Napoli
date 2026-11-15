import SwiftUI

nonisolated extension ShapeStyle where Self == Color {
    /// Positive state: road/exit open, usable alternative, verified information.
    static var a56Open: Color { Color("AccentColor") }

    /// Asset-backed compatibility aliases keep every closure in one visual state.
    static var a56Ramp: Color { Color("A56Issue") }
    static var a56Block: Color { Color("A56Issue") }
}

/// Quiet, shared surface. Status is conveyed by the content's words and symbols;
/// cards use a neutral fill and boundary without decorative accent edges.
private struct A56SurfaceModifier: ViewModifier {
    var radius: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.a56Surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                Color.primary.opacity(contrast == .increased ? 0.28 : 0.07),
                                lineWidth: contrast == .increased ? 1 : 0.5
                            )
                    }
            }
    }
}

extension View {
    func a56Surface(accent: Color? = nil, radius: CGFloat = 18) -> some View {
        // Retain the argument for existing detail/status call sites. Accent
        // belongs to their semantic content, never to the surface treatment.
        modifier(A56SurfaceModifier(radius: radius))
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

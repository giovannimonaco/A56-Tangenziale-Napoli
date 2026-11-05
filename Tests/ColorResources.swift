import SwiftUI

// These checks compile the domain files directly, without Xcode's asset
// generation or the app's view modifiers. They don't render colors.
extension ShapeStyle where Self == Color {
    static var a56Open: Color { Color("AccentColor") }
    static var a56Caution: Color { Color("A56Caution") }
    static var a56Block: Color { Color("A56Issue") }
}

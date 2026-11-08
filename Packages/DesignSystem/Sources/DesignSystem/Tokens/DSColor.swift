import SwiftUI

/// Color tokens from the Figma "Color · Light" and "Color · Dark" collections.
/// Each token is a colorset with Any and Dark appearances, so it follows the color scheme.
public extension Color {
    enum DS {
        /// Red casing around every screen.
        public static let shell = token("shell")
        /// Screen area where content lives.
        public static let viewer = token("viewer")
        /// Card background.
        public static let surface = token("surface")
        /// Secondary background (inactive tabs, skeleton bones).
        public static let surfaceMuted = token("surfaceMuted")
        /// White information module on the detail screen.
        public static let module = token("module")
        /// Readout background (height, weight, habitat).
        public static let panel = token("panel")
        /// Stats LCD background.
        public static let lcd = token("lcd")
        public static let lcdText = token("lcdText")
        /// Unlit stat segment.
        public static let segmentOff = token("segmentOff")
        public static let border = token("border")
        /// Yellow accent: numbers, active filter, active tab, primary button.
        public static let accent = token("accent")
        /// Accent used as text on light backgrounds, where pure yellow is not readable.
        public static let accentText = token("accentText")
        /// Text on top of `accent`.
        public static let onAccent = token("onAccent")
        public static let textPrimary = token("textPrimary")
        public static let textSecondary = token("textSecondary")
        /// Text on top of `shell`.
        public static let onShell = token("onShell")
        public static let danger = token("danger")

        private static func token(_ name: String) -> Color {
            Color(name, bundle: .module)
        }
    }
}

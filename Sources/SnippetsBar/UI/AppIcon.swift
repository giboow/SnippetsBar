import SwiftUI

/// App icon: white quote symbol on a blue rounded square. Used in the panel header and,
/// rendered as an image, as the application icon (alerts, Settings window).
struct AppIconView: View {
    var size: CGFloat

    static let blue = Color(red: 0.0, green: 0.48, blue: 1.0)

    var body: some View {
        Image(systemName: "text.quote")
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [Self.blue.opacity(0.85), Self.blue], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
            )
    }

    /// Image with the standard macOS icon margins (the shape fills about 80 % of the canvas).
    @MainActor
    static func applicationIcon(size: CGFloat = 512) -> NSImage? {
        let renderer = ImageRenderer(content: AppIconView(size: size * 0.8).frame(width: size, height: size))
        renderer.scale = 2
        return renderer.nsImage
    }
}

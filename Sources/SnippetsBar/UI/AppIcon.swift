import SwiftUI

/// App glyph: an opening quote and lines of text, drawn with plain shapes
/// (SF Symbols may not be used in app icons). White, on a transparent square.
struct QuoteGlyph: View {
    var size: CGFloat

    var body: some View {
        let s = size
        ZStack(alignment: .topLeading) {
            quoteMark(x: 0.26, y: 0.24)
            quoteMark(x: 0.42, y: 0.24)
            line(x: 0.58, y: 0.29, width: 0.16)
            line(x: 0.58, y: 0.39, width: 0.16)
            line(x: 0.26, y: 0.53, width: 0.48)
            line(x: 0.26, y: 0.65, width: 0.48)
        }
        .frame(width: s, height: s, alignment: .topLeading)
        .foregroundStyle(.white)
    }

    /// “6”-shaped mark: a round dot with a tail that curves up and thins out.
    private func quoteMark(x: CGFloat, y: CGFloat) -> some View {
        let w = 0.15 * size
        return ZStack(alignment: .topLeading) {
            QuoteTail().frame(width: w, height: 1.4 * w)
            Circle()
                .frame(width: 0.96 * w, height: 0.96 * w)
                .offset(x: 0.02 * w, y: 0.44 * w)
        }
        .offset(x: x * size, y: y * size)
    }

    private func line(x: CGFloat, y: CGFloat, width: CGFloat) -> some View {
        Capsule()
            .frame(width: width * size, height: 0.055 * size)
            .offset(x: x * size, y: y * size)
    }
}

/// Tail of a quote mark, from the left of the dot up to a point at the top right.
private struct QuoteTail: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        var path = Path()
        path.move(to: CGPoint(x: 0.02 * w, y: 0.95 * w))
        path.addQuadCurve(to: CGPoint(x: 0.80 * w, y: 0.02 * w), control: CGPoint(x: 0.0, y: 0.25 * w))
        path.addLine(to: CGPoint(x: 0.92 * w, y: 0.14 * w))
        path.addQuadCurve(to: CGPoint(x: 0.48 * w, y: 0.60 * w), control: CGPoint(x: 0.42 * w, y: 0.28 * w))
        path.closeSubpath()
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// App icon as drawn inside the app (panel header, alerts in development builds):
/// the glyph on a blue rounded square. The bundle icon (Resources/AppIcon.icon) uses the
/// same glyph; regenerate it with scripts/generate-icon.sh after changing QuoteGlyph.
struct AppIconView: View {
    var size: CGFloat

    static let blue = Color(red: 0.0, green: 0.48, blue: 1.0)

    var body: some View {
        QuoteGlyph(size: size)
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

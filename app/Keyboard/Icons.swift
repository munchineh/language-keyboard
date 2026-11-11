import SwiftUI

/// Two-tone icons: the main shape in full colour, the extra information in a
/// lighter shade (after the line-icon style Mancini shared, 2026-11-11).

/// Settings sliders on a 24pt grid (based on the mockup's SVG, with the two
/// sliders 6pt apart instead of 10 so the icon reads as one shape).
struct SlidersShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        path.move(to: p(4, 9)); path.addLine(to: p(13, 9))
        path.move(to: p(19, 9)); path.addLine(to: p(20, 9))
        path.addEllipse(in: CGRect(x: rect.minX + (16 - 2.4) * s, y: rect.minY + (9 - 2.4) * s, width: 4.8 * s, height: 4.8 * s))
        path.move(to: p(4, 15)); path.addLine(to: p(7, 15))
        path.move(to: p(13, 15)); path.addLine(to: p(20, 15))
        path.addEllipse(in: CGRect(x: rect.minX + (10 - 2.4) * s, y: rect.minY + (15 - 2.4) * s, width: 4.8 * s, height: 4.8 * s))
        return path
    }
}

/// Settings icon: the sliders in the main tone, with the language mark (한 / 中)
/// in the lighter tone overlapping the bottom-right corner diagonally. The sliders
/// are knocked out around the mark so the two never touch. The mark never
/// changes colour; check status lives in the suggestion bar instead.
struct SettingsGlyph: View {
    let badge: String
    let primary: Color
    let secondary: Color
    var size: CGFloat = 28

    var body: some View {
        Canvas { ctx, canvas in
            let w = canvas.width
            let markCenter = CGPoint(x: w * 0.73, y: w * 0.72)
            let markFont = Font.system(size: w * 0.52, weight: .bold)

            ctx.drawLayer { layer in
                // Sliders fill most of the square, nudged up-left to make room for the mark.
                let slidersRect = CGRect(x: -w * 0.12, y: -w * 0.10, width: w * 0.92, height: w * 0.92)
                layer.stroke(SlidersShape().path(in: slidersRect), with: .color(primary),
                             style: StrokeStyle(lineWidth: w * 0.064, lineCap: .round, lineJoin: .round))
                // Knock out a gap around the mark.
                layer.blendMode = .destinationOut
                let r = w * 0.31
                layer.fill(Path(ellipseIn: CGRect(x: markCenter.x - r, y: markCenter.y - r, width: r * 2, height: r * 2)),
                           with: .color(.black))
            }
            var mark = ctx.resolve(Text(badge).font(markFont))
            mark.shading = .color(secondary)
            ctx.draw(mark, at: markCenter, anchor: .center)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Round blue button with an arrow, used to apply a correction or an option.
struct ArrowButton: View {
    let theme: KeyboardTheme
    var systemName = "arrow.up"
    var label = "Apply"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(theme.accent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

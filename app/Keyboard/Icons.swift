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


/// Settings icon: a rounded hexagon (pointy top) with the language cut out.
struct HexagonShape: Shape {
    /// Corner rounding as a share of the width.
    var cornerRadius: CGFloat = 0.13

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let corners = (0..<6).map { i -> CGPoint in
            let a = CGFloat(i) * .pi / 3 - .pi / 2
            return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        }
        let radius = cornerRadius * rect.width
        var path = Path()
        // Start halfway along the last edge so every corner gets the same arc.
        let last = corners[5], first = corners[0]
        path.move(to: CGPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2))
        for i in 0..<6 {
            path.addArc(tangent1End: corners[i], tangent2End: corners[(i + 1) % 6], radius: radius)
        }
        path.closeSubpath()
        return path
    }
}

struct SettingsGlyph: View {
    let badge: String
    let color: Color
    var size: CGFloat = 26

    var body: some View {
        Canvas { ctx, canvas in
            let w = canvas.width
            ctx.drawLayer { layer in
                layer.fill(HexagonShape().path(in: CGRect(origin: .zero, size: canvas)), with: .color(color))
                layer.blendMode = .destinationOut
                let mark = layer.resolve(Text(badge).font(.system(size: w * 0.44, weight: .bold)))
                layer.draw(mark, at: CGPoint(x: w / 2, y: w / 2 + w * 0.005), anchor: .center)
            }
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

/// Orange line with a chevron that opens the app (or its Settings page).
struct FullAccessLink: View {
    let theme: KeyboardTheme
    let text: String
    var size: CGFloat = 14
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(text)
                    .font(.system(size: size))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Image(systemName: "chevron.right")
                    .font(.system(size: size - 2, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(theme.warning)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Settings to turn on Full Access")
    }
}

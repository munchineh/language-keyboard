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

/// Solid gear with six wide spokes and crisp edges (radius eases quickly
/// between inner and outer, after Mancini's reference).
struct GearShape: Shape {
    var teeth = 6
    var outer: CGFloat = 0.47
    var inner: CGFloat = 0.365

    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        let c = CGPoint(x: rect.midX, y: rect.midY)
        func ease(_ x: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
            if x <= a { return 0 }
            if x >= b { return 1 }
            let u = (x - a) / (b - a)
            return u * u * (3 - 2 * u)
        }
        var path = Path()
        let steps = 720
        for k in 0...steps {
            let t = CGFloat(k) / CGFloat(steps) * 2 * .pi
            let phase = (t * CGFloat(teeth) / (2 * .pi)).truncatingRemainder(dividingBy: 1)
            let f = min(ease(phase, 0.04, 0.08), 1 - ease(phase, 0.58, 0.62))
            let r = size * (inner + (outer - inner) * f)
            let a = t - .pi / 2 - 2 * .pi / CGFloat(teeth) * 0.33
            let p = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            if k == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

/// Settings icon: a solid gear with the language mark (한 / 中) cut out of
/// its centre as negative space. It never changes colour; check status lives
/// in the suggestion bar.
struct SettingsGlyph: View {
    let badge: String
    let color: Color
    var size: CGFloat = 26

    var body: some View {
        Canvas { ctx, canvas in
            let w = canvas.width
            ctx.drawLayer { layer in
                layer.fill(GearShape().path(in: CGRect(origin: .zero, size: canvas)), with: .color(color))
                layer.blendMode = .destinationOut
                let mark = layer.resolve(Text(badge).font(.system(size: w * 0.41, weight: .bold)))
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

/// Orange line with a chevron that opens the app's Settings page.
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

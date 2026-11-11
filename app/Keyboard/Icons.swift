import SwiftUI

/// Two-tone icons: the main shape in full colour, the extra information in a
/// lighter shade (after the line-icon style Mancini shared, 2026-11-11).

/// Settings sliders (from the mockup's SVG, 24pt grid), stroked with round caps.
struct SlidersShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        path.move(to: p(4, 7)); path.addLine(to: p(13, 7))
        path.move(to: p(19, 7)); path.addLine(to: p(20, 7))
        path.addEllipse(in: CGRect(x: rect.minX + (16 - 2.4) * s, y: rect.minY + (7 - 2.4) * s, width: 4.8 * s, height: 4.8 * s))
        path.move(to: p(4, 17)); path.addLine(to: p(7, 17))
        path.move(to: p(13, 17)); path.addLine(to: p(20, 17))
        path.addEllipse(in: CGRect(x: rect.minX + (10 - 2.4) * s, y: rect.minY + (17 - 2.4) * s, width: 4.8 * s, height: 4.8 * s))
        return path
    }
}

/// Settings icon with the current language mark in the second tone.
/// The mark turns green when the last check found nothing to fix, and pulses while checking.
struct SettingsGlyph: View {
    let badge: String
    let primary: Color
    let secondary: Color
    var pulsing = false

    @State private var dim = false

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            SlidersShape()
                .stroke(primary, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: 21, height: 21)
                .alignmentGuide(.lastTextBaseline) { d in d[.bottom] - 3 }
            Text(badge)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(secondary)
                .opacity(pulsing && dim ? 0.35 : 1)
        }
        .onAppear { if pulsing { startPulse() } }
        .onChange(of: pulsing) { _, on in if on { startPulse() } else { dim = false } }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { dim = true }
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

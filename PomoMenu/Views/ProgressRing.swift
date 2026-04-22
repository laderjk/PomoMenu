import SwiftUI

struct ProgressRing: View {
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: clampedProgress)
        }
    }

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }
}

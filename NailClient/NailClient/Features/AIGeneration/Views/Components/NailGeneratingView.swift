import SwiftUI

struct NailGeneratingView: View {
    enum Phase: CaseIterable {
        case stroke
        case fill
        case highlight
        case glow

        var secondaryMessage: String {
            switch self {
            case .stroke:
                return "디자인 분석 중…"
            case .fill:
                return "컬러 매칭 중…"
            case .highlight, .glow:
                return "마무리 광택 처리 중…"
            }
        }
    }

    struct Configuration {
        var backgroundColor: Color = Color(hex: 0xFDCFBB)
        var baseColor: Color = Color(hex: 0xE85B4E)
        var strokeDuration: TimeInterval = 0.8
        var fillDuration: TimeInterval = 0.8
        var highlightDuration: TimeInterval = 1.2
        var glowDuration: TimeInterval = 1.5
        var restartFadeDuration: TimeInterval = 0.18
        var restartDelay: TimeInterval = 0.05
        var nailSize: CGSize = CGSize(width: 140, height: 184)
        var showSecondaryText: Bool = true
        var showsBackground: Bool = true

        var totalCycleDuration: TimeInterval {
            max(
                1.4,
                strokeDuration + fillDuration + highlightDuration + glowDuration + restartFadeDuration + restartDelay
            )
        }
    }

    private enum Metrics {
        static let strokeLineWidth: CGFloat = 4
        static let contentSpacing: CGFloat = 18
        static let captionSpacing: CGFloat = 6
        static let progressHeaderMinHeight: CGFloat = 18
        static let glowBlurRadius: CGFloat = 16
        static let glowScale: CGFloat = 1.045
        static let glowColorOpacity: CGFloat = 0.86
        static let glowMinOpacity: CGFloat = 0.3
        static let glowMaxOpacity: CGFloat = 0.6
        static let highlightWidthFactor: CGFloat = 0.64
        static let highlightHeightFactor: CGFloat = 1.8
        static let highlightTravelFactor: CGFloat = 1.5
        static let highlightAngle: Angle = .degrees(-24)
        static let horizontalPadding: CGFloat = 24
    }

    let configuration: Configuration

    @State private var cycleProgress: CGFloat = 0
    @State private var isAnimating: Bool = false

    init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    var body: some View {
        ZStack {
            if configuration.showsBackground {
                configuration.backgroundColor
            }

            VStack(spacing: Metrics.contentSpacing) {
                if configuration.showSecondaryText {
                    progressHeader
                }

                nailBody
                    .frame(width: configuration.nailSize.width, height: configuration.nailSize.height)

                captionSection
            }
            .padding(.horizontal, Metrics.horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { startAnimationIfNeeded() }
        .onDisappear { stopAnimation() }
    }

    private var nailBody: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                NailShape()
                    .fill(configuration.baseColor.opacity(Metrics.glowColorOpacity))
                    .scaleEffect(Metrics.glowScale)
                    .blur(radius: Metrics.glowBlurRadius)
                    .opacity(glowOpacity)

                NailShape()
                    .fill(configuration.baseColor)
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(height: size.height * fillProgress)
                    }

                highlightSweep(size: size)

                NailShape()
                    .trim(from: 0, to: strokeProgress)
                    .stroke(
                        configuration.baseColor,
                        style: StrokeStyle(
                            lineWidth: Metrics.strokeLineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func highlightSweep(size: CGSize) -> some View {
        let travelDistance = size.width * Metrics.highlightTravelFactor
        let bandWidth = size.width * Metrics.highlightWidthFactor
        let bandHeight = size.height * Metrics.highlightHeightFactor
        let xOffset = (-travelDistance) + (travelDistance * 2 * highlightProgress)

        return Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.0), location: 0.0),
                        .init(color: .white.opacity(0.22), location: 0.22),
                        .init(color: .white.opacity(0.0), location: 0.5),
                        .init(color: .white.opacity(0.22), location: 0.78),
                        .init(color: .white.opacity(0.0), location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: bandWidth, height: bandHeight)
            .rotationEffect(Metrics.highlightAngle)
            .offset(x: xOffset)
            .blendMode(.screen)
            .mask { NailShape() }
    }

    private var captionSection: some View {
        VStack(spacing: Metrics.captionSpacing) {
            Text("오늘 네일 AI가 네일을 생성중이에요")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.82))
        }
        .multilineTextAlignment(.center)
    }

    private var progressHeader: some View {
        Text(phase.secondaryMessage)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.black.opacity(0.56))
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Metrics.progressHeaderMinHeight)
            .contentTransition(.opacity)
            .id(phase)
    }

    private var phase: Phase {
        if cycleProgress < phaseMarks.strokeEnd {
            return .stroke
        }
        if cycleProgress < phaseMarks.fillEnd {
            return .fill
        }
        if cycleProgress < phaseMarks.highlightEnd {
            return .highlight
        }
        return .glow
    }

    private var strokeProgress: CGFloat {
        clampedProgress(cycleProgress, from: 0, to: phaseMarks.strokeEnd)
    }

    private var fillProgress: CGFloat {
        clampedProgress(cycleProgress, from: phaseMarks.fillStart, to: phaseMarks.fillEnd)
    }

    private var highlightProgress: CGFloat {
        clampedProgress(cycleProgress, from: phaseMarks.highlightStart, to: phaseMarks.highlightEnd)
    }

    private var glowOpacity: CGFloat {
        let glowProgress = clampedProgress(cycleProgress, from: phaseMarks.highlightEnd, to: phaseMarks.glowEnd)
        if glowProgress <= 0 {
            return 0
        }
        let pulse = (sin(Double(glowProgress) * .pi * 2) + 1) * 0.5
        return Metrics.glowMinOpacity + (Metrics.glowMaxOpacity - Metrics.glowMinOpacity) * CGFloat(pulse)
    }

    private var phaseMarks: PhaseMarks {
        let stroke = max(0.1, configuration.strokeDuration)
        let fill = max(0.1, configuration.fillDuration)
        let highlight = max(0.1, configuration.highlightDuration)
        let glow = max(0.1, configuration.glowDuration)
        let tail = max(0.08, configuration.restartFadeDuration + configuration.restartDelay)
        let total = stroke + fill + highlight + glow + tail

        let strokeEnd = stroke / total
        let fillEnd = strokeEnd + (fill / total)
        let highlightEnd = fillEnd + (highlight / total)
        let glowEnd = highlightEnd + (glow / total)

        return PhaseMarks(
            strokeEnd: strokeEnd,
            fillStart: strokeEnd * 0.45,
            fillEnd: fillEnd,
            highlightStart: fillEnd * 0.92,
            highlightEnd: highlightEnd,
            glowEnd: min(1, glowEnd)
        )
    }

    private func startAnimationIfNeeded() {
        guard !isAnimating else { return }
        isAnimating = true
        cycleProgress = 0
        withAnimation(.linear(duration: configuration.totalCycleDuration).repeatForever(autoreverses: false)) {
            cycleProgress = 1
        }
    }

    private func stopAnimation() {
        isAnimating = false
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            cycleProgress = 0
        }
    }

    private func clampedProgress(_ value: CGFloat, from start: CGFloat, to end: CGFloat) -> CGFloat {
        guard end > start else { return 0 }
        let normalized = (value - start) / (end - start)
        return min(1, max(0, normalized))
    }
}

private struct PhaseMarks {
    let strokeEnd: CGFloat
    let fillStart: CGFloat
    let fillEnd: CGFloat
    let highlightStart: CGFloat
    let highlightEnd: CGFloat
    let glowEnd: CGFloat
}

struct NailShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        let cuticleLeft = CGPoint(x: 0.24 * w, y: 0.93 * h)
        let cuticleRight = CGPoint(x: 0.76 * w, y: 0.93 * h)
        let cuticleControl = CGPoint(x: 0.50 * w, y: 1.02 * h)

        let leftShoulder = CGPoint(x: 0.14 * w, y: 0.76 * h)
        let rightShoulder = CGPoint(x: 0.86 * w, y: 0.76 * h)
        let topLeftEdge = CGPoint(x: 0.30 * w, y: 0.09 * h)
        let topRightEdge = CGPoint(x: 0.70 * w, y: 0.09 * h)
        let topLeftCorner = CGPoint(x: 0.22 * w, y: 0.16 * h)
        let topRightCorner = CGPoint(x: 0.78 * w, y: 0.16 * h)

        let rightControl1 = CGPoint(x: 0.94 * w, y: 0.62 * h)
        let rightControl2 = CGPoint(x: 0.90 * w, y: 0.30 * h)
        let leftControl1 = CGPoint(x: 0.10 * w, y: 0.30 * h)
        let leftControl2 = CGPoint(x: 0.06 * w, y: 0.62 * h)

        return Path { path in
            path.move(to: cuticleLeft)
            path.addQuadCurve(to: cuticleRight, control: cuticleControl)
            path.addCurve(to: rightShoulder, control1: rightControl1, control2: rightControl2)
            path.addQuadCurve(to: topRightCorner, control: CGPoint(x: 0.88 * w, y: 0.56 * h))
            path.addQuadCurve(to: topRightEdge, control: CGPoint(x: 0.78 * w, y: 0.10 * h))
            path.addLine(to: topLeftEdge)
            path.addQuadCurve(to: topLeftCorner, control: CGPoint(x: 0.22 * w, y: 0.10 * h))
            path.addQuadCurve(to: leftShoulder, control: CGPoint(x: 0.12 * w, y: 0.56 * h))
            path.addCurve(to: cuticleLeft, control1: leftControl1, control2: leftControl2)
            path.closeSubpath()
        }
    }
}

#Preview {
    NailGeneratingView()
}

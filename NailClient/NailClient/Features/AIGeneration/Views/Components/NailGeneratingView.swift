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
        var nailSize: CGSize = CGSize(width: 146, height: 220)
        var showSecondaryText: Bool = true
        var showsBackground: Bool = true
    }

    private enum Metrics {
        static let strokeLineWidth: CGFloat = 4
        static let contentSpacing: CGFloat = 18
        static let captionSpacing: CGFloat = 6
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

    @State private var phase: Phase = .stroke
    @State private var strokeProgress: CGFloat = 0
    @State private var fillProgress: CGFloat = 0
    @State private var highlightProgress: CGFloat = 0
    @State private var glowOpacity: CGFloat = 0
    @State private var nailOpacity: CGFloat = 1
    @State private var animationTask: Task<Void, Never>?

    init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    var body: some View {
        ZStack {
            if configuration.showsBackground {
                configuration.backgroundColor
            }

            VStack(spacing: Metrics.contentSpacing) {
                nailBody
                    .frame(width: configuration.nailSize.width, height: configuration.nailSize.height)

                captionSection
            }
            .padding(.horizontal, Metrics.horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { startLoopIfNeeded() }
        .onDisappear { stopLoop() }
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
            .opacity(nailOpacity)
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
            Text("AI가 네일을 생성 중이에요…")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.82))

            if configuration.showSecondaryText {
                Text(phase.secondaryMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.56))
                    .contentTransition(.opacity)
                    .id(phase)
            }
        }
        .multilineTextAlignment(.center)
    }

    private func startLoopIfNeeded() {
        guard animationTask == nil else { return }

        animationTask = Task {
            await runAnimationLoop()
        }
    }

    private func stopLoop() {
        animationTask?.cancel()
        animationTask = nil
    }

    private func runAnimationLoop() async {
        while !Task.isCancelled {
            await resetForCycle()
            await runStrokePhase()
            await runFillPhase()
            await runHighlightPhase()
            await runGlowPhase()
            await runRestartTransition()
        }
    }

    private func runStrokePhase() async {
        await MainActor.run {
            phase = .stroke
            withAnimation(.easeInOut(duration: configuration.strokeDuration)) {
                strokeProgress = 1
            }
        }
        await sleep(configuration.strokeDuration)
    }

    private func runFillPhase() async {
        await MainActor.run {
            phase = .fill
            withAnimation(.easeInOut(duration: configuration.fillDuration)) {
                fillProgress = 1
            }
        }
        await sleep(configuration.fillDuration)
    }

    private func runHighlightPhase() async {
        await MainActor.run {
            phase = .highlight
            withAnimation(.easeInOut(duration: configuration.highlightDuration)) {
                highlightProgress = 1
            }
        }
        await sleep(configuration.highlightDuration)
    }

    private func runGlowPhase() async {
        await MainActor.run {
            phase = .glow
            glowOpacity = Metrics.glowMinOpacity

            withAnimation(
                .easeInOut(duration: configuration.glowDuration / 2)
                    .repeatCount(2, autoreverses: true)
            ) {
                glowOpacity = Metrics.glowMaxOpacity
            }
        }

        await sleep(configuration.glowDuration)

        await MainActor.run {
            glowOpacity = Metrics.glowMinOpacity
        }
    }

    private func runRestartTransition() async {
        await MainActor.run {
            withAnimation(.easeInOut(duration: configuration.restartFadeDuration)) {
                nailOpacity = 0
            }
        }
        await sleep(configuration.restartFadeDuration)

        await resetForCycle()

        await MainActor.run {
            withAnimation(.easeInOut(duration: configuration.restartFadeDuration)) {
                nailOpacity = 1
            }
        }
        await sleep(configuration.restartFadeDuration + configuration.restartDelay)
    }

    private func resetForCycle() async {
        await MainActor.run {
            withDisabledAnimations {
                phase = .stroke
                strokeProgress = 0
                fillProgress = 0
                highlightProgress = 0
                glowOpacity = 0
            }
        }
    }

    @MainActor
    private func withDisabledAnimations(_ updates: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, updates)
    }

    private func sleep(_ seconds: TimeInterval) async {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

struct NailShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        let cuticleLeft = CGPoint(x: 0.18 * w, y: 0.92 * h)
        let cuticleRight = CGPoint(x: 0.82 * w, y: 0.92 * h)
        let cuticleControl = CGPoint(x: 0.50 * w, y: 1.02 * h)

        let topLeft = CGPoint(x: 0.40 * w, y: 0.10 * h)
        let topRight = CGPoint(x: 0.60 * w, y: 0.10 * h)
        let tipControl = CGPoint(x: 0.50 * w, y: -0.02 * h)

        let rightControl1 = CGPoint(x: 0.97 * w, y: 0.72 * h)
        let rightControl2 = CGPoint(x: 0.88 * w, y: 0.28 * h)
        let leftControl1 = CGPoint(x: 0.12 * w, y: 0.28 * h)
        let leftControl2 = CGPoint(x: 0.03 * w, y: 0.72 * h)

        return Path { path in
            path.move(to: cuticleLeft)
            path.addQuadCurve(to: cuticleRight, control: cuticleControl)
            path.addCurve(to: topRight, control1: rightControl1, control2: rightControl2)
            path.addQuadCurve(to: topLeft, control: tipControl)
            path.addCurve(to: cuticleLeft, control1: leftControl1, control2: leftControl2)
            path.closeSubpath()
        }
    }
}

#Preview {
    NailGeneratingView()
}

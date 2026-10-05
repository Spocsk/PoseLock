import SwiftUI
import simd

/// Skeleton de référence et skeleton réellement capturé dans le même Canvas.
/// Les deux jeux de joints sont déjà normalisés (bassin à l’origine, échelle
/// hanches–tête ≈ 1), donc comparables une fois le bassin aligné.
struct PoseComparisonSkeleton: View {
    var poseID: PoseID
    var snapshot: SkeletonSnapshot?
    /// Piloté par le drag, et repris tel quel par la carte de partage.
    @Binding var yaw: Float
    var isInteractive: Bool = true
    var lineWidth: CGFloat = Theme.skeletonLine
    var jointSize: CGFloat = Theme.skeletonJoint

    @State private var yawAtDragStart: Float?

    init(
        poseID: PoseID,
        snapshot: SkeletonSnapshot?,
        yaw: Binding<Float> = .constant(0),
        isInteractive: Bool = true,
        lineWidth: CGFloat = Theme.skeletonLine,
        jointSize: CGFloat = Theme.skeletonJoint
    ) {
        self.poseID = poseID
        self.snapshot = snapshot
        _yaw = yaw
        self.isInteractive = isInteractive
        self.lineWidth = lineWidth
        self.jointSize = jointSize
    }

    var body: some View {
        VStack(spacing: 10) {
            canvas
                .contentShape(Rectangle())
                .gesture(isInteractive ? rotateGesture : nil)
            legend
        }
    }

    private var canvas: some View {
        let projections = projected()
        return Canvas { context, size in
            draw(
                projections.reference,
                in: context,
                size: size,
                width: lineWidth * 0.7,
                color: { _ in Theme.goldMuted },
                dots: false
            )
            if let captured = projections.captured {
                draw(
                    captured,
                    in: context,
                    size: size,
                    width: lineWidth,
                    color: capturedColor,
                    dots: true
                )
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: Theme.goldMuted, label: String(localized: "Référence"))
            if snapshot != nil {
                legendItem(color: Theme.lockGreen, label: String(localized: "Ta pose"))
            } else {
                Text("Skeleton non enregistré pour cette prise.")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.ivoryFaint)
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Capsule()
                .fill(color)
                .frame(width: 14, height: 3)
            Text(label)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.ivoryMuted)
        }
    }

    private var rotateGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let start = yawAtDragStart ?? yaw
                yawAtDragStart = start
                yaw = start + Float(value.translation.width) * 0.6
            }
            .onEnded { _ in
                yawAtDragStart = nil
            }
    }

    private func projected() -> (reference: [Joint: SIMD2<Float>], captured: [Joint: SIMD2<Float>]?) {
        let reference = BodyFrame.preview(for: poseID).joints3D
        guard let snapshot else {
            return (PosePreviewBuilder.projectFitted(reference, yaw: yaw), nil)
        }
        let captured = PosePreviewBuilder.alignYawToHips(snapshot.joints3D, like: reference)
        let sets = PosePreviewBuilder.projectFitted([reference, captured], yaw: yaw)
        return (sets[0], sets.count > 1 ? sets[1] : nil)
    }

    private func capturedColor(_ bone: Bone) -> Color {
        let regions = snapshot?.greenRegions ?? []
        let green = regions.contains { $0.bones.contains(bone) }
        return green ? Theme.lockGreen : Theme.ivory.opacity(0.7)
    }

    private func draw(
        _ points: [Joint: SIMD2<Float>],
        in context: GraphicsContext,
        size: CGSize,
        width: CGFloat,
        color: (Bone) -> Color,
        dots: Bool
    ) {
        let side = min(size.width, size.height)
        let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
        func mapped(_ p: SIMD2<Float>) -> CGPoint {
            CGPoint(
                x: origin.x + CGFloat(p.x) * side,
                y: origin.y + CGFloat(p.y) * side
            )
        }
        var drawn: Set<Joint> = []
        for bone in Bone.all {
            guard let a = points[bone.from], let b = points[bone.to] else { continue }
            var path = Path()
            path.move(to: mapped(a))
            path.addLine(to: mapped(b))
            context.stroke(
                path,
                with: .color(color(bone)),
                style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
            )
            drawn.insert(bone.from)
            drawn.insert(bone.to)
        }
        guard dots else { return }
        let radius = jointSize / 2
        for joint in drawn {
            guard let p = points[joint] else { continue }
            let center = mapped(p)
            let dot = Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            context.fill(dot, with: .color(Theme.ivory.opacity(0.9)))
        }
    }
}

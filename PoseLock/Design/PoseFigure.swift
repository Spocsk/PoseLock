import SwiftUI
import simd

/// Silhouette capsule 2D, construite depuis les 17 joints du preview.
/// Pas de mesh, pas d’asset : le corps est un polygone torse + des stadiums.
struct PoseFigure: View {
    var joints3D: [Joint: SIMD3<Float>]
    var highlight: PoseCoachStep.Highlight = .none
    var yaw: Float = 0
    var lineWidth: CGFloat = Theme.skeletonLine

    var body: some View {
        Canvas { context, size in
            let points = PosePreviewBuilder.projectFitted(joints3D, yaw: yaw)
            let rotated = joints3D.mapValues { PosePreviewBuilder.rotateY($0, degrees: yaw) }
            draw(points: points, depth: rotated, in: context, size: size)
        }
        .accessibilityHidden(true)
    }

    private func draw(
        points: [Joint: SIMD2<Float>],
        depth: [Joint: SIMD3<Float>],
        in context: GraphicsContext,
        size: CGSize
    ) {
        let side = min(size.width, size.height)
        guard side > 1 else { return }
        let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
        func mapped(_ p: SIMD2<Float>) -> CGPoint {
            CGPoint(
                x: origin.x + CGFloat(p.x) * side,
                y: origin.y + CGFloat(p.y) * side
            )
        }
        func z(_ joint: Joint) -> Float {
            depth[joint]?.z ?? 0
        }

        // Épaisseur anatomique indépendante de la largeur projetée du bassin :
        // le personnage conserve son volume lorsqu'il passe de profil.
        let hipW: CGFloat = {
            guard let head = points[.head], let root = points[.root] else { return side * 0.10 }
            return hypot(CGFloat(head.x - root.x), CGFloat(head.y - root.y)) * side * 0.24
        }()
        let scale: CGFloat = 1

        var layers: [(z: Float, draw: (GraphicsContext) -> Void)] = []

        if let torso = torsoPath(points, mapped: mapped, hipW: hipW) {
            let torsoZ = ([Joint.leftShoulder, .rightShoulder, .leftHip, .rightHip] as [Joint])
                .map(z).reduce(0, +) / 4
            let color = fillColor(for: .torso)
            layers.append((torsoZ, { ctx in
                ctx.fill(torso, with: .color(color))
                ctx.stroke(torso, with: .color(Theme.background.opacity(0.5)), lineWidth: side * 0.004)
            }))
        }

        if let head = points[.head], let neck = points[.neck] {
            let center = mapped(neck + (head - neck) * 0.65)
            let neckPt = mapped(neck)
            let radius = max(hipW * 0.43 * scale, 4)
            let color = fillColor(for: .head)
            layers.append((z(.head), { ctx in
                var neckPath = Path()
                neckPath.move(to: neckPt)
                neckPath.addLine(to: center)
                ctx.stroke(
                    neckPath,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: radius * 0.7, lineCap: .round)
                )
                let dot = Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                ctx.fill(dot, with: .color(color))
            }))
        }

        let limbs: [(Bone, CGFloat, SkeletonRegion)] = [
            (Bone(from: .leftShoulder, to: .leftElbow), hipW * 0.48 * scale, .leftArm),
            (Bone(from: .leftElbow, to: .leftWrist), hipW * 0.36 * scale, .leftArm),
            (Bone(from: .rightShoulder, to: .rightElbow), hipW * 0.48 * scale, .rightArm),
            (Bone(from: .rightElbow, to: .rightWrist), hipW * 0.36 * scale, .rightArm),
            (Bone(from: .leftHip, to: .leftKnee), hipW * 0.67 * scale, .leftLeg),
            (Bone(from: .leftKnee, to: .leftAnkle), hipW * 0.46 * scale, .leftLeg),
            (Bone(from: .rightHip, to: .rightKnee), hipW * 0.67 * scale, .rightLeg),
            (Bone(from: .rightKnee, to: .rightAnkle), hipW * 0.46 * scale, .rightLeg)
        ]
        for (bone, width, region) in limbs {
            guard let a = points[bone.from], let b = points[bone.to] else { continue }
            let depthZ = (z(bone.from) + z(bone.to)) / 2
            let color = fillColor(for: region)
            let pa = mapped(a)
            let pb = mapped(b)
            layers.append((depthZ, { ctx in
                var path = Path()
                path.move(to: pa)
                path.addLine(to: pb)
                ctx.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
                )
            }))
        }

        for layer in layers.sorted(by: { $0.z < $1.z }) {
            layer.draw(context)
        }

        drawHighlightBones(points: points, mapped: mapped, in: context, width: max(hipW * 0.12, 1.5))
    }

    private func torsoPath(
        _ points: [Joint: SIMD2<Float>],
        mapped: (SIMD2<Float>) -> CGPoint,
        hipW: CGFloat
    ) -> Path? {
        guard let ls = points[.leftShoulder],
              let rs = points[.rightShoulder],
              let lh = points[.leftHip],
              let rh = points[.rightHip] else { return nil }
        let pLS = mapped(ls)
        let pRS = mapped(rs)
        let pLH = mapped(lh)
        let pRH = mapped(rh)
        let waistLeft = CGPoint(
            x: pLS.x * 0.45 + pLH.x * 0.55,
            y: pLS.y * 0.45 + pLH.y * 0.55
        )
        let waistRight = CGPoint(
            x: pRS.x * 0.45 + pRH.x * 0.55,
            y: pRS.y * 0.45 + pRH.y * 0.55
        )
        let mid = CGPoint(
            x: (waistLeft.x + waistRight.x) / 2,
            y: (waistLeft.y + waistRight.y) / 2
        )
        let pinch = hipW * 0.22
        func inset(_ p: CGPoint) -> CGPoint {
            let dx = p.x - mid.x
            let dy = p.y - mid.y
            let len = hypot(dx, dy)
            guard len > 0.5 else { return p }
            let t = pinch / len
            return CGPoint(x: p.x - dx * t, y: p.y - dy * t)
        }
        var path = Path()
        path.move(to: pLS)
        path.addLine(to: pRS)
        path.addLine(to: inset(waistRight))
        path.addLine(to: pRH)
        path.addLine(to: pLH)
        path.addLine(to: inset(waistLeft))
        path.closeSubpath()
        return path
    }

    private func drawHighlightBones(
        points: [Joint: SIMD2<Float>],
        mapped: (SIMD2<Float>) -> CGPoint,
        in context: GraphicsContext,
        width: CGFloat
    ) {
        let bones: [Bone]
        switch highlight {
        case .none:
            return
        case .regions(let regions):
            bones = regions.flatMap(\.bones)
        case .allGreen:
            bones = Bone.all
        }
        let color: Color = {
            switch highlight {
            case .allGreen: return Theme.lockGreen.opacity(0.85)
            default: return Theme.gold
            }
        }()
        for bone in bones {
            guard let a = points[bone.from], let b = points[bone.to] else { continue }
            var path = Path()
            path.move(to: mapped(a))
            path.addLine(to: mapped(b))
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: width, lineCap: .round)
            )
        }
    }

    private func fillColor(for region: SkeletonRegion) -> Color {
        switch highlight {
        case .none:
            return Theme.ivory.opacity(0.55)
        case .regions(let regions):
            return regions.contains(region) ? Theme.gold : Theme.ivory.opacity(0.28)
        case .allGreen:
            return Theme.lockGreen
        }
    }
}

/// Preview d’une pose : silhouette interpolée debout → cible, avec yaw optionnel.
struct PosePreviewSkeleton: View {
    var poseID: PoseID
    var highlight: PoseCoachStep.Highlight = .none
    var lineWidth: CGFloat = Theme.skeletonLine
    var jointSize: CGFloat = Theme.skeletonJoint
    /// 0 = silhouette debout, 1 = pose cible.
    var assemble: CGFloat = 1
    var yaw: Float = 0

    var body: some View {
        PoseFigure(
            joints3D: mixedJoints,
            highlight: highlight,
            yaw: yaw,
            lineWidth: lineWidth * (jointSize / Theme.skeletonJoint)
        )
    }

    private var mixedJoints: [Joint: SIMD3<Float>] {
        let pose = BodyFrame.preview(for: poseID).joints3D
        let t = Float(min(max(assemble, 0), 1))
        if t >= 0.999 { return pose }
        let stand = BodyFrame.standingPreview().joints3D
        return PosePreviewBuilder.lerp(stand, pose, t: t)
    }
}

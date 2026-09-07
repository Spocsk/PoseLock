import SwiftUI

struct SkeletonOverlay: View {
    var frame: BodyFrame
    var evaluation: PoseEvaluation

    var body: some View {
        Canvas { context, size in
            guard !frame.joints2D.isEmpty else { return }
            var joints: Set<Joint> = []
            for bone in Bone.all {
                guard let a = frame.imagePoint(bone.from), let b = frame.imagePoint(bone.to) else { continue }
                if evaluation.missingJoints.contains(bone.from) || evaluation.missingJoints.contains(bone.to) {
                    continue
                }
                let green = evaluation.isGloballyGreen
                    || (SkeletonRenderer.region(for: bone).map { evaluation.greenRegions.contains($0) } ?? false)
                var path = Path()
                path.move(to: CGPoint(x: CGFloat(a.x) * size.width, y: CGFloat(a.y) * size.height))
                path.addLine(to: CGPoint(x: CGFloat(b.x) * size.width, y: CGFloat(b.y) * size.height))
                context.stroke(
                    path,
                    with: .color(green ? Theme.lockGreen : Theme.ivory.opacity(0.42)),
                    style: StrokeStyle(
                        lineWidth: green ? Theme.skeletonLineLocked : Theme.skeletonLine,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                joints.insert(bone.from)
                joints.insert(bone.to)
            }
            for joint in joints {
                guard let p = frame.imagePoint(joint) else { continue }
                let center = CGPoint(x: CGFloat(p.x) * size.width, y: CGFloat(p.y) * size.height)
                let radius = Theme.skeletonJoint / 2
                let dot = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                context.fill(dot, with: .color(Theme.ivory.opacity(0.9)))
            }
        }
        .allowsHitTesting(false)
    }
}

struct CameraHUD: View {
    var pose: PoseDefinition
    var evaluation: PoseEvaluation
    var score: Float
    var isFront: Bool
    var onClose: () -> Void
    var onSelectFront: (Bool) -> Void
    var onBubble: () -> Void
    /// Nil hors DEBUG : l'appelant ne le fournit pas, et le bouton n'existe pas.
    var onForceLock: (() -> Void)?

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                hudCircleButton("xmark", action: onClose)
                Spacer()
                Button(action: onBubble) {
                    VStack(spacing: 6) {
                        PosePreviewSkeleton(
                            poseID: pose.poseID,
                            highlight: .regions([.leftArm, .rightArm, .shoulders]),
                            lineWidth: 2.2,
                            jointSize: 3.5
                        )
                        .padding(10)
                        .frame(width: 76, height: 76)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        Text(pose.displayName)
                            .font(Theme.bubbleNameFont)
                            .foregroundStyle(Theme.ivory)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(width: 92)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pose.displayName)
                Spacer()
                hudCircleButton("camera.rotate") {
                    onSelectFront(!isFront)
                }
                .accessibilityLabel(isFront ? "Passer à la caméra arrière" : "Passer à la caméra avant")
            }
            .padding(.horizontal, 12)

            if evaluation.gate == .outOfFrame || evaluation.gate == .lowConfidence {
                RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
                    .stroke(Theme.frameRed, lineWidth: 2)
                    .padding(18)
                    .overlay(alignment: .bottom) {
                        Text("Recule. Corps entier.")
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.ivory)
                            .padding(.bottom, 28)
                    }
            }

            Spacer()

            if evaluation.showsScore {
                VStack(spacing: 8) {
                    Text("\(Int(score.rounded()))")
                        .font(Theme.scoreFont)
                        .foregroundStyle(evaluation.isGloballyGreen ? Theme.lockGreen : Theme.ivory)
                    Text(evaluation.worstCue)
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.ivoryMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }

            #if DEBUG
            if let onForceLock {
                DevForceLockButton(action: onForceLock)
                    .padding(.bottom, 12)
            }
            #endif

            Picker("Caméra", selection: Binding(
                get: { isFront },
                set: { onSelectFront($0) }
            )) {
                Text("Arrière").tag(false)
                Text("Avant").tag(true)
            }
            .pickerStyle(.segmented)
            .tint(Theme.gold)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func hudCircleButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.ivory)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
/// Pastille de debug, montrée dans le HUD et aussi dans l'écran de caméra refusée :
/// le simulateur n'a pas de caméra, donc c'est souvent là qu'on atterrit, et c'est
/// justement là qu'un lock forcé sert.
struct DevForceLockButton: View {
    var action: () -> Void

    var body: some View {
        Button("Forcer un lock (dev)", action: action)
            .font(Theme.supportFont)
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Theme.gold.opacity(0.5), lineWidth: 1))
    }
}
#endif

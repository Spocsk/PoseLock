import SwiftUI

struct SkeletonOverlay: View {
    var frame: BodyFrame
    var evaluation: PoseEvaluation

    var body: some View {
        Canvas { context, size in
            guard evaluation.gate != .outOfFrame else { return }
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
                    style: StrokeStyle(lineWidth: green ? 3.4 : 2.0, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

struct CameraHUD: View {
    var pose: PoseDefinition
    var evaluation: PoseEvaluation
    var score: Float
    var onClose: () -> Void
    var onFlip: () -> Void
    var onBubble: () -> Void

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.ivory)
                        .frame(width: 36, height: 36)
                }
                Spacer()
                Button(action: onBubble) {
                    VStack(spacing: 4) {
                        Image(systemName: pose.symbolName)
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(Theme.gold)
                        Text(pose.displayName)
                            .font(Theme.bubbleNameFont)
                            .foregroundStyle(Theme.ivory)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 72, height: 72)
                    .background(.black.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: onFlip) {
                    Image(systemName: "camera.rotate")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Theme.ivory.opacity(0.7))
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if evaluation.gate == .outOfFrame || evaluation.gate == .lowConfidence {
                RoundedRectangle(cornerRadius: 4)
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
                .padding(.bottom, 36)
            } else {
                Spacer().frame(height: 80)
            }
        }
    }
}

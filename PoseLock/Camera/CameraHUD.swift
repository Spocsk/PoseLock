import SwiftUI

struct SkeletonOverlay: View {
    var frame: BodyFrame
    var evaluation: PoseEvaluation
    /// Largeur / hauteur de l'image analysée quand la vue la montre en aspect fill
    /// (aperçu caméra). Nil quand la vue a déjà exactement la taille de l'image.
    var contentAspect: CGFloat? = nil

    var body: some View {
        Canvas { context, size in
            guard !frame.joints2D.isEmpty else { return }
            let map = Self.aspectFillMapping(view: size, contentAspect: contentAspect)
            var joints: Set<Joint> = []
            for bone in Bone.all {
                guard let a = frame.imagePoint(bone.from), let b = frame.imagePoint(bone.to) else { continue }
                if evaluation.missingJoints.contains(bone.from) || evaluation.missingJoints.contains(bone.to) {
                    continue
                }
                let green = evaluation.isGloballyGreen
                    || (SkeletonRenderer.region(for: bone).map { evaluation.greenRegions.contains($0) } ?? false)
                var path = Path()
                path.move(to: map(a))
                path.addLine(to: map(b))
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
                let center = map(p)
                let radius = Theme.skeletonJoint / 2
                let dot = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                context.fill(dot, with: .color(Theme.ivory.opacity(0.9)))
            }
        }
        .allowsHitTesting(false)
    }

    /// Même cadrage que `AVLayerVideoGravity.resizeAspectFill` : l'image remplit la
    /// vue et déborde, centrée. Sans ça les joints proches des bords tombent à
    /// côté du corps.
    static func aspectFillMapping(view: CGSize, contentAspect: CGFloat?) -> (SIMD2<Float>) -> CGPoint {
        guard let contentAspect, contentAspect > 0, view.width > 0, view.height > 0 else {
            return { CGPoint(x: CGFloat($0.x) * view.width, y: CGFloat($0.y) * view.height) }
        }
        let scale = max(view.width / contentAspect, view.height)
        let drawn = CGSize(width: contentAspect * scale, height: scale)
        let origin = CGPoint(x: (view.width - drawn.width) / 2, y: (view.height - drawn.height) / 2)
        return {
            CGPoint(
                x: origin.x + CGFloat($0.x) * drawn.width,
                y: origin.y + CGFloat($0.y) * drawn.height
            )
        }
    }
}

#if DEBUG
/// Photo démo + skeleton dans le même rectangle (aspect fill), pour que
/// les joints Vision 0…1 restent collés à la silhouette.
struct DemoPosePreview: View {
    var image: UIImage
    var frame: BodyFrame
    var evaluation: PoseEvaluation
    var isFront: Bool

    var body: some View {
        GeometryReader { proxy in
            let imageSize = image.size
            let scale = max(
                proxy.size.width / max(imageSize.width, 1),
                proxy.size.height / max(imageSize.height, 1)
            )
            // En selfie, on garde une marge de recul artificielle pour que les
            // mains, la tête et les chevilles restent toutes dans le guide rouge.
            let previewScale = scale * (isFront ? 0.9 : 1)
            let drawn = CGSize(
                width: imageSize.width * previewScale,
                height: imageSize.height * previewScale
            )
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: drawn.width, height: drawn.height)
                SkeletonOverlay(frame: frame, evaluation: evaluation)
                    .frame(width: drawn.width, height: drawn.height)
            }
            .frame(width: drawn.width, height: drawn.height)
            .scaleEffect(x: isFront ? -1 : 1, y: 1)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .clipped()
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
#endif

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
    /// Mesures brutes d'orientation, DEBUG seulement, pour vérifier sur iPhone
    /// que face / profil / dos donnent bien ~0 / ~80 / ~175.
    var debugReadout: String? = nil

    var body: some View {
        ZStack {
            if showsFramingGuide {
                framingGuide
            }

            controls
        }
    }

    private var controls: some View {
        VStack {
            HStack(alignment: .top) {
                hudCircleButton("xmark", action: onClose)
                    .accessibilityLabel("Fermer la caméra")
                Spacer()
                Button(action: onBubble) {
                    VStack(spacing: 6) {
                        PoseReferenceImage(poseID: pose.poseID, variant: .guided)
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

            Spacer()

            if evaluation.showsScore {
                VStack(spacing: 12) {
                    Text("\(Int(score.rounded()))")
                        .font(Theme.scoreFont)
                        .foregroundStyle(evaluation.isGloballyGreen ? Theme.lockGreen : Theme.ivory)
                    Text(evaluation.worstCue)
                        .font(Theme.distanceCueFont)
                        .foregroundStyle(Theme.ivory)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 16)
                }
                .padding(20)
                .background(Theme.background.opacity(0.85), in: RoundedRectangle(cornerRadius: Theme.continuousCorner))
                .padding(.horizontal, Theme.pageInset)
            }

            #if DEBUG
            if let debugReadout, ScreenBank.current == nil, ScreenBank.videoDemoScene == nil {
                Text(debugReadout)
                    .font(Theme.captionFont.monospacedDigit())
                    .foregroundStyle(Theme.gold)
                    .padding(.bottom, 4)
            }
            if let onForceLock, ScreenBank.current == nil, ScreenBank.videoDemoScene == nil {
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

    private var showsFramingGuide: Bool {
        isFront || evaluation.gate == .outOfFrame || evaluation.gate == .lowConfidence
    }

    private var framingGuide: some View {
        RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
            .stroke(Theme.frameRed, lineWidth: 2)
            .padding(18)
            .overlay(alignment: .bottom) {
                if evaluation.gate == .outOfFrame || evaluation.gate == .lowConfidence {
                    Text("Recule. Corps entier.")
                        .font(Theme.distanceCueFont)
                        .foregroundStyle(Theme.ivory)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 98)
                }
            }
            .allowsHitTesting(false)
    }

    private func hudCircleButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(Theme.bodyFont)
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

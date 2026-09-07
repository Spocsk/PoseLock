import SwiftUI

struct PoseCoachStep: Equatable {
    enum Highlight: Equatable {
        case none
        case regions(Set<SkeletonRegion>)
        case allGreen
    }

    var title: String
    var detail: String
    var symbolName: String
    var highlight: Highlight
}

enum PoseCoachCopy {
    static func steps(for poseID: PoseID) -> [PoseCoachStep] {
        let features = TemplateLibrary.features(for: poseID)
        let focus = Array(features.prefix(2))
        let cueText = focus.map(\.cue).joined(separator: " ")
        let regions = Set(focus.map(\.region))
        let hold = ScoringConstants.lockHoldSeconds
        let holdText = hold.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(hold))"
            : String(format: "%.1f", hold).replacingOccurrences(of: ".", with: ",")
        return [
            PoseCoachStep(
                title: "Corps entier",
                detail: "Recule. Chevilles et mains dans l’image.",
                symbolName: "figure.stand",
                highlight: .none
            ),
            PoseCoachStep(
                title: poseID.displayName,
                detail: cueText,
                symbolName: poseID.symbolName,
                highlight: .regions(regions)
            ),
            PoseCoachStep(
                title: "Tiens la ligne",
                detail: "Garde la pose \(holdText) s jusqu’au vert. Score ≥ \(Int(ScoringConstants.lockScore)).",
                symbolName: "checkmark.circle",
                highlight: .allGreen
            )
        ]
    }
}

struct PoseCoachView: View {
    var poseID: PoseID
    var onStart: () -> Void

    @State private var page = 0

    private var steps: [PoseCoachStep] { PoseCoachCopy.steps(for: poseID) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        coachPage(step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut(duration: 0.28), value: page)

                Button(page == steps.count - 1 ? "C’est parti" : "Continuer") {
                    if page < steps.count - 1 {
                        page += 1
                    } else {
                        onStart()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.gold)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Avant de locker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Passer") { onStart() }
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
    }

    private func coachPage(_ step: PoseCoachStep) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            Image(systemName: step.symbolName)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.gold)
                .symbolEffect(.pulse, options: .nonRepeating, value: page)
            PosePreviewSkeleton(poseID: poseID, highlight: step.highlight)
                .frame(height: 280)
                .padding(.horizontal, 32)
                .id(page)
                .transition(.opacity)
            Text(step.title)
                .font(Theme.titleFont)
                .foregroundStyle(Theme.ivory)
                .multilineTextAlignment(.center)
            Text(step.detail)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivoryMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
    }
}

struct PosePreviewSkeleton: View {
    var poseID: PoseID
    var highlight: PoseCoachStep.Highlight = .none
    var lineWidth: CGFloat = Theme.skeletonLine
    var jointSize: CGFloat = Theme.skeletonJoint

    private var frame: BodyFrame { BodyFrame.preview(for: poseID) }

    var body: some View {
        Canvas { context, size in
            var joints: Set<Joint> = []
            for bone in Bone.all {
                guard let a = frame.imagePoint(bone.from), let b = frame.imagePoint(bone.to) else { continue }
                let color = strokeColor(for: bone)
                var path = Path()
                path.move(to: CGPoint(x: CGFloat(a.x) * size.width, y: CGFloat(a.y) * size.height))
                path.addLine(to: CGPoint(x: CGFloat(b.x) * size.width, y: CGFloat(b.y) * size.height))
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                joints.insert(bone.from)
                joints.insert(bone.to)
            }
            for joint in joints {
                guard let p = frame.imagePoint(joint) else { continue }
                let center = CGPoint(x: CGFloat(p.x) * size.width, y: CGFloat(p.y) * size.height)
                let radius = jointSize / 2
                let dot = Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.fill(dot, with: .color(Theme.ivory.opacity(0.9)))
            }
        }
        .accessibilityHidden(true)
    }

    private func strokeColor(for bone: Bone) -> Color {
        switch highlight {
        case .none:
            return Theme.ivory.opacity(0.55)
        case .regions(let regions):
            let lit = regions.contains { $0.bones.contains(bone) }
            return lit ? Theme.gold : Theme.ivory.opacity(0.28)
        case .allGreen:
            return Theme.lockGreen
        }
    }
}

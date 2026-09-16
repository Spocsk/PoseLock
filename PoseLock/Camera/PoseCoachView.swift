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
    var cues: [String] = []
}

enum PoseCoachCopy {
    static func steps(for poseID: PoseID) -> [PoseCoachStep] {
        let setup = setupCues(for: poseID)
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
                detail: setup.cues.joined(separator: " "),
                symbolName: poseID.symbolName,
                highlight: .regions(setup.regions),
                cues: setup.cues
            ),
            PoseCoachStep(
                title: "Tiens la ligne",
                detail: "Garde la pose \(holdText) s jusqu’au vert. Score ≥ \(Int(ScoringConstants.lockScore)).",
                symbolName: "checkmark.circle",
                highlight: .allGreen
            )
        ]
    }

    /// Un cue par groupe de mise en place (buste, bras, tête), pas les deux premières features collées.
    static func setupCues(for poseID: PoseID) -> (cues: [String], regions: Set<SkeletonRegion>) {
        let features = TemplateLibrary.features(for: poseID)
        let groups: [[SkeletonRegion]] = [
            [.torso, .hips],
            [.leftArm],
            [.rightArm],
            [.shoulders],
            [.head],
            [.leftLeg, .rightLeg]
        ]
        var cues: [String] = []
        var regions: Set<SkeletonRegion> = []
        for group in groups {
            guard cues.count < 4 else { break }
            guard let feature = features.first(where: { group.contains($0.region) }) else { continue }
            guard !cues.contains(feature.cue) else { continue }
            cues.append(feature.cue)
            regions.insert(feature.region)
        }
        if cues.count < 3 {
            for feature in features {
                guard cues.count < 4 else { break }
                guard !cues.contains(feature.cue) else { continue }
                cues.append(feature.cue)
                regions.insert(feature.region)
            }
        }
        return (cues, regions)
    }
}

struct PoseCoachView: View {
    var poseID: PoseID
    var onStart: () -> Void

    @State private var page = 0
    @State private var assemble: CGFloat = 0
    @State private var yaw: Float = 0
    @State private var yawAtDragStart: Float?

    private var steps: [PoseCoachStep] { PoseCoachCopy.steps(for: poseID) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        ScrollView {
                            coachPage(step, index: index).padding(.bottom, 36)
                        }
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
                .buttonStyle(PrimaryButtonStyle())
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
            .onChange(of: page) { _, new in
                syncAssemble(for: new)
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
    }

    private func coachPage(_ step: PoseCoachStep, index: Int) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            Image(systemName: step.symbolName)
                .font(Theme.emblemFont)
                .foregroundStyle(Theme.gold)
                .symbolEffect(.pulse, options: .nonRepeating, value: page)
            PosePreviewSkeleton(
                poseID: poseID,
                highlight: step.highlight,
                assemble: index == 0 ? 0 : assemble,
                yaw: index == 0 ? 0 : yaw
            )
            .frame(height: 280)
            .padding(.horizontal, 32)
            .contentShape(Rectangle())
            .modifier(CoachYawModifier(enabled: index > 0, gesture: rotateGesture))
            if index > 0 {
                Text("Glisse pour tourner.")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.ivoryFaint)
            }
            Text(step.title)
                .font(Theme.titleFont)
                .foregroundStyle(Theme.ivory)
                .multilineTextAlignment(.center)
            cueBlock(step)
            Spacer()
        }
    }

    @ViewBuilder
    private func cueBlock(_ step: PoseCoachStep) -> some View {
        if step.cues.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(step.cues.enumerated()), id: \.offset) { index, cue in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.gold)
                            .frame(width: 14, alignment: .trailing)
                        Text(cue)
                            .font(Theme.supportFont)
                            .foregroundStyle(Theme.ivoryMuted)
                    }
                }
            }
            .padding(.horizontal, 28)
        } else {
            Text(step.detail)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivoryMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
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

    private func syncAssemble(for page: Int) {
        if page == 0 {
            assemble = 0
            yaw = 0
            return
        }
        if page == 1 {
            assemble = 0
            withAnimation(.easeInOut(duration: 1.2)) {
                assemble = 1
            }
            return
        }
        assemble = 1
    }
}

private struct CoachYawModifier<G: Gesture>: ViewModifier {
    var enabled: Bool
    var gesture: G

    func body(content: Content) -> some View {
        if enabled {
            content.highPriorityGesture(gesture)
        } else {
            content
        }
    }
}

import SwiftUI

struct PoseCoachStep: Equatable {
    var title: String
    var detail: String
    var symbolName: String
    var referenceVariant: PoseReferenceVariant
    var cues: [String] = []
}

enum PoseCoachCopy {
    static func steps(for poseID: PoseID) -> [PoseCoachStep] {
        let cues = setupCues(for: poseID).map { CueText.localized($0) }
        let holdText = ScoringConstants.lockHoldSeconds
            .formatted(.number.precision(.fractionLength(0...1)))
        return [
            PoseCoachStep(
                title: String(localized: "Corps entier"),
                detail: String(localized: "Recule. Chevilles et mains dans l’image."),
                symbolName: "figure.stand",
                referenceVariant: .plain
            ),
            PoseCoachStep(
                title: poseID.displayName,
                detail: cues.joined(separator: " "),
                symbolName: poseID.symbolName,
                referenceVariant: .guided,
                cues: cues
            ),
            PoseCoachStep(
                title: String(localized: "Tiens la ligne"),
                detail: String(localized: "Garde la pose \(holdText) s jusqu’au vert. Score ≥ \(Int(ScoringConstants.lockScore))."),
                symbolName: "checkmark.circle",
                referenceVariant: .guided
            )
        ]
    }

    /// Un cue par groupe de mise en place (buste, bras, tête), pas les deux premières features collées.
    static func setupCues(for poseID: PoseID) -> [String] {
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
        for group in groups {
            guard cues.count < 4 else { break }
            guard let feature = features.first(where: { group.contains($0.region) }) else { continue }
            guard !cues.contains(feature.cue) else { continue }
            cues.append(feature.cue)
        }
        if cues.count < 3 {
            for feature in features {
                guard cues.count < 4 else { break }
                guard !cues.contains(feature.cue) else { continue }
                cues.append(feature.cue)
            }
        }
        return cues
    }
}

struct PoseCoachView: View {
    var poseID: PoseID
    var onStart: () -> Void
    var initialPage: Int = 0

    @State private var page = 0
    private var steps: [PoseCoachStep] { PoseCoachCopy.steps(for: poseID) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        ScrollView {
                            coachPage(step).padding(.bottom, 36)
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
            .onAppear {
                page = initialPage
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
        .poseLockFeedback()
    }

    private func coachPage(_ step: PoseCoachStep) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            Image(systemName: step.symbolName)
                .font(Theme.emblemFont)
                .foregroundStyle(Theme.gold)
                .symbolEffect(.pulse, options: .nonRepeating, value: page)
            PoseReferenceImage(
                poseID: poseID,
                variant: step.referenceVariant
            )
            .frame(height: 280)
            .padding(.horizontal, 32)
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

}

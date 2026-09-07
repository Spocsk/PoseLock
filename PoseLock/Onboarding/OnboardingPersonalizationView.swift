import SwiftUI

/// Avant-dernière étape : elle ne calcule rien, elle rejoue les choix déjà faits
/// pendant que la bulle monte à 100 %. Le but est de rendre le réglage tangible.
struct OnboardingPersonalizationView: View {
    var goal: TrainingGoal?
    var pack: Pack
    var hapticsEnabled: Bool
    var onContinue: () -> Void

    @State private var percent = 0
    @State private var isDone = false

    /// Le compteur ralentit après 80 % : une montée linéaire fait faux.
    private static let ramp: [(value: Int, pause: Int)] = [
        (8, 240), (17, 170), (26, 160), (34, 150), (45, 190),
        (57, 180), (66, 220), (73, 250), (81, 290), (87, 330),
        (92, 400), (96, 470), (100, 520)
    ]

    private var lines: [(threshold: Int, label: String, value: String)] {
        [
            (17, "Objectif", goal?.displayName ?? "Libre"),
            (45, "Pack", pack.displayName),
            (73, "Pose du jour", pack.defaultPoseID.displayName),
            (92, "Seuil de lock", "\(Int(ScoringConstants.lockScore)) sur 100")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(
                title: isDone ? "Ton plan est prêt." : "On règle PoseLock sur toi.",
                detail: isDone
                    ? "Voilà ce sur quoi PoseLock va te noter dès la première séance."
                    : "Quelques secondes, rien à faire."
            )
            .staggeredAppear(0)

            bubble
                .staggeredAppear(1)
                .padding(.vertical, 28)

            VStack(spacing: 12) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    row(line)
                        .staggeredAppear(2 + index)
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 16)

            // Le seul argument de confiance que PoseLock peut tenir aujourd'hui :
            // ce qu'il ne fait pas. Pas d'avis, pas de compteur d'utilisateurs.
            if percent >= 45 {
                VStack(alignment: .leading, spacing: 10) {
                    trustRow("cpu", "L’analyse tourne sur l’iPhone, avec Vision.")
                    trustRow("wifi.slash", "La vidéo de séance n’en sort jamais.")
                    trustRow("person.crop.circle.badge.xmark", "Aucun compte pour commencer.")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .transition(.opacity)
            }

            if isDone {
                Button("Voir mon plan", action: onContinue)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.top, 28)
        .task { await run() }
    }

    private var bubble: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.gold.opacity(0.16), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 150
                    )
                )

            Circle()
                .stroke(Theme.hairline, lineWidth: 9)

            Circle()
                .trim(from: 0, to: Double(percent) / 100)
                .stroke(
                    LinearGradient(
                        colors: [Theme.goldMuted, Theme.gold],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(percent)")
                    .font(Theme.scoreFont)
                    .foregroundStyle(Theme.ivory)
                    .contentTransition(.numericText())
                    .monospacedDigit()
                Text("%")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ivoryMuted)
            }
        }
        .frame(width: 188, height: 188)
        .accessibilityElement()
        .accessibilityLabel("Personnalisation \(percent) %")
    }

    private func trustRow(_ symbolName: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Theme.gold)
                .frame(width: 20)
            Text(text)
                .font(Theme.supportFont)
                .foregroundStyle(Theme.ivoryMuted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func row(_ line: (threshold: Int, label: String, value: String)) -> some View {
        let isChecked = percent >= line.threshold
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(isChecked ? Color.clear : Theme.ivoryFaint, lineWidth: 1)
                    .frame(width: 20, height: 20)
                if isChecked {
                    Circle()
                        .fill(Theme.gold.opacity(0.14))
                        .frame(width: 20, height: 20)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                }
            }
            Text(line.label)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivoryMuted)
            Spacer(minLength: 8)
            Text(isChecked ? line.value : "…")
                .font(Theme.bodyFont)
                .foregroundStyle(isChecked ? Theme.ivory : Theme.ivoryFaint)
                .lineLimit(1)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isChecked)
    }

    private func run() async {
        for stage in Self.ramp {
            try? await Task.sleep(for: .milliseconds(stage.pause))
            let crossed = lines.contains { $0.threshold > percent && $0.threshold <= stage.value }
            withAnimation(.easeOut(duration: 0.4)) { percent = stage.value }
            if crossed { PoseLockHaptics.selection(enabled: hapticsEnabled) }
        }
        try? await Task.sleep(for: .milliseconds(260))
        PoseLockHaptics.lockClick(enabled: hapticsEnabled)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { isDone = true }
    }
}

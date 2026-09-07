import AVFoundation
import SwiftUI
import UIKit

/// L'ordre vend le résultat avant de demander quoi que ce soit : on questionne,
/// on reformule le problème, on montre ce que ça donne, et seulement là on demande
/// la caméra. Le compte vient après le paywall, jamais avant la valeur.
enum OnboardingStep: Int, CaseIterable, Comparable {
    case splash
    case goal
    case pack
    case pain
    case proof
    case camera
    case recap
    case personalization
    case paywall
    case account

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Étapes couvertes par la barre de progression. Le splash, la personnalisation,
    /// le paywall et le compte portent leur propre mise en page plein écran.
    static let tracked: [OnboardingStep] = [.goal, .pack, .pain, .proof, .camera, .recap]

    var previous: OnboardingStep? {
        switch self {
        // Repasser par la personnalisation rejouerait son décompte pour rien.
        case .paywall: return .recap
        // L'achat est fait : on ne remonte pas dans le tunnel.
        case .account: return nil
        default: return OnboardingStep(rawValue: rawValue - 1)
        }
    }

    var showsChrome: Bool { OnboardingStep.tracked.contains(self) }

    var trackedIndex: Int? {
        OnboardingStep.tracked.firstIndex(of: self).map { $0 + 1 }
    }
}

struct OnboardingFlow: View {
    @Bindable var settings: AppSettings
    @Environment(StoreManager.self) private var store
    @State private var step: OnboardingStep = .splash
    @State private var goingBack = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                if step.showsChrome {
                    OnboardingChrome(step: step, onBack: goBack)
                }
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch step {
            case .splash:
                OnboardingSplashView { advance(to: .goal) }
            case .goal:
                OnboardingGoalView(
                    selected: settings.goal,
                    hapticsEnabled: settings.hapticsEnabled
                ) { goal in
                    settings.goal = goal
                    settings.pack = goal.suggestedPack
                    advance(to: .pack)
                }
            case .pack:
                OnboardingPackView(
                    selected: $settings.pack,
                    suggested: settings.goal?.suggestedPack,
                    hapticsEnabled: settings.hapticsEnabled
                ) {
                    advance(to: .pain)
                }
            case .pain:
                OnboardingPainView(
                    goal: settings.goal,
                    hapticsEnabled: settings.hapticsEnabled
                ) {
                    advance(to: .proof)
                }
            case .proof:
                OnboardingProofView(pack: settings.pack) { advance(to: .camera) }
            case .camera:
                OnboardingCameraView { advance(to: .recap) }
            case .recap:
                OnboardingRecapView(goal: settings.goal, pack: settings.pack) {
                    advance(to: .personalization)
                }
            case .personalization:
                OnboardingPersonalizationView(
                    goal: settings.goal,
                    pack: settings.pack,
                    hapticsEnabled: settings.hapticsEnabled
                ) {
                    advance(to: .paywall)
                }
            case .paywall:
                OnboardingPaywallView(
                    onBack: goBack,
                    onUnavailable: finish,
                    onPurchased: { advance(to: .account) }
                )
            case .account:
                OnboardingAccountView { appleUserID in
                    settings.appleUserID = appleUserID
                    finish()
                }
            }
        }
        .transition(transition)
        .id(step)
    }

    private var transition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: goingBack ? .leading : .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.96)),
            removal: .move(edge: goingBack ? .trailing : .leading)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 1.04))
        )
    }

    private func advance(to next: OnboardingStep) {
        goingBack = next < step
        PoseLockHaptics.selection(enabled: settings.hapticsEnabled)
        withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) { step = next }
    }

    private func goBack() {
        guard let previous = step.previous else { return }
        advance(to: previous)
    }

    /// Sortie du tunnel : c'est le dernier moment où demander les notifications,
    /// pour ne pas empiler l'alerte système sur la feuille Apple.
    private func finish() {
        let renewalDate = store.renewalDate
        Task { await TrialReminder.schedule(before: renewalDate) }
        PoseLockHaptics.lockClick(enabled: settings.hapticsEnabled)
        settings.onboardingDone = true
    }
}

/// Fait entrer chaque bloc d'une slide l'un après l'autre plutôt que d'un seul tenant.
struct StaggeredAppear: ViewModifier {
    var index: Int

    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .onAppear {
                withAnimation(
                    .spring(response: 0.55, dampingFraction: 0.86)
                        .delay(0.06 + Double(index) * 0.09)
                ) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredAppear(_ index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}

struct OnboardingChrome: View {
    var step: OnboardingStep
    var onBack: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ivoryMuted)
                    .frame(width: 32, height: 32)
                    .background(Theme.elevated, in: Circle())
                    .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Étape précédente")

            HStack(spacing: 6) {
                ForEach(OnboardingStep.tracked, id: \.rawValue) { tracked in
                    Capsule()
                        .fill(tracked <= step ? Theme.gold : Theme.ivoryFaint.opacity(0.35))
                        .frame(height: 2)
                }
            }
            .animation(.easeInOut(duration: 0.28), value: step)
            .accessibilityElement()
            .accessibilityLabel("Étape \(step.trackedIndex ?? 1) sur \(OnboardingStep.tracked.count)")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }
}

struct OnboardingGoalView: View {
    var selected: TrainingGoal?
    var hapticsEnabled: Bool
    var onPick: (TrainingGoal) -> Void

    /// Le choix est accusé avant d'avancer : sans cette pause, le tap ressemble à
    /// un champ de formulaire qu'on remplit.
    @State private var picked: TrainingGoal?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Tu prépares quoi ?",
                detail: "Ça décide du pack proposé juste après. Rien n’est figé."
            )
            .staggeredAppear(0)

            VStack(spacing: 10) {
                ForEach(Array(TrainingGoal.allCases.enumerated()), id: \.element.id) { index, goal in
                    Button {
                        confirm(goal)
                    } label: {
                        OnboardingOptionRow(
                            title: goal.displayName,
                            subtitle: goal.subtitle,
                            symbolName: goal.symbolName,
                            isSelected: (picked ?? selected) == goal
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(picked != nil)
                    .staggeredAppear(1 + index)
                }
            }
            .padding(.horizontal, 24)

            if let picked {
                OnboardingAcknowledgement(text: picked.acknowledgement)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
            }

            Spacer()
        }
    }

    private func confirm(_ goal: TrainingGoal) {
        guard picked == nil else { return }
        PoseLockHaptics.selection(enabled: hapticsEnabled)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) { picked = goal }
        Task {
            try? await Task.sleep(for: .milliseconds(620))
            onPick(goal)
        }
    }
}

/// Accusé de réception après un choix : ce que l'app retient, en une ligne.
struct OnboardingAcknowledgement: View {
    var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .frame(width: 18, height: 18)
                .background(Theme.gold.opacity(0.14), in: Circle())
            Text(text)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivoryMuted)
            Spacer(minLength: 0)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct OnboardingPackView: View {
    @Binding var selected: Pack
    var suggested: Pack?
    var hapticsEnabled: Bool
    var onContinue: () -> Void

    @State private var touched = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Quel travail.",
                detail: "Les trois packs restent là. Celui-ci préremplit la pose du jour."
            )
            .staggeredAppear(0)

            VStack(spacing: 10) {
                ForEach(Array(Pack.onboardingCases.enumerated()), id: \.element.id) { index, pack in
                    Button {
                        selected = pack
                        PoseLockHaptics.selection(enabled: hapticsEnabled)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) { touched = true }
                    } label: {
                        OnboardingOptionRow(
                            title: pack.displayName,
                            subtitle: pack.subtitle,
                            symbolName: nil,
                            isSelected: selected == pack,
                            badge: pack == suggested ? "Suggéré" : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .staggeredAppear(1 + index)
                }
            }
            .padding(.horizontal, 24)

            if touched {
                OnboardingAcknowledgement(text: "Pose du jour : \(selected.defaultPoseID.displayName).")
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
            }

            Spacer()

            Button("Continuer", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .staggeredAppear(1 + Pack.onboardingCases.count)
        }
    }
}

/// Pain point : le problème reformulé dans les mots de l'objectif choisi, puis un
/// micro-engagement. Les deux réponses avancent — la question sert à se reconnaître,
/// pas à filtrer.
struct OnboardingPainView: View {
    var goal: TrainingGoal?
    var hapticsEnabled: Bool
    var onContinue: () -> Void

    @State private var answer: Bool?

    /// Sans objectif choisi, le cadrage le plus neutre des trois.
    private var resolved: TrainingGoal { goal ?? .shape }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(title: resolved.painTitle, detail: resolved.painDetail)
                .staggeredAppear(0)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(resolved.painPoints.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Theme.ivoryFaint)
                            .frame(width: 4, height: 4)
                            .padding(.top, 7)
                        Text(point)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.ivoryMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .staggeredAppear(1 + index)
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 12)

            // La pose sans mesure : aucun angle vert, aucun score. C'est le point
            // de départ que l'écran suivant vient contredire.
            PosePreviewSkeleton(poseID: resolved.suggestedPack.defaultPoseID)
                .frame(height: 150)
                .opacity(0.35)
                .padding(.horizontal, 64)
                .accessibilityHidden(true)
                .staggeredAppear(1 + resolved.painPoints.count)

            Spacer(minLength: 12)

            engagement
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .staggeredAppear(2 + resolved.painPoints.count)
        }
    }

    @ViewBuilder
    private var engagement: some View {
        if let answer {
            OnboardingAcknowledgement(
                text: answer
                    ? "On s’en occupe. C’est exactement ce que PoseLock mesure."
                    : "D’accord. Regarde quand même ce que ça donne."
            )
        } else {
            VStack(spacing: 12) {
                Text("Ça te parle ?")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ivory)

                Button("Oui, exactement") { reply(true) }
                    .buttonStyle(PrimaryButtonStyle())

                Button("Pas vraiment") { reply(false) }
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ivoryMuted)
            }
        }
    }

    private func reply(_ value: Bool) {
        guard answer == nil else { return }
        PoseLockHaptics.selection(enabled: hapticsEnabled)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) { answer = value }
        Task {
            try? await Task.sleep(for: .milliseconds(760))
            onContinue()
        }
    }
}

/// Preuve : le comparatif que le journal ouvrira, sur la pose du pack choisi.
/// Étiqueté « Exemple » — ce ne sont pas les chiffres de quelqu'un d'autre.
struct OnboardingProofView: View {
    var pack: Pack
    var onContinue: () -> Void

    private static let beforeScore = 62
    private static let afterScore = 91

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Voilà ce que tu vas voir.",
                detail: "La même pose, un mois d’écart, côte à côte. Le score compare tes angles à la pose cible."
            )
            .staggeredAppear(0)

            Spacer(minLength: 8)

            comparison
                .padding(.horizontal, 24)
                .staggeredAppear(1)

            Text("Vert : l’angle est dans la tolérance. Le lock s’ouvre à \(Int(ScoringConstants.lockScore)) sur 100.")
                .font(Theme.supportFont)
                .foregroundStyle(Theme.ivoryFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .staggeredAppear(2)

            Spacer(minLength: 8)

            Button("Continuer", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .staggeredAppear(3)
        }
    }

    private var comparison: some View {
        VStack(spacing: 0) {
            // Les deux chiffres illustrent la fonction, ils ne sont les résultats
            // de personne. Le dire est plus honnête que de laisser croire.
            Text("Exemple")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.ivoryFaint)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 14)
                .padding(.top, 12)

            HStack(spacing: 0) {
                column(
                    label: "Il y a un mois",
                    score: Self.beforeScore,
                    color: Theme.ivoryMuted,
                    highlight: .none
                )

                column(
                    label: "Aujourd’hui",
                    score: Self.afterScore,
                    color: Theme.lockGreen,
                    highlight: .allGreen
                )
            }
            // En overlay, le trait prend la hauteur des colonnes ; posé dans la
            // pile, c'est lui qui l'imposait.
            .overlay {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: 1)
            }
        }
        .background(Theme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }

    private func column(
        label: String,
        score: Int,
        color: Color,
        highlight: PoseCoachStep.Highlight
    ) -> some View {
        VStack(spacing: 10) {
            Text(label)
                .font(Theme.supportFont)
                .foregroundStyle(Theme.ivoryMuted)

            PosePreviewSkeleton(poseID: pack.defaultPoseID, highlight: highlight)
                .frame(height: 130)

            Text("\(score)")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(.top, 6)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) : \(score) sur 100")
    }
}

/// Étape caméra : elle ne fait qu'obtenir l'autorisation. Le cadrage est expliqué
/// par `PoseCoachView`, juste avant chaque lock.
struct OnboardingCameraView: View {
    var onContinue: () -> Void

    @State private var status = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var requesting = false

    private var isBlocked: Bool { status == .denied || status == .restricted }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    OnboardingHeader(
                        title: "La caméra",
                        detail: "PoseLock lit ta pose image par image et affiche un score en direct. Sans caméra, il n’y a rien à noter.",
                        bottomPadding: 0
                    )
                    .staggeredAppear(0)

                    proof
                        .padding(.horizontal, 24)
                        .staggeredAppear(1)

                    VStack(alignment: .leading, spacing: 12) {
                        privacyRow("cpu", "L’analyse tourne sur l’iPhone, avec Vision.")
                        privacyRow("wifi.slash", "Aucune image n’est envoyée à un serveur.")
                        privacyRow("trash", "Tu effaces le journal quand tu veux.")
                    }
                    .padding(.horizontal, 24)
                    .staggeredAppear(2)

                    if isBlocked {
                        Text("L’accès est refusé dans les Réglages iOS. L’app s’ouvre quand même, mais le lock restera indisponible.")
                            .font(Theme.supportFont)
                            .foregroundStyle(Theme.goldMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 24)
            }

            footer
                .staggeredAppear(3)
        }
    }

    private var proof: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.elevated)
            VStack(spacing: 12) {
                PosePreviewSkeleton(poseID: .frontDoubleBiceps, highlight: .allGreen)
                    .frame(height: 150)
                    .padding(.top, 20)
                HStack(spacing: 8) {
                    Text("\(Int(ScoringConstants.lockScore))")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Theme.lockGreen)
                    Text("lockable")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.ivoryMuted)
                        .textCase(.uppercase)
                        .tracking(1)
                }
                .padding(.bottom, 20)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.lockGreen.opacity(0.28), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    private func privacyRow(_ symbolName: String, _ text: String) -> some View {
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

    private var footer: some View {
        VStack(spacing: 12) {
            Button(primaryTitle) {
                if isBlocked {
                    openSettings()
                } else if status == .authorized {
                    onContinue()
                } else {
                    Task { await request() }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(requesting)

            if status != .authorized {
                Button(isBlocked ? "Continuer sans caméra" : "Plus tard", action: onContinue)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ivoryMuted)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }

    private var primaryTitle: String {
        if isBlocked { return "Ouvrir les Réglages" }
        if status == .authorized { return "Continuer" }
        return "Autoriser la caméra"
    }

    private func request() async {
        requesting = true
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        requesting = false
        status = AVCaptureDevice.authorizationStatus(for: .video)
        if granted { onContinue() }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct OnboardingRecapView: View {
    var goal: TrainingGoal?
    var pack: Pack
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Tout est réglé.",
                detail: "Tu peux changer chaque ligne plus tard, dans Réglages."
            )
            .staggeredAppear(0)

            VStack(spacing: 0) {
                if let goal {
                    recapRow("Objectif", goal.displayName)
                    Divider().overlay(Theme.hairline)
                }
                recapRow("Pack", pack.displayName)
                Divider().overlay(Theme.hairline)
                recapRow("Pose du jour", pack.defaultPoseID.displayName)
                Divider().overlay(Theme.hairline)
                recapRow("Seuil de lock", "\(Int(ScoringConstants.lockScore)) sur 100")
            }
            .background(Theme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .staggeredAppear(1)

            PosePreviewSkeleton(poseID: pack.defaultPoseID)
                .frame(height: 160)
                .padding(.horizontal, 48)
                .padding(.top, 28)
                .staggeredAppear(2)

            Spacer()

            Button("Continuer", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .staggeredAppear(3)
        }
    }

    private func recapRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivoryMuted)
            Spacer()
            Text(value)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivory)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct OnboardingHeader: View {
    var title: String
    var detail: String
    var bottomPadding: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.titleFont)
                .foregroundStyle(Theme.ivory)
            Text(detail)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivoryMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, bottomPadding)
    }
}

struct OnboardingOptionRow: View {
    var title: String
    var subtitle: String
    var symbolName: String?
    var isSelected: Bool
    var badge: String?

    var body: some View {
        HStack(spacing: 14) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(isSelected ? Theme.gold : Theme.ivoryMuted)
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Theme.ivory)
                    if let badge {
                        Text(badge)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.gold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.gold.opacity(0.12), in: Capsule())
                    }
                }
                Text(subtitle)
                    .font(Theme.supportFont)
                    .foregroundStyle(Theme.ivoryMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            ZStack {
                Circle()
                    .stroke(isSelected ? Theme.gold : Theme.ivoryFaint, lineWidth: isSelected ? 1.5 : 1)
                    .frame(width: 18, height: 18)
                if isSelected {
                    Circle().fill(Theme.gold).frame(width: 8, height: 8)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.elevated)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
                .stroke(isSelected ? Theme.gold.opacity(0.6) : Theme.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.gold, in: RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

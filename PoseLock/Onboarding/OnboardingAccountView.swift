import AuthenticationServices
import SwiftUI

/// Dernière étape, après l'achat. Elle reste contournable : l'app ne dépend
/// d'aucun compte, et exiger une connexion sans fonctionnalité liée à un compte
/// est un motif de rejet (règle 5.1.1).
struct OnboardingAccountView: View {
    var onFinish: (String?) -> Void

    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            emblem
                .staggeredAppear(0)

            Text("Ton compte Apple.")
                .font(Theme.titleFont)
                .foregroundStyle(Theme.ivory)
                .padding(.top, 28)
                .staggeredAppear(1)

            Text("Ton compte Apple, pour la suite. L’abonnement, lui, se restaure déjà depuis l’App Store.")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivoryMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .staggeredAppear(2)

            Text("Rien ne part de l’iPhone. L’identifiant reste sur l’appareil.")
                .font(Theme.supportFont)
                .foregroundStyle(Theme.ivoryFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .staggeredAppear(3)

            Spacer(minLength: 24)

            SignInWithAppleButton(.signUp) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    let credential = authorization.credential as? ASAuthorizationAppleIDCredential
                    onFinish(credential?.user)
                case .failure(let error):
                    // Une annulation n'est pas un échec : l'écran reste tel quel.
                    // Le reste (capacité absente du profil, réseau) mérite un mot,
                    // sinon le bouton a l'air simplement mort.
                    failed = (error as? ASAuthorizationError)?.code != .canceled
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
            .staggeredAppear(4)

            if failed {
                Text("Connexion Apple indisponible. Tu peux continuer sans.")
                    .font(Theme.supportFont)
                    .foregroundStyle(Theme.frameRed)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)
            }

            Button("Plus tard") { onFinish(nil) }
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivoryMuted)
                .frame(maxWidth: .infinity, minHeight: Theme.minimumTarget)
                .contentShape(Rectangle())
                .padding(.top, 14)
                .staggeredAppear(5)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }

    private var emblem: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.gold.opacity(0.18), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 90
                    )
                )
                .frame(width: 160, height: 160)
            Image(systemName: "person.crop.circle")
                .font(Theme.emblemFont)
                .foregroundStyle(Theme.gold)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHidden(true)
    }
}

import CoreImage
import SwiftUI
import UIKit

/// Première slide, plein écran et sans chrome : une photo, le wordmark, le CTA.
/// Elle ne pose aucune question, elle donne le ton.
struct OnboardingSplashView: View {
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @State private var revealed = false
    @State private var showAnalyticsChoice = false
    @AppStorage("poselock.analyticsChoiceMade") private var analyticsChoiceMade = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            photo
            vignette
            grain
            scrim
            copy
        }
        .alert("Statistiques facultatives", isPresented: $showAnalyticsChoice) {
            Button("Continuer sans") {
                analyticsChoiceMade = true
                PoseLockAnalytics.setConsent(false)
                onContinue()
            }
            Button("Autoriser") {
                analyticsChoiceMade = true
                PoseLockAnalytics.setConsent(true)
                PoseLockAnalytics.capture(.onboardingStarted)
                onContinue()
            }
        } message: {
            Text("Aide-nous à améliorer PoseLock avec quelques événements d’usage sans compte. Aucune image, vidéo, pose ou score n’est envoyé. Tu pourras changer d’avis dans Réglages.")
        }
    }

    // MARK: - Fond

    /// La photo porte tout le décor — projecteur, sol, sujet. Elle respire très
    /// lentement : sans ce mouvement l'écran d'ouverture a l'air figé.
    private var photo: some View {
        GeometryReader { proxy in
            Image("SplashPose")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(breathing ? 1.06 : 1.01)
                .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .opacity(revealed ? 1 : 0)
        .onAppear {
            #if DEBUG
            if ScreenBank.current != nil { revealed = true; return }
            #endif
            if reduceMotion { revealed = true; return }
            withAnimation(.easeOut(duration: 0.9)) {
                revealed = true
            }
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    /// Referme les angles sur le sujet, que le cadrage soit large ou serré.
    private var vignette: some View {
        RadialGradient(
            stops: [
                .init(color: .clear, location: 0.42),
                .init(color: Theme.background.opacity(0.40), location: 0.80),
                .init(color: Theme.background.opacity(0.80), location: 1)
            ],
            center: .center,
            startRadius: 0,
            endRadius: 560
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Un grain fin : il recolle la photo au reste de l'app et masque le
    /// crénelage du dégradé doré une fois l'image agrandie.
    private var grain: some View {
        Group {
            if let tile = SplashGrain.tile {
                Image(uiImage: tile)
                    .resizable(resizingMode: .tile)
                    .blendMode(.overlay)
                    .opacity(0.05)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Éteint le bas de l'image pour que le wordmark et le CTA restent lisibles.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.40),
                .init(color: Theme.background.opacity(0.55), location: 0.60),
                .init(color: Theme.background.opacity(0.95), location: 0.74),
                .init(color: Theme.background, location: 0.84)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Texte

    private var copy: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text("POSELOCK")
                .font(Theme.wordmarkFont)
                .foregroundStyle(Theme.ivory)
                .tracking(1.5)
                .staggeredAppear(2)

            Text("Pose. Score. Lock.")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.gold)
                .textCase(.uppercase)
                .tracking(1.4)
                .padding(.top, 8)
                .staggeredAppear(3)

            Text("Ta pose notée en direct, sur l’iPhone.\nLa vidéo n’en sort jamais.")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivoryMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .staggeredAppear(4)

            Button("Commencer") {
                if PoseLockAnalytics.isConfigured && !analyticsChoiceMade {
                    showAnalyticsChoice = true
                } else {
                    onContinue()
                }
            }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 32)
                .staggeredAppear(5)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 44)
    }
}

private enum SplashGrain {
    /// Généré une seule fois, puis répété : aucun asset à embarquer.
    static let tile: UIImage? = {
        let extent = CGRect(x: 0, y: 0, width: 180, height: 180)
        guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage else { return nil }
        let grey = noise
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
                kCIInputContrastKey: 0.6
            ])
            .cropped(to: extent)
        guard let cgImage = CIContext().createCGImage(grey, from: extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }()
}

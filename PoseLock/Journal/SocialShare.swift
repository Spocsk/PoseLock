import SwiftUI
import UIKit

/// Raccourcis d’export vers Instagram Stories et le share sheet TikTok.
/// Pas de SDK Meta / TikTok : URL schemes locaux + pasteboard, image déjà stampée.
enum SocialShare {
    static let instagramStoriesURL = URL(string: "instagram-stories://share")!
    static let instagramURL = URL(string: "instagram://app")!
    static let tiktokURL = URL(string: "tiktok://")!
    static let storiesPasteboardKey = "com.instagram.sharedSticker.backgroundImage"

    static func isInstagramAvailable(canOpen: (URL) -> Bool = { UIApplication.shared.canOpenURL($0) }) -> Bool {
        canOpen(instagramStoriesURL) || canOpen(instagramURL)
    }

    static func isTikTokAvailable(canOpen: (URL) -> Bool = { UIApplication.shared.canOpenURL($0) }) -> Bool {
        canOpen(tiktokURL)
    }

    static func storiesPasteboardItems(for image: UIImage) -> [[String: Any]] {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return [] }
        return [[storiesPasteboardKey: data]]
    }

    @discardableResult
    static func openInstagramStories(
        image: UIImage,
        canOpen: (URL) -> Bool = { UIApplication.shared.canOpenURL($0) },
        setPasteboard: ([[String: Any]]) -> Void = { items in
            UIPasteboard.general.setItems(
                items,
                options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
            )
        },
        open: (URL) -> Void = { UIApplication.shared.open($0) }
    ) -> Bool {
        guard isInstagramAvailable(canOpen: canOpen) else { return false }
        let items = storiesPasteboardItems(for: image)
        guard !items.isEmpty else { return false }
        setPasteboard(items)
        open(instagramStoriesURL)
        return true
    }
}

struct ShareDestinationBar: View {
    var image: UIImage
    var title: String

    @State private var missingApp: String?
    @State private var showActivity = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button("Story Instagram") {
                    PoseLockAnalytics.capture(.shareStarted)
                    if SocialShare.openInstagramStories(image: image) {
                        missingApp = nil
                    } else {
                        missingApp = String(localized: "Instagram n’est pas installé.")
                        showActivity = true
                    }
                }
                .buttonStyle(SecondaryShareButtonStyle())

                Button("TikTok") {
                    PoseLockAnalytics.capture(.shareStarted)
                    if SocialShare.isTikTokAvailable() {
                        missingApp = nil
                    } else {
                        missingApp = String(localized: "TikTok n’est pas installé.")
                    }
                    showActivity = true
                }
                .buttonStyle(SecondaryShareButtonStyle())
            }

            ShareLink(
                item: JPEGTransfer(image: image),
                preview: SharePreview(title, image: Image(uiImage: image))
            ) {
                Text("Autre")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .simultaneousGesture(TapGesture().onEnded {
                PoseLockAnalytics.capture(.shareStarted)
            })

            if let missingApp {
                Text(missingApp)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.ivoryMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showActivity) {
            ActivityShareSheet(items: [image])
                .ignoresSafeArea()
                .presentationDetents([.medium, .large])
        }
    }
}

private struct SecondaryShareButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.buttonFont)
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: Theme.minimumTarget)
            .background(
                Theme.elevated,
                in: RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
                    .stroke(Theme.gold.opacity(0.5), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

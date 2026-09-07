import SwiftUI
import UIKit

/// Signature posée sur les images qui quittent l'app : les cartes de partage et la
/// copie envoyée dans Photos. Elle n'est pas écrite dans le fichier gardé par
/// `PhotoStore` — le journal doit rester lisible sans marque, et la carte, qui part
/// de ce fichier, la reposerait une seconde fois par-dessus.
enum ShareMark {
    static let name = "PoseLock"

    /// Corps et marge proportionnels au petit côté, pour que la signature occupe la
    /// même place sur une carte 1080 × 1920 que sur une photo caméra.
    static func fontSize(reference: CGFloat) -> CGFloat { max(11, reference * 0.032) }
    static func inset(reference: CGFloat) -> CGFloat { reference * 0.045 }
    static func shadowRadius(reference: CGFloat) -> CGFloat { max(1, reference * 0.010) }
    static let shadowOpacity = 0.5

    /// Version UIKit, pour la copie déposée dans Photos.
    static func stamped(_ image: UIImage) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let reference = min(size.width, size.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
            let text = name as NSString
            let attributes = textAttributes(reference: reference)
            let measured = text.size(withAttributes: attributes)
            let margin = inset(reference: reference)
            text.draw(
                at: CGPoint(x: size.width - measured.width - margin, y: size.height - measured.height - margin),
                withAttributes: attributes
            )
        }
    }

    private static func textAttributes(reference: CGFloat) -> [NSAttributedString.Key: Any] {
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(shadowOpacity)
        shadow.shadowBlurRadius = shadowRadius(reference: reference)
        shadow.shadowOffset = .zero
        return [
            .font: UIFont.systemFont(ofSize: fontSize(reference: reference), weight: .regular),
            .foregroundColor: UIColor(Theme.gold),
            // Le coin d'une photo peut être un mur blanc de salle, où l'or seul est
            // illisible. Un `strokeWidth` négatif remplit *et* cerne le tracé. La
            // carte n'en a pas besoin, son coin est toujours le fond quasi noir.
            .strokeColor: UIColor.black.withAlphaComponent(0.6),
            .strokeWidth: -2.5,
            .shadow: shadow
        ]
    }
}

/// Version SwiftUI, pour les cartes rendues par `ImageRenderer`. À poser en overlay
/// dans un coin : `reference` est le petit côté de la carte, pas sa hauteur, sinon
/// la marque grossirait avec le format.
struct ShareMarkLabel: View {
    var reference: CGFloat

    var body: some View {
        Text(ShareMark.name)
            .font(.system(size: ShareMark.fontSize(reference: reference), weight: .regular))
            .foregroundStyle(Theme.gold)
            .shadow(color: .black.opacity(ShareMark.shadowOpacity), radius: ShareMark.shadowRadius(reference: reference))
            .padding(ShareMark.inset(reference: reference))
    }
}

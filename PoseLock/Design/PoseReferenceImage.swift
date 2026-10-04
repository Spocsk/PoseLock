import SwiftUI

/// Référence low-poly statique d’une pose. Les overlays mesurés de la caméra et
/// du journal restent dessinés séparément à partir des joints Vision.
struct PoseReferenceImage: View {
    var poseID: PoseID
    var variant: PoseReferenceVariant = .plain

    var body: some View {
        Image(poseID.referenceAssetName(for: variant))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

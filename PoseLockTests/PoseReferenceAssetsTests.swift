import UIKit
import XCTest
@testable import PoseLock

final class PoseReferenceAssetsTests: XCTestCase {
    func testEveryPoseHasBothReferenceVariants() {
        for poseID in PoseID.allCases {
            for variant in PoseReferenceVariant.allCases {
                let assetName = poseID.referenceAssetName(for: variant)
                XCTAssertNotNil(
                    UIImage(named: assetName),
                    "Asset manquant : \(assetName)"
                )
            }
        }
    }
}

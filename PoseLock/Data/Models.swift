import Foundation
import SwiftData

@Model
final class AppSettings {
    var onboardingDone: Bool
    var packRaw: String
    var cameraFront: Bool
    var hapticsEnabled: Bool
    var saveToPhotos: Bool
    var photoQualityHigh: Bool
    var appleUserID: String?

    init(
        onboardingDone: Bool = false,
        pack: Pack = .scene,
        cameraFront: Bool = false,
        hapticsEnabled: Bool = true,
        saveToPhotos: Bool = false,
        photoQualityHigh: Bool = true,
        appleUserID: String? = nil
    ) {
        self.onboardingDone = onboardingDone
        self.packRaw = pack.rawValue
        self.cameraFront = cameraFront
        self.hapticsEnabled = hapticsEnabled
        self.saveToPhotos = saveToPhotos
        self.photoQualityHigh = photoQualityHigh
        self.appleUserID = appleUserID
    }

    var pack: Pack {
        get { Pack(rawValue: packRaw) ?? .scene }
        set { packRaw = newValue.rawValue }
    }
}

@Model
final class LockEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var packRaw: String
    var poseRaw: String
    var score: Float
    var durationToLock: TimeInterval
    var cleanPath: String
    var overlayPath: String
    var templateVersion: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        pack: Pack,
        poseID: PoseID,
        score: Float,
        durationToLock: TimeInterval,
        cleanPath: String,
        overlayPath: String,
        templateVersion: String = ScoringConstants.templateVersion
    ) {
        self.id = id
        self.date = date
        self.packRaw = pack.rawValue
        self.poseRaw = poseID.rawValue
        self.score = score
        self.durationToLock = durationToLock
        self.cleanPath = cleanPath
        self.overlayPath = overlayPath
        self.templateVersion = templateVersion
    }

    var pack: Pack { Pack(rawValue: packRaw) ?? .scene }
    var poseID: PoseID { PoseID(rawValue: poseRaw) ?? .frontPosture }

    var snapshot: LockEntrySnapshot {
        LockEntrySnapshot(date: date, pack: pack, poseID: poseID, score: score)
    }
}

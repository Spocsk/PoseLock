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
    /// Optionnel : les installations d'avant l'étape objectif n'en ont pas.
    var goalRaw: String?
    var competitionDate: Date?
    var competitionPlace: String?
    var competitionRemindersEnabled: Bool = false

    init(
        onboardingDone: Bool = false,
        pack: Pack = .scene,
        cameraFront: Bool = false,
        hapticsEnabled: Bool = true,
        saveToPhotos: Bool = false,
        photoQualityHigh: Bool = true,
        appleUserID: String? = nil,
        goal: TrainingGoal? = nil,
        competitionDate: Date? = nil,
        competitionPlace: String? = nil,
        competitionRemindersEnabled: Bool = false
    ) {
        self.onboardingDone = onboardingDone
        self.packRaw = pack.rawValue
        self.cameraFront = cameraFront
        self.hapticsEnabled = hapticsEnabled
        self.saveToPhotos = saveToPhotos
        self.photoQualityHigh = photoQualityHigh
        self.appleUserID = appleUserID
        self.goalRaw = goal?.rawValue
        self.competitionDate = competitionDate
        self.competitionPlace = competitionPlace
        self.competitionRemindersEnabled = competitionRemindersEnabled
    }

    var pack: Pack {
        get { Pack(rawValue: packRaw) ?? .scene }
        set { packRaw = newValue.rawValue }
    }

    var goal: TrainingGoal? {
        get { goalRaw.flatMap(TrainingGoal.init(rawValue:)) }
        set { goalRaw = newValue?.rawValue }
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
    /// Optionnel : les prises d’avant l’ajout du récap n’ont pas de skeleton.
    var skeletonData: Data?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        pack: Pack,
        poseID: PoseID,
        score: Float,
        durationToLock: TimeInterval,
        cleanPath: String,
        overlayPath: String,
        templateVersion: String = ScoringConstants.templateVersion,
        skeletonData: Data? = nil
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
        self.skeletonData = skeletonData
    }

    var pack: Pack { Pack(rawValue: packRaw) ?? .scene }
    var poseID: PoseID { PoseID(rawValue: poseRaw) ?? .frontPosture }

    var skeleton: SkeletonSnapshot? {
        guard let skeletonData else { return nil }
        return try? JSONDecoder().decode(SkeletonSnapshot.self, from: skeletonData)
    }

    var snapshot: LockEntrySnapshot {
        LockEntrySnapshot(date: date, pack: pack, poseID: poseID, score: score)
    }
}

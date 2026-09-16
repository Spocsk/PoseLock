import simd
import UIKit
import XCTest
@testable import PoseLock

final class ScoringEngineTests: XCTestCase {
    func testBackPreviewTurnsTheWholeBodyAwayFromCamera() {
        for pose in [PoseID.quarterTurnBack, .backDoubleBiceps, .backLatSpread] {
            let joints = BodyFrame.preview(for: pose).joints3D
            XCTAssertLessThan(joints[.rightShoulder]!.x, joints[.leftShoulder]!.x)
            XCTAssertLessThan(joints[.rightHip]!.x, joints[.leftHip]!.x)
        }
    }

    func testProfilePreviewHasSidewaysPelvis() {
        let joints = BodyFrame.preview(for: .profilePosture).joints3D
        let hips = joints[.rightHip]! - joints[.leftHip]!
        XCTAssertGreaterThan(abs(hips.z), abs(hips.x) * 4)
    }

    func testBodyYawMeasuresCameraOrientationWithoutInventingATorsoTwist() {
        let cases: [(PoseID, Float)] = [
            (.quarterTurnFace, 0),
            (.profilePosture, 88),
            (.quarterTurnBack, 178)
        ]
        for (pose, expectedYaw) in cases {
            let frame = BodyFrame.preview(for: pose)
            XCTAssertEqual(ScoringEngine.extract(.bodyYaw, from: frame)!, expectedYaw, accuracy: 1, pose.rawValue)
            XCTAssertEqual(ScoringEngine.extract(.torsoTwist, from: frame)!, 0, accuracy: 1, pose.rawValue)
        }
    }

    func testTwistPoseSeparatesHipOrientationFromShoulderRotation() {
        let frame = BodyFrame.preview(for: .twistThreeQuarter)
        XCTAssertEqual(ScoringEngine.extract(.bodyYaw, from: frame)!, 12, accuracy: 1)
        XCTAssertEqual(ScoringEngine.extract(.torsoTwist, from: frame)!, 42, accuracy: 1)
    }

    func testEveryPreviewMatchesItsOrientationTargets() {
        for pose in PoseID.allCases {
            let frame = BodyFrame.preview(for: pose)
            let targets = TemplateLibrary.features(for: pose)
            for feature in [PoseFeature.bodyYaw, .torsoTwist] {
                guard let target = targets.first(where: { $0.feature == feature }) else { continue }
                XCTAssertEqual(
                    ScoringEngine.extract(feature, from: frame)!,
                    target.target,
                    accuracy: 1,
                    "\(pose.rawValue) / \(feature.rawValue)"
                )
            }
        }
    }

    func testContactPosesKeepHandsTogether() {
        for pose in [PoseID.sideChest, .sideChestMirror, .sideTriceps, .mostMuscular, .mostMuscularCrop] {
            let joints = BodyFrame.preview(for: pose).joints3D
            let hands = simd_distance(joints[.leftWrist]!, joints[.rightWrist]!)
            let shoulders = simd_distance(joints[.leftShoulder]!, joints[.rightShoulder]!)
            XCTAssertLessThan(hands, shoulders * 0.3, pose.rawValue)
        }
    }

    func testAbsAndThighKeepsBothHandsBehindTheHead() {
        let joints = BodyFrame.preview(for: .absAndThigh).joints3D
        for wrist in [Joint.leftWrist, .rightWrist] {
            XCTAssertGreaterThan(joints[wrist]!.y, joints[.neck]!.y)
            XCTAssertLessThan(joints[wrist]!.y, joints[.head]!.y)
            XCTAssertLessThan(abs(joints[wrist]!.x - joints[.neck]!.x), 0.10)
        }
        XCTAssertGreaterThan(abs(joints[.leftElbow]!.x - joints[.rightElbow]!.x), 0.50)
    }

    func testMandatoryPosePreviewsShowTheStaggeredLeg() {
        for pose in [PoseID.frontDoubleBiceps, .sideChest, .backDoubleBiceps, .backLatSpread, .sideTriceps, .absAndThigh] {
            let joints = BodyFrame.preview(for: pose).joints3D
            XCTAssertGreaterThan(
                simd_distance(joints[.leftAnkle]!, joints[.rightAnkle]!),
                0.16,
                pose.rawValue
            )
        }
    }

    func testNormalizationPutsRootAtOriginAndUnitScale() {
        var joints: [Joint: SIMD3<Float>] = [
            .root: SIMD3(10, 20, 30),
            .leftHip: SIMD3(9, 20, 30),
            .rightHip: SIMD3(11, 20, 30),
            .head: SIMD3(10, 40, 30),
            .leftShoulder: SIMD3(8, 32, 30),
            .rightShoulder: SIMD3(12, 32, 30)
        ]
        let normalized = ScoringEngine.normalize(joints: joints)
        let root = normalized[.root]!
        XCTAssertEqual(root.x, 0, accuracy: 0.001)
        XCTAssertEqual(root.y, 0, accuracy: 0.001)
        XCTAssertEqual(root.z, 0, accuracy: 0.001)
        let head = normalized[.head]!
        XCTAssertEqual(simd_length(head), 1, accuracy: 0.05)
    }

    func testAngleAtRightAngleIs90() {
        let a = SIMD3<Float>(0, 1, 0)
        let b = SIMD3<Float>(0, 0, 0)
        let c = SIMD3<Float>(1, 0, 0)
        XCTAssertEqual(ScoringEngine.angleDegrees(a, b, c), 90, accuracy: 0.1)
    }

    func testOutOfFrameWhenSubjectTooSmall() {
        let frame = BodyFrame(
            joints3D: [:],
            joints2D: [.head: SIMD2(0.5, 0.4), .leftAnkle: SIMD2(0.5, 0.5)],
            confidence: 0.9,
            subjectHeightRatio: 0.1,
            handsVisible: true,
            feetVisible: true
        )
        let (gate, _) = ScoringEngine.gate(frame)
        XCTAssertEqual(gate, .outOfFrame)
    }

    func testFrontPostureGoldScoresHigh() {
        let frame = BodyFrame.standingPreview()
        let template = TemplateLibrary.template(for: .frontPosture)
        let evaluation = ScoringEngine.evaluate(frame: frame, template: template)
        XCTAssertEqual(evaluation.gate, .ok)
        XCTAssertGreaterThan(evaluation.rawScore, 70)
        XCTAssertFalse(evaluation.worstCue.isEmpty)
    }

    func testSmootherConvergesTowardNewValue() {
        let a = ScoringEngine.smooth(previous: nil, new: 50)
        XCTAssertEqual(a, 50, accuracy: 0.01)
        var value: Float = 50
        for _ in 0..<40 {
            value = ScoringEngine.smooth(previous: value, new: 90)
        }
        XCTAssertGreaterThan(value, 85)
    }

    func testEveryPoseHasATemplate() {
        for pose in PoseID.allCases {
            let features = TemplateLibrary.features(for: pose)
            XCTAssertFalse(features.isEmpty, pose.rawValue)
            XCTAssertEqual(pose.pack, PoseCatalog.definition(for: pose).pack)
        }
    }

    func testCatalogCounts() {
        XCTAssertEqual(PoseCatalog.poses(for: .scene).count, 11)
        XCTAssertEqual(PoseCatalog.poses(for: .content).count, 6)
        XCTAssertEqual(PoseCatalog.poses(for: .physique).count, 6)
        XCTAssertEqual(PoseCatalog.poses(for: .zyzz).count, 3)
        XCTAssertFalse(Pack.onboardingCases.contains(.zyzz))
        XCTAssertEqual(Pack.onboardingCases.count, 3)
    }

    func testEveryPoseHasThreeCoachSteps() {
        for pose in PoseID.allCases {
            let steps = PoseCoachCopy.steps(for: pose)
            XCTAssertEqual(steps.count, 3, pose.rawValue)
            XCTAssertFalse(steps[1].detail.isEmpty, pose.rawValue)
            let setup = PoseCoachCopy.setupCues(for: pose)
            XCTAssertFalse(setup.cues.isEmpty, pose.rawValue)
        }
        let zyzz = PoseCoachCopy.setupCues(for: .zyzzClassic)
        XCTAssertGreaterThanOrEqual(zyzz.cues.count, 3)
        XCTAssertEqual(Set(zyzz.cues).count, zyzz.cues.count, "cues Zyzz dupliqués")
    }

    func testZyzzClassicRaisesBothHandsAboveTheHead() {
        let frame = BodyFrame.preview(for: .zyzzClassic)
        let joints = frame.joints3D
        for wrist in [Joint.leftWrist, .rightWrist] {
            XCTAssertGreaterThan(joints[wrist]!.y, joints[.head]!.y)
            XCTAssertLessThan(frame.joints2D[wrist]!.y, frame.joints2D[.head]!.y)
        }
        XCTAssertGreaterThan(joints[.leftWrist]!.y, joints[.rightWrist]!.y)
    }

    func testZyzzClassicHasOneExtendedArmAndOneFlexedArm() {
        let joints = BodyFrame.preview(for: .zyzzClassic).joints3D
        func elbowAngle(_ shoulder: Joint, _ elbow: Joint, _ wrist: Joint) -> Float {
            let upper = simd_normalize(joints[shoulder]! - joints[elbow]!)
            let lower = simd_normalize(joints[wrist]! - joints[elbow]!)
            return acos(min(1, max(-1, simd_dot(upper, lower)))) * 180 / .pi
        }
        XCTAssertEqual(elbowAngle(.leftShoulder, .leftElbow, .leftWrist), 165, accuracy: 1)
        XCTAssertEqual(elbowAngle(.rightShoulder, .rightElbow, .rightWrist), 75, accuracy: 1)
    }

    /// Le lock forcé de debug injecte cette frame. Elle doit passer la porte de
    /// cadrage, sinon le HUD réclamerait « Recule » au moment même du lock.
    /// Son score, lui, ne suffit pas : reconstruite depuis les cibles, elle ne
    /// repasse pas la mesure pour les poses tournées, d'où l'estampille côté debug.
    func testPreviewFrameOfEveryPosePassesTheFrameGate() {
        for pose in PoseID.allCases {
            let (gate, missing) = ScoringEngine.gate(BodyFrame.preview(for: pose))
            XCTAssertEqual(gate, .ok, pose.rawValue)
            XCTAssertTrue(missing.isEmpty, pose.rawValue)
        }
    }

    func testPreviewFramesHaveAllJointsAndDistinctPoses() {
        for pose in PoseID.allCases {
            let frame = BodyFrame.preview(for: pose)
            for joint in Joint.allCases {
                XCTAssertNotNil(frame.joints3D[joint], "\(pose.rawValue) missing \(joint.rawValue)")
                XCTAssertNotNil(frame.joints2D[joint], "\(pose.rawValue) 2D missing \(joint.rawValue)")
            }
            XCTAssertTrue(frame.handsVisible)
            XCTAssertTrue(frame.feetVisible)
        }

        let biceps = BodyFrame.preview(for: .frontDoubleBiceps)
        let lat = BodyFrame.preview(for: .frontLatSpread)
        let stand = BodyFrame.preview(for: .frontPosture)

        let bicepsWrist = biceps.joints3D[.leftWrist]!
        let bicepsShoulder = biceps.joints3D[.leftShoulder]!
        let bicepsElbow = biceps.joints3D[.leftElbow]!
        XCTAssertGreaterThan(bicepsWrist.y, bicepsShoulder.y - 0.05, "FDB: poignet trop bas")
        XCTAssertGreaterThan(bicepsElbow.y, stand.joints3D[.leftElbow]!.y + 0.15, "FDB: coude trop bas")

        let latWrist = lat.joints3D[.leftWrist]!
        let latHip = lat.joints3D[.leftHip]!
        XCTAssertLessThan(abs(latWrist.y - latHip.y), 0.45, "Lat spread: mains trop loin des hanches")
        XCTAssertLessThan(latWrist.y, bicepsWrist.y - 0.12, "Lat spread vs biceps: poignets pas distincts")

        let biceps2D = biceps.joints2D[.leftWrist]!
        let stand2D = stand.joints2D[.leftWrist]!
        XCTAssertLessThan(biceps2D.y, stand2D.y - 0.08, "2D: biceps doit monter les poignets")
    }
}

#if DEBUG
/// Le lock forcé n'existe qu'en debug, mais l'owner s'en sert pour traverser le
/// journal. Ce test tient sa promesse : sans caméra, il doit tout de même produire
/// ce que `persistLock` exige — un score lockable, une image, un squelette.
@MainActor
final class DebugForceLockTests: XCTestCase {
    func testForcedLockProducesEverythingTheJournalNeeds() async throws {
        let model = CameraViewModel()
        model.poseID = .backLatSpread // La pose dont la silhouette note 0 : cas le pire.

        await model.debugForceLock()

        XCTAssertTrue(model.didLock)
        XCTAssertGreaterThan(model.lastScore, ScoringConstants.lockScore)
        XCTAssertTrue(model.evaluation.isGloballyGreen)
        // Sans flux caméra le fond de substitution prend le relais, sinon
        // `persistLock` abandonnerait et rien n'atteindrait le journal.
        XCTAssertNotNil(model.lastClean)
        XCTAssertNotNil(model.lastOverlay)
        let skeleton = try XCTUnwrap(model.lastSkeleton)
        XCTAssertEqual(skeleton.joints.count, Joint.allCases.count)
    }

    func testForcedLockIsIgnoredOnceLocked() async {
        let model = CameraViewModel()
        await model.debugForceLock()
        let first = model.lastScore
        await model.debugForceLock()
        XCTAssertEqual(model.lastScore, first)
    }
}
#endif

final class DailyPoseSelectorTests: XCTestCase {
    func testDefaultsWhenNoHistory() {
        XCTAssertEqual(DailyPoseSelector.poseOfTheDay(pack: .scene, entries: []), .frontDoubleBiceps)
        XCTAssertEqual(DailyPoseSelector.poseOfTheDay(pack: .content, entries: []), .threeQuarterLat)
        XCTAssertEqual(DailyPoseSelector.poseOfTheDay(pack: .physique, entries: []), .frontPosture)
    }

    func testPicksLowestSevenDayAverage() {
        let now = Date()
        let entries = [
            LockEntrySnapshot(date: now, pack: .scene, poseID: .frontDoubleBiceps, score: 90),
            LockEntrySnapshot(date: now, pack: .scene, poseID: .sideChest, score: 40),
            LockEntrySnapshot(date: now, pack: .scene, poseID: .sideChest, score: 50)
        ]
        XCTAssertEqual(DailyPoseSelector.poseOfTheDay(pack: .scene, entries: entries, now: now), .sideChest)
    }

    func testIgnoresOtherPacks() {
        let now = Date()
        let entries = [
            LockEntrySnapshot(date: now, pack: .content, poseID: .vacuum, score: 10)
        ]
        XCTAssertEqual(DailyPoseSelector.poseOfTheDay(pack: .scene, entries: entries, now: now), .frontDoubleBiceps)
    }
}

final class LockQuotaTests: XCTestCase {
    func testFreeCapAtThree() {
        let now = Date()
        let entries = (0..<3).map { _ in
            LockEntrySnapshot(date: now, pack: .scene, poseID: .frontPosture, score: 88)
        }
        XCTAssertFalse(LockQuota.canLock(entries: entries, isPro: false, now: now))
        XCTAssertTrue(LockQuota.canLock(entries: entries, isPro: true, now: now))
        XCTAssertEqual(LockQuota.remainingFreeLocks(entries: entries, isPro: false, now: now), 0)
    }

    func testResetsNextCalendarDay() {
        let calendar = Calendar(identifier: .gregorian)
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let entries = (0..<3).map { _ in
            LockEntrySnapshot(date: yesterday, pack: .scene, poseID: .frontPosture, score: 88)
        }
        XCTAssertTrue(LockQuota.canLock(entries: entries, isPro: false, now: today))
        XCTAssertEqual(LockQuota.locks(in: entries, on: today), 0)
    }

    func testStreakCountsConsecutiveDays() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let entries: [LockEntrySnapshot] = (0..<3).map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            return LockEntrySnapshot(date: day, pack: .physique, poseID: .frontPosture, score: 80)
        }
        XCTAssertEqual(JournalStats.streak(entries: entries, now: today, calendar: calendar), 3)
    }
}

final class ShareMarkTests: XCTestCase {
    /// La signature doit atterrir dans le coin bas-droit et nulle part ailleurs :
    /// c'est ce coin qui reste vide sur la carte et sur une photo de pose.
    func testStampLandsInTheBottomTrailingCornerOnly() throws {
        let size = CGSize(width: 400, height: 600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let black = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        let marked = ShareMark.stamped(black)

        XCTAssertEqual(marked.size, black.size)
        XCTAssertTrue(
            try hasInk(marked, in: CGRect(x: 200, y: 300, width: 200, height: 300)),
            "rien n'a été dessiné dans le coin bas-droit"
        )
        XCTAssertFalse(
            try hasInk(marked, in: CGRect(x: 0, y: 0, width: 200, height: 300)),
            "le coin haut-gauche devait rester intact"
        )
    }

    func testStampLeavesADegenerateImageAlone() {
        let empty = UIImage()
        XCTAssertEqual(ShareMark.stamped(empty).size, .zero)
    }

    /// Vrai dès qu'un pixel de la zone n'est plus noir.
    private func hasInk(_ image: UIImage, in rect: CGRect) throws -> Bool {
        let cg = try XCTUnwrap(image.cgImage)
        let width = cg.width
        let height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        try XCTUnwrap(context).draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        for y in Int(rect.minY)..<min(Int(rect.maxY), height) {
            for x in Int(rect.minX)..<min(Int(rect.maxX), width) {
                let offset = (y * width + x) * 4
                if pixels[offset] > 40 || pixels[offset + 1] > 40 || pixels[offset + 2] > 40 {
                    return true
                }
            }
        }
        return false
    }
}

final class SkeletonSnapshotTests: XCTestCase {
    func testEncodeDecodeRoundTrip() throws {
        let frame = BodyFrame.preview(for: .frontDoubleBiceps)
        let evaluation = PoseEvaluation(
            gate: .ok,
            rawScore: 82,
            greenRegions: [.leftArm, .torso],
            missingJoints: [],
            worstCue: "",
            features: []
        )
        let snapshot = SkeletonSnapshot(frame: frame, evaluation: evaluation)
        XCTAssertFalse(snapshot.joints.isEmpty)

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SkeletonSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(Set(decoded.greenRegions), [.leftArm, .torso])

        let restored = decoded.joints3D
        for (joint, position) in frame.joints3D {
            let p = try XCTUnwrap(restored[joint])
            XCTAssertEqual(simd_length(p - position), 0, accuracy: 0.0001)
        }
    }
}

final class PoseRecapTests: XCTestCase {
    func testKeepsBestTakePerPose() throws {
        let now = Date()
        let best = now.addingTimeInterval(-60)
        let entries = [
            LockEntrySnapshot(date: now, pack: .scene, poseID: .sideChest, score: 61),
            LockEntrySnapshot(date: best, pack: .scene, poseID: .sideChest, score: 93),
            LockEntrySnapshot(date: now, pack: .scene, poseID: .frontDoubleBiceps, score: 70)
        ]
        let recaps = JournalStats.poseRecaps(entries: entries)
        XCTAssertEqual(recaps.count, 2)

        let sideChest = try XCTUnwrap(recaps.first { $0.poseID == .sideChest })
        XCTAssertEqual(sideChest.bestScore, 93)
        XCTAssertEqual(sideChest.bestDate, best)
        XCTAssertEqual(sideChest.takeCount, 2)
        XCTAssertEqual(sideChest.averageScore, 77, accuracy: 0.01)
    }

    func testSortsByBestScoreDescending() {
        let now = Date()
        let entries = [
            LockEntrySnapshot(date: now, pack: .scene, poseID: .sideChest, score: 40),
            LockEntrySnapshot(date: now, pack: .scene, poseID: .frontDoubleBiceps, score: 88)
        ]
        XCTAssertEqual(JournalStats.poseRecaps(entries: entries).map(\.poseID), [.frontDoubleBiceps, .sideChest])
    }

    func testIgnoresPosesWithoutTakes() {
        XCTAssertTrue(JournalStats.poseRecaps(entries: []).isEmpty)
    }

    func testDailyBestsKeepsBestScorePerDay() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let entries = [
            LockEntrySnapshot(date: today.addingTimeInterval(60), pack: .scene, poseID: .frontDoubleBiceps, score: 70),
            LockEntrySnapshot(date: today.addingTimeInterval(120), pack: .scene, poseID: .frontDoubleBiceps, score: 91),
            LockEntrySnapshot(date: yesterday, pack: .scene, poseID: .frontDoubleBiceps, score: 80),
            LockEntrySnapshot(date: today, pack: .scene, poseID: .sideChest, score: 99)
        ]
        let points = JournalStats.dailyBests(
            poseID: .frontDoubleBiceps,
            entries: entries,
            from: yesterday,
            to: today,
            calendar: calendar
        )
        XCTAssertEqual(points.map(\.score), [80, 91])
        XCTAssertEqual(points.map { calendar.startOfDay(for: $0.day) }, [yesterday, today])
    }

    func testDailyBestsIgnoresOutsideWindow() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let old = calendar.date(byAdding: .day, value: -20, to: today)!
        let entries = [
            LockEntrySnapshot(date: old, pack: .scene, poseID: .frontDoubleBiceps, score: 88),
            LockEntrySnapshot(date: today, pack: .scene, poseID: .frontDoubleBiceps, score: 60)
        ]
        let points = JournalStats.dailyBests(
            poseID: .frontDoubleBiceps,
            entries: entries,
            from: calendar.date(byAdding: .day, value: -13, to: today)!,
            to: today,
            calendar: calendar
        )
        XCTAssertEqual(points.map(\.score), [60])
    }
}

final class CompetitionDeadlineTests: XCTestCase {
    func testSkipsOffsetsAlreadyPassed() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 10))!
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14))!
        let deadline = CompetitionDeadline(date: date, place: nil)
        XCTAssertEqual(deadline.daysRemaining(now: now, calendar: calendar), 4)
        XCTAssertEqual(deadline.upcomingOffsets(now: now, calendar: calendar), [3, 1])
    }

    func testNotificationCopyUsesLockState() {
        let locked = CompetitionDeadline.notificationCopy(
            daysRemaining: 7,
            pose: .frontDoubleBiceps,
            place: "Lyon",
            hasLock: true
        )
        XCTAssertEqual(locked.title, "Il reste 7 jours")
        XCTAssertTrue(locked.body.contains("Front double biceps"))
        XCTAssertTrue(locked.body.contains("Lyon"))
        XCTAssertTrue(locked.body.contains("pas encore locké"))

        let fresh = CompetitionDeadline.notificationCopy(
            daysRemaining: 1,
            pose: .zyzzClassic,
            place: nil,
            hasLock: false
        )
        XCTAssertEqual(fresh.title, "Il reste 1 jour")
        XCTAssertTrue(fresh.body.contains("pas encore de lock"))
        XCTAssertFalse(fresh.body.contains(" · "))
    }
}

final class SharedProjectionTests: XCTestCase {
    func testSharedFrameKeepsBothRootsClose() throws {
        let reference = BodyFrame.preview(for: .frontDoubleBiceps).joints3D
        // Le capturé décalé et pivoté : ce qu'on obtiendrait d'un sujet mal placé.
        let captured = reference.mapValues { p in
            PosePreviewBuilder.rotateY(p, degrees: 35) + SIMD3<Float>(0.4, 0, 0)
        }
        let normalized = ScoringEngine.normalize(joints: captured)
        let aligned = PosePreviewBuilder.alignYawToHips(normalized, like: reference)

        let sets = PosePreviewBuilder.projectFitted([reference, aligned])
        XCTAssertEqual(sets.count, 2)
        let a = try XCTUnwrap(sets[0][.root])
        let b = try XCTUnwrap(sets[1][.root])
        XCTAssertEqual(simd_length(a - b), 0, accuracy: 0.03)
    }

    func testSeparateFramesWouldNotShareScale() throws {
        let reference = BodyFrame.preview(for: .sideChest).joints3D
        // Deux fois plus grand : un cadre partagé doit conserver l'écart.
        let scaled = reference.mapValues { $0 * 2 }
        let sets = PosePreviewBuilder.projectFitted([reference, scaled])
        let refHead = try XCTUnwrap(sets[0][.head])
        let scaledHead = try XCTUnwrap(sets[1][.head])
        XCTAssertGreaterThan(simd_length(refHead - scaledHead), 0.05)

        let alone = PosePreviewBuilder.projectFitted(reference)
        let scaledAlone = PosePreviewBuilder.projectFitted(scaled)
        let aloneHead = try XCTUnwrap(alone[.head])
        let scaledAloneHead = try XCTUnwrap(scaledAlone[.head])
        XCTAssertEqual(simd_length(aloneHead - scaledAloneHead), 0, accuracy: 0.01)
    }

    func testYawAppliesToEverySet() throws {
        let reference = BodyFrame.preview(for: .frontPosture).joints3D
        let straight = PosePreviewBuilder.projectFitted([reference, reference])
        let turned = PosePreviewBuilder.projectFitted([reference, reference], yaw: 60)
        XCTAssertEqual(turned[0], turned[1])
        let a = try XCTUnwrap(straight[0][.leftWrist])
        let b = try XCTUnwrap(turned[0][.leftWrist])
        XCTAssertGreaterThan(simd_length(a - b), 0.01)
    }
}

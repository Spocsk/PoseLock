import simd
import XCTest
@testable import PoseLock

final class ScoringEngineTests: XCTestCase {
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
        let frame = Self.standingFrame()
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
    }

    static func standingFrame() -> BodyFrame {
        let joints: [Joint: SIMD3<Float>] = [
            .root: SIMD3(0, 0, 0),
            .spine: SIMD3(0, 0.4, 0),
            .neck: SIMD3(0, 0.75, 0),
            .head: SIMD3(0, 1.0, 0),
            .leftShoulder: SIMD3(-0.22, 0.72, 0),
            .rightShoulder: SIMD3(0.22, 0.72, 0),
            .leftElbow: SIMD3(-0.24, 0.4, 0),
            .rightElbow: SIMD3(0.24, 0.4, 0),
            .leftWrist: SIMD3(-0.25, 0.08, 0),
            .rightWrist: SIMD3(0.25, 0.08, 0),
            .leftHip: SIMD3(-0.12, 0, 0),
            .rightHip: SIMD3(0.12, 0, 0),
            .leftKnee: SIMD3(-0.12, -0.45, 0),
            .rightKnee: SIMD3(0.12, -0.45, 0),
            .leftAnkle: SIMD3(-0.12, -0.9, 0),
            .rightAnkle: SIMD3(0.12, -0.9, 0)
        ]
        let normalized = ScoringEngine.normalize(joints: joints)
        var joints2D: [Joint: SIMD2<Float>] = [:]
        for (joint, p) in normalized {
            joints2D[joint] = SIMD2(p.x * 0.25 + 0.5, 0.15 + (1 - (p.y + 1) / 2) * 0.7)
        }
        return BodyFrame(
            joints3D: normalized,
            joints2D: joints2D,
            confidence: 0.9,
            subjectHeightRatio: 0.7,
            handsVisible: true,
            feetVisible: true
        )
    }
}

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

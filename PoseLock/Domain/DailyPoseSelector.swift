import Foundation

enum DailyPoseSelector {
    /// 1. Pack actif. 2. Plus bas score moyen 7 jours. 3. Sinon défaut du pack.
    static func poseOfTheDay(
        pack: Pack,
        entries: [LockEntrySnapshot],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PoseID {
        let poses = PoseCatalog.poses(for: pack).map(\.poseID)
        let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let recent = entries.filter { $0.pack == pack && $0.date >= start && $0.date <= now }

        var averages: [PoseID: (sum: Double, count: Int)] = [:]
        for entry in recent {
            var bucket = averages[entry.poseID, default: (0, 0)]
            bucket.sum += Double(entry.score)
            bucket.count += 1
            averages[entry.poseID] = bucket
        }

        let ranked = poses.compactMap { pose -> (PoseID, Double)? in
            guard let bucket = averages[pose], bucket.count > 0 else { return nil }
            return (pose, bucket.sum / Double(bucket.count))
        }

        if let weakest = ranked.min(by: { $0.1 < $1.1 }) {
            return weakest.0
        }
        return pack.defaultPoseID
    }
}

struct LockEntrySnapshot: Sendable, Equatable {
    let date: Date
    let pack: Pack
    let poseID: PoseID
    let score: Float
}

enum LockQuota {
    static func locks(
        in entries: [LockEntrySnapshot],
        on day: Date,
        calendar: Calendar = .current
    ) -> Int {
        entries.filter { calendar.isDate($0.date, inSameDayAs: day) }.count
    }

    static func remainingFreeLocks(
        entries: [LockEntrySnapshot],
        isPro: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        if isPro { return nil }
        let used = locks(in: entries, on: now, calendar: calendar)
        return max(0, ScoringConstants.freeLocksPerDay - used)
    }

    static func canLock(entries: [LockEntrySnapshot], isPro: Bool, now: Date = Date()) -> Bool {
        if isPro { return true }
        return (remainingFreeLocks(entries: entries, isPro: false, now: now) ?? 0) > 0
    }
}

struct DayRecap: Sendable, Equatable {
    let date: Date
    let lockCount: Int
    let bestScore: Int?
    let streak: Int
}

struct PoseRecap: Sendable, Equatable, Identifiable {
    let poseID: PoseID
    let bestScore: Float
    let bestDate: Date
    let takeCount: Int
    let averageScore: Float

    var id: String { poseID.rawValue }
}

struct WeekStats: Sendable, Equatable {
    let weekLockCount: Int
    let bestPoseName: String?
    let bestPoseScore: Int?
    let averageScore: Int?
}

struct DailyBest: Sendable, Equatable, Identifiable {
    let day: Date
    let score: Int
    var id: Date { day }
}

enum JournalStats {
    static func recap(
        entries: [LockEntrySnapshot],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DayRecap {
        let today = entries.filter { calendar.isDate($0.date, inSameDayAs: now) }
        let best = today.map(\.score).max().map { Int($0.rounded()) }
        return DayRecap(
            date: now,
            lockCount: today.count,
            bestScore: best,
            streak: streak(entries: entries, now: now, calendar: calendar)
        )
    }

    static func week(
        entries: [LockEntrySnapshot],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WeekStats {
        let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let recent = entries.filter { $0.date >= start && $0.date <= now }
        let avg = recent.isEmpty ? nil : Int((recent.map { Double($0.score) }.reduce(0, +) / Double(recent.count)).rounded())

        var best: (PoseID, Float)?
        for entry in recent {
            if best == nil || entry.score > best!.1 {
                best = (entry.poseID, entry.score)
            }
        }

        return WeekStats(
            weekLockCount: recent.count,
            bestPoseName: best.map { $0.0.displayName },
            bestPoseScore: best.map { Int($0.1.rounded()) },
            averageScore: avg
        )
    }

    static func streak(
        entries: [LockEntrySnapshot],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let days = Set(entries.map { calendar.startOfDay(for: $0.date) })
        var count = 0
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// Une ligne par pose travaillée, meilleure prise en tête de classement.
    static func poseRecaps(entries: [LockEntrySnapshot]) -> [PoseRecap] {
        Dictionary(grouping: entries, by: \.poseID)
            .compactMap { poseID, takes -> PoseRecap? in
                guard let best = takes.max(by: { $0.score < $1.score }) else { return nil }
                let total = takes.map { Double($0.score) }.reduce(0, +)
                return PoseRecap(
                    poseID: poseID,
                    bestScore: best.score,
                    bestDate: best.date,
                    takeCount: takes.count,
                    averageScore: Float(total / Double(takes.count))
                )
            }
            .sorted {
                $0.bestScore == $1.bestScore
                    ? $0.poseID.displayName < $1.poseID.displayName
                    : $0.bestScore > $1.bestScore
            }
    }

    static func counterpart(
        of entry: LockEntrySnapshot,
        in entries: [LockEntrySnapshot],
        daysAgo: Int,
        calendar: Calendar = .current
    ) -> LockEntrySnapshot? {
        guard let targetDay = calendar.date(byAdding: .day, value: -daysAgo, to: entry.date) else { return nil }
        let same = entries.filter {
            $0.poseID == entry.poseID && calendar.isDate($0.date, inSameDayAs: targetDay)
        }
        return same.max(by: { $0.score < $1.score })
    }

    /// Meilleur score par jour civil, pour une pose, dans `[from, to]`.
    static func dailyBests(
        poseID: PoseID,
        entries: [LockEntrySnapshot],
        from: Date,
        to: Date,
        calendar: Calendar = .current
    ) -> [DailyBest] {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        let relevant = entries.filter {
            $0.poseID == poseID && calendar.startOfDay(for: $0.date) >= start && calendar.startOfDay(for: $0.date) <= end
        }
        let grouped = Dictionary(grouping: relevant) { calendar.startOfDay(for: $0.date) }
        return grouped.compactMap { day, takes -> DailyBest? in
            guard let best = takes.map(\.score).max() else { return nil }
            return DailyBest(day: day, score: Int(best.rounded()))
        }
        .sorted { $0.day < $1.day }
    }
}

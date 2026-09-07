import SwiftUI

struct HomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(StoreManager.self) private var store
    var settings: AppSettings
    var entries: [LockEntry]

    private var snapshots: [LockEntrySnapshot] { entries.map(\.snapshot) }
    private var recap: DayRecap { JournalStats.recap(entries: snapshots) }
    private var week: WeekStats { JournalStats.week(entries: snapshots) }
    private var pose: PoseDefinition { PoseCatalog.definition(for: session.selectedPoseID) }
    private var lastScore: Int? {
        entries.first { $0.poseID == session.selectedPoseID }.map { Int($0.score.rounded()) }
    }

    private var trendPoints: [DailyBest] {
        let calendar = Calendar.current
        let to = Date()
        let from = calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: to)) ?? to
        return JournalStats.dailyBests(
            poseID: session.selectedPoseID,
            entries: snapshots,
            from: from,
            to: to
        )
    }

    private var trendAverage: Int? {
        guard !trendPoints.isEmpty else { return nil }
        let total = trendPoints.map(\.score).reduce(0, +)
        return Int((Double(total) / Double(trendPoints.count)).rounded())
    }

    private var lastLockDuration: TimeInterval? {
        entries.first { $0.poseID == session.selectedPoseID }?.durationToLock
    }

    var body: some View {
        @Bindable var session = session
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    DailyRecapView(recap: recap)
                    PoseCardView(
                        pose: pose,
                        lastScore: lastScore,
                        onWork: {
                            session.requestWork(isPro: store.isPro, settings: settings, entries: entries)
                        },
                        onBrowse: { session.showPoseLibrary = true }
                    )
                    ScoreTrendView(
                        poseName: pose.displayName,
                        points: trendPoints,
                        average: trendAverage,
                        lastLockDuration: lastLockDuration
                    )
                    StatsRowView(week: week)
                    ZyzzCatalogCard(isPro: store.isPro) {
                        session.requestPackChange(
                            .zyzz,
                            settings: settings,
                            isPro: store.isPro,
                            entries: entries
                        )
                    }
                    DeadlineCard(
                        isPro: store.isPro,
                        date: settings.competitionDate,
                        place: settings.competitionPlace,
                        goal: settings.goal,
                        recommendedPose: deadlinePose,
                        onLockedTap: {
                            session.paywallReason = .deadline
                            session.showPaywall = true
                        },
                        onAdd: { session.selectedTab = .settings },
                        onWork: {
                            if let recommended = deadlinePose {
                                session.selectedPoseID = recommended.poseID
                            }
                            session.requestWork(isPro: store.isPro, settings: settings, entries: entries)
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $session.showPoseLibrary) {
                PoseLibrarySheet(pack: settings.pack, isPro: store.isPro, selected: $session.selectedPoseID)
            }
        }
    }

    private var deadlinePose: PoseDefinition? {
        guard settings.competitionDate != nil else { return nil }
        let id = DailyPoseSelector.poseOfTheDay(pack: settings.pack, entries: snapshots)
        return PoseCatalog.definition(for: id)
    }
}

struct DailyRecapView: View {
    var recap: DayRecap

    private var dateText: String {
        recap.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR")))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(dateText.capitalized)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.ivoryMuted)
                if recap.streak > 0 {
                    Text("\(recap.streak) j")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.goldMuted)
                }
            }
            let best = recap.bestScore.map(String.init) ?? "—"
            Text("Aujourd’hui · \(recap.lockCount) lock\(recap.lockCount == 1 ? "" : "s") · meilleur \(best)")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Theme.ivory)
        }
        .padding(.top, 8)
    }
}

struct PoseCardView: View {
    var pose: PoseDefinition
    var lastScore: Int?
    var onWork: () -> Void
    var onBrowse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onBrowse) {
                HStack(spacing: 16) {
                    PosePreviewSkeleton(
                        poseID: pose.poseID,
                        highlight: .regions([.leftArm, .rightArm, .shoulders, .torso]),
                        lineWidth: 2.6,
                        jointSize: 4
                    )
                    .frame(width: 64, height: 80)
                    .background(Theme.background.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pose à travailler")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.ivoryMuted)
                        Text(pose.displayName)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(Theme.ivory)
                        Text(lastScore.map { "Dernier \($0)" } ?? "—")
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.goldMuted)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button("Travailler", action: onWork)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(18)
        .background(Theme.elevated)
        .overlay(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
    }
}

struct StatsRowView: View {
    var week: WeekStats

    var body: some View {
        HStack(spacing: 0) {
            stat("Cette semaine", "\(week.weekLockCount) lock\(week.weekLockCount == 1 ? "" : "s")")
            Divider().overlay(Theme.hairline).frame(height: 36)
            stat("Meilleure pose", week.bestPoseName.map { "\($0) \(week.bestPoseScore ?? 0)" } ?? "—")
            Divider().overlay(Theme.hairline).frame(height: 36)
            stat("Moyenne", week.averageScore.map(String.init) ?? "—")
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Theme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.ivoryMuted)
            Text(value)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.ivory)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ZyzzCatalogCard: View {
    var isPro: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                PosePreviewSkeleton(
                    poseID: .zyzzClassic,
                    highlight: .regions([.leftArm, .rightArm, .shoulders, .torso]),
                    lineWidth: 2.2,
                    jointSize: 3.5
                )
                .frame(width: 48, height: 64)
                .background(Theme.background.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Catégorie Zyzz")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Theme.ivory)
                    Text("Vacuum, twist, V-taper. La ligne esthétique.")
                        .font(Theme.supportFont)
                        .foregroundStyle(Theme.ivoryMuted)
                }
                Spacer()
                if !isPro {
                    Image(systemName: "lock.fill")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.goldMuted)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.elevated)
            .overlay(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
            .opacity(isPro ? 1 : 0.72)
        }
        .buttonStyle(.plain)
    }
}

struct DeadlineCard: View {
    var isPro: Bool
    var date: Date?
    var place: String?
    var goal: TrainingGoal?
    var recommendedPose: PoseDefinition?
    var onLockedTap: () -> Void
    var onAdd: () -> Void
    var onWork: () -> Void

    var body: some View {
        Group {
            if !isPro {
                Button(action: onLockedTap) {
                    content(locked: true)
                }
                .buttonStyle(.plain)
            } else if let date, daysRemaining(from: date) >= 0 {
                content(locked: false, date: date)
            } else {
                Button(action: onAdd) {
                    content(locked: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func content(locked: Bool, date: Date? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Échéance")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.ivoryMuted)
                Spacer()
                if locked {
                    Image(systemName: "lock.fill")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.goldMuted)
                }
            }
            if let date {
                Text(headline(for: date))
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.ivory)
                if let recommendedPose {
                    Text(recommendedPose.displayName)
                        .font(Theme.supportFont)
                        .foregroundStyle(Theme.ivoryMuted)
                    Button("Travailler", action: onWork)
                        .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                Text(emptyTitle)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.ivory)
                Text(emptyDetail)
                    .font(Theme.supportFont)
                    .foregroundStyle(Theme.ivoryMuted)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.elevated)
        .overlay(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
        .opacity(locked ? 0.72 : 1)
    }

    private var emptyTitle: String {
        goal == .competition ? "Ajoute ta date de scène." : "Ajoute une échéance."
    }

    private var emptyDetail: String {
        "Une date, un lieu. Les rappels suivent."
    }

    private func headline(for date: Date) -> String {
        let days = daysRemaining(from: date)
        let countdown: String
        if days == 0 {
            countdown = "Aujourd’hui"
        } else {
            countdown = "J-\(days)"
        }
        if let place, !place.isEmpty {
            return "\(countdown) · \(place)"
        }
        return countdown
    }

    private func daysRemaining(from date: Date) -> Int {
        CompetitionDeadline(date: date, place: place).daysRemaining()
    }
}

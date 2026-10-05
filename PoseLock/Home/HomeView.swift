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
                .padding(.horizontal, Theme.pageInset)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("PoseLock")
            .navigationBarTitleDisplayMode(.large)
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
        recap.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(dateText.capitalized)
                    .font(Theme.supportFont)
                    .foregroundStyle(Theme.ivoryMuted)
                if recap.streak > 0 {
                    Text("\(recap.streak) j")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.goldMuted)
                }
            }
            Text(recap.lockCount == 0 ? String(localized: "Ta prochaine pose commence ici.") : String(localized: "\(recap.lockCount) locks aujourd’hui"))
                .font(Theme.titleFont)
                .foregroundStyle(Theme.ivory)
            if let best = recap.bestScore {
                Text("Meilleur score · \(best) / 100")
                    .font(Theme.supportFont)
                    .foregroundStyle(Theme.ivoryMuted)
            }
        }
        .padding(.top, 8)
    }
}

struct PoseCardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var pose: PoseDefinition
    var lastScore: Int?
    var onWork: () -> Void
    var onBrowse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onBrowse) {
                HStack(spacing: 16) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        PoseReferenceImage(poseID: pose.poseID, variant: .guided)
                            .frame(width: 100, height: 140)
                            .background(Theme.background.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pose à travailler")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.ivoryMuted)
                        Text(pose.displayName)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.ivory)
                        Text(lastScore.map { String(localized: "Dernier score · \($0) / 100") } ?? String(localized: "Première séance"))
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.goldMuted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(Theme.supportFont)
                        .foregroundStyle(Theme.ivoryMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Choisir une autre pose")

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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var week: WeekStats

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20)) : AnyLayout(HStackLayout(spacing: 16))
        layout {
            stat(String(localized: "Cette semaine"), String(localized: "\(week.weekLockCount) locks"))
            stat(String(localized: "Meilleure pose"), week.bestPoseName.map { "\($0) \(week.bestPoseScore ?? 0)" } ?? "—")
            stat(String(localized: "Moyenne"), week.averageScore.map(String.init) ?? "—")
        }
        .padding(.vertical, 8)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.ivoryMuted)
            Text(value)
                .font(Theme.supportFont)
                .foregroundStyle(Theme.ivory)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
                    .font(Theme.bodyFont)
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
                    .font(Theme.bodyFont)
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

    }

    private var emptyTitle: String {
        goal == .competition ? String(localized: "Ajoute ta date de scène.") : String(localized: "Ajoute une échéance.")
    }

    private var emptyDetail: String {
        String(localized: "Une date, un lieu. Les rappels suivent.")
    }

    private func headline(for date: Date) -> String {
        let days = daysRemaining(from: date)
        let countdown: String
        if days == 0 {
            countdown = String(localized: "Aujourd’hui")
        } else {
            countdown = String(localized: "J-\(days)")
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

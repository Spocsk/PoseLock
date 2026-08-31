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
                    StatsRowView(week: week) {
                        session.showJournal = true
                    }
                    PackPillsView(
                        active: settings.pack,
                        unlocked: store.isPro ? Set(Pack.allCases) : [settings.pack]
                    ) { pack in
                        session.requestPackChange(pack, settings: settings, isPro: store.isPro, entries: entries)
                    }
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
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.elevated)
                            .frame(width: 64, height: 80)
                        Image(systemName: pose.symbolName)
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(Theme.gold)
                    }
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
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct StatsRowView: View {
    var week: WeekStats
    var onOpenJournal: () -> Void

    var body: some View {
        Button(action: onOpenJournal) {
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
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
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

struct PackPillsView: View {
    var active: Pack
    var unlocked: Set<Pack>
    var onSelect: (Pack) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Pack.allCases) { pack in
                Button {
                    onSelect(pack)
                } label: {
                    Text(pack.displayName)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(pack == active ? Theme.background : Theme.ivoryMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(pack == active ? Theme.gold : Theme.elevated)
                        .overlay(
                            Capsule().stroke(pack == active ? Color.clear : Theme.hairline, lineWidth: 1)
                        )
                        .clipShape(Capsule())
                        .opacity(unlocked.contains(pack) || pack == active ? 1 : 0.55)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

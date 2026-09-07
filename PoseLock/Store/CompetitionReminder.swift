import Foundation
import UserNotifications

/// Rappels d’échéance, locaux, sur le même modèle que `TrialReminder`.
/// Identifiants distincts : les deux peuvent coexister.
enum CompetitionReminder {
    static let identifiers = [
        7: "poselock.deadline.d7",
        3: "poselock.deadline.d3",
        1: "poselock.deadline.d1"
    ]

    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Array(identifiers.values))
    }

    /// Programme J-7 / J-3 / J-1 encore dans le futur. Demande la permission
    /// ici, pas au lancement. `false` si refusée ou s’il n’y a rien à poser.
    @discardableResult
    static func schedule(
        date: Date,
        place: String?,
        pack: Pack,
        entries: [LockEntrySnapshot],
        now: Date = Date()
    ) async -> Bool {
        cancel()

        let deadline = CompetitionDeadline(date: date, place: place)
        let offsets = deadline.upcomingOffsets(now: now)
        guard !offsets.isEmpty else { return true }

        let center = UNUserNotificationCenter.current()
        guard let granted = try? await center.requestAuthorization(options: [.alert, .sound]), granted else {
            return false
        }

        let pose = DailyPoseSelector.poseOfTheDay(pack: pack, entries: entries, now: now)
        let hasLock = entries.contains { $0.poseID == pose }

        for offset in offsets {
            guard let fire = deadline.fireDate(daysBefore: offset),
                  let identifier = identifiers[offset] else { continue }
            let copy = CompetitionDeadline.notificationCopy(
                daysRemaining: offset,
                pose: pose,
                place: place,
                hasLock: hasLock
            )
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fire
            )
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
        return true
    }
}

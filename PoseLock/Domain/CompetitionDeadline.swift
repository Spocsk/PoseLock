import Foundation

/// Une échéance saisie localement : date, lieu optionnel, copie des rappels.
/// Rien n’est envoyé nulle part.
struct CompetitionDeadline: Equatable, Sendable {
    let date: Date
    let place: String?

    static let reminderOffsets = [7, 3, 1]
    static let fireHour = 9

    func daysRemaining(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: now)
        let to = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    func fireDate(daysBefore: Int, calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: date)
        guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: start) else { return nil }
        return calendar.date(bySettingHour: Self.fireHour, minute: 0, second: 0, of: day)
    }

    /// Jalons encore dans le futur au moment `now`.
    func upcomingOffsets(now: Date = Date(), calendar: Calendar = .current) -> [Int] {
        Self.reminderOffsets.filter { offset in
            guard let fire = fireDate(daysBefore: offset, calendar: calendar) else { return false }
            return fire > now
        }
    }

    struct NotificationCopy: Equatable, Sendable {
        let title: String
        let body: String
    }

    static func notificationCopy(
        daysRemaining: Int,
        pose: PoseID,
        place: String?,
        hasLock: Bool
    ) -> NotificationCopy {
        let dayWord = daysRemaining == 1 ? "jour" : "jours"
        let title = "Il reste \(daysRemaining) \(dayWord)"
        let location = place.flatMap { $0.isEmpty ? nil : $0 }
        let whereAt = location.map { " · \($0)" } ?? ""
        let poseName = pose.displayName
        let body: String
        if hasLock {
            body = "Entraîne-toi sur \(poseName)\(whereAt) : ce n’est pas encore locké."
        } else {
            body = "Entraîne-toi sur \(poseName)\(whereAt) : pas encore de lock."
        }
        return NotificationCopy(title: title, body: body)
    }
}

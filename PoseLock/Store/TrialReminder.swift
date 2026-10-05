import Foundation
import UserNotifications

/// Apple ne garantit aucun rappel avant la fin d'un essai. Celui-ci est local :
/// programmé sur l'appareil, jamais envoyé nulle part.
enum TrialReminder {
    static let identifier = "poselock.trial.reminder"

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    static func fireDate(
        before renewalDate: Date?,
        isTrialActive: Bool,
        now: Date = Date()
    ) -> Date? {
        guard isTrialActive, let renewalDate else { return nil }
        let fireDate = renewalDate.addingTimeInterval(-24 * 60 * 60)
        return fireDate > now ? fireDate : nil
    }

    /// `renewalDate` vient de la transaction vérifiée, donc de la fin d'essai réelle.
    static func schedule(before renewalDate: Date?, isTrialActive: Bool) async {
        let center = UNUserNotificationCenter.current()
        cancel()

        guard let fireDate = fireDate(before: renewalDate, isTrialActive: isTrialActive),
              let granted = try? await center.requestAuthorization(options: [.alert, .sound]),
              granted
        else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Ton essai devient payant demain")
        content.body = String(localized: "Sans renouvellement : \(ScoringConstants.freeLocksPerDay) locks/jour, ton pack d’origine et pas de comparaison J-30.")
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await center.add(request)
    }
}

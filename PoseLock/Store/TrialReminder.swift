import Foundation
import UserNotifications

/// Apple ne garantit aucun rappel avant la fin d'un essai. Celui-ci est local :
/// programmé sur l'appareil, jamais envoyé nulle part.
enum TrialReminder {
    static let identifier = "poselock.trial.reminder"

    /// `renewalDate` vient de la transaction vérifiée, donc de la fin d'essai réelle.
    static func schedule(before renewalDate: Date?) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let renewalDate,
              let fireDate = Calendar.current.date(byAdding: .day, value: -1, to: renewalDate),
              fireDate > Date(),
              let granted = try? await center.requestAuthorization(options: [.alert, .sound]),
              granted
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "Ton essai se termine demain"
        content.body = "L’abonnement démarre dans 24 h. Tu peux encore annuler depuis l’App Store."
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

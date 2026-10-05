import MessageUI
import SwiftUI
import UIKit

struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var error: String?
    @State private var showMail = false
    @State private var mailBody = ""

    private var trimmed: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Dis-nous ce qui ne va pas.")
                    .font(Theme.supportFont)
                    .foregroundStyle(Theme.ivoryMuted)

                TextEditor(text: $message)
                    .scrollContentBackground(.hidden)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ivory)
                    .padding(10)
                    .frame(minHeight: 96)
                    .background(
                        Theme.elevated,
                        in: RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
                            .stroke(Theme.hairline, lineWidth: 1)
                    )

                if let error {
                    Text(error)
                        .font(Theme.supportFont)
                        .foregroundStyle(Theme.frameRed)
                }

                Spacer(minLength: 0)

                Button("Envoyer") { send() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(trimmed.isEmpty)
            }
            .padding(.horizontal, Theme.pageInset)
            .padding(.bottom, 20)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Un problème ?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
            .sheet(isPresented: $showMail) {
                MailComposeView(
                    recipients: [FeedbackMail.supportAddress],
                    subject: FeedbackMail.subject,
                    body: mailBody
                ) { result in
                    showMail = false
                    if result == .sent {
                        dismiss()
                    }
                }
                .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
    }

    private func send() {
        error = nil
        let versions = FeedbackMail.currentVersion()
        let system = UIDevice.current.systemVersion
        let composed = FeedbackMail.body(
            message: trimmed,
            version: versions.version,
            build: versions.build,
            systemVersion: system
        )
        if MFMailComposeViewController.canSendMail() {
            mailBody = composed
            showMail = true
            return
        }
        guard let url = FeedbackMail.mailtoURL(
            message: trimmed,
            version: versions.version,
            build: versions.build,
            systemVersion: system
        ) else {
            error = String(localized: "Mail n’est pas configuré.")
            return
        }
        UIApplication.shared.open(url) { success in
            if success {
                dismiss()
            } else {
                error = String(localized: "Mail n’est pas configuré.")
            }
        }
    }
}

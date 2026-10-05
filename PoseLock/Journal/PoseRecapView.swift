import SwiftUI
import UIKit

/// Lecture du journal par pose : la meilleure prise de chaque pose, avec le
/// skeleton de référence superposé au skeleton capturé.
struct PoseRecapView: View {
    var entries: [LockEntry]

    @State private var shared: SharedRecapEntry?

    private var recaps: [PoseRecap] {
        JournalStats.poseRecaps(entries: entries.map(\.snapshot))
    }

    var body: some View {
        Group {
            if recaps.isEmpty {
                JournalEmptyState(
                    systemImage: "figure.stand",
                    title: "Aucune pose travaillée",
                    detail: "Un lock, et le récap se remplit."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(recaps) { recap in
                            if let entry = bestEntry(for: recap) {
                                PoseRecapCard(recap: recap, entry: entry) { yaw in
                                    shared = SharedRecapEntry(entry: entry, yaw: yaw)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
        }
        .sheet(item: $shared) { wrapper in
            PoseRecapShareView(entry: wrapper.entry, yaw: wrapper.yaw)
        }
    }

    private func bestEntry(for recap: PoseRecap) -> LockEntry? {
        entries.first {
            $0.poseID == recap.poseID && $0.date == recap.bestDate && $0.score == recap.bestScore
        } ?? entries.first { $0.poseID == recap.poseID }
    }
}

/// `sheet(item:)` exige Identifiable, et l’`id` d’un modèle SwiftData est
/// ambigu entre l’UUID déclaré et le PersistentIdentifier.
private struct SharedRecapEntry: Identifiable {
    let entry: LockEntry
    let yaw: Float
    var id: UUID { entry.id }
}

struct PoseRecapCard: View {
    var recap: PoseRecap
    var entry: LockEntry
    var onShare: (Float) -> Void

    @State private var yaw: Float = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recap.poseID.displayName)
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.ivory)
                    Text(recap.poseID.pack.displayName)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.ivoryMuted)
                }
                Spacer()
                Text("\(Int(recap.bestScore.rounded()))")
                    .font(Theme.metricFont)
                    .foregroundStyle(Theme.gold)
            }

            HStack(alignment: .top, spacing: 12) {
                PoseComparisonSkeleton(
                    poseID: recap.poseID,
                    snapshot: entry.skeleton,
                    yaw: $yaw
                )
                .aspectRatio(3 / 4, contentMode: .fit)
                .frame(maxHeight: 210)
                .frame(maxWidth: .infinity)
                photo
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
            }

            HStack(spacing: 0) {
                stat(String(localized: "Prises"), "\(recap.takeCount)")
                Divider().overlay(Theme.hairline).frame(height: 28)
                stat(String(localized: "Moyenne"), "\(Int(recap.averageScore.rounded()))")
                Divider().overlay(Theme.hairline).frame(height: 28)
                stat(String(localized: "Meilleure"), dateText)
            }

            Button {
                onShare(yaw)
            } label: {
                Label("Partager", systemImage: "square.and.arrow.up")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
                            .fill(Theme.gold.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Theme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }

    private var dateText: String {
        recap.bestDate.formatted(
            .dateTime.day().month(.abbreviated)
        )
    }

    @ViewBuilder
    private var photo: some View {
        if let image = PhotoStore.image(at: entry.cleanPath) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
                .fill(Theme.background.opacity(0.6))
                .overlay(
                    Text("Photo absente")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.ivoryFaint)
                )
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.ivoryMuted)
            Text(value)
                .font(Theme.supportFont)
                .foregroundStyle(Theme.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PoseRecapShareView: View {
    var entry: LockEntry
    var yaw: Float
    @Environment(\.dismiss) private var dismiss
    @State private var rendered: UIImage?

    var body: some View {
        NavigationStack {
            VStack {
                PoseRecapCardCanvas(entry: entry, yaw: yaw)
                    .aspectRatio(9 / 16, contentMode: .fit)
                    .padding(24)
                Spacer()
                if let rendered {
                    ShareDestinationBar(image: rendered, title: entry.poseID.displayName)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 24)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(entry.poseID.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundStyle(Theme.gold)
                }
            }
            .onAppear { render() }
        }
        .preferredColorScheme(.dark)
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(
            content: PoseRecapCardCanvas(entry: entry, yaw: yaw)
                .frame(width: 1080, height: 1920)
        )
        renderer.scale = 1
        rendered = renderer.uiImage
    }
}

struct PoseRecapCardCanvas: View {
    var entry: LockEntry
    var yaw: Float

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.background
                VStack(spacing: 0) {
                    Spacer(minLength: geo.size.height * 0.06)
                    if let image = PhotoStore.image(at: entry.cleanPath) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: geo.size.width * 0.82)
                    }
                    PoseComparisonSkeleton(
                        poseID: entry.poseID,
                        snapshot: entry.skeleton,
                        yaw: .constant(yaw),
                        isInteractive: false,
                        lineWidth: max(3, geo.size.width * 0.010),
                        jointSize: max(4, geo.size.width * 0.014)
                    )
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .frame(maxWidth: geo.size.width * 0.72)
                    .frame(height: geo.size.height * 0.28)
                    .frame(maxWidth: .infinity)
                    .padding(.top, geo.size.height * 0.02)
                    Spacer()
                    Text(entry.poseID.displayName)
                        .font(.system(size: max(14, geo.size.width * 0.042), weight: .regular))
                        .foregroundStyle(Theme.ivoryMuted)
                    Text("\(Int(entry.score.rounded()))")
                        .font(.system(size: max(44, geo.size.width * 0.16), weight: .light))
                        .foregroundStyle(Theme.ivory)
                        .padding(.top, 4)
                    Spacer().frame(height: geo.size.height * 0.06)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                ShareMarkLabel(reference: min(geo.size.width, geo.size.height))
            }
        }
        .background(Theme.background)
    }
}

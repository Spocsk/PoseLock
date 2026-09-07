import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum JournalTab: String, CaseIterable, Identifiable {
    case takes
    case poses

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .takes: return "Prises"
        case .poses: return "Poses"
        }
    }
}

struct JournalView: View {
    var entries: [LockEntry]
    var isPro: Bool
    @State private var selectedID: UUID?
    @State private var tab: JournalTab = .takes

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 4)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Vue", selection: $tab) {
                    ForEach(JournalTab.allCases) { tab in
                        Text(tab.displayName).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                switch tab {
                case .takes:
                    takesGrid
                case .poses:
                    PoseRecapView(entries: entries)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedID) { id in
                if let entry = entries.first(where: { $0.id == id }) {
                    JournalDetailView(entry: entry, entries: entries, isPro: isPro)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var takesGrid: some View {
        if entries.isEmpty {
            VStack(spacing: 8) {
                Text("Aucune photo.")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ivory)
                Text("Un lock, et le journal commence.")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.ivoryMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(entries, id: \.id) { entry in
                        Button {
                            selectedID = entry.id
                        } label: {
                            JournalCell(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
        }
    }
}

struct JournalCell: View {
    var entry: LockEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                Rectangle().fill(Theme.elevated)
                if let image = PhotoStore.image(at: entry.cleanPath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(minHeight: 140)
            .clipped()

            Text("\(Int(entry.score.rounded()))")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.ivory)
            Text(entry.poseID.displayName)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.ivoryMuted)
                .lineLimit(1)
            Text(entry.date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR"))))
                .font(Theme.captionFont)
                .foregroundStyle(Theme.ivoryFaint)
        }
        .padding(.bottom, 6)
    }
}

struct JournalDetailView: View {
    var entry: LockEntry
    var entries: [LockEntry]
    var isPro: Bool
    @State private var showShare = false
    @State private var showOverlay = false

    private var snapshots: [LockEntrySnapshot] { entries.map(\.snapshot) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photo(path: showOverlay ? entry.overlayPath : entry.cleanPath)

                HStack {
                    Text(entry.poseID.displayName)
                        .foregroundStyle(Theme.ivory)
                    Spacer()
                    Text("\(Int(entry.score.rounded()))")
                        .foregroundStyle(Theme.gold)
                }
                .font(.system(size: 18, weight: .regular))

                Toggle("Overlay", isOn: $showOverlay)
                    .tint(Theme.gold)
                    .foregroundStyle(Theme.ivoryMuted)
                    .font(Theme.captionFont)

                compareRow(title: "J-7", days: 7)
                if isPro {
                    compareRow(title: "J-30", days: 30)
                } else {
                    Text("J-30 avec Pro.")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.ivoryFaint)
                }

                Button("Partager une carte") { showShare = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            ShareCardView(entry: entry)
        }
    }

    @ViewBuilder
    private func photo(path: String) -> some View {
        if let image = PhotoStore.image(at: path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
        } else {
            Rectangle()
                .fill(Theme.elevated)
                .aspectRatio(3 / 4, contentMode: .fit)
        }
    }

    @ViewBuilder
    private func compareRow(title: String, days: Int) -> some View {
        let match = JournalStats.counterpart(of: entry.snapshot, in: snapshots, daysAgo: days)
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.ivoryMuted)
            if let match, let image = PhotoStore.image(at: counterpartPath(match)) {
                HStack(alignment: .top, spacing: 12) {
                    if let current = PhotoStore.image(at: entry.cleanPath) {
                        Image(uiImage: current)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipped()
                    }
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipped()
                }
                Text("\(Int(entry.score.rounded()))  →  \(Int(match.score.rounded()))")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ivory)
            } else {
                Text("Pas encore de prise à \(title) pour cette pose.")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ivoryMuted)
            }
        }
    }

    private func counterpartPath(_ snapshot: LockEntrySnapshot) -> String {
        entries.first {
            $0.poseID == snapshot.poseID && $0.date == snapshot.date && $0.score == snapshot.score
        }?.cleanPath ?? ""
    }
}

struct ShareCardView: View {
    var entry: LockEntry
    @Environment(\.dismiss) private var dismiss
    @State private var rendered: UIImage?

    var body: some View {
        NavigationStack {
            VStack {
                ShareCardCanvas(entry: entry)
                    .aspectRatio(9 / 16, contentMode: .fit)
                    .padding(24)
                Spacer()
                if let rendered {
                    ShareLink(
                        item: JPEGTransfer(image: rendered),
                        preview: SharePreview(entry.poseID.displayName, image: Image(uiImage: rendered))
                    ) {
                        Text("Exporter")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 24)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Carte")
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
        let renderer = ImageRenderer(content: ShareCardCanvas(entry: entry).frame(width: 1080, height: 1920))
        renderer.scale = 1
        rendered = renderer.uiImage
    }
}

struct ShareCardCanvas: View {
    var entry: LockEntry

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.background
                VStack(spacing: 0) {
                    Spacer(minLength: geo.size.height * 0.08)
                    if let image = PhotoStore.image(at: entry.cleanPath) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: geo.size.width * 0.86)
                    }
                    Spacer()
                    Text(entry.poseID.displayName)
                        .font(.system(size: max(14, geo.size.width * 0.045), weight: .regular))
                        .foregroundStyle(Theme.ivoryMuted)
                    Text("\(Int(entry.score.rounded()))")
                        .font(.system(size: max(48, geo.size.width * 0.18), weight: .light))
                        .foregroundStyle(Theme.ivory)
                        .padding(.top, 4)
                    Spacer().frame(height: geo.size.height * 0.08)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                ShareMarkLabel(reference: min(geo.size.width, geo.size.height))
            }
        }
        .background(Theme.background)
    }
}

struct JPEGTransfer: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { item in
            item.image.jpegData(compressionQuality: 0.9) ?? Data()
        }
    }
}

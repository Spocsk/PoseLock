import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum JournalTab: String, CaseIterable, Identifiable {
    case takes
    case poses

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .takes: return String(localized: "Prises")
        case .poses: return String(localized: "Poses")
        }
    }
}

struct JournalView: View {
    @Environment(AppSession.self) private var session
    var entries: [LockEntry]
    var isPro: Bool
    var initialTab: JournalTab = .takes
    @State private var selectedID: UUID?
    @State private var tab: JournalTab = .takes

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

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
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $selectedID) { id in
                if let entry = entries.first(where: { $0.id == id }) {
                    JournalDetailView(entry: entry, entries: entries, isPro: isPro)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { tab = initialTab }
    }

    @ViewBuilder
    private var takesGrid: some View {
        if entries.isEmpty {
            JournalEmptyState(
                systemImage: "photo.on.rectangle.angled",
                title: "Ton journal commence ici",
                detail: "Travaille une pose et réalise ton premier lock pour retrouver ta photo et ton score.",
                actionTitle: "Choisir une pose"
            ) {
                session.selectedTab = .home
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(entries, id: \.id) { entry in
                        Button {
                            selectedID = entry.id
                        } label: {
                            JournalCell(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.pageInset)
            }
        }
    }
}

struct JournalEmptyState: View {
    var systemImage: String
    var title: LocalizedStringKey
    var detail: LocalizedStringKey
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(Theme.titleFont)
                .foregroundStyle(Theme.goldMuted)
                .accessibilityHidden(true)

            Text(title)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivory)

            Text(detail)
                .font(Theme.supportFont)
                .foregroundStyle(Theme.ivoryMuted)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 10)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct JournalCell: View {
    var entry: LockEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(Theme.elevated)
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    if let image = PhotoStore.image(at: entry.cleanPath) {
                        GeometryReader { proxy in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))

            Text("\(Int(entry.score.rounded()))")
                .font(Theme.supportFont)
                .foregroundStyle(Theme.ivory)
            Text(entry.poseID.displayName)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.ivoryMuted)
                .lineLimit(2)
            Text(entry.date.formatted(.dateTime.day().month(.abbreviated)))
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
    var showOverlayInitially: Bool = false
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
                .font(Theme.bodyFont)

                Toggle("Afficher la silhouette", isOn: $showOverlay)
                    .tint(Theme.gold)
                    .foregroundStyle(Theme.ivoryMuted)
                    .font(Theme.captionFont)

                compareRow(title: String(localized: "J-7"), days: 7)
                if isPro {
                    compareRow(title: String(localized: "J-30"), days: 30)
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
        .onAppear { showOverlay = showOverlayInitially }
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
                Text("\(Int(match.score.rounded()))  →  \(Int(entry.score.rounded()))")
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
                    ShareDestinationBar(image: rendered, title: entry.poseID.displayName)
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

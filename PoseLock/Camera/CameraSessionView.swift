import Photos
import SwiftData
import SwiftUI
import UIKit

struct CameraSessionView: View {
    @Environment(AppSession.self) private var session
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings: AppSettings
    var entries: [LockEntry]

    @State private var model = CameraViewModel()
    @State private var showLibrary = false
    @State private var persisted = false

    var body: some View {
        @Bindable var session = session
        ZStack {
            Theme.background.ignoresSafeArea()
            CameraPreviewRepresentable(session: model.capture.session)
                .ignoresSafeArea()
            SkeletonOverlay(frame: model.bodyFrame, evaluation: model.evaluation)
                .ignoresSafeArea()
            CameraHUD(
                pose: PoseCatalog.definition(for: session.selectedPoseID),
                evaluation: model.evaluation,
                score: model.smoothedScore,
                onClose: { session.showCamera = false },
                onFlip: { model.flip() },
                onBubble: { showLibrary = true }
            )
            Color.white.opacity(model.flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if model.cameraDenied {
                permissionOverlay
            }

            if model.didLock {
                lockOverlay
            }
        }
        .statusBarHidden()
        .onAppear {
            model.poseID = session.selectedPoseID
            model.start(front: settings.cameraFront)
        }
        .onDisappear {
            settings.cameraFront = model.isFront
            model.stop()
        }
        .onChange(of: session.selectedPoseID) { _, newPose in
            model.notePoseChange(newPose)
        }
        .onChange(of: model.didLock) { _, locked in
            if locked { persistLock() }
        }
        .sheet(isPresented: $showLibrary) {
            PoseLibrarySheet(
                pack: settings.pack,
                isPro: store.isPro,
                selected: $session.selectedPoseID
            )
        }
        .sheet(isPresented: $session.showPaywall) {
            PaywallSheet(reason: session.paywallReason)
        }
    }

    private var permissionOverlay: some View {
        VStack(spacing: 16) {
            Text("Caméra refusée.")
                .font(Theme.titleFont)
                .foregroundStyle(Theme.ivory)
            Text("PoseLock note la pose on-device. Relance l’autorisation pour travailler.")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivoryMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Autoriser la caméra") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 32)
            Button("Fermer") { session.showCamera = false }
                .foregroundStyle(Theme.gold)
        }
        .padding(24)
        .background(Theme.background.opacity(0.92))
    }

    private var lockOverlay: some View {
        VStack(spacing: 16) {
            if let clean = model.lastClean {
                Image(uiImage: clean)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Text("\(Int(model.lastScore.rounded()))")
                .font(Theme.scoreFont)
                .foregroundStyle(Theme.lockGreen)
            HStack(spacing: 12) {
                Button("Même pose") {
                    persisted = false
                    model.resetAfterLock()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Fermer") { session.showCamera = false }
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.ivory)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.elevated)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Theme.background.opacity(0.55).ignoresSafeArea())
    }

    private func persistLock() {
        guard !persisted else { return }
        persisted = true
        PoseLockHaptics.lockClick(enabled: settings.hapticsEnabled)
        guard let clean = model.lastClean else { return }
        let overlay = model.lastOverlay ?? clean
        let id = UUID()
        do {
            let saved = try PhotoStore.save(
                id: id,
                clean: clean,
                overlay: overlay,
                highQuality: settings.photoQualityHigh
            )
            let entry = LockEntry(
                id: id,
                pack: session.selectedPoseID.pack,
                poseID: session.selectedPoseID,
                score: model.lastScore,
                durationToLock: model.durationToLock,
                cleanPath: saved.cleanPath,
                overlayPath: saved.overlayPath
            )
            modelContext.insert(entry)
            if settings.saveToPhotos {
                Task { await saveToSystemPhotos(clean) }
            }
        } catch {
            persisted = false
        }
    }

    private func saveToSystemPhotos(_ image: UIImage) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return }
        try? await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}

struct PoseLibrarySheet: View {
    var pack: Pack
    var isPro: Bool
    @Binding var selected: PoseID
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSession.self) private var session
    @Environment(StoreManager.self) private var store

    var body: some View {
        NavigationStack {
            List {
                ForEach(Pack.allCases) { listed in
                    Section(listed.displayName) {
                        ForEach(PoseCatalog.poses(for: listed)) { pose in
                            Button {
                                choose(pose.poseID, pack: listed)
                            } label: {
                                HStack {
                                    Image(systemName: pose.symbolName)
                                        .foregroundStyle(Theme.gold)
                                        .frame(width: 28)
                                    Text(pose.displayName)
                                        .foregroundStyle(Theme.ivory)
                                    Spacer()
                                    if pose.poseID == selected {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Theme.gold)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Poses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundStyle(Theme.gold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func choose(_ poseID: PoseID, pack listed: Pack) {
        if !isPro && listed != pack {
            session.paywallReason = .otherPack
            session.showPaywall = true
            return
        }
        selected = poseID
        dismiss()
    }
}

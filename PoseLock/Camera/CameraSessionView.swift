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
            CameraPreviewRepresentable(session: model.capture.session, isFront: model.isFront)
                .ignoresSafeArea()
            SkeletonOverlay(frame: model.bodyFrame, evaluation: model.evaluation)
                .ignoresSafeArea()
            CameraHUD(
                pose: PoseCatalog.definition(for: session.selectedPoseID),
                evaluation: model.evaluation,
                score: model.smoothedScore,
                isFront: model.isFront,
                onClose: { session.showCamera = false },
                onSelectFront: { model.setCamera(front: $0) },
                onBubble: { showLibrary = true },
                onForceLock: forceLockAction
            )
            .padding(.top, 8)
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

    /// Le lock forcé n'existe qu'en debug : en release il n'y a pas de fermeture à
    /// passer, donc pas de bouton à afficher.
    private var forceLockAction: (() -> Void)? {
        #if DEBUG
        return { Task { await model.debugForceLock() } }
        #else
        return nil
        #endif
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
            #if DEBUG
            if let forceLockAction {
                DevForceLockButton(action: forceLockAction)
            }
            #endif
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
                    .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
            }
            Text("\(Int(model.lastScore.rounded()))")
                .font(Theme.scoreFont)
                .foregroundStyle(Theme.lockGreen)
            HStack(spacing: 12) {
                Button("Rejouer") {
                    persisted = false
                    model.resetAfterLock()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button {
                    session.showCamera = false
                } label: {
                    Text("Fermer")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.ivory)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background {
            Rectangle()
                .fill(.thickMaterial)
                .overlay(Theme.background.opacity(0.35))
                .ignoresSafeArea()
        }
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
                overlayPath: saved.overlayPath,
                skeletonData: model.lastSkeleton.flatMap { try? JSONEncoder().encode($0) }
            )
            modelContext.insert(entry)
            if settings.saveToPhotos {
                // Signée seulement pour sortir : le fichier gardé par PhotoStore, que
                // le journal et les cartes relisent, reste sans marque.
                Task { await saveToSystemPhotos(ShareMark.stamped(clean)) }
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
                                    PosePreviewSkeleton(
                                        poseID: pose.poseID,
                                        highlight: .regions([.leftArm, .rightArm, .shoulders]),
                                        lineWidth: 1.8,
                                        jointSize: 3
                                    )
                                    .frame(width: 36, height: 48)
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
            session.paywallReason = listed == .zyzz ? .zyzz : .otherPack
            session.showPaywall = true
            return
        }
        selected = poseID
        dismiss()
    }
}

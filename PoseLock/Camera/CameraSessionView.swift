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
            #if DEBUG
            if let demo = model.demoPreviewImage {
                DemoPosePreview(
                    image: demo,
                    frame: model.bodyFrame,
                    evaluation: model.evaluation,
                    isFront: model.isFront
                )
            } else {
                livePreview
            }
            #else
            livePreview
            #endif
            CameraHUD(
                pose: PoseCatalog.definition(for: session.selectedPoseID),
                evaluation: model.evaluation,
                score: model.smoothedScore,
                isFront: model.isFront,
                onClose: { session.showCamera = false },
                onSelectFront: selectCamera,
                onBubble: { showLibrary = true },
                onForceLock: forceLockAction,
                debugReadout: debugReadout
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
            startSession()
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
        .poseLockFeedback()
    }

    private var livePreview: some View {
        ZStack {
            CameraPreviewRepresentable(session: model.capture.session, isFront: model.isFront)
                .ignoresSafeArea()
            SkeletonOverlay(
                frame: model.bodyFrame,
                evaluation: model.evaluation,
                contentAspect: CaptureSessionController.portraitAspect
            )
            .ignoresSafeArea()
        }
    }

    private func startSession() {
        #if DEBUG
        if ScreenBank.usesDemoCamera {
            model.startDemoPreview(
                poseID: session.selectedPoseID,
                front: settings.cameraFront
            )
            if ScreenBank.videoDemoScene == .cameraLock {
                Task {
                    // Laisse le temps de voir le skeleton, le 93 et « Tiens la
                    // ligne. » avant le flash et la photo lockée.
                    try? await Task.sleep(for: .milliseconds(1800))
                    await model.debugForceLock()
                }
            } else if ScreenBank.current?.locksOnAppear == true {
                Task {
                    try? await Task.sleep(for: .milliseconds(280))
                    await model.debugForceLock()
                }
            }
            return
        }
        #endif
        model.start(front: settings.cameraFront)
        PoseLockAnalytics.capture(.cameraSessionStarted)
    }

    private func selectCamera(front: Bool) {
        #if DEBUG
        if model.demoPreviewImage != nil {
            model.setDemoCamera(front: front)
            return
        }
        #endif
        model.setCamera(front: front)
    }

    private var debugReadout: String? {
        #if DEBUG
        guard !model.bodyFrame.joints3D.isEmpty else { return nil }
        func degrees(_ feature: PoseFeature) -> String {
            ScoringEngine.extract(feature, from: model.bodyFrame).map { "\(Int($0.rounded()))°" } ?? "–"
        }
        func ratio(_ feature: PoseFeature) -> String {
            ScoringEngine.extract(feature, from: model.bodyFrame).map { String(format: "%.2f", $0) } ?? "–"
        }
        // vTaper / chestOpen : les cibles des lat spreads et des poses Zyzz
        // supposent un ratio épaules / hanches Vision proche de 2, à confirmer.
        return "yaw \(degrees(.bodyYaw)) · twist \(degrees(.torsoTwist)) · vT \(ratio(.vTaper)) · ch \(ratio(.chestOpen))"
        #else
        return nil
        #endif
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

    /// La photo propre, sauf après un lock forcé hors démo : rien n'a été vu en
    /// direct, donc la carte montre la photo avec son squelette.
    private var lockCardImage: UIImage? {
        #if DEBUG
        if model.lastLockWasForced, model.demoPreviewImage == nil {
            return model.lastOverlay ?? model.lastClean
        }
        #endif
        return model.lastClean
    }

    private var lockOverlay: some View {
        VStack(spacing: 16) {
            if let shown = lockCardImage {
                Image(uiImage: shown)
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
                        .font(Theme.bodyFont)
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
            PoseLockAnalytics.capture(.lockSaved)
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
                                    PoseReferenceImage(poseID: pose.poseID, variant: .guided)
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

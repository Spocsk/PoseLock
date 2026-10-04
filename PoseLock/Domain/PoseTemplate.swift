import Foundation
import simd

struct FeatureTarget: Sendable, Equatable {
    let feature: PoseFeature
    /// Degrés (0…180) ou ratio selon la feature.
    let target: Float
    let tolerance: Float
    let weight: Float
    let cue: String
    let region: SkeletonRegion
}

struct PoseTemplate: Sendable, Equatable {
    let poseID: PoseID
    let version: String
    let features: [FeatureTarget]

    /// Le même template, côté gauche et côté droit échangés. Un side chest se
    /// montre des deux côtés, et la caméra avant (image miroir) inverse ce que
    /// Vision appelle gauche et droite : le scoring garde le meilleur des deux.
    var mirrored: PoseTemplate {
        PoseTemplate(poseID: poseID, version: version, features: features.map(\.mirrored))
    }

    /// Faux pour un template symétrique : rien à gagner à le noter deux fois.
    var hasSide: Bool { mirrored != self }
}

extension FeatureTarget {
    var mirrored: FeatureTarget {
        FeatureTarget(
            feature: feature.mirrored,
            target: target,
            tolerance: tolerance,
            weight: weight,
            cue: SideWording.swap(cue),
            region: region.mirrored
        )
    }
}

extension PoseFeature {
    var mirrored: PoseFeature {
        switch self {
        case .leftElbow: return .rightElbow
        case .rightElbow: return .leftElbow
        case .leftKnee: return .rightKnee
        case .rightKnee: return .leftKnee
        case .leftShoulderAbduction: return .rightShoulderAbduction
        case .rightShoulderAbduction: return .leftShoulderAbduction
        case .leftWristHeight: return .rightWristHeight
        case .rightWristHeight: return .leftWristHeight
        default: return self
        }
    }
}

extension SkeletonRegion {
    var mirrored: SkeletonRegion {
        switch self {
        case .leftArm: return .rightArm
        case .rightArm: return .leftArm
        case .leftLeg: return .rightLeg
        case .rightLeg: return .leftLeg
        default: return self
        }
    }
}

/// Échange « gauche » et « droit(e) » seulement quand ils désignent un côté du
/// corps : « Buste droit » ou « Bassin droit » veulent dire rectiligne.
enum SideWording {
    private static let pairs: [(String, String)] = [
        ("bras gauche", "bras droit"),
        ("jambe gauche", "jambe droite"),
        ("poignet gauche", "poignet droit"),
        ("coude gauche", "coude droit"),
        ("main gauche", "main droite"),
        ("à gauche", "à droite")
    ]

    static func swap(_ text: String) -> String {
        var out = text
        var placeholders: [(String, String)] = []
        for (index, (left, right)) in pairs.enumerated() {
            for (a, b) in [(left, right), (right, left)] {
                for (from, to) in [(a, b), (a.capitalizedFirst, b.capitalizedFirst)] {
                    let token = "\u{1}\(index)\(placeholders.count)\u{1}"
                    guard out.contains(from) else { continue }
                    out = out.replacingOccurrences(of: from, with: token)
                    placeholders.append((token, to))
                }
            }
        }
        for (token, to) in placeholders {
            out = out.replacingOccurrences(of: token, with: to)
        }
        return out
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// Templates gold v1 — une variante par pose, tolérances larges.
/// Les poids viennent d’un référentiel posing, pas d’un goût personnel.
/// Variantes morpho (brachial court/long, taille haute/basse) = post-V1.
enum TemplateLibrary {
    static func template(for poseID: PoseID) -> PoseTemplate {
        PoseTemplate(poseID: poseID, version: ScoringConstants.templateVersion, features: features(for: poseID))
    }

    static func features(for poseID: PoseID) -> [FeatureTarget] {
        switch poseID {
        case .quarterTurnFace:
            return [
                t(.bodyYaw, 0, 12, 1.2, "Face caméra. Buste droit.", .torso),
                t(.shoulderLevel, 0, 12, 1.0, "Niveau les épaules.", .shoulders),
                t(.spineInclination, 4, 12, 0.8, "Grandis-toi. Poitrine haute.", .torso),
                t(.leftElbow, 165, 20, 0.6, "Relâche le bras gauche.", .leftArm),
                t(.rightElbow, 165, 20, 0.6, "Relâche le bras droit.", .rightArm),
                t(.stanceWidth, 0.18, 0.10, 0.7, "Rapproche les pieds, genoux tendus.", .hips)
            ]
        case .quarterTurnProfile:
            return [
                t(.bodyYaw, 80, 18, 1.3, "Profil. Poitrine vers l’avant.", .torso),
                t(.spineInclination, 6, 12, 0.9, "Étire la ligne de dos.", .torso),
                t(.shoulderLevel, 8, 14, 0.8, "Épaule avant un peu plus haute.", .shoulders),
                t(.leftElbow, 160, 25, 0.5, "Bras longs, pas cassés.", .leftArm),
                t(.rightElbow, 160, 25, 0.5, "Bras longs, pas cassés.", .rightArm)
            ]
        case .quarterTurnBack:
            return [
                t(.bodyYaw, 178, 14, 1.2, "Dos caméra. Buste droit.", .torso),
                t(.shoulderLevel, 0, 12, 1.0, "Épaules larges, même hauteur.", .shoulders),
                t(.spineInclination, 8, 12, 1.0, "Creuse légèrement le dos.", .torso),
                t(.chestOpen, 0.42, 0.12, 0.9, "Ouvre le haut du dos.", .shoulders),
                t(.stanceWidth, 0.18, 0.10, 0.7, "Pieds proches, genoux tendus.", .hips)
            ]
        case .frontDoubleBiceps:
            return [
                t(.leftElbow, 58, 16, 1.4, "Plie davantage le bras gauche.", .leftArm),
                t(.rightElbow, 58, 16, 1.4, "Plie davantage le bras droit.", .rightArm),
                t(.leftShoulderAbduction, 92, 16, 1.2, "Monte le bras gauche.", .leftArm),
                t(.rightShoulderAbduction, 92, 16, 1.2, "Monte le bras droit.", .rightArm),
                t(.leftWristHeight, 0.12, 0.18, 0.8, "Poignet gauche au-dessus de l’épaule.", .leftArm),
                t(.rightWristHeight, 0.12, 0.18, 0.8, "Poignet droit au-dessus de l’épaule.", .rightArm),
                t(.bodyYaw, 0, 14, 1.0, "Face caméra. Buste carré.", .torso),
                t(.shoulderLevel, 0, 10, 1.1, "Niveau les épaules.", .shoulders),
                t(.leftKnee, 160, 16, 0.6, "Avance légèrement la jambe gauche.", .leftLeg),
                t(.rightKnee, 170, 12, 0.6, "Garde la jambe droite tendue.", .rightLeg),
                t(.stanceWidth, 0.34, 0.12, 0.6, "Un pied en avant et sur le côté.", .hips)
            ]
        case .frontLatSpread:
            return [
                t(.leftElbow, 95, 18, 1.1, "Coude gauche à la taille.", .leftArm),
                t(.rightElbow, 95, 18, 1.1, "Coude droit à la taille.", .rightArm),
                t(.chestOpen, 0.52, 0.10, 1.5, "Écarte les lats. Plus large.", .shoulders),
                t(.vTaper, 2.15, 0.28, 1.2, "Ouvre le haut, serre la taille.", .torso),
                t(.bodyYaw, 0, 12, 1.0, "Face caméra.", .torso),
                t(.shoulderLevel, 0, 10, 1.0, "Épaules égales.", .shoulders),
                t(.stanceWidth, 0.18, 0.10, 0.6, "Pieds alignés et proches.", .hips)
            ]
        case .sideChest:
            return [
                t(.bodyYaw, 78, 16, 1.4, "Profil. Poitrine vers la caméra.", .torso),
                t(.leftElbow, 90, 18, 1.1, "Plie le bras avant à angle droit.", .leftArm),
                t(.rightElbow, 90, 20, 0.8, "Ramène l’autre main sur le poignet.", .rightArm),
                t(.chestOpen, 0.40, 0.12, 1.3, "Ouvre la cage. Gonfle.", .torso),
                t(.spineInclination, 10, 12, 0.9, "Arc léger, poitrine haute.", .torso),
                t(.leftKnee, 150, 18, 0.7, "Plie la jambe visible, appui sur les orteils.", .leftLeg)
            ]
        case .backDoubleBiceps:
            return [
                t(.bodyYaw, 175, 16, 1.2, "Dos plein cadre.", .torso),
                t(.leftElbow, 58, 16, 1.3, "Plie le bras gauche.", .leftArm),
                t(.rightElbow, 58, 16, 1.3, "Plie le bras droit.", .rightArm),
                t(.leftShoulderAbduction, 90, 16, 1.1, "Monte le bras gauche.", .leftArm),
                t(.rightShoulderAbduction, 90, 16, 1.1, "Monte le bras droit.", .rightArm),
                t(.spineInclination, 12, 12, 1.0, "Creuse le dos.", .torso),
                t(.shoulderLevel, 0, 10, 1.0, "Épaules égales.", .shoulders),
                t(.rightKnee, 158, 16, 0.7, "Recule un pied et monte sur les orteils.", .rightLeg),
                t(.stanceWidth, 0.30, 0.12, 0.5, "Stabilise le pied d’appui.", .hips)
            ]
        case .backLatSpread:
            return [
                t(.bodyYaw, 175, 16, 1.2, "Dos à la caméra.", .torso),
                t(.leftElbow, 90, 18, 1.0, "Mains à la taille.", .leftArm),
                t(.rightElbow, 90, 18, 1.0, "Mains à la taille.", .rightArm),
                t(.chestOpen, 0.55, 0.10, 1.5, "Écarte les lats.", .shoulders),
                t(.spineInclination, 10, 12, 0.9, "Légère cambrure.", .torso),
                t(.rightKnee, 152, 16, 0.6, "Recule un pied, talon levé.", .rightLeg),
                t(.stanceWidth, 0.24, 0.10, 0.5, "Garde les pieds proches.", .hips)
            ]
        case .sideTriceps:
            return [
                t(.bodyYaw, 82, 16, 1.3, "Profil. Épaule avant vers nous.", .torso),
                t(.leftElbow, 172, 12, 1.4, "Tends le bras avant.", .leftArm),
                t(.rightElbow, 105, 20, 0.7, "Saisis le poignet derrière le dos.", .rightArm),
                t(.spineInclination, 8, 12, 0.8, "Poitrine haute.", .torso),
                t(.leftKnee, 160, 16, 0.6, "Plie légèrement la jambe avant.", .leftLeg),
                t(.rightKnee, 150, 18, 0.6, "Recule l’autre pied sur les orteils.", .rightLeg)
            ]
        case .absAndThigh:
            return [
                t(.bodyYaw, 0, 12, 1.0, "Face caméra. Buste carré.", .torso),
                t(.spineInclination, 10, 10, 1.1, "Crunch léger. Contracte les abdos.", .torso),
                t(.leftShoulderAbduction, 138, 18, 0.8, "Place les deux mains derrière la tête.", .leftArm),
                t(.rightShoulderAbduction, 138, 18, 0.8, "Garde les coudes ouverts.", .rightArm),
                t(.leftElbow, 35, 18, 0.8, "Main gauche derrière la tête.", .leftArm),
                t(.rightElbow, 35, 18, 0.8, "Main droite derrière la tête.", .rightArm),
                t(.leftKnee, 155, 16, 1.2, "Avance une jambe. Contracte le quad.", .leftLeg),
                t(.rightKnee, 170, 14, 0.8, "Jambe arrière tendue.", .rightLeg)
            ]
        case .mostMuscular:
            return [
                t(.bodyYaw, 5, 14, 0.9, "Face. Caisse vers la caméra.", .torso),
                t(.leftElbow, 105, 20, 1.2, "Rapproche les poings.", .leftArm),
                t(.rightElbow, 105, 20, 1.2, "Rapproche les poings.", .rightArm),
                t(.chestOpen, 0.48, 0.12, 1.3, "Ouvre la cage. Trapèzes.", .shoulders),
                t(.spineInclination, 12, 12, 1.0, "Penche un peu. Most muscular.", .torso),
                t(.leftShoulderAbduction, 40, 16, 0.9, "Coudes devant le torse.", .leftArm),
                t(.rightShoulderAbduction, 40, 16, 0.9, "Coudes devant le torse.", .rightArm)
            ]
        case .threeQuarterLat:
            return [
                t(.bodyYaw, 38, 16, 1.3, "Trois-quarts. Montre le lat.", .torso),
                t(.leftShoulderAbduction, 70, 18, 1.1, "Ouvre le bras avant.", .leftArm),
                t(.chestOpen, 0.46, 0.12, 1.2, "Lat étalé, taille étroite.", .shoulders),
                t(.vTaper, 1.92, 0.28, 1.1, "V-taper. Écarte le haut.", .torso),
                t(.spineInclination, 8, 12, 0.8, "Poitrine haute.", .torso)
            ]
        case .sideChestMirror:
            return [
                t(.bodyYaw, 85, 16, 1.3, "Profil miroir. Poitrine.", .torso),
                t(.leftElbow, 90, 18, 1.1, "Bras avant plié.", .leftArm),
                t(.chestOpen, 0.40, 0.12, 1.2, "Gonfle la cage.", .torso),
                t(.spineInclination, 10, 12, 0.9, "Arc léger.", .torso)
            ]
        case .mostMuscularCrop:
            return [
                t(.bodyYaw, 8, 14, 0.9, "Face. Haut du corps.", .torso),
                t(.leftElbow, 105, 20, 1.2, "Poings rapprochés.", .leftArm),
                t(.rightElbow, 105, 20, 1.2, "Poings rapprochés.", .rightArm),
                t(.chestOpen, 0.50, 0.12, 1.3, "Ouvre trapèzes et pecs.", .shoulders),
                t(.spineInclination, 14, 12, 1.0, "Penche vers l’objectif.", .torso)
            ]
        case .vacuum:
            return [
                t(.bodyYaw, 70, 18, 1.0, "Profil ou trois-quarts.", .torso),
                t(.spineInclination, 4, 10, 1.4, "Expire. Rentre la taille.", .torso),
                t(.vTaper, 1.65, 0.30, 1.3, "Taille étroite. Vacuum.", .torso),
                t(.leftElbow, 155, 22, 0.5, "Bras longs, hors du ventre.", .leftArm),
                t(.rightElbow, 155, 22, 0.5, "Bras longs, hors du ventre.", .rightArm)
            ]
        case .backDoubleThreeQuarter:
            return [
                t(.bodyYaw, 140, 18, 1.3, "Dos trois-quarts.", .torso),
                t(.leftElbow, 60, 16, 1.2, "Plie le bras visible.", .leftArm),
                t(.rightElbow, 60, 16, 1.2, "Plie l’autre bras.", .rightArm),
                t(.spineInclination, 12, 12, 1.0, "Creuse le dos.", .torso),
                t(.chestOpen, 0.48, 0.12, 1.0, "Lats ouverts.", .shoulders)
            ]
        case .handsOnHips:
            return [
                t(.bodyYaw, 12, 14, 1.0, "Face, légère rotation.", .torso),
                t(.leftElbow, 100, 16, 1.1, "Main gauche à la hanche.", .leftArm),
                t(.rightElbow, 100, 16, 1.1, "Main droite à la hanche.", .rightArm),
                t(.vTaper, 1.50, 0.26, 1.2, "Ouvre les épaules.", .shoulders),
                t(.shoulderLevel, 0, 10, 1.0, "Épaules égales.", .shoulders),
                t(.stanceWidth, 0.30, 0.12, 0.7, "Pieds écartés.", .hips)
            ]
        case .frontPosture:
            return [
                t(.bodyYaw, 0, 12, 1.2, "Face. Buste carré.", .torso),
                t(.shoulderLevel, 0, 8, 1.4, "Niveau les épaules.", .shoulders),
                t(.hipLevel, 0, 8, 1.2, "Bassin droit.", .hips),
                t(.spineInclination, 2, 8, 1.3, "Grandis-toi. Oreilles au-dessus des épaules.", .torso),
                t(.headAlignment, 0, 8, 1.0, "Tête dans l’axe.", .head),
                t(.leftElbow, 168, 14, 0.6, "Bras le long du corps.", .leftArm),
                t(.rightElbow, 168, 14, 0.6, "Bras le long du corps.", .rightArm),
                t(.stanceWidth, 0.22, 0.10, 0.7, "Pieds sous les hanches.", .hips)
            ]
        case .profilePosture:
            return [
                t(.bodyYaw, 88, 14, 1.3, "Profil franc.", .torso),
                t(.spineInclination, 4, 10, 1.3, "Oreille au-dessus de l’épaule.", .torso),
                t(.headAlignment, 4, 10, 1.0, "Regarde loin. Nuque longue.", .head),
                t(.shoulderLevel, 6, 12, 0.8, "Épaules empilées.", .shoulders),
                t(.leftElbow, 168, 14, 0.5, "Bras longs.", .leftArm)
            ]
        case .shoulderToWaist:
            return [
                t(.bodyYaw, 0, 12, 1.0, "Corps entier, face.", .torso),
                t(.vTaper, 2.0, 0.24, 1.6, "Ouvre les épaules, serre la taille.", .shoulders),
                t(.chestOpen, 0.48, 0.12, 1.2, "Écarte un peu les bras.", .shoulders),
                t(.shoulderLevel, 0, 10, 1.1, "Symétrie gauche / droite.", .shoulders),
                t(.hipLevel, 0, 10, 0.9, "Bassin droit.", .hips),
                t(.spineInclination, 3, 10, 0.8, "Grandis-toi.", .torso)
            ]
        case .clavicleOpen:
            return [
                t(.bodyYaw, 8, 12, 0.8, "Face, légère ouverture.", .torso),
                t(.chestOpen, 0.50, 0.10, 1.5, "Ouvre les clavicules. Cage large.", .shoulders),
                t(.leftShoulderAbduction, 28, 14, 1.0, "Écarte un peu le bras gauche.", .leftArm),
                t(.rightShoulderAbduction, 28, 14, 1.0, "Écarte un peu le bras droit.", .rightArm),
                t(.spineInclination, 4, 10, 1.0, "Sternum haut.", .torso),
                t(.shoulderLevel, 0, 10, 1.0, "Épaules égales.", .shoulders)
            ]
        case .shoulderSymmetry:
            return [
                t(.shoulderLevel, 0, 6, 1.6, "Mets les épaules à la même hauteur.", .shoulders),
                t(.hipLevel, 0, 8, 1.2, "Bassin droit.", .hips),
                t(.bodyYaw, 0, 10, 1.1, "Face. Pas de torsion.", .torso),
                t(.leftShoulderAbduction, 18, 12, 0.9, "Même écart à gauche.", .leftArm),
                t(.rightShoulderAbduction, 18, 12, 0.9, "Même écart à droite.", .rightArm),
                t(.headAlignment, 0, 8, 0.8, "Tête au centre.", .head)
            ]
        case .twistThreeQuarter:
            return [
                t(.bodyYaw, 12, 14, 0.8, "Hanches presque face.", .hips),
                t(.torsoTwist, 42, 14, 1.4, "Tourne le buste, hanches plus face.", .torso),
                t(.shoulderLevel, 6, 12, 0.9, "Épaule avant un peu plus proche.", .shoulders),
                t(.chestOpen, 0.44, 0.12, 1.1, "Ouvre le côté visible.", .shoulders),
                t(.spineInclination, 6, 12, 0.8, "Poitrine haute.", .torso),
                t(.headAlignment, 0, 14, 0.7, "Tête droite.", .head)
            ]
        case .zyzzClassic:
            return [
                t(.bodyYaw, 38, 16, 1.3, "Trois-quarts. Poitrine vers la caméra.", .torso),
                t(.leftShoulderAbduction, 155, 18, 1.3, "Lève le bras gauche en diagonale au-dessus de la tête.", .leftArm),
                t(.leftElbow, 165, 18, 1.2, "Allonge le bras gauche, coude souple.", .leftArm),
                t(.rightShoulderAbduction, 125, 18, 1.3, "Monte aussi le coude droit, vers l’extérieur.", .rightArm),
                t(.rightElbow, 75, 18, 1.1, "Plie le bras droit, main au-dessus de la tête.", .rightArm),
                t(.chestOpen, 0.50, 0.12, 1.3, "Ouvre la cage.", .shoulders),
                t(.vTaper, 2.08, 0.28, 1.2, "Épaules larges, taille rentrée.", .torso),
                t(.spineInclination, 6, 12, 1.0, "Expire. Rentre la taille.", .torso),
                t(.shoulderLevel, 8, 12, 0.8, "Épaule avant un peu plus haute.", .shoulders)
            ]
        case .zyzzVacuum:
            return [
                t(.bodyYaw, 0, 12, 1.1, "Face caméra. Buste carré.", .torso),
                t(.spineInclination, 4, 10, 1.4, "Expire. Rentre la taille.", .torso),
                t(.vTaper, 2.0, 0.28, 1.4, "Taille étroite. Vacuum.", .torso),
                t(.chestOpen, 0.48, 0.12, 1.1, "Cage haute, lats ouverts.", .shoulders),
                t(.leftElbow, 165, 20, 0.6, "Bras longs, hors du ventre.", .leftArm),
                t(.rightElbow, 165, 20, 0.6, "Bras longs, hors du ventre.", .rightArm),
                t(.shoulderLevel, 0, 10, 1.0, "Épaules égales.", .shoulders)
            ]
        case .zyzzTwist:
            return [
                t(.bodyYaw, 20, 16, 0.8, "Hanches presque face.", .hips),
                t(.torsoTwist, 35, 16, 1.5, "Twist plus marqué. Poitrine vers la caméra.", .torso),
                t(.chestOpen, 0.46, 0.12, 1.2, "Ouvre le côté visible.", .shoulders),
                t(.shoulderLevel, 10, 12, 0.9, "Ligne d’épaule avant plus haute.", .shoulders),
                t(.vTaper, 1.92, 0.26, 1.1, "Serre la taille.", .torso),
                t(.spineInclination, 8, 12, 0.9, "Poitrine haute.", .torso),
                t(.headAlignment, 0, 14, 0.8, "Tête droite.", .head)
            ]
        }
    }

    private static func t(
        _ feature: PoseFeature,
        _ target: Float,
        _ tolerance: Float,
        _ weight: Float,
        _ cue: String,
        _ region: SkeletonRegion
    ) -> FeatureTarget {
        FeatureTarget(feature: feature, target: target, tolerance: tolerance, weight: weight, cue: cue, region: region)
    }
}

/// Silhouette 3D/2D à partir des cibles du template — illustration coach, home, paywall.
enum PosePreviewBuilder {
    private static let upperArm: Float = 0.33
    private static let forearm: Float = 0.32
    private static let thigh: Float = 0.45
    private static let shin: Float = 0.45

    static func frame(for poseID: PoseID) -> BodyFrame {
        let features = TemplateLibrary.features(for: poseID)
        func target(_ feature: PoseFeature, _ fallback: Float) -> Float {
            features.first { $0.feature == feature }?.target ?? fallback
        }
        func optional(_ feature: PoseFeature) -> Float? {
            features.first { $0.feature == feature }?.target
        }

        let bodyYaw: Float = target(.bodyYaw, 0)
        let torsoTwist: Float = target(.torsoTwist, 0)
        let hipHalf: Float = 0.12
        let stance: Float = target(.stanceWidth, 0.26)
        let vTaper: Float = target(.vTaper, 1.7)
        let chest = optional(.chestOpen)
        var shoulderHalf: Float = chest.map { $0 / 2 } ?? (vTaper * hipHalf)
        shoulderHalf = min(max(shoulderHalf, 0.18), 0.34)

        var joints: [Joint: SIMD3<Float>] = [:]
        joints[.root] = .zero
        joints[.leftHip] = SIMD3<Float>(-hipHalf, 0, 0)
        joints[.rightHip] = SIMD3<Float>(hipHalf, 0, 0)

        let hipLevel: Float = target(.hipLevel, 0)
        if hipLevel > 0.4 {
            let dy = (hipLevel / 90) * (hipHalf * 2)
            joints[.rightHip]!.y += dy / 2
            joints[.leftHip]!.y -= dy / 2
        }

        let inc = target(.spineInclination, 3) * Float.pi / 180
        // +z = vers la caméra. Les poses de crunch penchent en avant, les autres
        // se grandissent avec le haut du dos légèrement en arrière.
        let lean: Float = leansForward(poseID) ? 1 : -1
        let spineDir = SIMD3<Float>(0, cos(inc), lean * sin(inc))
        joints[.spine] = spineDir * 0.40
        joints[.neck] = spineDir * 0.75
        let headInc = target(.headAlignment, 0) * Float.pi / 180
        joints[.head] = joints[.neck]! + SIMD3<Float>(sin(headInc), cos(headInc), lean * sin(inc) * 0.15) * 0.26

        let shoulderY: Float = 0.72
        joints[.leftShoulder] = SIMD3<Float>(-shoulderHalf, shoulderY, 0)
        joints[.rightShoulder] = SIMD3<Float>(shoulderHalf, shoulderY, 0)
        let shoulderLevel: Float = target(.shoulderLevel, 0)
        if shoulderLevel > 0.4 {
            // Après la rotation `bodyYaw`, c'est l'épaule gauche qui fait face à la
            // caméra : c'est elle que les cues « épaule avant plus haute » relèvent.
            let dy = (shoulderLevel / 90) * (shoulderHalf * 2)
            joints[.leftShoulder]!.y += dy / 2
            joints[.rightShoulder]!.y -= dy / 2
        }

        let leftElbowAngle = target(.leftElbow, 168)
        let rightElbowAngle = target(.rightElbow, 168)
        let leftAbd = inferredAbduction(elbow: leftElbowAngle, specified: optional(.leftShoulderAbduction))
        let rightAbd = inferredAbduction(elbow: rightElbowAngle, specified: optional(.rightShoulderAbduction))

        let leftNape = leftAbd >= 70 && leftElbowAngle < 70
        let rightNape = rightAbd >= 70 && rightElbowAngle < 70
        let leftArm = arm(
            shoulder: joints[.leftShoulder]!,
            hip: joints[.leftHip]!,
            neck: joints[.neck]!,
            isLeft: true,
            abduction: leftAbd,
            elbowAngle: leftElbowAngle,
            wristHeight: poseID == .frontDoubleBiceps ? nil : optional(.leftWristHeight),
            place: poseID == .zyzzClassic ? .automatic : wristPlace(
                elbow: leftElbowAngle,
                abduction: leftAbd,
                exclusiveNape: leftNape && !rightNape
            )
        )
        joints[.leftElbow] = leftArm.elbow
        joints[.leftWrist] = leftArm.wrist

        let rightArm = arm(
            shoulder: joints[.rightShoulder]!,
            hip: joints[.rightHip]!,
            neck: joints[.neck]!,
            isLeft: false,
            abduction: rightAbd,
            elbowAngle: rightElbowAngle,
            wristHeight: poseID == .frontDoubleBiceps ? nil : optional(.rightWristHeight),
            place: poseID == .zyzzClassic ? .automatic : wristPlace(
                elbow: rightElbowAngle,
                abduction: rightAbd,
                exclusiveNape: rightNape && !leftNape
            )
        )
        joints[.rightElbow] = rightArm.elbow
        joints[.rightWrist] = rightArm.wrist

        let leftLeg = leg(
            hip: joints[.leftHip]!,
            isLeft: true,
            kneeAngle: target(.leftKnee, 172),
            ankleX: -stance / 2
        )
        joints[.leftKnee] = leftLeg.knee
        joints[.leftAnkle] = leftLeg.ankle

        let rightLeg = leg(
            hip: joints[.rightHip]!,
            isLeft: false,
            kneeAngle: target(.rightKnee, 172),
            ankleX: stance / 2
        )
        joints[.rightKnee] = rightLeg.knee
        joints[.rightAnkle] = rightLeg.ankle

        // Les contacts mains/corps définissent la pose : un angle seul ne
        // distingue pas une main dans la nuque d'un biceps contracté.
        switch poseID {
        case .sideChest, .sideChestMirror:
            joints[.leftElbow] = SIMD3(-0.30, 0.40, 0.16)
            joints[.rightElbow] = SIMD3(0.27, 0.29, 0.12)
            joints[.leftWrist] = SIMD3(-0.02, 0.34, 0.34)
            joints[.rightWrist] = SIMD3(0.02, 0.34, 0.34)
            joints[.leftAnkle]!.z += 0.18
        case .sideTriceps:
            joints[.leftElbow] = SIMD3(-0.22, 0.39, -0.10)
            joints[.leftWrist] = SIMD3(-0.14, 0.08, -0.18)
            joints[.rightElbow] = SIMD3(0.30, 0.35, -0.16)
            joints[.rightWrist] = SIMD3(-0.10, 0.08, -0.18)
            joints[.rightAnkle]!.z -= 0.18
        case .absAndThigh:
            joints[.leftElbow] = SIMD3(-0.40, 0.91, 0)
            joints[.rightElbow] = SIMD3(0.40, 0.91, 0)
            joints[.leftWrist] = joints[.neck]! + SIMD3(-0.05, 0.06, -0.12)
            joints[.rightWrist] = joints[.neck]! + SIMD3(0.05, 0.06, -0.12)
            joints[.leftAnkle]!.z += 0.22
        case .frontDoubleBiceps:
            joints[.leftAnkle]!.z += 0.18
        case .backDoubleBiceps, .backLatSpread:
            joints[.rightAnkle]!.z -= 0.18
        case .mostMuscular, .mostMuscularCrop:
            joints[.leftElbow] = SIMD3(-0.34, 0.43, 0.12)
            joints[.rightElbow] = SIMD3(0.34, 0.43, 0.12)
            joints[.leftWrist] = SIMD3(-0.06, 0.29, 0.30)
            joints[.rightWrist] = SIMD3(0.06, 0.29, 0.30)
        default: break
        }

        let yawJoints: [Joint] = [
            .spine, .neck, .head,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist
        ]
        for joint in Joint.allCases {
            if let p = joints[joint] {
                joints[joint] = rotateY(p, degrees: bodyYaw)
            }
        }
        for joint in yawJoints {
            if let p = joints[joint] {
                joints[joint] = rotateY(p, degrees: torsoTwist)
            }
        }

        let normalized = ScoringEngine.normalize(joints: joints)
        return BodyFrame(
            joints3D: normalized,
            joints2D: projectFitted(normalized),
            confidence: 0.95,
            subjectHeightRatio: 0.72,
            handsVisible: true,
            feetVisible: true
        )
    }

    private static func leansForward(_ poseID: PoseID) -> Bool {
        switch poseID {
        case .mostMuscular, .mostMuscularCrop, .absAndThigh: return true
        default: return false
        }
    }

    /// 0 = bras le long du corps, 90 = horizontal, ~90+ légèrement relevé.
    private static func inferredAbduction(elbow: Float, specified: Float?) -> Float {
        if let specified { return specified }
        if elbow < 75 { return 92 }
        if elbow < 125 { return 48 }
        return 16
    }

    private enum WristPlace {
        case automatic
        case nape
        case hip
    }

    /// Nuque seulement si un seul bras est candidat — sinon FDB / BDB resteraient collés à la tête.
    private static func wristPlace(elbow: Float, abduction: Float, exclusiveNape: Bool) -> WristPlace {
        if exclusiveNape { return .nape }
        if elbow >= 85 && elbow <= 120 && abduction < 70 { return .hip }
        return .automatic
    }

    static func lerp(
        _ from: [Joint: SIMD3<Float>],
        _ to: [Joint: SIMD3<Float>],
        t: Float
    ) -> [Joint: SIMD3<Float>] {
        let clamped = min(max(t, 0), 1)
        var out: [Joint: SIMD3<Float>] = [:]
        for joint in Joint.allCases {
            guard let a = from[joint], let b = to[joint] else { continue }
            out[joint] = a + (b - a) * clamped
        }
        return out
    }

    private static func arm(
        shoulder: SIMD3<Float>,
        hip: SIMD3<Float>,
        neck: SIMD3<Float>,
        isLeft: Bool,
        abduction: Float,
        elbowAngle: Float,
        wristHeight: Float?,
        place: WristPlace
    ) -> (elbow: SIMD3<Float>, wrist: SIMD3<Float>) {
        let side: Float = isLeft ? -1 : 1
        switch place {
        case .nape:
            let elbow = shoulder + SIMD3<Float>(side * 0.16, 0.24, 0.10)
            let wrist = neck + SIMD3<Float>(side * 0.03, -0.02, 0.12)
            return (elbow, wrist)
        case .hip:
            let elbow = shoulder + SIMD3<Float>(side * 0.22, -0.10, 0.08)
            let wrist = hip + SIMD3<Float>(side * 0.06, 0.08, 0.06)
            return (elbow, wrist)
        case .automatic:
            break
        }
        let a = abduction * Float.pi / 180
        let fistsInFront = abduction < 55 && elbowAngle < 85
        var upperDir = SIMD3<Float>(side * sin(a), -cos(a), fistsInFront ? 0.45 * sin(max(a, 0.2)) : 0)
        upperDir = simd_normalize(upperDir)
        let elbow = shoulder + upperArm * upperDir

        let u = simd_normalize(elbow - shoulder)
        let bend = (180 - elbowAngle) * Float.pi / 180
        var toward: SIMD3<Float>
        if elbowAngle < 80 {
            toward = SIMD3<Float>(-side * 0.15, 1, fistsInFront ? 0.4 : 0)
        } else if elbowAngle < 125 {
            toward = hip - elbow
        } else {
            toward = u
        }
        var plane = toward - u * simd_dot(toward, u)
        if simd_length(plane) < 0.08 {
            plane = SIMD3<Float>(0, 1, 0) - u * simd_dot(SIMD3<Float>(0, 1, 0), u)
        }
        if simd_length(plane) < 0.04 {
            plane = SIMD3<Float>(side, 0, 0)
        }
        plane = simd_normalize(plane)
        var forearmDir = simd_normalize(u * cos(bend) + plane * sin(bend))
        var wrist = elbow + forearm * forearmDir

        if let wristHeight {
            let desiredY = shoulder.y + wristHeight
            let dy = (desiredY - elbow.y) / forearm
            let clamped = min(max(dy, -0.98), 0.98)
            let rest = sqrt(max(0, 1 - clamped * clamped))
            var hz = SIMD2<Float>(forearmDir.x, forearmDir.z)
            let hl = simd_length(hz)
            if hl > 0.01 {
                hz = (hz / hl) * rest
            } else {
                hz = SIMD2<Float>(side * rest * 0.25, 0)
            }
            forearmDir = simd_normalize(SIMD3<Float>(hz.x, clamped, hz.y))
            wrist = elbow + forearm * forearmDir
        }
        return (elbow, wrist)
    }

    private static func leg(
        hip: SIMD3<Float>,
        isLeft: Bool,
        kneeAngle: Float,
        ankleX: Float
    ) -> (knee: SIMD3<Float>, ankle: SIMD3<Float>) {
        let ankle = SIMD3<Float>(ankleX, hip.y - (thigh + shin) * 0.98, 0)
        let hipToAnkle = ankle - hip
        var dist = simd_length(hipToAnkle)
        let maxReach = thigh + shin - 0.01
        if dist > maxReach {
            dist = maxReach
        }
        dist = max(dist, 0.08)
        let dir = simd_normalize(hipToAnkle)
        let x = (dist * dist + thigh * thigh - shin * shin) / (2 * dist)
        let heightSq = max(0, thigh * thigh - x * x)
        let height = sqrt(heightSq)
        let side: Float = isLeft ? -1 : 1
        var perp = SIMD3<Float>(-dir.y * side, dir.x * side, 0.12)
        if simd_length(perp) < 0.01 {
            perp = SIMD3<Float>(side, 0, 0)
        }
        perp = simd_normalize(perp)
        let visibleBend = max(0, (180 - kneeAngle) / 25)
        let knee = hip + dir * x + perp * (height * min(visibleBend, 1))
        return (knee, ankle)
    }

    /// Aligne le bassin du skeleton capturé sur celui de la référence. Vision
    /// place le sujet selon son orientation devant l’objectif, ce qui n’a rien
    /// à voir avec la pose : sans ce recalage les deux silhouettes ne seraient
    /// pas comparables. La torsion buste / bassin, elle, est préservée.
    static func alignYawToHips(
        _ joints: [Joint: SIMD3<Float>],
        like reference: [Joint: SIMD3<Float>]
    ) -> [Joint: SIMD3<Float>] {
        guard let delta = hipYaw(reference).flatMap({ ref in hipYaw(joints).map { ref - $0 } }) else {
            return joints
        }
        return joints.mapValues { rotateY($0, degrees: delta) }
    }

    private static func hipYaw(_ joints: [Joint: SIMD3<Float>]) -> Float? {
        guard let left = joints[.leftHip], let right = joints[.rightHip] else { return nil }
        let dx = right.x - left.x
        let dz = right.z - left.z
        guard dx * dx + dz * dz > 0.0001 else { return nil }
        return atan2(dz, dx) * 180 / .pi
    }

    static func rotateY(_ p: SIMD3<Float>, degrees: Float) -> SIMD3<Float> {
        let r = degrees * Float.pi / 180
        let c = cos(r)
        let s = sin(r)
        return SIMD3<Float>(p.x * c + p.z * s, p.y, -p.x * s + p.z * c)
    }

    /// Projette en 0…1, Y vers le bas, en tenant compte de Z pour les ¾.
    static func projectFitted(_ joints3D: [Joint: SIMD3<Float>], yaw: Float = 0) -> [Joint: SIMD2<Float>] {
        projectFitted([joints3D], yaw: yaw).first ?? [:]
    }

    /// Même cadre pour tous les jeux de joints : indispensable pour comparer
    /// deux skeletons, sinon chacun serait recadré sur sa propre bounding box
    /// et l’écart disparaîtrait.
    static func projectFitted(_ sets: [[Joint: SIMD3<Float>]], yaw: Float = 0) -> [[Joint: SIMD2<Float>]] {
        let projected: [[Joint: SIMD2<Float>]] = sets.map { set in
            set.mapValues { p -> SIMD2<Float> in
                let r = yaw == 0 ? p : rotateY(p, degrees: yaw)
                return SIMD2<Float>(r.x + r.z * 0.38, r.y)
            }
        }
        let all = projected.flatMap(\.values)
        guard let minX = all.map(\.x).min(),
              let maxX = all.map(\.x).max(),
              let minY = all.map(\.y).min(),
              let maxY = all.map(\.y).max() else {
            return sets.map { _ in [:] }
        }
        let width = max(maxX - minX, 0.18)
        let height = max(maxY - minY, 0.18)
        let cx = (minX + maxX) / 2
        let scale = max(width / 0.76, height / 0.84)
        return projected.map { set in
            var out: [Joint: SIMD2<Float>] = [:]
            for (joint, p) in set {
                let nx = 0.5 + (p.x - cx) / scale
                let ny = 0.10 + (maxY - p.y) / scale
                out[joint] = SIMD2<Float>(min(max(nx, 0.04), 0.96), min(max(ny, 0.04), 0.96))
            }
            return out
        }
    }
}

extension BodyFrame {
    static func preview(for poseID: PoseID) -> BodyFrame {
        PosePreviewBuilder.frame(for: poseID)
    }
}

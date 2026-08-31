import Foundation

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
                t(.torsoTwist, 20, 18, 1.2, "Ouvre un quart vers la caméra.", .torso),
                t(.shoulderLevel, 0, 12, 1.0, "Niveau les épaules.", .shoulders),
                t(.spineInclination, 4, 12, 0.8, "Grandis-toi. Poitrine haute.", .torso),
                t(.leftElbow, 165, 20, 0.6, "Relâche le bras gauche.", .leftArm),
                t(.rightElbow, 165, 20, 0.6, "Relâche le bras droit.", .rightArm),
                t(.stanceWidth, 0.28, 0.12, 0.7, "Écarte un peu les pieds.", .hips)
            ]
        case .quarterTurnProfile:
            return [
                t(.torsoTwist, 80, 18, 1.3, "Profil. Poitrine vers l’avant.", .torso),
                t(.spineInclination, 6, 12, 0.9, "Étire la ligne de dos.", .torso),
                t(.shoulderLevel, 8, 14, 0.8, "Épaule avant un peu plus haute.", .shoulders),
                t(.leftElbow, 160, 25, 0.5, "Bras longs, pas cassés.", .leftArm),
                t(.rightElbow, 160, 25, 0.5, "Bras longs, pas cassés.", .rightArm)
            ]
        case .quarterTurnBack:
            return [
                t(.torsoTwist, 160, 20, 1.2, "Dos à la caméra, un quart.", .torso),
                t(.shoulderLevel, 0, 12, 1.0, "Épaules larges, même hauteur.", .shoulders),
                t(.spineInclination, 8, 12, 1.0, "Creuse légèrement le dos.", .torso),
                t(.chestOpen, 0.42, 0.12, 0.9, "Ouvre le haut du dos.", .shoulders)
            ]
        case .frontDoubleBiceps:
            return [
                t(.leftElbow, 58, 16, 1.4, "Plie davantage le bras gauche.", .leftArm),
                t(.rightElbow, 58, 16, 1.4, "Plie davantage le bras droit.", .rightArm),
                t(.leftShoulderAbduction, 92, 16, 1.2, "Monte le bras gauche.", .leftArm),
                t(.rightShoulderAbduction, 92, 16, 1.2, "Monte le bras droit.", .rightArm),
                t(.leftWristHeight, 0.12, 0.18, 0.8, "Poignet gauche au-dessus de l’épaule.", .leftArm),
                t(.rightWristHeight, 0.12, 0.18, 0.8, "Poignet droit au-dessus de l’épaule.", .rightArm),
                t(.torsoTwist, 0, 14, 1.0, "Face caméra. Buste carré.", .torso),
                t(.shoulderLevel, 0, 10, 1.1, "Niveau les épaules.", .shoulders),
                t(.leftKnee, 168, 14, 0.6, "Tends la jambe gauche.", .leftLeg),
                t(.rightKnee, 168, 14, 0.6, "Tends la jambe droite.", .rightLeg)
            ]
        case .frontLatSpread:
            return [
                t(.leftElbow, 95, 18, 1.1, "Coude gauche à la taille.", .leftArm),
                t(.rightElbow, 95, 18, 1.1, "Coude droit à la taille.", .rightArm),
                t(.chestOpen, 0.52, 0.10, 1.5, "Écarte les lats. Plus large.", .shoulders),
                t(.vTaper, 1.55, 0.28, 1.2, "Ouvre le haut, serre la taille.", .torso),
                t(.torsoTwist, 0, 12, 1.0, "Face caméra.", .torso),
                t(.shoulderLevel, 0, 10, 1.0, "Épaules égales.", .shoulders)
            ]
        case .sideChest:
            return [
                t(.torsoTwist, 78, 16, 1.4, "Profil. Poitrine vers la caméra.", .torso),
                t(.leftElbow, 70, 18, 1.1, "Plie le bras avant.", .leftArm),
                t(.rightElbow, 155, 20, 0.8, "Bras arrière long.", .rightArm),
                t(.chestOpen, 0.40, 0.12, 1.3, "Ouvre la cage. Gonfle.", .torso),
                t(.spineInclination, 10, 12, 0.9, "Arc léger, poitrine haute.", .torso),
                t(.leftKnee, 165, 16, 0.7, "Jambe avant tendue.", .leftLeg)
            ]
        case .backDoubleBiceps:
            return [
                t(.torsoTwist, 175, 16, 1.2, "Dos plein cadre.", .torso),
                t(.leftElbow, 58, 16, 1.3, "Plie le bras gauche.", .leftArm),
                t(.rightElbow, 58, 16, 1.3, "Plie le bras droit.", .rightArm),
                t(.leftShoulderAbduction, 90, 16, 1.1, "Monte le bras gauche.", .leftArm),
                t(.rightShoulderAbduction, 90, 16, 1.1, "Monte le bras droit.", .rightArm),
                t(.spineInclination, 12, 12, 1.0, "Creuse le dos.", .torso),
                t(.shoulderLevel, 0, 10, 1.0, "Épaules égales.", .shoulders)
            ]
        case .backLatSpread:
            return [
                t(.torsoTwist, 175, 16, 1.2, "Dos à la caméra.", .torso),
                t(.leftElbow, 100, 18, 1.0, "Mains à la taille.", .leftArm),
                t(.rightElbow, 100, 18, 1.0, "Mains à la taille.", .rightArm),
                t(.chestOpen, 0.55, 0.10, 1.5, "Écarte les lats.", .shoulders),
                t(.spineInclination, 10, 12, 0.9, "Légère cambrure.", .torso)
            ]
        case .sideTriceps:
            return [
                t(.torsoTwist, 82, 16, 1.3, "Profil. Épaule avant vers nous.", .torso),
                t(.leftElbow, 172, 12, 1.4, "Tends le bras avant.", .leftArm),
                t(.rightElbow, 70, 20, 0.7, "Bras arrière en appui.", .rightArm),
                t(.spineInclination, 8, 12, 0.8, "Poitrine haute.", .torso),
                t(.leftKnee, 168, 14, 0.6, "Jambe avant longue.", .leftLeg)
            ]
        case .absAndThigh:
            return [
                t(.torsoTwist, 8, 14, 1.0, "Face caméra, légèrement de trois-quarts.", .torso),
                t(.spineInclination, 6, 10, 1.1, "Rentrez le bassin. Abs.", .torso),
                t(.leftElbow, 88, 18, 0.8, "Main derrière la tête ou à la hanche.", .leftArm),
                t(.rightElbow, 160, 20, 0.6, "Autre bras long.", .rightArm),
                t(.leftKnee, 155, 16, 1.2, "Plie la jambe avant. Quad.", .leftLeg),
                t(.rightKnee, 170, 14, 0.8, "Jambe arrière tendue.", .rightLeg)
            ]
        case .mostMuscular:
            return [
                t(.torsoTwist, 5, 14, 0.9, "Face. Caisse vers la caméra.", .torso),
                t(.leftElbow, 72, 16, 1.2, "Rapproche les poings.", .leftArm),
                t(.rightElbow, 72, 16, 1.2, "Rapproche les poings.", .rightArm),
                t(.chestOpen, 0.48, 0.12, 1.3, "Ouvre la cage. Trapèzes.", .shoulders),
                t(.spineInclination, 12, 12, 1.0, "Penche un peu. Most muscular.", .torso),
                t(.leftShoulderAbduction, 40, 16, 0.9, "Coudes devant le torse.", .leftArm),
                t(.rightShoulderAbduction, 40, 16, 0.9, "Coudes devant le torse.", .rightArm)
            ]
        case .threeQuarterLat:
            return [
                t(.torsoTwist, 38, 16, 1.3, "Trois-quarts. Montre le lat.", .torso),
                t(.leftShoulderAbduction, 70, 18, 1.1, "Ouvre le bras avant.", .leftArm),
                t(.chestOpen, 0.46, 0.12, 1.2, "Lat étalé, taille étroite.", .shoulders),
                t(.vTaper, 1.48, 0.28, 1.1, "V-taper. Écarte le haut.", .torso),
                t(.spineInclination, 8, 12, 0.8, "Poitrine haute.", .torso)
            ]
        case .sideChestMirror:
            return [
                t(.torsoTwist, 85, 16, 1.3, "Profil miroir. Poitrine.", .torso),
                t(.leftElbow, 68, 18, 1.1, "Bras avant plié.", .leftArm),
                t(.chestOpen, 0.40, 0.12, 1.2, "Gonfle la cage.", .torso),
                t(.spineInclination, 10, 12, 0.9, "Arc léger.", .torso)
            ]
        case .mostMuscularCrop:
            return [
                t(.torsoTwist, 8, 14, 0.9, "Face. Haut du corps.", .torso),
                t(.leftElbow, 70, 16, 1.2, "Poings rapprochés.", .leftArm),
                t(.rightElbow, 70, 16, 1.2, "Poings rapprochés.", .rightArm),
                t(.chestOpen, 0.50, 0.12, 1.3, "Ouvre trapèzes et pecs.", .shoulders),
                t(.spineInclination, 14, 12, 1.0, "Penche vers l’objectif.", .torso)
            ]
        case .vacuum:
            return [
                t(.torsoTwist, 70, 18, 1.0, "Profil ou trois-quarts.", .torso),
                t(.spineInclination, 4, 10, 1.4, "Expire. Rentre la taille.", .torso),
                t(.vTaper, 1.65, 0.30, 1.3, "Taille étroite. Vacuum.", .torso),
                t(.leftElbow, 155, 22, 0.5, "Bras longs, hors du ventre.", .leftArm),
                t(.rightElbow, 155, 22, 0.5, "Bras longs, hors du ventre.", .rightArm)
            ]
        case .backDoubleThreeQuarter:
            return [
                t(.torsoTwist, 140, 18, 1.3, "Dos trois-quarts.", .torso),
                t(.leftElbow, 60, 16, 1.2, "Plie le bras visible.", .leftArm),
                t(.rightElbow, 60, 16, 1.2, "Plie l’autre bras.", .rightArm),
                t(.spineInclination, 12, 12, 1.0, "Creuse le dos.", .torso),
                t(.chestOpen, 0.48, 0.12, 1.0, "Lats ouverts.", .shoulders)
            ]
        case .handsOnHips:
            return [
                t(.torsoTwist, 12, 14, 1.0, "Face, légère rotation.", .torso),
                t(.leftElbow, 100, 16, 1.1, "Main gauche à la hanche.", .leftArm),
                t(.rightElbow, 100, 16, 1.1, "Main droite à la hanche.", .rightArm),
                t(.vTaper, 1.50, 0.26, 1.2, "Ouvre les épaules.", .shoulders),
                t(.shoulderLevel, 0, 10, 1.0, "Épaules égales.", .shoulders),
                t(.stanceWidth, 0.30, 0.12, 0.7, "Pieds écartés.", .hips)
            ]
        case .frontPosture:
            return [
                t(.torsoTwist, 0, 12, 1.2, "Face. Buste carré.", .torso),
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
                t(.torsoTwist, 88, 14, 1.3, "Profil franc.", .torso),
                t(.spineInclination, 4, 10, 1.3, "Oreille au-dessus de l’épaule.", .torso),
                t(.headAlignment, 4, 10, 1.0, "Regarde loin. Nuque longue.", .head),
                t(.shoulderLevel, 6, 12, 0.8, "Épaules empilées.", .shoulders),
                t(.leftElbow, 168, 14, 0.5, "Bras longs.", .leftArm)
            ]
        case .shoulderToWaist:
            return [
                t(.torsoTwist, 0, 12, 1.0, "Corps entier, face.", .torso),
                t(.vTaper, 1.52, 0.24, 1.6, "Ouvre les épaules, serre la taille.", .shoulders),
                t(.chestOpen, 0.48, 0.12, 1.2, "Écarte un peu les bras.", .shoulders),
                t(.shoulderLevel, 0, 10, 1.1, "Symétrie gauche / droite.", .shoulders),
                t(.hipLevel, 0, 10, 0.9, "Bassin droit.", .hips),
                t(.spineInclination, 3, 10, 0.8, "Grandis-toi.", .torso)
            ]
        case .clavicleOpen:
            return [
                t(.torsoTwist, 8, 12, 0.8, "Face, légère ouverture.", .torso),
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
                t(.torsoTwist, 0, 10, 1.1, "Face. Pas de torsion.", .torso),
                t(.leftShoulderAbduction, 18, 12, 0.9, "Même écart à gauche.", .leftArm),
                t(.rightShoulderAbduction, 18, 12, 0.9, "Même écart à droite.", .rightArm),
                t(.headAlignment, 0, 8, 0.8, "Tête au centre.", .head)
            ]
        case .twistThreeQuarter:
            return [
                t(.torsoTwist, 42, 14, 1.4, "Tourne le buste, hanches plus face.", .torso),
                t(.shoulderLevel, 6, 12, 0.9, "Épaule avant un peu plus proche.", .shoulders),
                t(.chestOpen, 0.44, 0.12, 1.1, "Ouvre le côté visible.", .shoulders),
                t(.spineInclination, 6, 12, 0.8, "Poitrine haute.", .torso),
                t(.headAlignment, 20, 14, 0.7, "Regard par-dessus l’épaule avant.", .head)
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

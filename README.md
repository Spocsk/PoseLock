# PoseLock

Application iOS de posing. *Pose. Score. Lock.*

iPhone, iOS 17+, SwiftUI, Vision Body Pose 3D, SwiftData, StoreKit 2. On-device. Pas de backend.

## Ouvrir

1. Cloner le dépôt.
2. Ouvrir `PoseLock.xcodeproj` dans **Xcode 15+**.
3. Sélectionner un Development Team (Signing).
4. Le scheme `PoseLock` charge `PoseLock/Store/Products.storekit` pour tester l’abonnement sans App Store.

Bundle ID : `com.spocsk.PoseLock`.

## Vérifier sur Mac

Simulateur : onboarding → accueil → réglages → caméra (preview). Vision 3D est souvent vide au simulateur.

**iPhone réel (A12+)** :

1. Cadre, skeleton, 3 poses (une par pack si Pro, sinon le pack onboarding), 3 locks en moins de 3 minutes.
2. Journal : 2 stills (clean + overlay), comparatif J-7 vide le premier jour.
3. 4ᵉ lock free → feuille Pro.
4. Refus caméra puis relance depuis le CTA.
5. Tests : `PoseLockTests` (scoring, pose du jour, quota).

## Architecture

Quatre surfaces : onboarding, accueil, caméra (full screen, hors tab bar), réglages. Journal et bibliothèque de poses = feuilles.

Le score juge la ligne, jamais la personne. Templates gold `v1`, une variante par pose, division Scène = Classic Physique.

## Landing

Site statique dans `docs/`, publié sur Vercel avec deux fonctions pour la liste d’attente. Le projet Vercel `poselock` pointe sur ce dossier avec le preset `Other`.

URL : [https://poselock.app/](https://poselock.app/)

En local :

```bash
python3 -m http.server 8080 --directory docs
```

Puis ouvrir `http://127.0.0.1:8080`. Le bouton App Store du héros est volontairement inactif (pas de fiche pour l’instant). Le formulaire demande une fonction Vercel et ne fonctionne pas avec ce serveur statique.

En production, configurer `RESEND_API_KEY`, `RESEND_SEGMENT_ID`, `WAITLIST_TOKEN_SECRET` (32 octets en base64url) et `PUBLIC_ORIGIN=https://poselock.app` dans Vercel. Le segment Resend reçoit uniquement les adresses confirmées. Les futurs Broadcasts doivent inclure la désinscription et attendre la sortie effective de l’app.

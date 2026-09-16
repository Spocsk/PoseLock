# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

Application : Swift / SwiftUI, Xcode, iOS 17+, bundle `com.spocsk.PoseLock`.
Landing marketing : HTML/CSS/JS statique dans `docs/`, GitHub Pages, sans build Node. Motion : GSAP (ScrollTrigger), anime.js, snippets CSS [transitions.dev](https://transitions.dev). Choix confirmé pour l’hébergement « pour le moment ».

## Users

Bodybuilders et poseurs qui préparent une compétition Classic / une prise de contenu / leur forme. Ils tiennent une pose face à un iPhone, seuls, souvent dans une salle ou chez eux, et n’ont personne pour juger la ligne en direct.

## Product Purpose

PoseLock note l’exécution d’une pose bodybuilding en direct, on-device, et lock une photo quand le score tient assez longtemps au-dessus du seuil. Succès : la personne corrige la ligne pendant la séance, pas une semaine plus tard sur des photos.

## Positioning

Le score juge la ligne contre un template d’angles, jamais la personne. Vision Body Pose tourne sur l’iPhone ; la vidéo de séance ne quitte jamais l’appareil. Un voisin « coach IA dans le cloud » ne peut pas copier ça sans mentir.

## Operating Context

Séance caméra plein écran (hors tab bar). Accueil, journal, réglages. Packs Scène, Contenu, Physique à l’onboarding ; Zyzz est un catalogue de poses Pro, pas un partenariat. Lock gratuit plafonné. Export d’image toujours signé PoseLock.

## Capabilities and Constraints

- Seuil de lock : 85 / 100, hold 1,5 s.
- Gratuit : 3 locks par jour, un pack parmi Scène / Contenu / Physique.
- Pro (entitlement RevenueCat `pro`) : locks illimités, les trois packs, comparatif J-30, rappels d’échéance, catalogue Zyzz.
- Aucun serveur applicatif. Le seul réseau est RevenueCat (historique d’achat). Pas d’analytics, pas de crash reporter.
- Overlay caméra = stickman. Previews de poses = silhouette capsule 2D (`PoseFigure`), jamais une photo d’autrui ni un perso 3D.
- Vacuum : consigne coach, Vision ne le score pas.
- Compte Apple skippable ; entitlement Sign in with Apple absent tant qu’il n’y a pas d’équipe payante.
- Prix, durées d’essai : jamais écrits en dur ; ils viennent du Store.
- Landing : pas de fiche App Store à ce jour. CTA = « Bientôt sur l’App Store », sans lien.

## Brand Commitments

Nom : PoseLock. Ligne : « Pose. Score. Lock. » Voix française, sèche, minuscules d’ambiance. Fond quasi noir, ivoire, un or froid, vert lock / rouge cadre. Zyzz = nom de pose, pas une affiliation (pas de photo d’Aziz, pas de « officiel »).

## Evidence on Hand

- Copie d’app : splash, onboarding, paywall, réglages (`PoseLock/`).
- Photo de splash : `PoseLock/Assets.xcassets/SplashPose.imageset/splash-pose.jpg` (décor de scène, pas un utilisateur nommé).
- Icône : `PoseLock/Assets.xcassets/AppIcon.appiconset/`.
- Démo chiffrée autorisée : scores d’onboarding 62 → 91, toujours étiquetés « Exemple ».
- Absences à ne pas fabriquer : avis, notes App Store, nombre d’utilisateurs, témoignages, URL TestFlight, prix.

## Product Principles

1. Le score mesure la pose, pas le corps.
2. Ce qui se filme reste sur l’iPhone.
3. Une preuve n’existe que si on peut la tenir.
4. Pro n’invente pas de bénéfice (signature sur tous les exports, vacuum non scorable).
5. La landing vend le mécanisme, pas une grille d’icônes.

## Accessibility & Inclusion

Respecter `prefers-reduced-motion` (crossfade, pas de pin spatial). Contraste ivoire sur noir. Cibles 44px. Pas de dépendance à la couleur seule pour le lock (mot LOCK + vert).

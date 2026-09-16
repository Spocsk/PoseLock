---
name: PoseLock
description: "Pose. Score. Lock. — salle éteinte, tableau de juge."
colors:
  bg: "#0A0A0A"
  elevated: "#171717"
  ivory: "#E8E3DB"
  ivory-muted: "rgba(232, 227, 219, 0.76)"
  ivory-faint: "rgba(232, 227, 219, 0.60)"
  gold: "#C4B08B"
  gold-muted: "rgba(196, 176, 139, 0.76)"
  gold-disabled: "rgba(196, 176, 139, 0.38)"
  lock: "#8CC794"
  frame-red: "#C74747"
  hairline: "rgba(232, 227, 219, 0.12)"
typography:
  display:
    fontFamily: "Big Shoulders Display, Arial Narrow, sans-serif"
    fontSize: "clamp(2.6rem, 8vw, 6rem)"
    fontWeight: 900
    lineHeight: 0.9
    letterSpacing: "0.06em"
  headline:
    fontFamily: "Big Shoulders Display, Arial Narrow, sans-serif"
    fontSize: "clamp(2.4rem, 6vw, 5rem)"
    fontWeight: 900
    lineHeight: 0.92
    letterSpacing: "0.01em"
  title:
    fontFamily: "Big Shoulders Display, Arial Narrow, sans-serif"
    fontSize: "clamp(1.8rem, 3vw, 2.6rem)"
    fontWeight: 700
    lineHeight: 1.05
    letterSpacing: "normal"
  score:
    fontFamily: "Big Shoulders Display, Arial Narrow, sans-serif"
    fontSize: "6rem"
    fontWeight: 300
    lineHeight: 1
    letterSpacing: "-0.04em"
  body:
    fontFamily: "Source Sans 3, Segoe UI, sans-serif"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: "normal"
  label:
    fontFamily: "Source Sans 3, Segoe UI, sans-serif"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "0.16em"
rounded:
  control: "16px"
  tabs: "48px"
  pill: "999px"
spacing:
  page: "clamp(20px, 4vw, 40px)"
  nav: "64px"
  measure: "68ch"
  target: "44px"
components:
  button-primary:
    backgroundColor: "{colors.gold}"
    textColor: "{colors.bg}"
    rounded: "{rounded.pill}"
    padding: "0 1.15rem"
    height: "44px"
  button-primary-disabled:
    backgroundColor: "{colors.gold-disabled}"
    textColor: "{colors.bg}"
    rounded: "{rounded.pill}"
    padding: "0 1.15rem"
    height: "44px"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.ivory-muted}"
    rounded: "{rounded.pill}"
    padding: "0 1.15rem"
    height: "44px"
  toast-lock:
    backgroundColor: "{colors.elevated}"
    textColor: "{colors.lock}"
    rounded: "{rounded.control}"
    padding: "0.7rem 1rem"
  tab-bar:
    backgroundColor: "{colors.elevated}"
    textColor: "{colors.ivory-faint}"
    rounded: "{rounded.tabs}"
    padding: "3px"
  tab-active:
    backgroundColor: "{colors.gold}"
    textColor: "{colors.bg}"
    rounded: "{rounded.tabs}"
    padding: "8px 16px"
    height: "44px"
  phone-hud:
    backgroundColor: "rgba(10, 10, 10, 0.88)"
    textColor: "{colors.ivory}"
    rounded: "{rounded.control}"
    padding: "14px 16px 16px"
---

# Design System: PoseLock

## Overview

**Creative North Star: "Salle éteinte, tableau de juge"**

PoseLock se lit comme une scène de gym au repos : quasi-noir, un projecteur, un chiffre. Le marketing web n’est pas une grille de features fitness. C’est un poster scrollé — photo de splash bord à bord, wordmark en Big Shoulders, score qui monte jusqu’au vert. L’app iOS reprend la même salle : fond appareil-photo, ivoire, un or froid, puis le vert seulement quand la pose tient.

La densité est sèche. Peu de chrome, beaucoup d’air vertical (8–18 vh entre les affiches). La lecture est Source Sans 3 ; le tableau de juge (wordmark, titres d’affiche, scores, LOCK) est Big Shoulders Display. Sur iOS, San Francisco et Dynamic Type tiennent ce rôle : l’app ne bundle pas les faces web. Ce n’est pas une seconde identité — c’est la même salle, en police système.

Rejets confirmés : social proof inventé, prix ou durée d’essai écrits en dur, second accent, perso 3D, photo d’autrui en preview de pose, overlay live en corps plein.

**Key Characteristics:**

- Un poster, pas des cartes.
- Un accent (or froid) ; vert et rouge sont des états de pose.
- Scoreboard condensé / lecture humaniste.
- Grain, vignette, une seule ombre sous le téléphone.
- Preuves chiffrées étiquetées « Exemple ».
- Overlay live = stickman ; preview = silhouette capsule 2D.

## Colors

Palette courte, saturée à l’os : noir de salle, ivoire de papier, or de métal, puis deux états (lock / hors cadre).

### Primary

- **Or froid** (`{colors.gold}`): seul accent de marque. CTA, wordmark secondaire (« Pose. Score. Lock. »), liens, pastille d’onglet active, focus ring, sélection de texte, badges Pro, filet de scrollbar. Sur iOS : `tint`, cartes de plan sélectionnées (fond 10 %, stroke 1,5 px à 65 % d’opacité), ShareMark.

### Neutral

- **Quasi-noir** (`{colors.bg}`): fond de page, fond d’app, texte sur or. Référence caméra iOS / Fitness+ au repos.
- **Élevé** (`{colors.elevated}`): toast, barre d’onglets, surfaces iOS (cartes, paywall, timeline d’essai). Un cran au-dessus du sol, pas une « card blanche ».
- **Ivoire** (`{colors.ivory}`): texte et titres. Preview de pose au repos.
- **Ivoire 76 %** (`{colors.ivory-muted}`): lede, consignes, body secondaire.
- **Ivoire 60 %** (`{colors.ivory-faint}`): micro-aide, footer, onglets inactifs, beats non courants.
- **Hairline ivoire 12 %** (`{colors.hairline}`): filets de listes, chassis du téléphone, bord du toast. Sur iOS, `Theme.hairline` est du blanc à 12 % — même rôle, pas un second token à mélanger sur le web.

### State (not a second accent)

- **Vert lock** (`{colors.lock}`): pose lockable. Score, mot LOCK, check, toast « Lock. », silhouette « après » du journal. Jamais un fond de section.
- **Rouge cadre** (`{colors.frame-red}`): hors champ / hors tolérance. Filet 2 px autour du viseur, erreurs de copie. Jamais un bouton primaire, jamais de décor.

**The One Accent Rule.** L’or est le seul accent de marque. Vert et rouge ne décorent pas : ils rapportent l’état de la pose.

**The Lock Is Earned Rule.** Le vert n’apparaît que pour un lock (ou un exemple étiqueté de cet état). Un écran au repos reste ivoire et or.

## Typography

**Display Font:** Big Shoulders Display (Arial Narrow, sans-serif)
**Body Font:** Source Sans 3 (Segoe UI, sans-serif)
**Native stand-in:** San Francisco, Dynamic Type — titre 22 / corps 15 / support 13 / caption 11 au corps standard. `captionFont` = micro-labels seulement.

**Character:** Condensé de tableau d’affichage contre humaniste de notice. Le score est léger (300) et collé (`-0.04em`) ; le poster est black (900) et un peu aéré.

### Hierarchy

- **Display** (900, `clamp(2.6rem, 8vw, 6rem)`, line-height 0.9, tracking 0.06em) : wordmark héro et close « Pose. Score. Lock. ».
- **Headline** (900, `clamp(2.4rem, 6vw, 5rem)`, line-height 0.92) : affiches de section. Le pin « Pose / Score / Lock » monte à `clamp(3rem, 9vw, 6rem)` / 0.88.
- **Title** (700, `clamp(1.8rem, 3vw, 2.6rem)`) : nom de catalogue. Sur iOS, `titleFont` (title2) porte les titres d’écran.
- **Score** (300, 6rem / 4.6rem sous 860px, tracking `-0.04em`, tabular nums) : reel héro, scores journal, HUD téléphone (3.4rem dans le chassis). Mot LOCK : 700, tracking 0.28em, vert.
- **Body** (400, 17px / 1.45 sur `html` ; ledes de section à 1.125rem ; listes de faits à 1.25rem). Mesure ~68ch, souvent plafonnée à 36rem. Support iOS : footnote 13.
- **Label** (11px minimum, uppercase, tracking 0.12–0.22em, or) : « Exemple », beats Pose/Score/Lock, note Pro, caption de score. Nav-mark POSELOCK : Display 700, 1.05rem, tracking 0.14em.

### Named Rules

**The Scoreboard Rule.** Big Shoulders (ou SF light/bold sur iOS) = chiffres, LOCK, posters, wordmark. Source Sans 3 (ou SF text) = tout ce qu’on lit.

**The Caption Floor Rule.** Rien d’essentiel sous 11px. Les captions 11px sont des micro-labels, pas du corps.

## Layout

Nav fixe 64px, dégradé noir 72 % → transparent, `pointer-events` seulement sur marque et CTA. Gouttière `clamp(20px, 4vw, 40px)`. Sur iOS, inset de page 24px, cible minimale 44px.

Héro : une grille 1.1fr / 0.7fr, copy en bas à gauche, reel à droite. Sous 860px, une colonne, reel à gauche, CTA nav masqué. Mécanisme : 280vh, objet pinté (téléphone 320px, 9/19.4) ; sous 860px le pin tombe, téléphone 280px. Catalogues : figure 3/4 (max 280px) + copy. Journal : deux prises séparées d’un filet 1×8rem (horizontal sous 860px).

Rythme : affiches, pas modules. Padding de section en vh (8–18). Listes caméra / confiance = filets hairline, pas de cartes. `prefers-reduced-motion` : pas de pin spatial, crossfade / opacités.

**The Poster Rule.** Une section = une affiche. Pas de grille de cards, pas d’icônes-feature.

## Elevation & Depth

Sol plat. La profondeur vient de la photo (object-position 62% 28%), d’une vignette radiale + bas, d’un grain overlay à 14 %, et d’une ombre unique sous le chassis.

### Shadow Vocabulary

- **Phone drop** (`box-shadow: 0 28px 70px rgba(0, 0, 0, 0.55)`): uniquement le téléphone pinté. Nulle part ailleurs sur la landing.
- **ShareMark** (export iOS) : ombre noire 50 %, rayon ~1 % du petit côté, plus un stroke UIKit sur photo — lisibilité sur mur clair, pas une élévation d’UI.

Nav = lave de fond, pas une barre ombrée. Surfaces = `elevated` + hairline 1px.

**The Flat Floor Rule.** Pas d’ombre de card. Une seule ombre structurelle : le téléphone. Le reste est tonal (bg / elevated) ou un filet.

## Shapes

Coins continus 16px (`--radius`, `Theme.continuousCorner`) : chassis, HUD, toast, cartes iOS, plan paywall, timeline. CTA et skip d’action : pilule 999px. Onglets catalogues : pilule 48px dans un rail 48px. Preview de pose dans le HUD : disque 56px, fill ivoire 8 %.

Le cadre du viseur est un inset 10px, radius 12px (16 − 4), stroke 2px transparent → rouge ou vert. Sélection : or sur noir. Focus visible : outline or 2px, offset 3px.

**The Continuous Sixteen Rule.** 16px continu pour tout chassis / HUD / surface. Pilule pour CTA et tabs. Pas de radius 8px de card (le skip-link 8px est un one-off d’accessibilité, pas une marche d’échelle).

## Components

Caractère : contrôles d’or en pilule, HUD de juge 16px, stickman live.

### Buttons

- **Shape:** pilule (`999px`), hauteur 44px, padding horizontal 1.15rem, Source Sans 600, tracking 0.01em.
- **Primary:** or, texte quasi-noir. Cursor default tant que le CTA Store est un état, pas un lien.
- **Disabled:** or 38 %, même texte. C’est l’état shipping (« Bientôt sur l’App Store »), pas un ghost.
- **Ghost:** fond transparent, ivoire 76 %, hairline 1px. Lien GitHub uniquement.
- **Hover / Focus:** pas de lift. `:focus-visible` = anneau or 2px / offset 3px.

### Chips / Tabs

Rail `elevated`, padding 3px, radius 48px. Onglets 44px de haut, 8×16, Source Sans 500 0.9375rem. Inactif : ivoire 60 %. Actif / hover : texte quasi-noir sur pastille or qui suit (250ms, `cubic-bezier(0.22, 1, 0.36, 1)`). Badge « Pro » : 11px, tracking 0.12em.

### Cards / Containers

Pas de cards sur la landing. Listes à filets. Téléphone : fond `#111`, hairline, ombre phone-drop, overflow hidden. HUD : noir 88 %, 16px, score 3.4rem light. Sur iOS, une « carte » = `elevated` + radius continu 16 + stroke hairline 1px (sélection : or 1,5 px). Padding interne 14–16.

### Inputs / Fields

Aucun champ texte sur la landing. Sur iOS, les choix (packs, plans) sont des surfaces 16px, pas des text fields — selected = stroke or 1,5 px.

### Navigation

Marque POSELOCK en Display 700, ivoire, tracking 0.14em. CTA Store à droite, masqué sous 860px. Pas de menu.

### Signature components

- **Score reel:** Big Shoulders 300, 6rem, cellule 6rem (4.6rem mobile), spin 1400ms, stagger 90ms. Au lock : chiffres verts, mot LOCK, check 22px stroke `#8CC794`.
- **Stickman / PoseFigure:** live = os ; preview = capsule 2D depuis les 17 joints. Vert = dans la tolérance, ivoire = hors, or = highlight de région. Jamais une photo, jamais un perso 3D.
- **ShareMark:** « PoseLock » or, coin bas-droit, corps `max(11, petit-côté × 0.032)`. Toute image qui sort de l’app est signée.

## Do's and Don'ts

### Do:

- **Do** traiter la page comme un poster de salle : une photo, un score, une phrase.
- **Do** étiqueter « Exemple » tout score qui n’est pas celui du visiteur (62, 87, 91 compris).
- **Do** réserver le vert au lock et le rouge au hors-cadre.
- **Do** garder le CTA Store disabled tant qu’il n’y a pas de fiche.
- **Do** respecter `prefers-reduced-motion` (plus de pin, plus de reel spatial).
- **Do** tirer prix, période et essai du Store, jamais du CSS ni du Swift.

### Don't:

- **Don't** inventer avis, note, nombre d’utilisateurs, témoignage, URL TestFlight.
- **Don't** introduire un second accent (bleu fitness, néon salle, gradient marketing).
- **Don't** poser un corps plein sur des joints Vision live.
- **Don't** présenter Zyzz comme un partenariat, une photo d’Aziz, ou un catalogue « officiel ».
- **Don't** écrire un prix, une durée d’essai ou un pourcentage en dur.
- **Don't** ombrer des cartes pour « donner du relief » — le sol est plat.
- **Don't** mixer Big Shoulders dans l’app native ni San Francisco comme face marketing web.

# Référence pour le brouillon de paywall RevenueCat

Objectif : reproduire **en brouillon non attaché** le paywall natif SwiftUI existant, pour conserver une référence éditable dans RevenueCat. Cette maquette ne pilote pas l'écran iOS actuel. Les offres, prix, essais et droits restent lus depuis l'offering `default` et ses `StoreProduct` par `StoreManager`. Ne jamais publier une maquette qui introduirait une promesse différente de l'app ou de l'App Store.

## Structure à reconstruire dans l'éditeur

1. Fond quasi noir `#0A0A0A`. Marges horizontales 24 px. Typographie système, titres 22, corps 15, support 13, microtexte 11.
2. En haut : retour à gauche, « Restaurer » à droite. Variante upsell : bouton « Fermer » et héros illustrant une pose front double biceps guidée, avec score de démonstration « lockable » ; éviter une photo de personne réelle ou une preuve sociale inventée.
3. Titre dynamique : « Passe en Pro » sans essai ; sinon « Essaie [durée] gratuitement. ». Sous-texte onboarding : « Le mode caméra, les catalogues, Zyzz et le journal, sans plafond, dès la première séance. » Les upsells utilisent un titre et une phrase adaptés à la raison (plafond, pack, échéance, Zyzz).
4. Si, et seulement si, le `StoreProduct` choisi porte un essai gratuit : carte chronologique à trois étapes « Aujourd’hui », « 24 h avant la fin », « À la fin de l’essai ». Texte conforme au rappel local et à la facturation réelle. En Test Store sans essai, masquer entièrement cette carte.
5. Deux cartes d'offre dans l'ordre RevenueCat, période en petites capitales, prix, équivalent mensuel lorsqu'il est calculable et badge de remise lorsqu'il existe. Sélection annuelle par défaut si dernière dans l'offering. Fond `#171717`, rayon 16 px ; carte sélectionnée : voile or et bordure or 1,5 px. Couleur or `#C4B08B`, texte ivoire `#E8E3DB`.
6. Cinq bénéfices exactement : « Locks illimités », « Scène, Contenu, Physique », « Comparatif J-30 », « Rappels d’échéance », « Catégorie Zyzz » — avec détails alignés sur `ProBenefit` dans `AppSession.swift`. Aucun avantage « sans marque » : toutes les images exportées portent la signature PoseLock.
7. Bas fixe : réassurance conditionnelle, CTA conditionnel (« Passer en Pro » / « Essayer [durée] gratuitement »), mention de prix et reconduction provenant du produit sélectionné, lien de restauration. Ne saisir **aucun prix, durée d'essai ou pourcentage en dur** dans l'éditeur.

## Limites à vérifier dans l'éditeur

Le constructeur RevenueCat peut ne pas exprimer exactement l'espacement de lettres des périodes, la bordure sélectionnée à 1,5 px, la sélection par défaut, les variantes de raison et la logique conditionnelle de l'essai. Si un bloc ne peut pas être rendu fidèlement, l'indiquer dans le brouillon ; ne pas modifier le paywall SwiftUI pour masquer l'écart. `RevenueCatUI` ne doit pas être réintroduit sans résoudre la régression de workflow déjà documentée dans `AGENTS.md`.

## Contrôles lors de la connexion MCP

- Confirmer le projet `PoseLock`, entitlement `pro`, offering `default`, packages `$rc_monthly` / `$rc_annual`, produits `poselock.pro.monthly` / `poselock.pro.yearly` et leurs disponibilités.
- Inspecter les champs de prix/essai réels, l'éventuel paywall attaché et la capacité de créer un brouillon non publié. Créer alors la maquette ci-dessus, comparer les aperçus aux deux vues natives et laisser l'offering actif inchangé.
- Contrôler le Test Store et une configuration App Store de production avant lancement. L'app Release attend toujours une clé `appl_…` et celle-ci n'est pas présente dans le dépôt.

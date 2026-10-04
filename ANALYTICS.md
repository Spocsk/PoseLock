# Mesure PoseLock : Mixpanel EU + RevenueCat

Le catalogue, les achats et les abonnements restent chez RevenueCat. Mixpanel mesure uniquement les usages auxquels la personne a consenti. Il n'y a **pas de liaison d'identité** entre le visiteur web, l'installation iOS et l'abonné RevenueCat. Les chiffres d'acquisition App Store restent à lire dans App Store Connect.

## Activation

1. Projet Mixpanel **PoseLock** créé en région EU (ID `4066589`, fuseau `Europe/Paris`) et son *project token public* configuré dans `docs/analytics.js` (`PROJECT_TOKEN`) et `PoseLock/Info.plist` (`MixpanelProjectToken`). Ne jamais placer une clé secrète ou de service dans ces fichiers. La validation locale du token accepte 16 à 64 caractères alphanumériques.
2. Vérifier que l'endpoint du projet est `https://api-eu.mixpanel.com`. Les transports web/iOS utilisent `POST /track?ip=0` avec `distinct_id` aléatoire, uniquement après accord. La propriété `environment` distingue `development` (localhost et build DEBUG) de `production`. Ils n'utilisent ni SDK de collecte, ni autocapture, ni session replay, ni file hors ligne. Le refus n'émet aucune requête ; le retrait annule les requêtes en cours et efface l'identifiant local. Une requête déjà reçue par Mixpanel ne peut pas être rétractée par ce mécanisme.
3. Dans le navigateur et sur simulateur, contrôler le trafic réseau en refusant, acceptant et retirant l'accord. Examiner aussi les propriétés réellement ingérées dans Mixpanel, puis actualiser si nécessaire les déclarations App Privacy / la politique de confidentialité avant publication.
4. Le tableau [PoseLock — lancement](https://eu.mixpanel.com/project/4066589/view/4563038/app/boards#id=11543857) est créé. Son premier rapport, `Visiteurs landing — production`, compte les visiteurs uniques de `page_viewed` sur 30 jours avec `environment=production`. Les visites locales de vérification restent donc exclues. Ajouter ensuite trafic par UTM, lecture vidéo, clic App Store, tunnel d'onboarding iOS, vues paywall → achats consentis, démarrages caméra, locks et partages lorsque ces événements seront réellement reçus. Séparer web/iOS : leurs identifiants ne sont pas reliés. L'événement `purchase_completed` ne constitue pas un bilan de revenus exhaustif : les achats sans consentement ne remontent pas.

Le MCP personnalisé `mixpanel-eu` est enregistré et authentifié dans Codex (`https://mcp-eu.mixpanel.com/mcp`). Le plugin Mixpanel standard pointe vers la région globale et ne peut pas interroger ce projet EU ; une nouvelle tâche Codex peut être nécessaire pour charger les outils du MCP personnalisé. Le projet a été validé dans l'interface Mixpanel EU : l'API d'ingestion a répondu avec succès et `page_viewed` est visible dans les événements de développement. Le flux iOS reste à contrôler sur simulateur avec accord explicite.

Le MCP officiel RevenueCat est enregistré (`https://mcp.revenuecat.ai/mcp`), mais son OAuth n'est pas encore autorisé. Sa connexion demande un accès RevenueCat de lecture/écriture ; le contrôle de l'offering et une éventuelle maquette du paywall dans l'éditeur attendent cette autorisation.

Événements web : `page_viewed`, `launch_video_played`, `waitlist_requested`, `app_store_clicked` (seulement quand le lien App Store sera actif). Propriétés web : chemin et UTM `source`, `medium`, `campaign` si leurs valeurs passent la liste autorisée. Événements iOS : `onboarding_started`, `onboarding_step_completed` (nom d'étape uniquement), `paywall_viewed`, `purchase_completed`, `camera_session_started`, `lock_saved`, `share_started`. Jamais de champ libre, image, vidéo, pose, score, objectif ni identifiant Apple.

## Intégration RevenueCat ↔ Mixpanel

Ne pas activer l'intégration serveur RevenueCat → Mixpanel par défaut : elle transmettrait les événements d'achat des personnes ayant refusé la mesure Mixpanel, car le consentement local ne contrôle pas ce flux serveur. Pour l'instant, RevenueCat reste la source de vérité du revenu/abonnement ; Mixpanel reçoit uniquement `purchase_completed` depuis l'app après consentement. Évaluer ultérieurement une liaison consentie et documentée si un besoin de cohorte revenu individualisée apparaît.

## Paywall RevenueCat

Le paywall iOS reste natif SwiftUI. `StoreManager.refreshOffers()` lit l'offering `default` (ou l'offering courant), et `PlanOffer` déduit prix, durée, remise et éventuel essai du `StoreProduct` RevenueCat. Une maquette dans l'éditeur RevenueCat peut servir de référence et de futur point de départ, mais elle ne remplace pas l'UI actuelle et ne doit pas être publiée/attachée à l'offering sans vérification visuelle et produit. `RevenueCatUI` a été retiré intentionnellement.

## Vérification rapide

```bash
node --test docs/tests/analytics.test.js
xcodebuild -scheme PoseLock -destination 'generic/platform=iOS Simulator' build
```

Le site est hébergé sur Vercel depuis `docs/`, à `https://poselock.vercel.app/`. GitHub Pages n’est plus utilisé. Le lien de confidentialité de l’app utilise l’adresse Vercel tant que `poselock.app` n’est pas connecté.

Search Console : une fois `poselock.app` connecté, vérifier `https://poselock.app/`, puis soumettre `https://poselock.app/sitemap.xml`. Les pages déclarent déjà ce futur domaine comme URL canonique.

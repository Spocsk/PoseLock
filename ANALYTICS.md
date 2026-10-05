# Mesure PoseLock : TelemetryDeck + RevenueCat

Le catalogue, les achats et les abonnements restent chez RevenueCat. TelemetryDeck mesure uniquement les usages auxquels la personne a consenti. Il n'y a **pas de liaison d'identité** entre l'installation iOS et l'abonné RevenueCat. Les chiffres d'acquisition (impressions, téléchargements, rétention) restent à lire dans App Store Connect.

Mixpanel EU a été utilisé en septembre 2026 puis remplacé par TelemetryDeck en octobre 2026 (interface plus simple, hébergement UE). Le site `docs/` n'envoie aucun événement.

## Activation

1. Organisation TelemetryDeck **Tech Master**, namespace `fr.dylan-cdo`. App **PoseLock**, App ID `72790DE8-2D17-4687-A8CD-321CF82831A3`, renseigné dans `PoseLock/Info.plist` (`TelemetryDeckAppID`). L'App ID est public par nature (il voyage dans chaque build). `PoseLockAnalytics.isConfigured` exige un UUID valide ; sinon le réglage reste grisé.
2. `PoseLockAnalytics` envoie directement à l'Ingest API v2 (`POST https://nom.telemetrydeck.com/v2/namespace/fr.dylan-cdo/`), sans SwiftSDK, sans autocapture ni file hors ligne. `clientUser` est le SHA-256 d'un identifiant aléatoire local ; `sessionID` change à chaque lancement. Les builds DEBUG envoient `isTestMode: true` : activer le *Test Mode* du tableau de bord pour les voir. Le refus n'émet aucune requête ; le retrait annule les requêtes en cours et efface l'identifiant local. Un signal déjà reçu ne peut pas être rétracté par ce mécanisme.
3. Les clés de consentement s'appellent `poselock.analyticsConsent` / `poselock.analyticsChoiceMade`. Les anciennes clés `poselock.mixpanel*` sont effacées au premier choix ; un appareil qui avait accepté Mixpanel repart donc sans accord (réactivable dans Réglages).
4. Le MCP TelemetryDeck permet de lister l'app et d'interroger les signaux (TQL). Il ne crée ni app ni tableau de bord : ceux-ci se configurent dans le dashboard TelemetryDeck.

Événements iOS (champ `type`) : `Onboarding.started`, `Onboarding.stepCompleted` (paramètre `Onboarding.step`, nom d'étape uniquement), `Paywall.viewed`, `Purchase.completed`, `Camera.sessionStarted`, `Lock.saved`, `Share.started`. Jamais de champ libre, image, vidéo, pose, score, objectif ni identifiant Apple. `Purchase.completed` ne constitue pas un bilan de revenus exhaustif : les achats sans consentement ne remontent pas, RevenueCat reste la source de vérité.

Le MCP officiel RevenueCat est enregistré (`https://mcp.revenuecat.ai/mcp`), mais son OAuth n'est pas encore autorisé.

## Intégration RevenueCat ↔ TelemetryDeck

Ne pas activer d'intégration serveur RevenueCat → outil d'analytics : elle transmettrait les achats des personnes ayant refusé la mesure, car le consentement local ne contrôle pas ce flux serveur.

## Paywall RevenueCat

Le paywall iOS reste natif SwiftUI. `StoreManager.refreshOffers()` lit l'offering `default` (ou l'offering courant), et `PlanOffer` déduit prix, durée, remise et éventuel essai du `StoreProduct` RevenueCat. Une maquette dans l'éditeur RevenueCat peut servir de référence et de futur point de départ, mais elle ne remplace pas l'UI actuelle et ne doit pas être publiée/attachée à l'offering sans vérification visuelle et produit. `RevenueCatUI` a été retiré intentionnellement.

## Vérification rapide

```bash
xcodebuild -scheme PoseLock -destination 'generic/platform=iOS Simulator' build
```

Le site est hébergé sur Vercel depuis `docs/`, à `https://poselock.vercel.app/`. GitHub Pages n’est plus utilisé. Le lien de confidentialité de l’app utilise l’adresse Vercel tant que `poselock.app` n’est pas connecté.

Search Console : une fois `poselock.app` connecté, vérifier `https://poselock.app/`, puis soumettre `https://poselock.app/sitemap.xml`. Les pages déclarent déjà ce futur domaine comme URL canonique.

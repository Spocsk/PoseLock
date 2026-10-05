(function () {
  "use strict";

  // App ID TelemetryDeck (public par nature, comme dans l'app iOS). Les signaux du
  // site portent `TelemetryDeck.Device.platform: "Web"` pour rester séparables.
  var APP_ID = "72790DE8-2D17-4687-A8CD-321CF82831A3";
  var ENDPOINT = "https://nom.telemetrydeck.com/v2/";
  var CONSENT_KEY = "poselock_analytics_consent";
  var VISITOR_KEY = "poselock_analytics_anonymous_id";
  // Un accord donné à Mixpanel ne vaut pas pour TelemetryDeck : on l'efface.
  var LEGACY_KEYS = ["poselock_mixpanel_consent_v2", "poselock_mixpanel_anonymous_id"];
  var SIGNALS = {
    page_viewed: "Web.pageViewed",
    launch_video_played: "Web.launchVideoPlayed",
    app_store_clicked: "Web.appStoreClicked",
    waitlist_requested: "Web.waitlistRequested"
  };
  var COPY = {
    fr: { label: "Préférences de statistiques", title: "Statistiques facultatives", body: "Avec ton accord, PoseLock mesure les pages consultées et les interactions principales avec TelemetryDeck (UE). Aucun replay, image, pose ou score. Tu peux retirer ton accord ici à tout moment.", more: "En savoir plus", accept: "Accepter", decline: "Refuser ou retirer", privacy: "/confidentialite/" },
    en: { label: "Analytics preferences", title: "Optional analytics", body: "With your consent, PoseLock measures pages viewed and key interactions with TelemetryDeck (EU). No replay, image, pose or score. You can withdraw consent here at any time.", more: "Learn more", accept: "Accept", decline: "Decline or withdraw", privacy: "/en/privacy/" },
    es: { label: "Preferencias de estadísticas", title: "Estadísticas opcionales", body: "Con tu consentimiento, PoseLock mide las páginas vistas y las interacciones principales con TelemetryDeck (UE). Sin grabaciones, imágenes, poses ni puntuaciones. Puedes retirarlo aquí cuando quieras.", more: "Más información", accept: "Aceptar", decline: "Rechazar o retirar", privacy: "/es/privacidad/" },
    de: { label: "Statistik-Einstellungen", title: "Optionale Statistiken", body: "Mit deiner Zustimmung misst PoseLock aufgerufene Seiten und wichtige Interaktionen mit TelemetryDeck (EU). Keine Aufzeichnung, keine Bilder, Posen oder Scores. Du kannst die Zustimmung hier jederzeit widerrufen.", more: "Mehr erfahren", accept: "Zustimmen", decline: "Ablehnen oder widerrufen", privacy: "/de/datenschutz/" },
    "pt-BR": { label: "Preferências de estatísticas", title: "Estatísticas opcionais", body: "Com o seu consentimento, o PoseLock mede as páginas vistas e as principais interações com a TelemetryDeck (UE). Sem gravação, imagens, poses ou pontuações. Você pode retirar o consentimento aqui a qualquer momento.", more: "Saiba mais", accept: "Aceitar", decline: "Recusar ou retirar", privacy: "/pt-br/privacidade/" }
  };
  var language = document.documentElement.lang || "fr";
  var copy = COPY[language] || COPY.fr;
  var banner;
  var volatileChoice = null;
  var volatileVisitor = null;
  var sessionID = window.crypto.randomUUID();
  var pending = [];

  if (!/^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/i.test(APP_ID)) return;

  LEGACY_KEYS.forEach(function (key) {
    try { localStorage.removeItem(key); } catch (_) { /* Rien à effacer. */ }
  });

  function choice() {
    try { return localStorage.getItem(CONSENT_KEY) || volatileChoice; } catch (_) { return volatileChoice; }
  }

  function remember(value) {
    volatileChoice = value;
    try { localStorage.setItem(CONSENT_KEY, value); } catch (_) { /* Ce chargement uniquement. */ }
  }

  function visitor() {
    try {
      var existing = localStorage.getItem(VISITOR_KEY);
      if (existing) return existing;
    } catch (_) { if (volatileVisitor) return volatileVisitor; }
    var id = window.crypto.randomUUID();
    volatileVisitor = id;
    try { localStorage.setItem(VISITOR_KEY, id); } catch (_) { /* Aucun stockage durable. */ }
    return id;
  }

  // TelemetryDeck attend un hash : l'identifiant aléatoire local ne part jamais en clair.
  function hashed(value) {
    return window.crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)).then(function (buffer) {
      return Array.prototype.map.call(new Uint8Array(buffer), function (byte) {
        return ("0" + byte.toString(16)).slice(-2);
      }).join("");
    });
  }

  function utm(name) {
    var value = new URLSearchParams(location.search).get("utm_" + name);
    return value && /^[a-zA-Z0-9_-]{1,60}$/.test(value) ? value : undefined;
  }

  function capture(name) {
    var type = SIGNALS[name];
    if (choice() !== "yes" || !type) return;
    var production = location.hostname === "poselock.app" || location.hostname === "poselock.vercel.app";
    var payload = {
      "TelemetryDeck.Device.platform": "Web",
      "TelemetryDeck.RunContext.language": language,
      "Web.path": location.pathname
    };
    ["source", "medium", "campaign"].forEach(function (key) {
      var value = utm(key);
      if (value) payload["Web.utm." + key] = value;
    });
    var controller = new AbortController();
    pending.push(controller);
    return hashed(visitor()).then(function (clientUser) {
      if (controller.signal.aborted) return;
      // Pas de keepalive : un corps JSON déclenche un preflight CORS, que keepalive refuse.
      return fetch(ENDPOINT, {
        method: "POST",
        mode: "cors",
        credentials: "omit",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify([{ appID: APP_ID, clientUser: clientUser, sessionID: sessionID, type: type, isTestMode: !production, payload: payload }]),
        signal: controller.signal
      });
    }).catch(function () { /* Pas de file hors ligne ni de nouvelle tentative. */ })
      .finally(function () { pending = pending.filter(function (item) { return item !== controller; }); });
  }

  function closeBanner() {
    if (banner) banner.remove();
    banner = null;
  }

  function setChoice(value) {
    remember(value);
    closeBanner();
    if (value === "yes") {
      return capture("page_viewed");
    }
    pending.forEach(function (controller) { controller.abort(); });
    pending = [];
    volatileVisitor = null;
    try { localStorage.removeItem(VISITOR_KEY); } catch (_) { /* Rien à effacer. */ }
  }

  function showPreferences() {
    closeBanner();
    banner = document.createElement("aside");
    banner.className = "analytics-banner";
    banner.setAttribute("aria-label", copy.label);
    banner.innerHTML = "<strong>" + copy.title + "</strong><p>" + copy.body + ' <a href="' + copy.privacy + '">' + copy.more + '</a>.</p><div><button type="button" data-accept>' + copy.accept + '</button><button type="button" data-decline>' + copy.decline + "</button></div>";
    banner.querySelector("[data-accept]").addEventListener("click", function () { setChoice("yes"); });
    banner.querySelector("[data-decline]").addEventListener("click", function () { setChoice("no"); });
    document.body.appendChild(banner);
  }

  document.querySelectorAll("[data-analytics-preferences]").forEach(function (button) {
    button.hidden = false;
    button.addEventListener("click", showPreferences);
  });
  window.poseLockAnalytics = { capture: capture };
  if (choice() === "yes") capture("page_viewed");
  else if (choice() !== "no") showPreferences();

  var video = document.querySelector(".launch-film video");
  if (video) video.addEventListener("play", function () { capture("launch_video_played"); }, { once: true });
  document.querySelectorAll("[data-app-store-link]").forEach(function (link) {
    link.addEventListener("click", function () { capture("app_store_clicked"); });
  });
})();

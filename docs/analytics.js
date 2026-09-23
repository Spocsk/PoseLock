(function () {
  "use strict";

  if (location.hostname === "spocsk.github.io" && (location.pathname === "/PoseLock" || location.pathname.indexOf("/PoseLock/") === 0)) {
    location.replace("https://poselock.app" + (location.pathname.slice(9) || "/") + location.search + location.hash);
    return;
  }

  // Token public du projet PoseLock EU uniquement. Jamais de clé API privée.
  var PROJECT_TOKEN = "03ed0cec87dc4b14df0bc46af678fa4d";
  var CONSENT_KEY = "poselock_mixpanel_consent_v2";
  var VISITOR_KEY = "poselock_mixpanel_anonymous_id";
  var ENDPOINT = "https://api-eu.mixpanel.com/track?ip=0";
  var allowedEvents = ["page_viewed", "launch_video_played", "app_store_clicked", "waitlist_requested"];
  var banner;
  var volatileChoice = null;
  var volatileVisitor = null;
  var pending = [];

  if (!/^[A-Za-z0-9]{16,64}$/.test(PROJECT_TOKEN)) return;

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

  function utm(name) {
    var value = new URLSearchParams(location.search).get("utm_" + name);
    return value && /^[a-zA-Z0-9_-]{1,60}$/.test(value) ? value : undefined;
  }

  function capture(name, extra) {
    if (choice() !== "yes" || allowedEvents.indexOf(name) === -1) return;
    var isLocal = location.hostname === "localhost" || location.hostname === "127.0.0.1";
    var properties = { token: PROJECT_TOKEN, distinct_id: visitor(), environment: isLocal ? "development" : "production" };
    if (name !== "launch_video_played") {
      properties.path = location.pathname;
      ["source", "medium", "campaign"].forEach(function (key) {
        var value = utm(key);
        if (value) properties[key] = value;
      });
    }
    if (extra) Object.keys(extra).forEach(function (key) { properties[key] = extra[key]; });
    var controller = new AbortController();
    pending.push(controller);
    fetch(ENDPOINT, {
      method: "POST",
      mode: "cors",
      credentials: "omit",
      // Form-encoded is a simple cross-origin request: no CORS preflight.
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: "data=" + encodeURIComponent(JSON.stringify([{ event: name, properties: properties }])),
      signal: controller.signal,
      keepalive: name === "app_store_clicked"
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
      capture("page_viewed");
    } else {
      pending.forEach(function (controller) { controller.abort(); });
      pending = [];
      volatileVisitor = null;
      try { localStorage.removeItem(VISITOR_KEY); } catch (_) { /* Rien à effacer. */ }
    }
  }

  function showPreferences() {
    closeBanner();
    banner = document.createElement("aside");
    banner.className = "analytics-banner";
    banner.setAttribute("aria-label", "Préférences de statistiques");
    banner.innerHTML = '<strong>Statistiques facultatives</strong><p>Avec ton accord, PoseLock mesure les pages consultées et les interactions principales. Aucun replay, image, pose ou score. Tu peux retirer ton accord ici à tout moment. <a href="/confidentialite/">En savoir plus</a>.</p><div><button type="button" data-accept>Accepter</button><button type="button" data-decline>Refuser ou retirer</button></div>';
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

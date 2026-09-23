(function () {
  "use strict";

  var form = document.querySelector("[data-waitlist-form]");
  if (!form) return;
  var status = form.querySelector("[data-waitlist-status]");
  var button = form.querySelector('button[type="submit"]');

  if (location.hostname !== "poselock.app") {
    button.disabled = true;
    status.textContent = "Les inscriptions ouvriront sur poselock.app dès que le domaine sera prêt.";
    return;
  }

  form.addEventListener("submit", async function (event) {
    event.preventDefault();
    if (!form.reportValidity()) return;
    button.disabled = true;
    status.textContent = "Envoi en cours…";
    var params = new URLSearchParams(location.search);
    try {
      var response = await fetch("api/subscribe", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: form.elements.email.value,
          consent: form.elements.consent.checked,
          website: form.elements.website.value,
          source: params.get("utm_source"),
          medium: params.get("utm_medium"),
          campaign: params.get("utm_campaign")
        })
      });
      var result = await response.json();
      if (!response.ok) throw new Error(result.error || "L’envoi a échoué.");
      status.textContent = "Vérifie ta boîte mail pour confirmer ton adresse. Regarde aussi les indésirables.";
      form.reset();
      if (window.poseLockAnalytics) window.poseLockAnalytics.capture("waitlist_requested");
    } catch (error) {
      status.textContent = error.message || "L’envoi a échoué. Réessaie plus tard.";
    } finally {
      button.disabled = false;
    }
  });
})();

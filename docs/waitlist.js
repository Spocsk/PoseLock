(function () {
  "use strict";

  var form = document.querySelector("[data-waitlist-form]");
  if (!form) return;
  var status = form.querySelector("[data-waitlist-status]");
  var button = form.querySelector('button[type="submit"]');
  var COPY = {
    fr: { closed: "Les inscriptions ouvriront sur poselock.app dès que le domaine sera prêt.", sending: "Envoi en cours…", sent: "Vérifie ta boîte mail pour confirmer ton adresse. Regarde aussi les indésirables.", failed: "L’envoi a échoué. Réessaie plus tard." },
    en: { closed: "Sign-ups will open on poselock.app as soon as the domain is ready.", sending: "Sending…", sent: "Check your inbox to confirm your address. Look in spam too.", failed: "Sending failed. Please try again later." },
    es: { closed: "Las inscripciones se abrirán en poselock.app en cuanto el dominio esté listo.", sending: "Enviando…", sent: "Revisa tu correo para confirmar tu dirección. Mira también en spam.", failed: "No se pudo enviar. Inténtalo más tarde." },
    de: { closed: "Die Anmeldung öffnet auf poselock.app, sobald die Domain bereit ist.", sending: "Wird gesendet…", sent: "Schau in dein Postfach, um deine Adresse zu bestätigen. Prüf auch den Spam-Ordner.", failed: "Senden fehlgeschlagen. Bitte versuch es später erneut." },
    "pt-BR": { closed: "As inscrições vão abrir em poselock.app assim que o domínio estiver pronto.", sending: "Enviando…", sent: "Confira seu email para confirmar o endereço. Veja também o spam.", failed: "O envio falhou. Tente de novo mais tarde." }
  };
  var locale = COPY[document.documentElement.lang] ? document.documentElement.lang : "fr";
  var copy = COPY[locale];

  if (location.hostname !== "poselock.app") {
    button.disabled = true;
    status.textContent = copy.closed;
    return;
  }

  form.addEventListener("submit", async function (event) {
    event.preventDefault();
    if (!form.reportValidity()) return;
    button.disabled = true;
    status.textContent = copy.sending;
    var params = new URLSearchParams(location.search);
    try {
      var response = await fetch("/api/subscribe", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: form.elements.email.value,
          consent: form.elements.consent.checked,
          website: form.elements.website.value,
          locale: locale,
          source: params.get("utm_source"),
          medium: params.get("utm_medium"),
          campaign: params.get("utm_campaign")
        })
      });
      var result = await response.json();
      if (!response.ok) throw new Error(result.error || copy.failed);
      status.textContent = copy.sent;
      form.reset();
      if (window.poseLockAnalytics) window.poseLockAnalytics.capture("waitlist_requested");
    } catch (error) {
      status.textContent = error.message || copy.failed;
    } finally {
      button.disabled = false;
    }
  });
})();

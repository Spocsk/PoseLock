"use strict";

const {
  CONSENT_VERSION, json, requestBody, normalizeEmail, campaignValue, seal, emailThrottleKey, resend
} = require("./_lib/waitlist");

module.exports = async function subscribe(req, res) {
  if (req.method !== "POST") return json(res, 405, { error: "Méthode non autorisée." });
  if (Number(req.headers["content-length"] || 0) > 2048) return json(res, 413, { error: "Requête trop longue." });

  const origin = req.headers.origin;
  const host = req.headers.host;
  if (host !== new URL(process.env.PUBLIC_ORIGIN || "https://poselock.app").host) {
    return json(res, 503, { error: "Les inscriptions ouvriront sur poselock.app." });
  }
  if (origin && host && origin !== `https://${host}` && origin !== `http://${host}`) {
    return json(res, 403, { error: "Origine non autorisée." });
  }

  const body = requestBody(req);
  if (!body) return json(res, 400, { error: "Requête invalide." });
  if (body.website) return json(res, 202, { status: "check_email" });
  const email = normalizeEmail(body.email);
  if (!email || body.consent !== true) {
    return json(res, 400, { error: "Saisis une adresse valide et accepte les emails PoseLock." });
  }
  if (!process.env.RESEND_API_KEY || !process.env.PUBLIC_ORIGIN || !process.env.WAITLIST_TOKEN_SECRET) {
    return json(res, 503, { error: "Les inscriptions sont momentanément indisponibles." });
  }

  try {
    const now = Date.now();
    const token = seal({
      email,
      issuedAt: now,
      version: CONSENT_VERSION,
      source: campaignValue(body.source),
      medium: campaignValue(body.medium),
      campaign: campaignValue(body.campaign)
    });
    const link = new URL("/confirmation/", process.env.PUBLIC_ORIGIN);
    link.searchParams.set("token", token);
    const result = await resend("/emails", {
      method: "POST",
      idempotencyKey: emailThrottleKey(email, now),
      body: {
        from: "PoseLock <bonjour@poselock.app>",
        to: [email],
        subject: "Confirme ton inscription à PoseLock",
        text: `Tu as demandé à recevoir la sortie et les actualités PoseLock. Confirme ton adresse dans les 24 heures : ${link}\n\nSi tu n’as rien demandé, ignore ce message.`,
        html: `<html lang="fr"><body style="font-family:Arial,sans-serif;background:#070809;color:#f5f3ef;padding:32px"><h1>Confirme ton adresse.</h1><p>Tu as demandé à recevoir la sortie et les actualités PoseLock.</p><p><a href="${link}" style="display:inline-block;background:#ff9a3c;color:#070809;padding:14px 22px;border-radius:999px;text-decoration:none;font-weight:bold">Confirmer mon inscription</a></p><p>Ce lien expire dans 24 heures. Si tu n’as rien demandé, ignore ce message.</p></body></html>`
      }
    });
    if (result.ok || (result.status === 409 && result.data.name === "invalid_idempotent_request")) {
      return json(res, 202, { status: "check_email" });
    }
    console.error("Resend confirmation request failed", result.status, result.data.name || "unknown");
    return json(res, 503, { error: "L’envoi a échoué. Réessaie plus tard." });
  } catch (error) {
    console.error("Waitlist subscribe failed", error.name || "Error");
    return json(res, 503, { error: "L’envoi a échoué. Réessaie plus tard." });
  }
};

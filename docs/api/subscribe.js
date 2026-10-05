"use strict";

const {
  CONSENT_VERSION, json, requestBody, normalizeEmail, campaignValue, seal, emailThrottleKey, resend
} = require("./_lib/waitlist");
const { locale, messages, confirmationPath } = require("./_lib/i18n");

module.exports = async function subscribe(req, res) {
  const body = requestBody(req);
  const lang = locale(body && body.locale);
  const t = messages(lang);
  if (req.method !== "POST") return json(res, 405, { error: t.method });
  if (Number(req.headers["content-length"] || 0) > 2048) return json(res, 413, { error: t.tooLong });

  const origin = req.headers.origin;
  const host = req.headers.host;
  if (host !== new URL(process.env.PUBLIC_ORIGIN || "https://poselock.app").host) {
    return json(res, 503, { error: t.closed });
  }
  if (origin && host && origin !== `https://${host}` && origin !== `http://${host}`) {
    return json(res, 403, { error: t.origin });
  }

  if (!body) return json(res, 400, { error: t.invalid });
  if (body.website) return json(res, 202, { status: "check_email" });
  const email = normalizeEmail(body.email);
  if (!email || body.consent !== true) {
    return json(res, 400, { error: t.email });
  }
  if (!process.env.RESEND_API_KEY || !process.env.PUBLIC_ORIGIN || !process.env.WAITLIST_TOKEN_SECRET) {
    return json(res, 503, { error: t.unavailable });
  }

  try {
    const now = Date.now();
    // La langue voyage dans le jeton scellé ; CONSENT_VERSION ne change pas, les
    // jetons déjà envoyés restent valides.
    const token = seal({
      email,
      issuedAt: now,
      version: CONSENT_VERSION,
      locale: lang,
      source: campaignValue(body.source),
      medium: campaignValue(body.medium),
      campaign: campaignValue(body.campaign)
    });
    const link = new URL(confirmationPath(lang), process.env.PUBLIC_ORIGIN);
    link.searchParams.set("token", token);
    const result = await resend("/emails", {
      method: "POST",
      idempotencyKey: emailThrottleKey(email, now),
      body: {
        from: "PoseLock <bonjour@poselock.app>",
        to: [email],
        subject: t.subject,
        text: t.text.replace("{link}", link),
        html: `<html lang="${lang}"><body style="font-family:Arial,sans-serif;background:#070809;color:#f5f3ef;padding:32px"><h1>${t.heading}</h1><p>${t.intro}</p><p><a href="${link}" style="display:inline-block;background:#ff9a3c;color:#070809;padding:14px 22px;border-radius:999px;text-decoration:none;font-weight:bold">${t.button}</a></p><p>${t.footer}</p></body></html>`
      }
    });
    if (result.ok || (result.status === 409 && result.data.name === "invalid_idempotent_request")) {
      return json(res, 202, { status: "check_email" });
    }
    console.error("Resend confirmation request failed", result.status, result.data.name || "unknown");
    return json(res, 503, { error: t.sendFailed });
  } catch (error) {
    console.error("Waitlist subscribe failed", error.name || "Error");
    return json(res, 503, { error: t.sendFailed });
  }
};

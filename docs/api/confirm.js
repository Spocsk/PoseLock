"use strict";

const { json, requestBody, open, resend, contactProperties } = require("./_lib/waitlist");
const { messages } = require("./_lib/i18n");

module.exports = async function confirm(req, res) {
  const body = requestBody(req);
  const t = messages(body && body.locale);
  if (req.method !== "POST") return json(res, 405, { error: t.method });
  if (Number(req.headers["content-length"] || 0) > 2500) return json(res, 413, { error: t.tooLong });
  const origin = req.headers.origin;
  const host = req.headers.host;
  if (origin && host && origin !== `https://${host}` && origin !== `http://${host}`) {
    return json(res, 403, { error: t.origin });
  }
  if (!body) return json(res, 400, { error: t.invalid });
  const payload = open(body.token);
  if (!payload) return json(res, 400, { error: t.badLink });
  if (payload.expired) return json(res, 410, { error: t.expired });
  if (!process.env.RESEND_API_KEY || !process.env.RESEND_SEGMENT_ID) {
    return json(res, 503, { error: t.confirmUnavailable });
  }

  try {
    const path = `/contacts/${encodeURIComponent(payload.email)}`;
    const existing = await resend(path);
    if (existing.status !== 404 && !existing.ok) throw new Error(`get:${existing.status}`);
    if (existing.ok && existing.data.unsubscribed) {
      return json(res, 200, { status: "unsubscribed" });
    }
    const confirmedAt = Number(existing.data?.properties?.poselock_consent_at || 0);
    if (confirmedAt >= payload.issuedAt) return json(res, 200, { status: "already_confirmed" });

    const properties = contactProperties(payload, Date.now());
    if (existing.status === 404) {
      const created = await resend("/contacts", {
        method: "POST",
        body: {
          email: payload.email,
          unsubscribed: false,
          properties,
          segments: [{ id: process.env.RESEND_SEGMENT_ID }]
        }
      });
      if (created.ok) return json(res, 200, { status: "confirmed" });
      if (created.status !== 409) throw new Error(`create:${created.status}`);
    }

    const updated = await resend(path, { method: "PATCH", body: { properties } });
    if (!updated.ok) throw new Error(`update:${updated.status}`);
    const assigned = await resend(`/contacts/${encodeURIComponent(payload.email)}/segments/${encodeURIComponent(process.env.RESEND_SEGMENT_ID)}`, { method: "POST" });
    if (!assigned.ok && assigned.status !== 409) throw new Error(`segment:${assigned.status}`);
    return json(res, 200, { status: "confirmed" });
  } catch (error) {
    console.error("Waitlist confirmation failed", error.message || "Error");
    return json(res, 503, { error: t.confirmFailed });
  }
};

"use strict";

const crypto = require("node:crypto");

const CONSENT_VERSION = "2026-09-23-launch-news-v1";
const TOKEN_LIFETIME_MS = 24 * 60 * 60 * 1000;
const RESEND_API = "https://api.resend.com";

function json(res, status, body) {
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.setHeader("Cache-Control", "no-store");
  res.status(status).json(body);
}

function requestBody(req) {
  try {
    const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : req.body;
    return body && typeof body === "object" && !Array.isArray(body) ? body : null;
  } catch (_) {
    return null;
  }
}

function normalizeEmail(value) {
  if (typeof value !== "string") return null;
  const email = value.trim().toLowerCase();
  if (email.length > 254 || !/^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(email)) return null;
  return email;
}

function campaignValue(value) {
  return typeof value === "string" && /^[a-zA-Z0-9_-]{1,60}$/.test(value) ? value : "";
}

function tokenKey() {
  const secret = process.env.WAITLIST_TOKEN_SECRET || "";
  const key = Buffer.from(secret, "base64url");
  if (key.length !== 32) throw new Error("WAITLIST_TOKEN_SECRET must be 32 bytes in base64url");
  return key;
}

function seal(payload) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", tokenKey(), iv);
  const encrypted = Buffer.concat([cipher.update(JSON.stringify(payload), "utf8"), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), encrypted]).toString("base64url");
}

function open(token, now = Date.now()) {
  if (typeof token !== "string" || token.length > 2048 || !/^[\w-]+$/.test(token)) return null;
  try {
    const bytes = Buffer.from(token, "base64url");
    if (bytes.length < 29) return null;
    const decipher = crypto.createDecipheriv("aes-256-gcm", tokenKey(), bytes.subarray(0, 12));
    decipher.setAuthTag(bytes.subarray(12, 28));
    const payload = JSON.parse(Buffer.concat([decipher.update(bytes.subarray(28)), decipher.final()]).toString("utf8"));
    if (normalizeEmail(payload.email) !== payload.email || payload.version !== CONSENT_VERSION || !Number.isSafeInteger(payload.issuedAt)) return null;
    if (payload.issuedAt > now + 5 * 60 * 1000) return null;
    return { ...payload, expired: now - payload.issuedAt > TOKEN_LIFETIME_MS };
  } catch (_) {
    return null;
  }
}

function emailThrottleKey(email, now = Date.now()) {
  const hour = Math.floor(now / (60 * 60 * 1000));
  return "poselock-confirm-" + crypto.createHmac("sha256", tokenKey()).update(`${email}:${hour}`).digest("hex");
}

async function resend(path, options = {}) {
  if (!process.env.RESEND_API_KEY) throw new Error("RESEND_API_KEY is missing");
  const response = await fetch(RESEND_API + path, {
    method: options.method || "GET",
    headers: {
      Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
      "Content-Type": "application/json",
      ...(options.idempotencyKey ? { "Idempotency-Key": options.idempotencyKey } : {})
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
    signal: AbortSignal.timeout(8000)
  });
  let data;
  try { data = await response.json(); } catch (_) { data = {}; }
  return { status: response.status, ok: response.ok, data };
}

function contactProperties(payload, now) {
  return {
    poselock_consent_at: now,
    poselock_consent_version: CONSENT_VERSION,
    poselock_source: campaignValue(payload.source) || "direct",
    poselock_medium: campaignValue(payload.medium),
    poselock_campaign: campaignValue(payload.campaign)
  };
}

module.exports = {
  CONSENT_VERSION,
  TOKEN_LIFETIME_MS,
  json,
  requestBody,
  normalizeEmail,
  campaignValue,
  seal,
  open,
  emailThrottleKey,
  resend,
  contactProperties
};

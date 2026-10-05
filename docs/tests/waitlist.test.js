const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");

process.env.WAITLIST_TOKEN_SECRET = Buffer.alloc(32, 7).toString("base64url");
process.env.RESEND_API_KEY = "test-key";
process.env.RESEND_SEGMENT_ID = "test-segment";
process.env.PUBLIC_ORIGIN = "https://poselock.app";

const waitlist = require("../api/_lib/waitlist");
const subscribe = require("../api/subscribe");
const confirm = require("../api/confirm");

function response(status, data) {
  return { ok: status >= 200 && status < 300, status, async json() { return data; } };
}

function invoke(handler, body, method = "POST", host = "poselock.app") {
  const res = {
    code: 0, data: null, headers: {},
    setHeader(key, value) { this.headers[key] = value; },
    status(code) { this.code = code; return this; },
    json(data) { this.data = data; return this; }
  };
  return Promise.resolve(handler({ method, body, headers: { origin: `https://${host}`, host } }, res)).then(() => res);
}

function token(email = "poseur@example.com", issuedAt = Date.now()) {
  return waitlist.seal({ email, issuedAt, version: waitlist.CONSENT_VERSION, source: "instagram", medium: "social", campaign: "launch" });
}

test("confirmation token hides the address, expires, and rejects tampering", () => {
  const issuedAt = Date.now();
  const value = token("poseur@example.com", issuedAt);
  assert.equal(value.includes("poseur"), false);
  assert.equal(waitlist.open(value, issuedAt).email, "poseur@example.com");
  assert.equal(waitlist.open(value, issuedAt + waitlist.TOKEN_LIFETIME_MS + 1).expired, true);
  assert.equal(waitlist.open(value.slice(0, -1) + (value.endsWith("a") ? "b" : "a")), null);
  assert.notEqual(waitlist.emailThrottleKey("poseur@example.com", issuedAt), waitlist.emailThrottleKey("poseur@example.com", issuedAt + 3600000));
});

test("signup requires explicit consent and sends only a confirmation email", async () => {
  const calls = [];
  global.fetch = async (url, options) => { calls.push({ url, options }); return response(200, { id: "sent" }); };
  assert.equal((await invoke(subscribe, { email: "poseur@example.com", consent: false })).code, 400);
  assert.equal((await invoke(subscribe, "not-json")).code, 400);
  const result = await invoke(subscribe, { email: " Poseur@Example.com ", consent: true, source: "instagram" });
  assert.equal(result.code, 202);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, "https://api.resend.com/emails");
  const sent = JSON.parse(calls[0].options.body);
  assert.deepEqual(sent.to, ["poseur@example.com"]);
  assert.match(sent.text, /confirmation\//);
  assert.ok(calls[0].options.headers["Idempotency-Key"]);
});

test("temporary deployment does not accept signups", async () => {
  global.fetch = async () => { throw new Error("must not call Resend"); };
  const result = await invoke(subscribe, { email: "poseur@example.com", consent: true }, "POST", "poselock.vercel.app");
  assert.equal(result.code, 503);
});

test("signup repeated within the throttle window does not expose address state", async () => {
  global.fetch = async () => response(409, { name: "invalid_idempotent_request" });
  const result = await invoke(subscribe, { email: "poseur@example.com", consent: true });
  assert.equal(result.code, 202);
  assert.deepEqual(result.data, { status: "check_email" });
});

test("confirmation creates a contact in the dedicated segment once", async () => {
  const calls = [];
  global.fetch = async (url, options) => {
    calls.push({ url, options });
    return url.endsWith("/contacts/poseur%40example.com") ? response(404, { name: "not_found" }) : response(201, { id: "contact" });
  };
  const result = await invoke(confirm, { token: token() });
  assert.equal(result.code, 200);
  const created = JSON.parse(calls[1].options.body);
  assert.deepEqual(created.segments, [{ id: "test-segment" }]);
  assert.equal(created.properties.poselock_source, "instagram");
  assert.equal(created.properties.poselock_consent_version, waitlist.CONSENT_VERSION);
});

test("old links cannot reactivate an unsubscribed contact", async () => {
  const issuedAt = Date.now() - 1000;
  const calls = [];
  global.fetch = async (url, options) => {
    calls.push({ url, options });
    return response(200, { unsubscribed: true, properties: { poselock_consent_at: issuedAt + 500 } });
  };
  const result = await invoke(confirm, { token: token("poseur@example.com", issuedAt) });
  assert.equal(result.data.status, "unsubscribed");
  assert.equal(calls.length, 1);
});

test("a globally unsubscribed contact is never silently reactivated", async () => {
  const calls = [];
  global.fetch = async (url, options) => {
    calls.push({ url, options });
    return response(200, { unsubscribed: true, properties: {} });
  };
  const result = await invoke(confirm, { token: token() });
  assert.equal(result.data.status, "unsubscribed");
  assert.equal(calls.length, 1);
});

test("expired and invalid links make no Resend request", async () => {
  global.fetch = async () => { throw new Error("must not call Resend"); };
  assert.equal((await invoke(confirm, { token: token("poseur@example.com", Date.now() - waitlist.TOKEN_LIFETIME_MS - 1) })).code, 410);
  assert.equal((await invoke(confirm, { token: crypto.randomBytes(24).toString("base64url") })).code, 400);
});

test("signup email and confirmation link follow the page language", async () => {
  const calls = [];
  global.fetch = async (url, options) => { calls.push({ url, options }); return response(200, { id: "sent" }); };
  await invoke(subscribe, { email: "poseur@example.com", consent: true, locale: "de" });
  const sent = JSON.parse(calls[0].options.body);
  assert.equal(sent.subject, "Bestätige deine Anmeldung bei PoseLock");
  assert.match(sent.text, /https:\/\/poselock\.app\/de\/bestaetigen\/\?token=/);
  assert.match(sent.html, /<html lang="de">/);
  const link = new URL(sent.text.match(/https:\S+/)[0]);
  assert.equal(waitlist.open(link.searchParams.get("token")).locale, "de");
});

test("an unknown language falls back to French, never into the template", async () => {
  const calls = [];
  global.fetch = async (url, options) => { calls.push({ url, options }); return response(200, { id: "sent" }); };
  await invoke(subscribe, { email: "poseur@example.com", consent: true, locale: "<script>" });
  const sent = JSON.parse(calls[0].options.body);
  assert.equal(sent.subject, "Confirme ton inscription à PoseLock");
  assert.match(sent.text, /poselock\.app\/confirmation\/\?token=/);
  assert.doesNotMatch(sent.html, /<script>/);
});

test("confirmation errors are returned in the visitor's language", async () => {
  global.fetch = async () => { throw new Error("must not call Resend"); };
  const result = await invoke(confirm, { token: "bad", locale: "pt-BR" });
  assert.equal(result.code, 400);
  assert.equal(result.data.error, "Este link é inválido.");
});

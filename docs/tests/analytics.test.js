const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { webcrypto } = require("node:crypto");

const source = fs.readFileSync(path.join(__dirname, "..", "analytics.js"), "utf8");
const settle = () => new Promise((resolve) => setImmediate(resolve));

function run({ appID = "72790DE8-2D17-4687-A8CD-321CF82831A3", initial = {}, lang = "en", hostname = "localhost" } = {}) {
  const requests = [];
  const values = new Map(Object.entries(initial));
  const preferences = { listeners: {}, addEventListener(name, fn) { this.listeners[name] = fn; } };
  let banner;
  const document = {
    documentElement: { lang },
    querySelectorAll(selector) { return selector === "[data-analytics-preferences]" ? [preferences] : []; },
    querySelector() { return null; },
    createElement() {
      const buttons = new Map();
      return {
        className: "", innerHTML: "", setAttribute() {}, remove() { banner = null; },
        querySelector(selector) {
          if (!buttons.has(selector)) buttons.set(selector, { addEventListener(_, fn) { this.click = fn; } });
          return buttons.get(selector);
        }
      };
    },
    body: { appendChild(node) { banner = node; } }
  };
  let uuid = 0;
  const context = {
    document,
    location: { search: "?utm_source=tiktok&utm_campaign=test", pathname: "/en/", hostname },
    URLSearchParams, AbortController, Promise, TextEncoder, Uint8Array, Array,
    fetch(url, options) { requests.push({ url, options }); return Promise.resolve({ ok: true }); },
    crypto: { randomUUID() { uuid += 1; return `anonymous-test-id-${uuid}`; }, subtle: webcrypto.subtle },
    localStorage: {
      getItem(key) { return values.has(key) ? values.get(key) : null; },
      setItem(key, value) { values.set(key, value); },
      removeItem(key) { values.delete(key); }
    }
  };
  context.window = context;
  vm.runInNewContext(source.replace(/var APP_ID = "[^"]*";/, `var APP_ID = "${appID}";`), context);
  return { requests, preferences, values, get banner() { return banner; } };
}

test("no valid app ID means no tracking and no consent banner", async () => {
  const app = run({ appID: "" });
  await settle();
  assert.deepEqual(app.requests, []);
  assert.equal(app.banner, undefined);
});

test("a Mixpanel consent is not carried over to TelemetryDeck", async () => {
  const app = run({ initial: { poselock_mixpanel_consent_v2: "yes", poselock_mixpanel_anonymous_id: "old" } });
  await settle();
  assert.deepEqual(app.requests, []);
  assert.equal(app.values.has("poselock_mixpanel_consent_v2"), false);
  assert.equal(app.values.has("poselock_mixpanel_anonymous_id"), false);
  assert.ok(app.banner, "the banner asks again");
});

test("the banner speaks the page language and links to its privacy page", () => {
  const app = run({ lang: "de" });
  assert.match(app.banner.innerHTML, /Optionale Statistiken/);
  assert.match(app.banner.innerHTML, /href="\/de\/datenschutz\/"/);
});

test("refusal never sends a TelemetryDeck request", async () => {
  const app = run();
  app.banner.querySelector("[data-decline]").click();
  await settle();
  assert.deepEqual(app.requests, []);
  assert.equal(app.values.get("poselock_analytics_consent"), "no");
});

test("acceptance sends one hashed, allowlisted web signal and revocation clears identity", async () => {
  const app = run();
  app.banner.querySelector("[data-accept]").click();
  await settle();
  assert.equal(app.requests.length, 1);
  assert.equal(app.requests[0].url, "https://nom.telemetrydeck.com/v2/");
  assert.equal(app.requests[0].options.keepalive, undefined);
  const [signal] = JSON.parse(app.requests[0].options.body);
  assert.equal(signal.type, "Web.pageViewed");
  assert.equal(signal.isTestMode, true, "localhost is test mode");
  assert.match(signal.clientUser, /^[0-9a-f]{64}$/);
  assert.ok(!app.requests[0].options.body.includes(app.values.get("poselock_analytics_anonymous_id")), "the raw ID never leaves");
  assert.equal(signal.payload["TelemetryDeck.Device.platform"], "Web");
  assert.equal(signal.payload["Web.utm.source"], "tiktok");
  app.preferences.listeners.click();
  app.banner.querySelector("[data-decline]").click();
  assert.equal(app.values.has("poselock_analytics_anonymous_id"), false);
});

test("prior TelemetryDeck consent sends a page view on a new visit, in production mode on poselock.app", async () => {
  const app = run({ initial: { poselock_analytics_consent: "yes" }, hostname: "poselock.app" });
  await settle();
  assert.equal(app.requests.length, 1);
  assert.equal(JSON.parse(app.requests[0].options.body)[0].isTestMode, false);
});

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname, "..", "analytics.js"), "utf8");

function run(token, initialChoice) {
  const requests = [];
  const values = new Map();
  if (initialChoice) values.set("poselock_mixpanel_consent_v2", initialChoice);
  const preferences = { listeners: {}, addEventListener(name, fn) { this.listeners[name] = fn; } };
  let banner;
  const document = {
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
  const context = {
    document,
    location: { search: "?utm_source=tiktok&utm_campaign=test", pathname: "/", hostname: "localhost" },
    URLSearchParams,
    AbortController,
    Promise,
    fetch(url, options) { requests.push({ url, options }); return Promise.resolve({ ok: true }); },
    crypto: { randomUUID() { return "anonymous-test-id"; } },
    localStorage: {
      getItem(key) { return values.get(key) || null; },
      setItem(key, value) { values.set(key, value); },
      removeItem(key) { values.delete(key); }
    }
  };
  context.window = context;
  vm.runInNewContext(source.replace(/var PROJECT_TOKEN = "[^"]*";/, `var PROJECT_TOKEN = "${token}";`), context);
  return { requests, preferences, values, get banner() { return banner; } };
}

test("no project token means no tracking or consent banner", () => {
  const app = run("");
  assert.deepEqual(app.requests, []);
  assert.equal(app.banner, undefined);
});

test("refusal never sends Mixpanel requests", () => {
  const app = run("0123456789abcdef0123456789abcdef");
  assert.deepEqual(app.requests, []);
  app.banner.querySelector("[data-decline]").click();
  assert.deepEqual(app.requests, []);
  assert.equal(app.values.get("poselock_mixpanel_consent_v2"), "no");
});

test("acceptance sends only allowlisted event and revocation clears identity", () => {
  const app = run("0123456789abcdef0123456789abcdef");
  app.banner.querySelector("[data-accept]").click();
  assert.equal(app.requests.length, 1);
  assert.equal(app.requests[0].url, "https://api-eu.mixpanel.com/track?ip=0");
  const payload = JSON.parse(decodeURIComponent(app.requests[0].options.body.slice(5)));
  assert.equal(payload[0].event, "page_viewed");
  assert.equal(payload[0].properties.source, "tiktok");
  assert.equal(payload[0].properties.distinct_id, "anonymous-test-id");
  app.preferences.listeners.click();
  app.banner.querySelector("[data-decline]").click();
  assert.equal(app.values.has("poselock_mixpanel_anonymous_id"), false);
  assert.equal(app.requests[0].options.signal.aborted, true);
});

test("prior consent sends page view on a new visit", () => {
  const app = run("0123456789abcdef0123456789abcdef", "yes");
  assert.equal(app.requests.length, 1);
});

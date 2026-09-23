const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const base = "https://poselock.app/";
const routes = [
  "",
  "guides/posing-bodybuilding/",
  "guides/front-double-biceps/",
  "guides/poser-seul/",
  "confidentialite/",
  "support/"
];

test("all public pages have unique canonical, description and crawlable text", () => {
  const titles = new Set();
  for (const route of routes) {
    const file = path.join(root, route, "index.html");
    const html = fs.readFileSync(file, "utf8");
    assert.match(html, new RegExp(`<link rel="canonical" href="${base}${route}"`));
    assert.match(html, /<meta name="description" content="[^"]+">/);
    assert.match(html, /<main\b/);
    assert.match(html, /<h1\b/);
    assert.doesNotMatch(html, /noindex/);
    const title = html.match(/<title>([^<]+)<\/title>/)?.[1];
    assert.ok(title);
    assert.ok(!titles.has(title));
    titles.add(title);
  }
});

test("sitemap covers all six pages and the landing links to guides", () => {
  const sitemap = fs.readFileSync(path.join(root, "sitemap.xml"), "utf8");
  const landing = fs.readFileSync(path.join(root, "index.html"), "utf8");
  for (const route of routes) assert.ok(sitemap.includes(`<loc>${base}${route}</loc>`));
  for (const route of routes.slice(1, 4)) assert.ok(landing.includes(`href="${route}"`));
  assert.match(fs.readFileSync(path.join(root, "robots.txt"), "utf8"), /^Allow: \/$/m);
  const confirmation = fs.readFileSync(path.join(root, "confirmation", "index.html"), "utf8");
  assert.match(confirmation, /name="robots" content="noindex, nofollow"/);
});

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const root = path.join(__dirname, "..");
const routes = JSON.parse(fs.readFileSync(path.join(root, "i18n", "routes.json"), "utf8"));
const base = routes.origin;
const locales = Object.keys(routes.locales);
const pages = Object.entries(routes.pages);
const read = (route) => fs.readFileSync(path.join(root, route, "index.html"), "utf8");

test("generated pages are up to date with the French sources and translations", () => {
  execFileSync("python3", [path.join(root, "..", "scripts", "site_i18n.py"), "--check"], { stdio: "pipe" });
});

test("every public page has a self canonical, unique title, description and the right language", () => {
  const titles = new Set();
  for (const [name, page] of pages) {
    if (page.noindex) continue;
    for (const locale of locales) {
      const route = page[locale];
      const html = read(route);
      assert.match(html, new RegExp(`<link rel="canonical" href="${base}${route}"`), route);
      assert.match(html, new RegExp(`<html lang="${routes.locales[locale].hreflang}"`), route);
      assert.match(html, /<meta name="description" content="[^"]+">/, route);
      assert.match(html, /<main\b/);
      assert.match(html, /<h1\b/);
      assert.doesNotMatch(html, /noindex/, route);
      const title = html.match(/<title>([^<]+)<\/title>/)?.[1];
      assert.ok(title, route);
      assert.ok(!titles.has(title), `${name}/${locale}: titre dupliqué « ${title} »`);
      titles.add(title);
    }
  }
});

test("hreflang alternates are reciprocal and include x-default", () => {
  for (const [, page] of pages) {
    if (page.noindex) continue;
    for (const locale of locales) {
      const html = read(page[locale]);
      for (const other of locales) {
        assert.ok(html.includes(`<link rel="alternate" hreflang="${routes.locales[other].hreflang}" href="${base}${page[other]}">`), `${page[locale]} → ${other}`);
      }
      assert.ok(html.includes(`<link rel="alternate" hreflang="x-default" href="${base}${page[routes.xDefault]}">`));
    }
  }
});

test("pages never use relative asset or API paths, so they work under /en/ and the others", () => {
  for (const [, page] of pages) {
    for (const locale of locales) {
      const html = read(page[locale]);
      assert.doesNotMatch(html, /(?:href|src|action|poster)="(?!https?:|mailto:|#|\/)/, page[locale]);
      assert.doesNotMatch(html, /fetch\("(?!\/)/, page[locale]);
    }
  }
});

test("localized pages point to their own screenshots and language switcher", () => {
  for (const locale of locales.filter((l) => l !== routes.defaultLocale)) {
    const folder = routes.locales[locale].prefix.replaceAll("/", "");
    const home = read(routes.pages.home[locale]);
    assert.ok(home.includes(`/assets/screens/app-store/${folder}/01-camera-1000.webp`));
    assert.ok(fs.existsSync(path.join(root, "assets/screens/app-store", folder, "01-camera-1000.webp")));
    assert.doesNotMatch(home, /launch-film/, "le film n’existe qu’en français");
    assert.ok(home.includes(`href="${routes.pages.privacy[locale]}"`));
    assert.match(home, /<nav class="lang-switch"/);
  }
});

test("sitemap covers every page in every language and the confirmation pages stay out", () => {
  const sitemap = fs.readFileSync(path.join(root, "sitemap.xml"), "utf8");
  for (const [, page] of pages) {
    for (const locale of locales) {
      const listed = sitemap.includes(`<loc>${base}${page[locale]}</loc>`);
      assert.equal(listed, !page.noindex, page[locale]);
      if (page.noindex) assert.match(read(page[locale]), /name="robots" content="noindex, nofollow"/);
    }
  }
  assert.match(fs.readFileSync(path.join(root, "robots.txt"), "utf8"), /^Allow: \/$/m);
});

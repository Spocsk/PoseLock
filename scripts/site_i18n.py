#!/usr/bin/env python3
"""Génère les pages localisées du site à partir des pages françaises.

Les pages françaises (racine de docs/) font foi pour le balisage. Chaque langue
fournit docs/i18n/<langue>.json : des fragments français exacts et leur
traduction, par page (+ "common"). Le script échoue si un fragment propre à une
page n'est plus trouvé, ou s'il reste du français visible dans une page générée :
un texte français modifié ne laisse donc pas une traduction périmée en silence.

    python3 scripts/site_i18n.py          # régénère tout
    python3 scripts/site_i18n.py --check  # vérifie sans écrire

Il injecte aussi, dans toutes les langues (français compris) : canonical,
hreflang réciproques + x-default, sélecteur de langue, et écrit sitemap.xml.
"""
import html
import json
import pathlib
import re
import sys

DOCS = pathlib.Path(__file__).resolve().parents[1] / "docs"
ROUTES = json.loads((DOCS / "i18n/routes.json").read_text())
ORIGIN = ROUTES["origin"]
LOCALES = ROUTES["locales"]
PAGES = ROUTES["pages"]
SWITCH_LABEL = {"fr": "Langue", "en": "Language", "es": "Idioma", "de": "Sprache", "pt-BR": "Idioma"}
FRENCH = re.compile(
    r"\b(?:[ldjnmtsc]|qu)’[a-zàâéèêëîïôûù]|\b(?:une|pour|avec|dans|ton|tes|est|aussi|sans|leur|chaque|déjà|où|être|très)\b",
    re.IGNORECASE,
)
errors = []


def file_for(route):
    return DOCS / route.lstrip("/") / "index.html"


def localized(page, locale):
    return PAGES[page][locale]


def head_block(page, locale):
    route = localized(page, locale)
    lines = [f'<link rel="canonical" href="{ORIGIN}{route}">']
    if not PAGES[page].get("noindex"):
        for other, spec in LOCALES.items():
            lines.append(f'<link rel="alternate" hreflang="{spec["hreflang"]}" href="{ORIGIN}{localized(page, other)}">')
        lines.append(f'<link rel="alternate" hreflang="x-default" href="{ORIGIN}{localized(page, ROUTES["xDefault"])}">')
    return "<!-- i18n:head -->" + "\n  ".join(lines) + "<!-- /i18n:head -->"


def switcher(page, locale):
    links = []
    for other, spec in LOCALES.items():
        current = ' aria-current="page"' if other == locale else ""
        links.append(f'<a href="{localized(page, other)}" hreflang="{spec["hreflang"]}" lang="{spec["hreflang"]}"{current}>{spec["label"]}</a>')
    return f'<!-- i18n:switcher --><nav class="lang-switch" aria-label="{SWITCH_LABEL[locale]}">{"".join(links)}</nav><!-- /i18n:switcher -->'


def decorate(text, page, locale):
    """Canonical, hreflang et sélecteur : identiques pour toutes les langues."""
    if "<!-- i18n:head -->" in text:
        text = re.sub(r"<!-- i18n:head -->.*?<!-- /i18n:head -->", lambda _: head_block(page, locale), text, flags=re.S)
    elif re.search(r'<link rel="canonical"[^>]*>', text):
        text = re.sub(r'<link rel="canonical"[^>]*>', lambda _: head_block(page, locale), text, count=1)
    else:
        text = text.replace("<title>", head_block(page, locale) + "\n  <title>", 1)
    if "<!-- i18n:switcher -->" not in text:
        errors.append(f"{page}/{locale}: marqueur i18n:switcher absent")
    text = re.sub(r"<!-- i18n:switcher -->.*?<!-- /i18n:switcher -->", lambda _: switcher(page, locale), text, flags=re.S)
    return text


def translate(source, page, locale, table):
    spec = LOCALES[locale]
    folder = spec["prefix"].strip("/")
    text = re.sub(r"\s*<!-- fr-only.*?<!-- /fr-only -->", "", source, flags=re.S)

    fragments = {**table.get("common", {}), **table.get(page, {})}
    required = set(table.get(page, {}))
    for fr in sorted(fragments, key=len, reverse=True):
        if fr in text:
            text = text.replace(fr, fragments[fr])
        elif fr in required:
            errors.append(f"{page}/{locale}: fragment introuvable « {fr[:70]} »")

    # Liens internes vers la même page dans la langue courante.
    for other in PAGES:
        fr_route, target = PAGES[other]["fr"], localized(other, locale)
        text = text.replace(f'href="{fr_route}"', f'href="{target}"')
        text = text.replace(f'href="{fr_route}#', f'href="{target}#')
        text = text.replace(f'"{ORIGIN}{fr_route}"', f'"{ORIGIN}{target}"')
    text = text.replace("/assets/screens/app-store/", f"/assets/screens/app-store/{folder}/")
    text = text.replace("/assets/screens/current/", f"/assets/screens/current/{folder}/")
    text = text.replace('<html lang="fr"', f'<html lang="{spec["hreflang"]}"', 1)
    text = text.replace('content="fr_FR"', f'content="{spec["og"]}"')
    text = text.replace('"inLanguage":"fr-FR"', f'"inLanguage":"{spec["hreflang"]}"')

    attributes = re.findall(r'\b(?:alt|aria-label|content|placeholder|title)="([^"]*)"', text)
    visible = re.sub(r"<!--.*?-->|<style.*?</style>|<[^>]+>", " ", text, flags=re.S)
    visible = html.unescape(visible + " " + " | ".join(attributes))
    for match in FRENCH.finditer(visible):
        snippet = visible[max(0, match.start() - 40): match.end() + 40].replace("\n", " ")
        errors.append(f"{page}/{locale}: français restant « …{snippet.strip()}… »")
    return text


def sitemap():
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">']
    for page, routes in PAGES.items():
        if routes.get("noindex"):
            continue
        for locale in LOCALES:
            lines.append(f"  <url><loc>{ORIGIN}{routes[locale]}</loc>")
            for other, spec in LOCALES.items():
                lines.append(f'    <xhtml:link rel="alternate" hreflang="{spec["hreflang"]}" href="{ORIGIN}{routes[other]}"/>')
            lines.append(f'    <xhtml:link rel="alternate" hreflang="x-default" href="{ORIGIN}{routes[ROUTES["xDefault"]]}"/>')
            lines.append("  </url>")
    lines.append("</urlset>")
    return "\n".join(lines) + "\n"


def main():
    check = "--check" in sys.argv
    outputs = {}
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    tables = {loc: json.loads((DOCS / f"i18n/{loc}.json").read_text())
              for loc in LOCALES if loc != ROUTES["defaultLocale"] and only in (None, loc)}
    for page, routes in PAGES.items():
        source = file_for(routes["fr"]).read_text()
        outputs[file_for(routes["fr"])] = decorate(source, page, "fr")
        for locale, table in tables.items():
            outputs[file_for(routes[locale])] = decorate(translate(source, page, locale, table), page, locale)
    if only is None:
        outputs[DOCS / "sitemap.xml"] = sitemap()
    if errors:
        sys.exit("\n".join(errors))
    stale = []
    for path, text in outputs.items():
        if not path.exists() or path.read_text() != text:
            stale.append(path.relative_to(DOCS))
            if not check:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text)
    if check and stale:
        sys.exit("Pages à régénérer : " + ", ".join(map(str, stale)))
    print(f"{len(outputs)} fichiers à jour" + (f", {len(stale)} réécrits" if stale and not check else ""))


main()

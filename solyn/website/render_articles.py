#!/usr/bin/env python3
"""render_articles.py — render hand-written voice articles (content/articles/*.md)
into warm-brand HTML pages under public/guide/, with Article + FAQPage + Breadcrumb
schema, internal cluster links, and a sitemap-guides.xml.

Run: python3 render_articles.py
"""
import os, re, json, glob

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "content", "articles")
OUT = os.path.join(ROOT, "public", "blog")
DOMAIN = "https://getdailyvox.com"
APP_STORE = "https://apps.apple.com/app/id6760454642"
IVORY, INK, SAGE, GOLD, TERRA = "#FAF8F5", "#2B2520", "#5B7C6B", "#D4A547", "#C4956A"

def esc(s): return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")
def inline(s):
    s = esc(s)
    s = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', s)
    return s

def parse(md):
    fm = {}
    m = re.match(r'^---\n(.*?)\n---\n(.*)$', md, re.S)
    body = md
    if m:
        for line in m.group(1).splitlines():
            if ':' in line:
                k, v = line.split(':', 1)
                fm[k.strip()] = v.strip().strip('"')
        body = m.group(2)
    return fm, body.strip()

def body_to_html(body):
    """Return (html, faq_pairs). Minimal markdown for our article shapes."""
    lines = body.splitlines()
    html, faq = [], []
    i, in_q = 0, False
    para, listbuf = [], []
    def flush_para():
        if para:
            html.append("<p>" + inline(" ".join(para)).strip() + "</p>"); para.clear()
    def flush_list():
        if listbuf:
            html.append("<ol>" + "".join(f"<li>{inline(x)}</li>" for x in listbuf) + "</ol>"); listbuf.clear()
    while i < len(lines):
        ln = lines[i].rstrip()
        if not ln.strip():
            flush_para(); flush_list(); i += 1; continue
        if ln.startswith("# "):           # H1 (skip; title comes from frontmatter visible H1 added separately)
            i += 1; continue
        if ln.startswith("## "):
            flush_para(); flush_list()
            h = ln[3:].strip()
            in_q = h.lower().startswith("question")
            html.append(f"<h2>{inline(h)}</h2>"); i += 1; continue
        mq = re.match(r'^\*\*(.+\?)\*\*$', ln)
        if in_q and mq:                    # FAQ question
            flush_para(); flush_list()
            q = mq.group(1)
            ans = []
            i += 1
            while i < len(lines) and lines[i].strip() and not re.match(r'^\*\*.+\?\*\*$', lines[i]):
                ans.append(lines[i].strip()); i += 1
            a = " ".join(ans)
            faq.append((q, a))
            html.append(f'<details><summary>{inline(q)}</summary><p>{inline(a)}</p></details>')
            continue
        if re.match(r'^\d+\.\s+', ln):
            flush_para(); listbuf.append(re.sub(r'^\d+\.\s+', '', ln)); i += 1; continue
        flush_list(); para.append(ln); i += 1
    flush_para(); flush_list()
    return "\n".join(html), faq

def page_html(fm, body_html, faq, related):
    slug = fm["slug"]; canonical = f"{DOMAIN}/blog/{slug}"
    title = fm["title"]; meta = fm.get("meta_description", "")
    article_schema = {"@context":"https://schema.org","@type":"Article","headline":title,
        "description":meta,"url":canonical,"author":{"@type":"Organization","name":"DailyVox"},
        "publisher":{"@type":"Organization","name":"DailyVox","url":DOMAIN}}
    faq_schema = {"@context":"https://schema.org","@type":"FAQPage","mainEntity":[
        {"@type":"Question","name":q,"acceptedAnswer":{"@type":"Answer","text":a}} for q,a in faq]} if faq else None
    bc = {"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[
        {"@type":"ListItem","position":1,"name":"Home","item":DOMAIN+"/"},
        {"@type":"ListItem","position":2,"name":"Blog","item":DOMAIN+"/blog"},
        {"@type":"ListItem","position":3,"name":title}]}
    schemas = "\n".join(f'<script type="application/ld+json">{json.dumps(s)}</script>'
                        for s in [article_schema, faq_schema, bc] if s)
    rel = "".join(f'<a href="/blog/{s}">{t}</a>' for s,t in related)
    return f"""<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(meta)}">
<link rel="canonical" href="{canonical}">
<meta name="theme-color" content="{IVORY}">
<meta property="og:type" content="article"><meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(meta)}"><meta property="og:url" content="{canonical}">
{schemas}
<style>
:root{{--ivory:{IVORY};--ink:{INK};--sage:{SAGE};--gold:{GOLD};--terra:{TERRA}}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--ivory);color:var(--ink);font:18px/1.7 -apple-system,'Nunito',Segoe UI,sans-serif}}
header,main,footer{{max-width:720px;margin:0 auto;padding:0 22px}}
header{{display:flex;gap:20px;align-items:center;padding:18px 22px;font-weight:700}}
header a{{color:var(--ink);text-decoration:none;font-size:15px}}header .logo{{color:var(--sage);font-size:20px}}
h1{{font-size:34px;line-height:1.2;margin:22px 0 8px}}h2{{font-size:23px;color:var(--sage);margin-top:34px}}
.bc{{font-size:14px;color:#8a8175;margin-top:14px}}.bc a{{color:#8a8175}}
ol{{padding-left:22px}}ol li{{margin:6px 0}}
.cta{{background:var(--sage);color:#fff;border-radius:16px;padding:24px;margin:38px 0;text-align:center}}
.cta a{{display:inline-block;background:var(--gold);color:var(--ink);font-weight:800;padding:12px 24px;border-radius:30px;text-decoration:none;margin-top:10px}}
details{{border-top:1px solid #e7e0d6;padding:13px 0}}summary{{font-weight:700;cursor:pointer}}
.related{{display:flex;flex-wrap:wrap;gap:10px;margin:20px 0 50px}}.related a{{background:#fff;border:1px solid #e7e0d6;border-radius:20px;padding:8px 15px;font-size:14px;color:var(--terra);text-decoration:none}}
footer{{color:#8a8175;font-size:14px;padding:28px 22px 60px;border-top:1px solid #e7e0d6}}
a{{color:var(--terra)}}
</style></head>
<body>
<header><a class="logo" href="/">DailyVox</a><a href="/blog">Blog</a><a href="/faq">FAQ</a><a href="/privacy">Privacy</a></header>
<main>
<div class="bc"><a href="/">Home</a> &rsaquo; <a href="/blog">Blog</a></div>
<h1>{esc(title)}</h1>
{body_html}
<div class="cta"><strong>DailyVox keeps your words on your phone.</strong><br><a href="{APP_STORE}">Get it on the App Store</a></div>
<div class="related">{rel}</div>
</main>
<footer>DailyVox &middot; Private, on-device voice journaling. Your words never leave your phone.</footer>
</body></html>"""

def main():
    os.makedirs(OUT, exist_ok=True)
    files = sorted(glob.glob(os.path.join(SRC, "*.md")))
    pages = []
    for f in files:
        fm, body = parse(open(f, encoding="utf-8").read())
        if "slug" not in fm: continue
        pages.append((fm, body, fm["slug"], fm["title"]))
    index = [(s, t) for *_, s, t in pages]
    sitemap = []
    for fm, body, slug, title in pages:
        body_html, faq = body_to_html(body)
        related = [(s, t) for s, t in index if s != slug][:4]
        html = page_html(fm, body_html, faq, related)
        open(os.path.join(OUT, slug + ".html"), "w", encoding="utf-8").write(html)
        sitemap.append(f"{DOMAIN}/blog/{slug}")
        print(f"  rendered /blog/{slug}  ({len(body.split())} words, {len(faq)} FAQ)")
    sm = os.path.join(ROOT, "public", "sitemap-articles.xml")
    open(sm, "w").write('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + "\n".join(f"<url><loc>{u}</loc><changefreq>monthly</changefreq><priority>0.8</priority></url>" for u in sitemap)
        + "\n</urlset>")
    print(f"\n{len(pages)} pages -> public/blog/ ; sitemap -> public/sitemap-articles.xml")

if __name__ == "__main__":
    main()

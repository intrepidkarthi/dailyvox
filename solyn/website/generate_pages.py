#!/usr/bin/env python3
"""Programmatic SEO page generator for DailyVox blog."""

import json
import os
import re

BASE_DIR = os.path.join(os.path.dirname(__file__), "public", "blog")
SITE_URL = "https://getdailyvox.com"
DATE = "2026-03-17"

TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title} - DailyVox Blog</title>
  <meta name="description" content="{meta_description}">
  <meta name="keywords" content="{meta_keywords}">
  <meta name="theme-color" content="#05081a">
  <meta property="og:type" content="article">
  <meta property="og:url" content="{canonical_url}">
  <meta property="og:title" content="{title}">
  <meta property="og:description" content="{meta_description}">
  <meta property="og:image" content="https://getdailyvox.com/og-image.png">
  <meta name="twitter:card" content="summary_large_image">
  <link rel="canonical" href="{canonical_url}">
  <link rel="stylesheet" href="/style.css">
  <link rel="icon" href="/app-icon.png">
  <script type="application/ld+json">
  {{
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    "headline": "{title}",
    "description": "{meta_description}",
    "url": "{canonical_url}",
    "datePublished": "{date}",
    "dateModified": "{date}",
    "author": {{ "@type": "Organization", "name": "DailyVox" }},
    "publisher": {{ "@type": "Organization", "name": "DailyVox", "url": "https://getdailyvox.com" }},
    "mainEntityOfPage": {{ "@type": "WebPage", "@id": "{canonical_url}" }}
  }}
  </script>
</head>
<body>
  <nav>
    <div class="container">
      <a href="/" class="nav-brand">
        <img src="/app-icon.png" alt="DailyVox">
        <span>DailyVox</span>
      </a>
      <ul class="nav-links">
        <li><a href="/blog">Blog</a></li>
        <li><a href="/privacy.html">Privacy</a></li>
        <li><a href="/support.html">Support</a></li>
      </ul>
    </div>
  </nav>

  <main class="container">
    <article class="blog-article">
      <div class="article-header">
        <a href="/blog" class="back-link">&larr; Back to Blog</a>
        <span class="blog-tag {tag_class}">{tag_label}</span>
        <h1>{h1}</h1>
        <p class="article-meta">{date_display} &middot; {read_time} min read</p>
      </div>

      <div class="article-body">
        {body_html}

        <div class="article-cta">
          <h3>{cta_title}</h3>
          <p>{cta_description}</p>
          <a href="https://apps.apple.com/app/id6760454642" class="cta-button">Download on the App Store</a>
        </div>
      </div>
    </article>
  </main>

  <footer>
    <div class="container">
      <div class="footer-links">
        <a href="/blog">Blog</a>
        <a href="/privacy.html">Privacy Policy</a>
        <a href="/support.html">Support</a>
      </div>
      <p>&copy; 2026 DailyVox. All rights reserved.</p>
    </div>
  </footer>
</body>
</html>"""


def word_count(html):
    text = re.sub(r'<[^>]+>', '', html)
    return len(text.split())


def generate_page(page_data):
    wc = word_count(page_data["body_html"])
    read_time = max(1, round(wc / 250))

    html = TEMPLATE.format(
        title=page_data["title"],
        meta_description=page_data["meta_description"],
        meta_keywords=page_data["meta_keywords"],
        canonical_url=f"{SITE_URL}/blog/{page_data['slug']}",
        date=DATE,
        date_display="March 17, 2026",
        tag_class=page_data["tag_class"],
        tag_label=page_data["tag_label"],
        h1=page_data["h1"],
        read_time=read_time,
        body_html=page_data["body_html"],
        cta_title=page_data["cta_title"],
        cta_description=page_data["cta_description"],
    )

    out_path = os.path.join(BASE_DIR, f"{page_data['slug']}.html")
    with open(out_path, "w") as f:
        f.write(html)

    print(f"  {page_data['slug']}.html ({wc} words, {read_time} min read)")
    return page_data


def generate_index_entry(page):
    return f"""
      <a href="/blog/{page['slug']}" class="blog-list-item">
        <div class="blog-list-meta">
          <span class="blog-tag {page['tag_class']}">{page['tag_label']}</span>
          <span class="blog-date">March 17, 2026</span>
        </div>
        <h2>{page['h1']}</h2>
        <p>{page['meta_description']}</p>
      </a>"""


def generate_sitemap_entry(page):
    return f"""  <url>
    <loc>{SITE_URL}/blog/{page['slug']}</loc>
    <lastmod>{DATE}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>"""


def main():
    data_dir = os.path.join(os.path.dirname(__file__), "seo_data")
    all_pages = []

    for filename in sorted(os.listdir(data_dir)):
        if not filename.endswith(".json"):
            continue
        filepath = os.path.join(data_dir, filename)
        with open(filepath) as f:
            pages = json.load(f)

        print(f"\nGenerating {filename} ({len(pages)} pages):")
        for page in pages:
            generate_page(page)
            all_pages.append(page)

    # Output index entries and sitemap entries for manual integration
    print(f"\n--- Generated {len(all_pages)} pages total ---")

    print("\n--- Sitemap entries (add to sitemap.xml) ---")
    for page in all_pages:
        print(generate_sitemap_entry(page))

    print("\n--- Blog index entries (add to blog/index.html) ---")
    for page in all_pages:
        print(generate_index_entry(page))


if __name__ == "__main__":
    main()

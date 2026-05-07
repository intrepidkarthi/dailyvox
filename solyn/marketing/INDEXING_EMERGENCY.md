# Indexing Emergency Action Plan

## Problem
- 1,681 pages exist on getdailyvox.com
- Only ~60 are indexed by Google
- Root cause: sitemap.xml was missing `/for/`, `/in/`, `/use/`, `/alternative/`, `/reports/`, `/research/`, `/about`, `/technology` — over 1,500 pages invisible to Google

## Fix Applied
- Rebuilt sitemap as a **sitemap index** with 8 sub-sitemaps
- All 1,681 pages now included with proper priorities and lastmod dates

## Immediate Actions (Do Today)

### 1. Deploy the new sitemaps
Upload these files to getdailyvox.com root:
- `sitemap.xml` (index file pointing to 8 sub-sitemaps)
- `sitemap-core.xml` (13 pages)
- `sitemap-blog.xml` (101 pages)
- `sitemap-alternatives.xml` (20 pages)
- `sitemap-use.xml` (40 pages)
- `sitemap-for-1.xml` (500 pages)
- `sitemap-for-2.xml` (500 pages)
- `sitemap-for-3.xml` (108 pages)
- `sitemap-cities.xml` (399 pages)

### 2. Submit in Google Search Console
1. Go to https://search.google.com/search-console
2. Select getdailyvox.com property
3. Go to **Sitemaps** (left sidebar)
4. Delete the old sitemap if listed
5. Submit: `https://getdailyvox.com/sitemap.xml`
6. Google will discover all 8 sub-sitemaps automatically

### 3. Manually Request Indexing (Top 20 Priority Pages)
Use **URL Inspection** tool in Search Console. Enter each URL, click "Request Indexing."
Google allows ~10-20 requests per day.

**Day 1 — highest value:**
1. https://getdailyvox.com/
2. https://getdailyvox.com/technology
3. https://getdailyvox.com/about
4. https://getdailyvox.com/blog/best-journal-app-for-privacy
5. https://getdailyvox.com/blog/best-free-journal-app
6. https://getdailyvox.com/blog/best-journal-app-for-adhd
7. https://getdailyvox.com/blog/best-offline-journal-app
8. https://getdailyvox.com/blog/voice-journaling-why-speaking-beats-typing
9. https://getdailyvox.com/blog/what-is-a-digital-twin
10. https://getdailyvox.com/journal-app-comparison

**Day 2 — comparisons & alternatives:**
11. https://getdailyvox.com/alternative/day-one
12. https://getdailyvox.com/alternative/reflectly
13. https://getdailyvox.com/alternative/apple-journal
14. https://getdailyvox.com/blog/dailyvox-vs-day-one
15. https://getdailyvox.com/blog/journal-app-privacy-comparison
16. https://getdailyvox.com/reports/journal-app-privacy-audit-2026
17. https://getdailyvox.com/reports/state-of-on-device-ai-journaling-2026
18. https://getdailyvox.com/research
19. https://getdailyvox.com/voice-journaling-statistics
20. https://getdailyvox.com/glossary

**Day 3+ — continue with remaining blog posts, then /use/ pages, then /alternative/ pages**

### 4. Ping Search Engines
After deploying, run:
```bash
cd solyn/website/public && bash ping-google.sh
```

### 5. Force Crawl via External Links
Post these on social media and Reddit (these create external signals that trigger crawling):
- Share the privacy audit report on Twitter with a link
- Post the technology page on Hacker News (Show HN: on-device AI architecture)
- Answer a Reddit thread in r/privacy linking to the privacy audit
- Share the best-journal-app-for-adhd post in r/ADHD

## Expected Timeline
- **24-48 hours**: Google discovers new sitemap, starts crawling
- **1-2 weeks**: Core pages + blog posts indexed (100-200 pages)
- **2-4 weeks**: Alternative and use-case pages indexed (200-500 pages)
- **4-8 weeks**: /for/ and /in/ pages start getting indexed (bulk pages take longer)
- **8-12 weeks**: Full index coverage approaching 1,500+

## Bing IndexNow (Instant Indexing)
Bing supports IndexNow protocol for instant indexing. Generate an API key:
1. Go to https://www.bing.com/indexnow
2. Generate a key
3. Host the key file at getdailyvox.com/{key}.txt
4. Submit URLs via the API — Bing indexes within minutes, not weeks

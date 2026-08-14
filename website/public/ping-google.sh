#!/bin/bash
# Post-deploy: notify search engines about updated sitemaps
# Google ping is deprecated — use Search Console manually
# Bing supports IndexNow for instant indexing

DOMAIN="https://getdailyvox.com"

echo "=== Google Sitemap Ping (deprecated — use Search Console instead) ==="
echo "Google no longer supports sitemap ping."
echo "→ Go to: https://search.google.com/search-console"
echo "→ Sitemaps → Submit: ${DOMAIN}/sitemap.xml"
echo "→ URL Inspection → Request Indexing on priority pages"
echo ""

echo "=== Pinging Bing ==="
curl -s -o /dev/null -w "Bing response: %{http_code}\n" "https://www.bing.com/ping?sitemap=${DOMAIN}/sitemap.xml"
echo ""

echo "=== IndexNow (Bing, Yandex, Naver) ==="
echo "For instant Bing indexing:"
echo "1. Generate an API key at https://www.bing.com/indexnow"
echo "2. Save it as ${DOMAIN}/{key}.txt"
echo "3. Then run:"
echo '   curl -X POST "https://api.indexnow.org/indexnow" \'
echo '     -H "Content-Type: application/json" \'
echo '     -d '"'"'{"host":"getdailyvox.com","key":"YOUR_KEY","urlList":["https://getdailyvox.com/","https://getdailyvox.com/technology","https://getdailyvox.com/blog/best-journal-app-for-privacy"]}'"'"''
echo ""

echo "=== Priority URLs for Manual Indexing ==="
echo "Submit these first in Google Search Console URL Inspection:"
echo "  1. ${DOMAIN}/"
echo "  2. ${DOMAIN}/technology"
echo "  3. ${DOMAIN}/about"
echo "  4. ${DOMAIN}/blog/best-journal-app-for-privacy"
echo "  5. ${DOMAIN}/blog/best-free-journal-app"
echo "  6. ${DOMAIN}/blog/best-journal-app-for-adhd"
echo "  7. ${DOMAIN}/blog/best-offline-journal-app"
echo "  8. ${DOMAIN}/journal-app-comparison"
echo "  9. ${DOMAIN}/alternative/day-one"
echo " 10. ${DOMAIN}/reports/journal-app-privacy-audit-2026"

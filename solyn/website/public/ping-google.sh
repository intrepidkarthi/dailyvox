#!/bin/bash
# Ping Google and Bing to re-crawl all sitemaps
# Run this after deploying the new sitemaps

DOMAIN="https://getdailyvox.com"

echo "=== Pinging Google ==="
curl -s "https://www.google.com/ping?sitemap=${DOMAIN}/sitemap.xml"
echo ""

echo "=== Pinging Bing ==="
curl -s "https://www.bing.com/ping?sitemap=${DOMAIN}/sitemap.xml"
echo ""

echo "=== Pinging individual sitemaps to Google ==="
for sm in sitemap-core.xml sitemap-blog.xml sitemap-alternatives.xml sitemap-use.xml sitemap-for-1.xml sitemap-for-2.xml sitemap-for-3.xml sitemap-cities.xml; do
  echo "  Pinging: ${sm}"
  curl -s "https://www.google.com/ping?sitemap=${DOMAIN}/${sm}" > /dev/null
done

echo ""
echo "Done. Next steps:"
echo "1. Deploy these sitemaps to getdailyvox.com"
echo "2. Go to Google Search Console -> Sitemaps -> Submit sitemap.xml"
echo "3. Use 'Request Indexing' on the top 20 pages via URL Inspection tool"
echo "4. Run: gsc-bulk-index.sh for bulk indexing via API (if you have API access)"

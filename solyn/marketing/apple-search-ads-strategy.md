# Apple Search Ads Strategy for DailyVox

## How Apple Search Ads Works (Quick Primer)

Apple Search Ads (ASA) places your app at the top of App Store search results when users search for relevant keywords. You pay per tap (CPT model), not per impression. There are two tiers:

- **ASA Basic**: Set a budget, pick countries, Apple handles the rest. Simple but no keyword control, no reporting on which keywords work. Not recommended.
- **ASA Advanced**: Full control over keywords, bids, ad groups, match types, and custom creatives. This is what DailyVox should use.

Apple frequently offers a **$100 credit for new accounts** -- use this to test before spending real money. There is no minimum spend commitment and campaigns can be paused instantly.

---

## Recommended Monthly Budget

| Phase | Monthly Budget | Duration | Goal |
|-------|---------------|----------|------|
| Phase 1: Testing | $100-150/mo ($3-5/day) | Months 1-2 | Find winning keywords, establish CPAs |
| Phase 2: Optimization | $200-300/mo ($7-10/day) | Months 3-4 | Scale winners, cut losers |
| Phase 3: Scaling | $300-500/mo ($10-17/day) | Month 5+ | Maximize installs on proven keywords |

**Start with $100/month.** This is realistic for a solo indie dev and enough to gather meaningful data across 3-4 campaigns. Do not scale until you know your CPA and which keywords convert.

---

## Expected CPA Ranges

| Keyword Type | Expected CPT | Expected CPA | Conversion Rate |
|-------------|-------------|--------------|-----------------|
| Brand (DailyVox) | $0.10-0.30 | $0.30-0.80 | 50-70% |
| Category/Generic | $0.50-1.50 | $1.50-4.00 | 30-50% |
| Competitor names | $0.80-2.50 | $2.50-6.00 | 20-35% |
| Long-tail/niche | $0.30-0.80 | $1.00-2.50 | 35-55% |

---

## Top 30 Keywords to Bid On

### Tier 1: Brand Defense (must-have, cheapest CPA)
1. `dailyvox`
2. `daily vox`
3. `dailyvox journal`

### Tier 2: Competitor Names (higher CPA but high-intent users)
4. `day one journal`
5. `day one app`
6. `reflectly`
7. `reflectly journal`
8. `journey diary`
9. `daylio`
10. `daylio journal`
11. `stoic app`
12. `rosebud journal`
13. `five minute journal`
14. `penzu`
15. `grid diary`
16. `audio diary app`

### Tier 3: Category/Generic (medium CPA, good volume)
17. `journal app`
18. `diary app`
19. `journaling app`
20. `daily journal`
21. `voice journal`
22. `voice diary`
23. `mindfulness journal`
24. `gratitude journal`

### Tier 4: Long-tail / Niche (low competition, best ROI potential)
25. `voice journaling`
26. `ai journal app`
27. `audio journal`
28. `talk to journal`
29. `free journal app`
30. `mood journal free`

**Priority guidance**: Long-tail and niche keywords (Tier 4) often deliver the best ROI for indie developers.

---

## Campaign Structure

### Campaign 1: Brand
- **Ad Group: Brand Exact** -- Keywords: `dailyvox`, `daily vox`, `dailyvox journal` (exact match)
- **Bid**: $0.30-0.50

### Campaign 2: Category (Generic)
- **Ad Group: Journal Generic** -- `journal app`, `diary app`, `journaling app`, `daily journal` (exact match)
- **Ad Group: Voice/AI Niche** -- `voice journal`, `voice diary`, `ai journal app`, `audio journal`, `voice journaling`, `talk to journal` (exact match)
- **Ad Group: Wellness/Mood** -- `mindfulness journal`, `gratitude journal`, `mood journal free` (exact match)
- **Ad Group: Free Keywords** -- `free journal app`, `free diary app` (exact match)
- **Bid**: Start at $0.80-1.20

### Campaign 3: Competitor
- **Ad Group: Premium Competitors** -- `day one journal`, `day one app`, `reflectly`, `five minute journal` (exact match)
- **Ad Group: Mid-tier Competitors** -- `daylio`, `stoic app`, `rosebud journal`, `penzu`, `grid diary` (exact match)
- **Ad Group: Audio Competitors** -- `audio diary app` (exact match)
- **Bid**: Start at $0.60-0.80

### Campaign 4: Discovery
- **Ad Group: Broad Match** -- All keywords from campaigns 1-3, broad match, Search Match OFF
- **Ad Group: Search Match** -- No keywords, Search Match ON
- Add all exact match keywords from campaigns 1-3 as NEGATIVE keywords here
- **Bid**: $0.50-0.70

---

## Creative Recommendations

### Custom Product Pages (CPPs)
1. **"Voice First" CPP** -- For voice/audio keywords. Lead screenshot: voice recording interface.
2. **"Competitor Switch" CPP** -- For competitor keywords. Emphasize free + voice-first + AI.
3. **"Wellness" CPP** -- For mindfulness/gratitude keywords. Lead screenshot: mood tracking.

### What to emphasize
- **"Free"** -- Massive differentiator
- **"Voice-first"** -- Unique selling point
- **"AI-powered"** -- Modern/smart signal
- **"No typing"** -- Concrete friction removal

---

## Measurement Plan

### Key Metrics
| Metric | Target |
|--------|--------|
| CPT (Cost Per Tap) | Under $1.50 |
| TTR (Tap-Through Rate) | Above 8% |
| CR (Conversion Rate) | Above 40% |
| CPA (Cost Per Acquisition) | Under $3.00 |

### Weekly Optimization
1. **Every Monday**: Pause keywords with CPA above $5 and fewer than 3 installs
2. **Every Monday**: Graduate winning Discovery terms to exact match
3. **Bi-weekly**: Increase bids 10-20% on keywords with CPA under $2.00
4. **Monthly**: Review CPP performance, iterate on winners

---

## Common Mistakes to Avoid

1. Using Basic mode instead of Advanced
2. Bidding on ultra-high-volume keywords ("journal" alone)
3. Leaving Search Match ON in main campaigns
4. Keyword overlap across campaigns (bid against yourself)
5. Neglecting negative keywords
6. Not bidding on your own brand name
7. Optimizing for CPI instead of engagement
8. Scaling before understanding unit economics
9. Ignoring seasonality (Q4 spike, January = journal gold)
10. Not creating custom product pages

---

## Quick-Start Checklist

- [ ] Claim the $100 Apple Search Ads credit for new accounts
- [ ] Set up 4 campaigns: Brand, Category, Competitor, Discovery
- [ ] Create 3 custom product pages (Voice, Competitor Switch, Wellness)
- [ ] Start with exact match only in campaigns 1-3
- [ ] Add negative keywords to prevent overlap with Discovery campaign
- [ ] Set daily budget cap at $3-5/day
- [ ] Implement AdServices attribution in the app
- [ ] Set a weekly Monday calendar reminder to review and optimize
- [ ] After 2 weeks of data, make first bid adjustments
- [ ] After 1 month, assess which campaigns to scale and which to cut

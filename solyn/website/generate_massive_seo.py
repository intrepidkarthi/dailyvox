#!/usr/bin/env python3
"""
Massive programmatic SEO page generator for DailyVox.
Generates ~1,500 unique landing pages targeting long-tail keywords.
"""

import os
import hashlib
import random

BASE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "public")
APP_STORE = "https://apps.apple.com/app/id6760454642"
DOMAIN = "https://getdailyvox.com"
DATE = "April 12, 2026"
DATE_ISO = "2026-04-12"

RELATED_LINKS = [
    ("/blog/voice-journaling-why-speaking-beats-typing", "Voice Journaling: Why Speaking Beats Typing"),
    ("/blog/what-is-voice-journaling", "What Is Voice Journaling? The Complete Guide"),
    ("/blog/adhd-voice-journaling-protocol", "The ADHD Voice Journaling Protocol"),
    ("/blog/best-free-journal-app-no-paywall-2026", "Best Free Journal Apps in 2026"),
    ("/blog/science-of-talking-to-yourself", "The Science of Talking to Yourself"),
    ("/blog/voice-journaling-vs-therapy", "Voice Journaling vs. Therapy"),
    ("/blog/journaling-for-mental-fitness", "Journaling for Mental Fitness"),
    ("/blog/how-to-journal-when-you-hate-writing", "How to Journal When You Hate Writing"),
    ("/blog/ai-mood-prediction-vs-tracking", "AI Mood Prediction vs. Mood Tracking"),
    ("/blog/journal-every-day-90-days", "What Happens When You Journal Every Day for 90 Days"),
    ("/blog/how-digital-twin-learns-personality", "How Your Digital Twin Learns Your Personality"),
    ("/blog/talk-to-your-past-self-digital-twin", "How to Talk to Your Past Self"),
    ("/blog/best-journal-app-for-privacy", "Best Private Journal App (2026)"),
    ("/blog/ai-journal-that-works-offline", "Why Your AI Journal Should Work Without Wi-Fi"),
    ("/blog/how-to-start-journaling", "How to Start Journaling"),
    ("/blog/best-journal-app-iphone", "Best Journal App for iPhone (2026)"),
    ("/blog/five-minute-voice-morning-journal", "The 5-Minute Voice Morning Journal"),
    ("/blog/voice-journaling-nervous-system-regulation", "Voice Journaling and Nervous System Regulation"),
    ("/blog/anti-optimization-journal", "The Anti-Optimization Journal"),
    ("/blog/how-to-journal-for-mental-health", "How to Journal for Mental Health"),
]

def get_related(seed, count=3):
    """Get deterministic but varied related links based on seed."""
    r = random.Random(seed)
    return r.sample(RELATED_LINKS, count)

def make_slug(text):
    return text.lower().replace(" ", "-").replace("&", "and").replace("'", "").replace(",", "").replace(".", "").replace("/", "-").replace("(", "").replace(")", "")

def page_html(title, meta_desc, canonical_path, breadcrumbs, body_html, cta_title, cta_desc):
    related = get_related(canonical_path)
    related_html = "\n".join(
        f'          <li><a href="{link}">{name}</a></li>' for link, name in related
    )
    bc_items = []
    for i, (name, url) in enumerate(breadcrumbs):
        if i == len(breadcrumbs) - 1:
            bc_items.append(f'{{"@type":"ListItem","position":{i+1},"name":"{name}"}}')
        else:
            bc_items.append(f'{{"@type":"ListItem","position":{i+1},"name":"{name}","item":"{url}"}}')
    bc_json = ",\n      ".join(bc_items)

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
<!-- Google tag (gtag.js) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-R544S4KDBQ"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){{dataLayer.push(arguments);}}
  gtag('js', new Date());
  gtag('config', 'G-R544S4KDBQ');
</script>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title} - DailyVox</title>
  <meta name="description" content="{meta_desc}">
  <meta name="theme-color" content="#05081a">
  <meta property="og:type" content="article">
  <meta property="og:url" content="{DOMAIN}{canonical_path}">
  <meta property="og:title" content="{title}">
  <meta property="og:description" content="{meta_desc}">
  <meta property="og:image" content="{DOMAIN}/og-image.png">
  <meta name="twitter:card" content="summary_large_image">
  <link rel="canonical" href="{DOMAIN}{canonical_path}">
  <link rel="stylesheet" href="/style.css">
  <link rel="icon" href="/app-icon.png">
  <script type="application/ld+json">
  {{
    "@context": "https://schema.org",
    "@type": "Article",
    "headline": "{title}",
    "description": "{meta_desc}",
    "url": "{DOMAIN}{canonical_path}",
    "datePublished": "{DATE_ISO}",
    "dateModified": "{DATE_ISO}",
    "author": {{ "@type": "Organization", "name": "DailyVox" }},
    "publisher": {{ "@type": "Organization", "name": "DailyVox", "url": "{DOMAIN}" }}
  }}
  </script>
  <script type="application/ld+json">
  {{
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    "itemListElement": [
      {bc_json}
    ]
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
        <li><a href="/faq">FAQ</a></li>
        <li><a href="/privacy">Privacy</a></li>
        <li><a href="/support">Support</a></li>
      </ul>
    </div>
  </nav>

  <main class="container">
    <article class="blog-article">
      <div class="article-header">
        <h1>{title}</h1>
        <p class="article-meta">{DATE}</p>
      </div>

      <div class="article-body">
{body_html}

        <h2>Related Articles</h2>
        <ul>
{related_html}
        </ul>

        <div class="article-cta">
          <h3>{cta_title}</h3>
          <p>{cta_desc}</p>
          <a href="{APP_STORE}" class="cta-button">Download on the App Store</a>
        </div>
      </div>
    </article>
  </main>

  <footer>
    <div class="container">
      <div class="footer-links">
        <a href="/blog">Blog</a>
        <a href="/faq">FAQ</a>
        <a href="/privacy">Privacy Policy</a>
        <a href="/support">Support</a>
      </div>
      <p>&copy; 2026 DailyVox. All rights reserved.</p>
    </div>
  </footer>
</body>
</html>'''


# ============================================================
# PROFESSIONS DATA
# ============================================================
PROFESSIONS = {
    "therapists": ("Therapists", "After hours of holding space for others, you need space for yourself. Voice journaling lets you process countertransference, session reflections, and emotional fatigue without adding more screen time.", "between sessions", "decompress after holding space for others all day"),
    "teachers": ("Teachers", "Between lesson planning, grading, and 30 conversations before lunch, your own thoughts get buried. A 2-minute voice entry on the drive home captures what matters before it fades.", "during your commute home", "process classroom experiences without more paperwork"),
    "nurses": ("Nurses", "12-hour shifts don't leave time for writing. But you can speak into your phone during a break or on the drive home. Voice journaling helps nurses process the emotional weight of patient care privately.", "after long shifts", "decompress from patient care without writing a word"),
    "lawyers": ("Lawyers", "Legal work demands precision with words all day. Voice journaling is the opposite — unfiltered, private, no audience. Process case stress, client dynamics, and career decisions without drafting another document.", "between cases", "process the emotional weight of legal work privately"),
    "doctors": ("Doctors", "Medicine teaches you to compartmentalize. Voice journaling gives those compartments a safe place to open. Process difficult diagnoses, patient losses, and the relentless pace in 2 minutes.", "between patients", "process what medical training taught you to suppress"),
    "dentists": ("Dentists", "Repetitive precision all day, patient anxiety to manage, business pressures to juggle. Voice journal during your commute to separate work-you from home-you.", "during your commute", "transition between clinical precision and personal reflection"),
    "pharmacists": ("Pharmacists", "Hundreds of prescriptions, zero room for error, and customers who need patience. Voice journaling helps pharmacists process the quiet stress of a job where mistakes aren't an option.", "after your shift", "process the quiet pressure of zero-error work"),
    "veterinarians": ("Veterinarians", "You chose this career because you love animals. Nobody warned you about the grief, the euthanasia decisions, and the compassion fatigue. Voice journal to process what you can't share with clients.", "after difficult cases", "process compassion fatigue and difficult decisions privately"),
    "pilots": ("Pilots", "Hours of focused attention, layovers in unfamiliar cities, time away from family. Voice journaling during downtime helps pilots stay grounded — mentally, not just physically.", "during layovers", "stay mentally grounded between flights"),
    "truck-drivers": ("Truck Drivers", "Long hours alone on the road — the perfect time for voice journaling. No typing, no pulling over. Just speak your thoughts while you drive. DailyVox works offline, even without cell signal.", "on the road", "turn long solo drives into productive self-reflection"),
    "police-officers": ("Police Officers", "Every shift carries weight that most people will never understand. Voice journaling gives law enforcement a private, secure outlet — no department records, no cloud servers, just your phone.", "after shifts", "process what you see on the job in complete privacy"),
    "firefighters": ("First Responders", "You run toward what everyone else runs from. The adrenaline fades, but the images don't. Voice journaling gives first responders a private way to process without the stigma of asking for help.", "after calls", "process critical incidents privately without stigma"),
    "paramedics": ("Paramedics", "Every call is different. Every call leaves a mark. Voice journaling between shifts helps paramedics process the emotional toll of emergency medicine without adding another task to an exhausting day.", "between shifts", "process the emotional toll of emergency medicine"),
    "military": ("Veterans & Military", "Military life demands suppression. Voice journaling offers a private, offline, secure space to process — no servers, no cloud, no one listening. Just you and your phone.", "in complete privacy", "process experiences in a secure, offline space"),
    "social-workers": ("Social Workers", "Carrying other people's trauma is the job description. Voice journaling helps social workers maintain boundaries between their clients' stories and their own emotional health.", "between client visits", "maintain emotional boundaries with client trauma"),
    "coaches": ("Life Coaches & Fitness Coaches", "You spend all day helping others reflect. Voice journaling is how you do the same for yourself — quick, honest, without the performance of being 'the coach.'", "after coaching sessions", "practice what you preach about self-reflection"),
    "real-estate-agents": ("Real Estate Agents", "High-stakes negotiations, emotional buyers, unpredictable schedules. Voice journal between showings to process client dynamics and stay centered during the chaos.", "between showings", "stay centered during high-stakes negotiations"),
    "accountants": ("Accountants", "Numbers all day, every day. Voice journaling offers the opposite — unstructured, emotional, human. Process tax season stress, client frustrations, and career thoughts.", "after number-heavy days", "process the human side of a numbers-driven career"),
    "financial-advisors": ("Financial Advisors", "You manage other people's financial anxiety all day. Voice journaling helps you process your own stress about markets, clients, and the weight of managing someone's life savings.", "after market days", "process the emotional weight of managing others' money"),
    "architects": ("Architects", "Creative work requires mental clarity. Voice journaling clears the cognitive clutter between projects, helping architects process design challenges and client feedback.", "between projects", "clear cognitive clutter and process design challenges"),
    "engineers": ("Engineers", "Problem-solving all day, debugging all night. Voice journaling gives engineers a non-technical outlet — process frustrations, career thoughts, and the human side of technical work.", "during breaks", "process the human side of technical work"),
    "scientists": ("Scientists", "Research is isolating. Voice journaling helps scientists process experiment failures, publication pressure, and the emotional rollercoaster of discovery.", "after lab sessions", "process research frustrations and breakthroughs"),
    "researchers": ("Researchers", "The research life is years of uncertainty punctuated by brief moments of clarity. Voice journaling tracks your thinking over time — imposter syndrome, breakthroughs, and everything between.", "throughout your research journey", "track your thinking through years of uncertainty"),
    "phd-students": ("PhD Students", "Imposter syndrome, advisor dynamics, isolation, and the endless feeling that you should be working. Voice journaling gives PhD students a pressure valve that costs nothing.", "during your PhD journey", "release academic pressure without adding another task"),
    "college-students": ("College Students", "New city, new friends, new identity. College is overwhelming and exhilarating at the same time. Voice journal to process it all — free, private, no account needed.", "during college life", "process the overwhelming transition to independence"),
    "high-school-students": ("High School Students", "Grades, friendships, identity, future pressure. Voice journaling gives teens a private outlet that's faster than writing and more honest than texting.", "daily", "privately process the pressure of growing up"),
    "professors": ("Professors", "Teaching, research, committees, tenure pressure. Voice journaling helps professors reflect on what actually matters amid the institutional noise.", "between classes", "reflect on purpose amid institutional demands"),
    "librarians": ("Librarians", "Quiet profession, rich inner life. Voice journaling lets librarians process community interactions, professional frustrations, and the satisfaction of connecting people with knowledge.", "after work", "process the rich inner life of a quiet profession"),
    "musicians": ("Musicians", "Creativity is emotional. Voice journaling captures the ideas, frustrations, and breakthroughs that happen between practice sessions and performances.", "between practice sessions", "capture creative ideas before they fade"),
    "artists": ("Artists", "Art requires vulnerability. Voice journaling provides a private space to process creative blocks, self-doubt, and the emotional cycles of making things.", "during creative work", "process creative blocks and self-doubt privately"),
    "photographers": ("Photographers", "You document everyone else's moments. Voice journaling is how you document your own — the stories behind the shots, the creative evolution, the business stress.", "after shoots", "document the stories behind your work"),
    "writers": ("Writers", "Ironic — writers who hate journaling. But voice journaling isn't writing. It's talking. Many writers find that speaking unlocks ideas that the keyboard blocks.", "when stuck", "unlock ideas by speaking instead of typing"),
    "filmmakers": ("Filmmakers", "Production is chaos. Voice journaling between setups, during commutes, or after wrapping captures the creative decisions and emotions that don't make it into the director's cut.", "during production", "capture creative decisions film logs miss"),
    "actors": ("Actors", "Auditions, rejection, character work, identity questions. Voice journaling helps actors separate their own emotions from the characters they carry.", "after auditions", "separate your identity from the characters you play"),
    "designers": ("Designers", "Visual work, verbal processing. Many designers find that speaking about design problems unlocks solutions that staring at the screen doesn't.", "during design work", "solve visual problems through verbal processing"),
    "developers": ("Developers", "Debugging code is logical. Debugging your feelings is not. Voice journaling gives developers a non-technical outlet for burnout, imposter syndrome, and career reflections.", "after coding sessions", "debug your feelings, not just your code"),
    "data-scientists": ("Data Scientists", "You analyze everyone else's data. Voice journaling generates your own — mood patterns, stress triggers, and career insights from your personal dataset.", "daily", "analyze your own emotional patterns like you analyze data"),
    "product-managers": ("Product Managers", "Caught between engineering, design, and business. Voice journaling helps PMs process conflicting stakeholder demands and clarify their own thinking.", "between meetings", "clarify your thinking amid conflicting demands"),
    "project-managers": ("Project Managers", "You manage everyone's timeline but your own mental health. Voice journaling is the 2-minute check-in nobody scheduled for you.", "between sprints", "check in with yourself between managing everyone else"),
    "executives": ("Executives", "The higher you climb, the fewer people you can be honest with. Voice journaling is the private advisor that never judges, never leaks, and never has an agenda.", "daily", "be honest when you can't be honest with anyone else"),
    "ceos": ("CEOs & Founders", "Every decision affects everyone. Voice journaling captures the thinking behind decisions — invaluable when you need to remember why you chose a direction.", "daily", "capture the thinking behind high-stakes decisions"),
    "freelancers": ("Freelancers", "No colleagues to vent to, no structure to fall back on. Voice journaling gives freelancers the sounding board that solo work doesn't provide.", "between projects", "get the sounding board solo work doesn't provide"),
    "consultants": ("Consultants", "New client, new context, new problems — every week. Voice journaling helps consultants maintain continuity of self amid constant context-switching.", "between engagements", "maintain your identity amid constant context-switching"),
    "remote-workers": ("Remote Workers", "No commute to decompress, no watercooler to vent. Voice journaling replaces the informal processing that remote work eliminates.", "during breaks", "replace the informal processing remote work eliminates"),
    "shift-workers": ("Shift Workers", "Your schedule doesn't fit a 'morning routine.' Voice journaling works at 3 AM, 3 PM, or anywhere between. No rules about when to journal.", "anytime", "journal on your schedule, not someone else's"),
    "retail-workers": ("Retail Workers", "Customer-facing all day, processing alone at night. Voice journaling helps retail workers decompress from the emotional labor of service work.", "after shifts", "decompress from the emotional labor of customer service"),
    "restaurant-workers": ("Restaurant Workers", "Rushes, difficult customers, physical exhaustion. Voice journaling takes 2 minutes — less than a smoke break — and helps more.", "after the rush", "process the chaos of service industry work"),
    "bartenders": ("Bartenders", "You hear everyone's stories but never tell your own. Voice journaling flips that — a private space where the listener gets to speak.", "after closing", "finally be the one who gets to speak"),
    "chefs": ("Chefs", "Creative pressure, physical demands, long hours. Voice journaling captures the passion and frustration of kitchen life in 2 minutes.", "after service", "capture the passion and frustration of kitchen life"),
    "baristas": ("Baristas", "Hundreds of interactions before noon, then the crash. Voice journaling helps baristas process the social overload of customer-facing work.", "after your shift", "process the social overload of constant interaction"),
    "personal-trainers": ("Personal Trainers", "You motivate others all day. Voice journaling is where you honestly assess your own energy, goals, and satisfaction.", "between clients", "turn the coaching lens on yourself"),
    "yoga-instructors": ("Yoga Instructors", "You teach presence but struggle with your own thoughts. Voice journaling bridges the gap between the calm you project and the reality you feel.", "after classes", "process the gap between the calm you project and what you feel"),
    "physical-therapists": ("Physical Therapists", "Patients in pain, slow progress, emotional stories. Voice journaling helps PTs process the empathy fatigue of rehabilitation work.", "between patients", "process empathy fatigue from rehabilitation work"),
    "psychologists": ("Psychologists", "You understand the theory of emotional processing better than anyone. Voice journaling is where you practice it on yourself.", "after sessions", "practice the emotional processing you prescribe to others"),
    "counselors": ("Counselors", "Holding space for others' pain all day, then going home and holding your own. Voice journaling creates the boundary between work-pain and self-pain.", "after sessions", "create boundaries between others' pain and your own"),
    "journalists": ("Journalists", "You report the story but rarely process how it affected you. Voice journaling captures the human toll of covering difficult events.", "after assignments", "process the human toll of the stories you cover"),
    "podcasters": ("Podcasters", "You talk for a living, but always for an audience. Voice journaling is talking without an audience — the unedited, unpublished version of your thoughts.", "between episodes", "talk without an audience for once"),
    "marketers": ("Marketers", "You craft messages all day for others. Voice journaling is the uncraft — raw, unpolished thoughts just for you. No audience, no metrics, no A/B test.", "daily", "stop crafting messages and just speak honestly"),
    "salespeople": ("Salespeople", "Rejection is the job. Voice journaling helps salespeople process the emotional toll of hearing 'no' 50 times a day without carrying it home.", "after calls", "process the toll of constant rejection privately"),
    "recruiters": ("Recruiters", "Managing candidate expectations, hiring manager demands, and your own targets. Voice journaling is the 2-minute reset between conversations.", "between interviews", "reset between the competing demands of everyone else"),
    "flight-attendants": ("Flight Attendants", "Jet lag, different cities, passenger stress. Voice journaling works offline at 35,000 feet — process your day while the passengers sleep.", "during layovers", "journal at 35,000 feet, no Wi-Fi needed"),
    "stay-at-home-parents": ("Stay-at-Home Parents", "Your identity merged with your kids' schedule. Voice journaling takes 2 minutes during nap time to remember that you exist as a person, not just a parent.", "during nap time", "remember you exist as a person, not just a parent"),
    "new-moms": ("New Moms", "Sleep-deprived, identity-shifting, hands-literally-full. Voice journaling is the only journaling method that works while feeding, rocking, or walking with a stroller.", "hands-free", "journal when your hands are full and your mind is overflowing"),
    "new-dads": ("New Dads", "Nobody asks how the dad is doing. Voice journaling gives new fathers a space to process the massive identity shift that society expects them to handle silently.", "during quiet moments", "process the identity shift nobody asks you about"),
    "single-parents": ("Single Parents", "Everything falls on you. Voice journaling is 2 minutes you don't have — but need. Process the overwhelm, the guilt, and the quiet pride of doing it alone.", "whenever you can", "process the overwhelm of doing everything alone"),
    "caregivers": ("Caregivers", "You pour everything into someone else. Voice journaling is 2 minutes of pouring into yourself. Caregiver burnout is real — this is the smallest possible self-care.", "between care duties", "2 minutes of self-care in a life dedicated to someone else"),
    "retirees": ("Retirees", "After decades of being defined by work, who are you now? Voice journaling helps retirees process the identity transition and capture the stories and wisdom they've accumulated.", "daily", "process the identity transition and preserve your stories"),
    "seniors": ("Seniors", "No tiny keyboard needed. No typing, no writing, no squinting at a screen. Just speak. DailyVox captures your voice and turns it into text. Your memories, preserved your way.", "daily", "preserve memories without typing a single word"),
    "veterans": ("Veterans", "Privacy isn't optional — it's survival. DailyVox works offline, has no servers, and locks behind Face ID. Your thoughts never leave your device. Built for people who need real privacy.", "in complete security", "journal in a space as secure as you need it to be"),
}

# ============================================================
# USE CASES DATA
# ============================================================
USE_CASES = {
    "morning-routine": ("Morning Routine", "Start your day with a 2-minute voice check-in. Name your mood, set an intention, dump your worries. No notebook required — just speak while making coffee.", "voice morning journal routine"),
    "before-bed": ("Before Bed", "Racing thoughts at midnight? Speak them into your phone. Voice journaling before bed externalizes the mental loops that keep you awake.", "bedtime journal voice app"),
    "during-commute": ("During Your Commute", "Dead time becomes reflection time. Voice journal while driving, walking, or riding transit. DailyVox works offline — even in subway tunnels.", "commute journal voice app"),
    "after-therapy": ("After Therapy Sessions", "Extend the work between sessions. Voice journal what came up, what surprised you, and what you want to explore next time.", "post therapy journal app"),
    "grief-processing": ("Grief & Loss", "When writing feels impossible, speaking is easier. Voice journaling gives grief a place to go — no structure required, just let it out.", "grief journal voice app"),
    "pregnancy-journal": ("Pregnancy", "Document every trimester hands-free. Voice journal symptoms, emotions, appointments, and the thousand tiny moments worth remembering.", "pregnancy diary voice app"),
    "gratitude-practice": ("Gratitude Practice", "One minute of spoken gratitude rewires your brain's negativity bias. Voice journaling makes gratitude practice faster than any notebook method.", "gratitude journal voice app"),
    "dream-journal": ("Dream Journaling", "Dreams fade in minutes. Keep your phone by the bed and voice record immediately on waking — before the details disappear.", "dream journal voice app"),
    "travel-diary": ("Travel", "No Wi-Fi in the mountains? No problem. DailyVox works 100% offline. Capture travel experiences by voice in any country, any timezone.", "travel diary voice app offline"),
    "breakup-recovery": ("Breakup Recovery", "Processing a breakup out loud is more cathartic than writing about it. Voice journaling prevents the alternative — texting your ex at 2 AM.", "breakup journal app"),
    "sobriety-journal": ("Sobriety & Recovery", "Daily check-ins support recovery. Voice journaling makes the check-in effortless — 2 minutes, no writing, completely private.", "sobriety journal app private"),
    "anger-management": ("Anger Management", "Speak the anger instead of acting on it. Voice journaling creates a 2-minute buffer between trigger and reaction.", "anger management journal app"),
    "job-search": ("Job Search", "Track your headspace, not just your applications. Voice journal the rejections, the interviews, the doubt, and the hope.", "job search journal app"),
    "new-city": ("Moving to a New City", "Everything is unfamiliar. Voice journaling anchors you — process the loneliness, excitement, and identity shift of starting over.", "moving journal app"),
    "empty-nest": ("Empty Nest", "The house is quiet for the first time in decades. Voice journaling helps parents process the transition from daily parenting to the next chapter.", "empty nest journal app"),
    "starting-college": ("Starting College", "New city, new people, new identity. Voice journal the overwhelm, homesickness, and excitement that texting your parents doesn't capture.", "college journal app free"),
    "career-change": ("Career Change", "Leaving one identity for another. Voice journaling tracks the fear, excitement, and second-guessing of reinventing your professional life.", "career change journal app"),
    "retirement": ("Retirement", "Who are you without your job title? Voice journaling helps you process the biggest identity transition of adulthood.", "retirement journal app"),
    "health-diagnosis": ("Health Diagnosis", "Processing a diagnosis is emotional, not logical. Voice journaling gives the fear, anger, and confusion somewhere to go.", "health journal app private"),
    "chronic-illness": ("Chronic Illness", "Some days are good. Some aren't. Voice journaling tracks the patterns, captures the frustrations, and validates the experience over time.", "chronic illness journal app"),
    "burnout-recovery": ("Burnout Recovery", "You don't need another productivity system. You need 2 minutes of honest processing. Voice journaling is recovery, not optimization.", "burnout recovery journal"),
    "creative-block": ("Creative Block", "Speak instead of staring at the blank page. Voice journaling bypasses the creative block by engaging a different part of your brain.", "creative journal voice app"),
    "meditation-alternative": ("Meditation Alternative", "Can't sit still and clear your mind? Voice journaling lets you use your busy mind instead of fighting it.", "meditation alternative journal app"),
    "prayer-journal": ("Prayer & Spiritual Practice", "Speak your prayers, reflections, and spiritual insights. Voice journaling preserves your faith journey privately on your device.", "prayer journal app private"),
    "goal-setting": ("Goal Setting", "Spoken commitments stick better than written ones. Voice journal your goals and track your progress through mood and reflection patterns.", "goal setting journal app"),
    "year-in-review": ("Year in Review", "12 months of voice entries become the most honest year-in-review you've ever had. Your Digital Twin shows how you've changed.", "year in review journal app"),
    "monthly-reflection": ("Monthly Reflection", "A 5-minute monthly voice entry captures what no calendar or task list preserves — how the month actually felt.", "monthly reflection journal"),
    "relationship-checkin": ("Relationship Check-In", "Process your relationship feelings privately before bringing them to your partner. Clarity first, conversation second.", "relationship journal app private"),
    "interview-prep": ("Interview Prep", "Voice journal your thoughts before and after interviews. Hearing yourself articulate your story improves your real interview performance.", "interview prep journal app"),
    "public-speaking": ("Public Speaking Prep", "Practice by speaking into your journal. Review your transcripts. Get comfortable hearing your own voice before the audience does.", "public speaking practice app"),
    "fitness-goals": ("Fitness Journey", "Track the mental game of fitness, not just the reps. Voice journal motivation, setbacks, and the relationship between mood and performance.", "fitness journal app voice"),
    "weight-loss": ("Weight Loss Journey", "It's not about the food — it's about the feelings. Voice journal the emotional patterns behind eating habits.", "weight loss journal app"),
    "language-learning": ("Language Learning", "Practice speaking your target language into a voice journal. The transcription shows pronunciation feedback instantly.", "language learning voice journal"),
    "study-abroad": ("Study Abroad", "Capture the culture shock, homesickness, and growth of living in another country. Works offline — no international data plan needed.", "study abroad journal app offline"),
    "wedding-planning": ("Wedding Planning", "The happiest and most stressful time of your life, often simultaneously. Voice journal the real emotions behind the Pinterest boards.", "wedding planning journal app"),
    "divorce-processing": ("Divorce", "The hardest conversations happen inside your own head. Voice journaling gives them space to exist without sending them to anyone.", "divorce journal app private"),
    "new-baby": ("New Baby", "Capture the first smile, the sleepless nights, the overwhelming love — by voice, while your hands hold the baby.", "new baby journal app voice"),
    "adoption-journey": ("Adoption Journey", "Document the waiting, the hope, the paperwork, and the joy. A voice journal preserves the emotional arc that adoption paperwork doesn't capture.", "adoption journal app"),
    "sabbatical": ("Sabbatical", "Time off to think. Voice journaling structures the unstructured — capture insights before they dissolve back into relaxation.", "sabbatical journal app"),
    "immigration": ("Immigration Journey", "New country, new language, new identity. Voice journaling preserves who you were while you become who you're becoming.", "immigration journal app"),
}

# ============================================================
# ALTERNATIVES DATA
# ============================================================
ALTERNATIVES = {
    "day-one": ("Day One", "$34.99/year", "Cloud-based, requires account, AI features locked behind Gold tier ($49.99/yr). DailyVox is free, on-device, voice-first."),
    "reflectly": ("Reflectly", "$59.99/year", "Cloud AI processing, limited free tier. DailyVox gives you all AI features — mood detection, Digital Twin, predictions — for free."),
    "journey": ("Journey App", "$29.99/year", "Cross-platform but cloud-dependent. DailyVox is iOS-only but 100% offline with on-device AI. Your data never leaves your phone."),
    "daylio": ("Daylio", "$23.99/year", "Emoji-based mood logging, no actual journaling. DailyVox gives you full voice entries with automatic mood detection — no tapping emojis."),
    "penzu": ("Penzu", "$19.99/year", "Text-only, cloud-based, subscription required. DailyVox is voice-first, on-device, and completely free."),
    "five-minute-journal": ("Five Minute Journal", "$14.99 one-time", "Structured prompts only, no voice, no AI. DailyVox lets you speak freely and AI handles the insights."),
    "apple-journal": ("Apple Journal", "Free", "Basic and limited — no voice transcription, no AI insights, no mood tracking, no Digital Twin. DailyVox adds intelligence Apple left out."),
    "notion-journal": ("Notion for Journaling", "Free-$10/month", "Notion is a productivity tool, not a journal. No voice input, no mood tracking, no privacy focus. DailyVox is purpose-built."),
    "grid-diary": ("Grid Diary", "$2.99/week", "Template-based, no voice, cloud sync. DailyVox is free, voice-first, and keeps everything on your device."),
    "audio-diary": ("AudioDiary", "$59.99/year", "Voice journaling but cloud-based and expensive. DailyVox does everything AudioDiary does for $0 — and keeps your data on-device."),
    "stoic": ("Stoic App", "$39.99/year", "CBT-focused journaling, cloud-based. DailyVox adds voice input and Digital Twin personality modeling — all free and on-device."),
    "rosebud": ("Rosebud Journal", "$9.99/month", "Cloud AI journaling, sends entries to servers. DailyVox matches the AI features without sending a single byte to the cloud."),
    "diarium": ("Diarium", "$7.99/year", "Cross-platform calendar diary. DailyVox adds voice-first input, on-device AI, and a Digital Twin that learns your personality."),
    "momento": ("Momento", "Free with IAP", "Social media aggregation journal. DailyVox is the opposite — private, voice-based, and entirely offline."),
    "bear": ("Bear App", "$29.99/year", "Beautiful note-taking, not journaling. No voice, no mood tracking, no AI insights. DailyVox is built specifically for journals."),
    "obsidian-journal": ("Obsidian for Journaling", "Free-$50/year", "Powerful but complex. No voice input, no mood detection, steep learning curve. DailyVox is open-and-talk simple."),
    "evernote-journal": ("Evernote for Journaling", "$14.99/month", "Bloated note-taking app, not a journal. DailyVox is lightweight, voice-first, and purpose-built for daily reflection."),
    "samsung-notes": ("Samsung Notes", "Free (Android only)", "Android only, no AI, no voice journaling features. DailyVox is iOS with on-device AI and voice-first design."),
    "bearable": ("Bearable", "Free with $5.99/month premium", "Health tracking app, not a journal. DailyVox combines voice journaling with automatic mood tracking in one free app."),
    "finch": ("Finch Self-Care", "Free with IAP", "Gamified wellness, not journaling. DailyVox skips the gamification and focuses on real, private self-reflection."),
}

# ============================================================
# CITIES DATA
# ============================================================
CITIES = [
    # US Major
    "New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia",
    "San Antonio", "San Diego", "Dallas", "San Jose", "Austin", "Jacksonville",
    "Fort Worth", "Columbus", "Charlotte", "San Francisco", "Indianapolis",
    "Seattle", "Denver", "Washington DC", "Nashville", "Oklahoma City",
    "El Paso", "Boston", "Portland", "Las Vegas", "Memphis", "Louisville",
    "Baltimore", "Milwaukee", "Albuquerque", "Tucson", "Fresno", "Sacramento",
    "Mesa", "Kansas City", "Atlanta", "Omaha", "Colorado Springs", "Raleigh",
    "Long Beach", "Virginia Beach", "Miami", "Oakland", "Minneapolis",
    "Tampa", "Tulsa", "Arlington", "New Orleans", "Cleveland", "Honolulu",
    "Pittsburgh", "Cincinnati", "St Louis", "Orlando", "Salt Lake City",
    "Detroit", "Buffalo", "Madison", "Richmond",
    # UK
    "London", "Manchester", "Birmingham", "Leeds", "Glasgow", "Edinburgh",
    "Liverpool", "Bristol", "Cardiff", "Belfast", "Sheffield", "Cambridge", "Oxford",
    # Canada
    "Toronto", "Vancouver", "Montreal", "Calgary", "Ottawa", "Edmonton",
    # Australia
    "Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide", "Auckland",
    # India
    "Mumbai", "Delhi", "Bangalore", "Hyderabad", "Chennai", "Kolkata",
    "Pune", "Ahmedabad", "Jaipur", "Lucknow", "Chandigarh", "Kochi",
    "Coimbatore", "Indore", "Bhopal", "Thiruvananthapuram",
    # Southeast Asia
    "Singapore", "Kuala Lumpur", "Bangkok", "Jakarta", "Manila",
    # Middle East
    "Dubai", "Abu Dhabi", "Doha", "Riyadh",
    # Europe
    "Berlin", "Munich", "Paris", "Amsterdam", "Stockholm", "Copenhagen",
    "Oslo", "Helsinki", "Zurich", "Vienna", "Prague", "Warsaw", "Dublin",
    "Lisbon", "Barcelona", "Madrid", "Rome", "Milan",
    # Africa
    "Cape Town", "Johannesburg", "Nairobi", "Lagos", "Cairo",
    # South America
    "Sao Paulo", "Buenos Aires", "Bogota", "Lima", "Santiago", "Mexico City",
    # East Asia
    "Tokyo", "Seoul", "Taipei", "Hong Kong",
    # More US cities
    "Boise", "Des Moines", "Little Rock", "Anchorage", "Spokane",
    "Knoxville", "Chattanooga", "Savannah", "Charleston", "Greenville",
    "Lexington", "Dayton", "Akron", "Syracuse", "Rochester",
    "Worcester", "Providence", "Hartford", "New Haven", "Stamford",
    "Jersey City", "Newark", "Trenton", "Wilmington", "Norfolk",
    "Durham", "Winston Salem", "Greensboro", "Columbia", "Augusta",
    "Tallahassee", "Gainesville", "Sarasota", "Fort Lauderdale", "West Palm Beach",
    "Baton Rouge", "Shreveport", "Jackson", "Birmingham Alabama", "Montgomery",
    "Mobile", "Huntsville", "Fayetteville", "Bentonville", "Springfield",
    "Wichita", "Topeka", "Lincoln", "Sioux Falls", "Fargo",
    "Bismarck", "Billings", "Bozeman", "Missoula", "Cheyenne",
    "Santa Fe", "Provo", "Ogden", "Reno", "Henderson",
    "Scottsdale", "Tempe", "Chandler", "Gilbert", "Glendale Arizona",
    "Irvine", "Pasadena", "Santa Monica", "Burbank", "Torrance",
    "Anaheim", "Santa Ana", "Riverside", "Ontario California", "Bakersfield",
    "Stockton", "Modesto", "Santa Cruz", "Santa Barbara", "San Luis Obispo",
    "Monterey", "Redding", "Eugene", "Salem Oregon", "Bend",
    "Olympia", "Tacoma", "Bellevue", "Kirkland", "Redmond",
    # More UK
    "Nottingham", "Leicester", "Coventry", "Newcastle", "Brighton",
    "Southampton", "Plymouth", "York", "Bath", "Exeter",
    "Norwich", "Ipswich", "Aberdeen", "Dundee", "Inverness",
    # More Europe
    "Hamburg", "Frankfurt", "Cologne", "Stuttgart", "Dusseldorf",
    "Leipzig", "Dresden", "Lyon", "Marseille", "Toulouse",
    "Nice", "Bordeaux", "Lille", "Strasbourg", "Nantes",
    "Rotterdam", "The Hague", "Utrecht", "Antwerp", "Brussels",
    "Gothenburg", "Malmo", "Aarhus", "Turku", "Tampere",
    "Geneva", "Basel", "Bern", "Lausanne", "Graz",
    "Salzburg", "Innsbruck", "Krakow", "Wroclaw", "Gdansk",
    "Brno", "Bratislava", "Budapest", "Bucharest", "Sofia",
    "Zagreb", "Ljubljana", "Belgrade", "Thessaloniki", "Athens",
    "Porto", "Valencia", "Seville", "Bilbao", "Malaga",
    "Florence", "Naples", "Turin", "Bologna", "Palermo",
    # More India
    "Nagpur", "Visakhapatnam", "Patna", "Vadodara", "Surat",
    "Rajkot", "Ludhiana", "Agra", "Varanasi", "Kanpur",
    "Nashik", "Aurangabad", "Mangalore", "Mysore", "Hubli",
    "Madurai", "Tiruchirappalli", "Salem Tamil Nadu", "Noida", "Gurgaon",
    "Guwahati", "Ranchi", "Dehradun", "Raipur", "Jodhpur",
    # More Asia Pacific
    "Osaka", "Kyoto", "Yokohama", "Nagoya", "Sapporo", "Fukuoka",
    "Busan", "Incheon", "Daegu", "Taichung", "Kaohsiung",
    "Shenzhen", "Guangzhou", "Shanghai", "Beijing", "Chengdu",
    "Hanoi", "Ho Chi Minh City", "Phnom Penh", "Colombo",
    "Dhaka", "Kathmandu", "Islamabad", "Lahore", "Karachi",
    # More Australia/NZ
    "Canberra", "Gold Coast", "Hobart", "Darwin", "Cairns",
    "Wellington", "Christchurch", "Hamilton New Zealand", "Dunedin",
    # More Middle East
    "Muscat", "Kuwait City", "Bahrain", "Amman", "Beirut",
    "Tel Aviv", "Jerusalem", "Ankara", "Istanbul",
    # More Africa
    "Accra", "Dar es Salaam", "Addis Ababa", "Kampala", "Kigali",
    "Casablanca", "Tunis", "Algiers", "Durban", "Pretoria",
    # More Americas
    "Guadalajara", "Monterrey", "Medellin", "Cali", "Quito",
    "Guayaquil", "La Paz", "Montevideo", "Asuncion", "Caracas",
    "San Juan", "Havana", "Panama City", "San Jose Costa Rica",
    "Guatemala City", "Tegucigalpa", "Kingston", "Port of Spain",
]

# ============================================================
# CROSS COMBINATIONS: ALL professions × top 15 use cases
# ============================================================
TOP_USE_CASES = [
    ("morning-routine", "Morning Routine"),
    ("before-bed", "Before Bed"),
    ("during-commute", "During Commute"),
    ("burnout-recovery", "Burnout Recovery"),
    ("after-therapy", "After Therapy"),
    ("anger-management", "Anger Management"),
    ("gratitude-practice", "Gratitude Practice"),
    ("career-change", "Career Change"),
    ("goal-setting", "Goal Setting"),
    ("creative-block", "Creative Block"),
    ("grief-processing", "Grief Processing"),
    ("sobriety-journal", "Sobriety & Recovery"),
    ("meditation-alternative", "Meditation Alternative"),
    ("job-search", "Job Search"),
    ("health-diagnosis", "Health Diagnosis"),
]

# ALL professions get cross-combined
TOP_PROFESSIONS = [(slug, data[0]) for slug, data in PROFESSIONS.items()]

# ============================================================
# GENERATION
# ============================================================
sitemap_entries = []
created = 0
skipped = 0

def write_page(directory, filename, html):
    global created, skipped
    dirpath = os.path.join(BASE_DIR, directory)
    os.makedirs(dirpath, exist_ok=True)
    filepath = os.path.join(dirpath, filename)
    if os.path.exists(filepath):
        skipped += 1
        return
    with open(filepath, "w") as f:
        f.write(html)
    created += 1

def add_sitemap(path, priority="0.7"):
    sitemap_entries.append(f"""  <url>
    <loc>{DOMAIN}{path}</loc>
    <lastmod>{DATE_ISO}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>{priority}</priority>
  </url>""")

# --- Generate Profession Pages ---
print("Generating profession pages...")
for slug, (title, desc, when, benefit) in PROFESSIONS.items():
    path = f"/for/{slug}"
    full_title = f"Voice Journaling for {title}"
    meta = f"Voice journaling helps {title.lower()} {benefit}. Free, private, works offline. No typing required."
    body = f"""        <p>{desc}</p>

        <h2>Why Voice Journaling Works for {title}</h2>

        <p>You speak 150 words per minute. You type 40. For {title.lower()} who are already exhausted at the end of the day, the 2-minute voice journal is the only journaling method that sticks. No typing, no blank page, no time commitment.</p>

        <p>DailyVox transcribes your voice on-device, detects your mood automatically, and builds a Digital Twin that learns your personality patterns over time. Everything stays on your phone — no servers, no cloud, no account required.</p>

        <h2>How to Start</h2>

        <p>Open DailyVox {when}. Press record. Talk for 2 minutes about your day. That's it. The AI handles mood detection, keyword extraction, and personality modeling. You just talk. After a month, your Digital Twin will show you patterns you never noticed — because you were too busy being a {title.lower().rstrip('s') if title.endswith('s') and not title.endswith('ss') else title.lower()} to see them.</p>

        <p>Free forever. No subscription. No account. No data collection. Works offline.</p>"""

    bc = [("Home", DOMAIN + "/"), ("For " + title, ""), (full_title, "")]
    html = page_html(full_title, meta, path, bc, body, f"Try DailyVox — Free for {title}", f"Voice journal {when}. On-device AI, mood tracking, Digital Twin. Completely free and private.")
    write_page("for", f"{slug}.html", html)
    add_sitemap(path)

# --- Generate Use Case Pages ---
print("Generating use case pages...")
for slug, (title, desc, keyword) in USE_CASES.items():
    path = f"/use/{slug}"
    full_title = f"Voice Journaling for {title}"
    meta = f"{desc[:150]}. Free voice journal app — works offline, no account needed."
    body = f"""        <p>{desc}</p>

        <h2>Why Voice Journaling Is Perfect for {title}</h2>

        <p>Traditional journaling requires time, a desk, and the mental energy to write. Voice journaling needs 2 minutes and a phone. For {title.lower()}, this difference is everything — you can journal while walking, driving, cooking, or lying in bed.</p>

        <p>DailyVox automatically detects your mood from what you say, tracks the people and topics you mention, and builds a Digital Twin that learns your personality over time. No typing. No internet required. No data leaves your phone.</p>

        <h2>Getting Started</h2>

        <p>Download DailyVox (free, no account needed). Press record. Talk about what's on your mind. The AI transcribes your voice, detects your emotional state, and files everything privately on your device. After a few weeks, you'll have a detailed emotional map of your {title.lower()} journey that no written journal could match.</p>"""

    bc = [("Home", DOMAIN + "/"), ("Use Cases", ""), (full_title, "")]
    html = page_html(full_title, meta, path, bc, body, f"Start Your {title} Voice Journal", f"Free voice journaling for {title.lower()}. On-device AI, mood tracking, works offline.")
    write_page("use", f"{slug}.html", html)
    add_sitemap(path)

# --- Generate Alternative Pages ---
print("Generating alternative pages...")
for slug, (name, price, comparison) in ALTERNATIVES.items():
    path = f"/alternative/{slug}"
    full_title = f"Best {name} Alternative (2026): Free, Private, Voice-First"
    meta = f"Looking for a {name} alternative? DailyVox offers voice journaling, AI mood tracking, and a Digital Twin — all free, all on-device."
    body = f"""        <p>If you're considering {name} ({price}), there's an alternative worth knowing about. DailyVox offers AI-powered voice journaling with mood detection, a Digital Twin that learns your personality, and encrypted backups — completely free, with no cloud servers.</p>

        <h2>{name} vs DailyVox</h2>

        <p><strong>{name}:</strong> {comparison}</p>

        <p><strong>DailyVox:</strong> Free forever. Voice-first journaling with on-device AI. Your entries never leave your phone. No account, no subscription, no ads. Apple's "Data Not Collected" privacy label.</p>

        <h2>What You Get With DailyVox</h2>

        <ul>
          <li>Voice-to-text journaling — speak for 2 minutes, get a full diary entry</li>
          <li>Automatic mood detection across 9 emotional categories</li>
          <li>Digital Twin that learns your personality and predicts your moods</li>
          <li>Works 100% offline — no internet required</li>
          <li>Face ID lock and AES-256 encrypted backups</li>
          <li>Export to PDF, JSON, Markdown, or CSV</li>
        </ul>

        <h2>Why Switch?</h2>

        <p>DailyVox isn't trying to be {name}. It's a different approach: voice-first, privacy-first, free forever. If {name} works for you, great. If the price, privacy model, or lack of voice features bothers you, DailyVox is worth trying.</p>"""

    bc = [("Home", DOMAIN + "/"), ("Alternatives", ""), (full_title, "")]
    html = page_html(full_title, meta, path, bc, body, f"Try DailyVox — The Free {name} Alternative", f"Voice journaling with AI. Free, private, on-device. No account needed.")
    write_page("alternative", f"{slug}.html", html)
    add_sitemap(path)

# --- Generate City Pages ---
print("Generating city pages...")
for city in CITIES:
    slug = make_slug(city)
    path = f"/in/{slug}"
    full_title = f"Best Journal App in {city} (2026)"
    meta = f"The best journal app for people in {city}. DailyVox — free AI voice journal that works offline. No subscription, no data collection."
    body = f"""        <p>Looking for a journal app in {city}? DailyVox is a free AI voice journal that works anywhere — online or offline. No subscription, no account, no data collection. Speak your thoughts and the app transcribes, tracks your mood, and builds a Digital Twin of your personality.</p>

        <h2>Why {city} Residents Love Voice Journaling</h2>

        <p>Whether you're commuting across {city}, walking through the city, or unwinding at home, voice journaling fits into your routine. Two minutes of speaking captures more than ten minutes of typing — and DailyVox works without internet, so underground transit and dead zones don't matter.</p>

        <h2>What DailyVox Offers</h2>

        <ul>
          <li>Voice-to-text journaling with on-device AI transcription</li>
          <li>Automatic mood detection across 9 categories</li>
          <li>Digital Twin that learns your personality over time</li>
          <li>Works 100% offline — no Wi-Fi or data needed</li>
          <li>Free forever. No subscription, no ads, no account</li>
          <li>Face ID lock and encrypted backups</li>
        </ul>

        <p>Available on the App Store for iPhone and iPad. Download DailyVox and start voice journaling in {city} today.</p>"""

    bc = [("Home", DOMAIN + "/"), ("Cities", ""), (full_title, "")]
    html = page_html(full_title, meta, path, bc, body, f"Voice Journal in {city}", f"DailyVox is the free AI voice journal for {city}. Works offline, no account needed.")
    write_page("in", f"{slug}.html", html)
    add_sitemap(path, "0.5")

# --- Generate Cross-Combination Pages ---
print("Generating cross-combination pages...")
for prof_slug, prof_name in TOP_PROFESSIONS:
    for use_slug, use_name in TOP_USE_CASES:
        slug = f"{prof_slug}-{use_slug}"
        path = f"/for/{slug}"
        full_title = f"Voice Journaling for {prof_name}: {use_name}"
        meta = f"How {prof_name.lower()} can use voice journaling for {use_name.lower()}. Free app, works offline, no account needed."
        body = f"""        <p>Being a {prof_name.lower().rstrip('s') if prof_name.endswith('s') and not prof_name.endswith('ss') else prof_name.lower()} is demanding. Adding a {use_name.lower()} voice journaling practice takes just 2 minutes and fits naturally into your existing schedule.</p>

        <h2>How {prof_name} Can Use Voice Journaling for {use_name}</h2>

        <p>Voice journaling removes every barrier to consistent journaling. No typing, no blank page, no time commitment. For {prof_name.lower()} incorporating a {use_name.lower()} practice, the process is simple: open DailyVox, press record, and talk for 2 minutes.</p>

        <p>The AI automatically detects your mood, identifies the people and topics you mention, and builds a personality model over time. Your Digital Twin learns when your {use_name.lower()} entries are most insightful and what patterns emerge across weeks and months.</p>

        <h2>Why It Works</h2>

        <p>Speaking is 3x faster than typing. {prof_name} already have full days — voice journaling fits into the margins without adding another obligation. And because DailyVox works offline with no account required, there's zero setup friction.</p>

        <p>Free forever. Private. On your device only.</p>"""

        bc = [("Home", DOMAIN + "/"), ("For " + prof_name, DOMAIN + f"/for/{prof_slug}"), (full_title, "")]
        html = page_html(full_title, meta, path, bc, body, f"Voice Journal for {prof_name} — {use_name}", f"Free voice journaling for {prof_name.lower()}. On-device AI, works offline.")
        write_page("for", f"{slug}.html", html)
        add_sitemap(path, "0.5")

# --- Write sitemap fragment ---
print("Writing sitemap entries...")
sitemap_path = os.path.join(BASE_DIR, "..", "sitemap_new_pages.xml")
with open(sitemap_path, "w") as f:
    f.write("\n".join(sitemap_entries))

print(f"\nDone!")
print(f"Created: {created} pages")
print(f"Skipped (already exist): {skipped}")
print(f"Sitemap entries: {len(sitemap_entries)}")
print(f"Sitemap fragment written to: {sitemap_path}")

//
//  ScreenshotDataSeeder.swift
//  solyn
//
//  Seeds realistic diary entries for App Store screenshot generation.
//  Only activates when launched with the -ScreenshotMode argument.
//

import Foundation
import DailyVoxTwinEngine
import CoreData

struct ScreenshotDataSeeder {

    @MainActor
    static func seedIfNeeded(context: NSManagedObjectContext) {
        guard ProcessInfo.processInfo.arguments.contains("-ScreenshotMode") else { return }

        // Bypass onboarding and enable goals
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(true, forKey: "dvx_goal_enabled")
        UserDefaults.standard.set(5, forKey: "dvx_goal_target")

        // Clean slate for reproducible screenshots
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = DiaryEntry.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try? context.execute(deleteRequest)
        context.reset()

        // Delete existing AI state so Digital Twin rebuilds fresh
        let aiRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "AIState")
        let aiDelete = NSBatchDeleteRequest(fetchRequest: aiRequest)
        try? context.execute(aiDelete)

        let calendar = Calendar.current
        let now = Date()

        let entries: [(text: String, mood: String, daysAgo: Int, starred: Bool, duration: Double)] = [
            // Recent streak (last 7 days)
            (
                "Had a wonderful morning walk in the park today. The cherry blossoms are starting to bloom and there's something magical about seeing the first signs of spring. Stopped at my favorite coffee shop on the way back and just sat there for a while, watching people go by. These small moments of peace are what I treasure most.",
                "happy", 0, true, 120
            ),
            (
                "Big presentation at work went really well today. Sarah and Mike gave great feedback on the quarterly report. I've been working on this for weeks and it feels incredible to see it come together. The team seemed genuinely excited about our new direction. Celebrated with the team over lunch.",
                "excited", 1, true, 90
            ),
            (
                "Spent the evening reading and journaling. There's a quiet comfort in having a routine that grounds me. Made some chamomile tea, put on soft music, and just let my thoughts flow. I've been thinking a lot about what matters most to me and how I want to spend my time.",
                "calm", 2, false, 60
            ),
            (
                "Grateful for my family today. Mom called and we talked for over an hour about everything and nothing. She told me stories about when I was little that I'd never heard before. Dad chimed in from the background with his usual jokes. I need to visit them more often.",
                "grateful", 3, true, 150
            ),
            (
                "Started a new workout routine at the gym. Ran 3 miles on the treadmill and did some strength training. My body is sore but my mind feels clear and energized. There's something about pushing through physical discomfort that makes everything else feel easier to handle.",
                "excited", 4, false, 45
            ),
            (
                "Quiet Sunday at home. Cooked a big batch of pasta sauce from scratch using grandma's recipe. The whole apartment smelled amazing. Watched a documentary about ocean conservation that really made me think about the small changes I can make in my daily life.",
                "calm", 5, false, 80
            ),
            (
                "Had coffee with James this morning. We talked about our plans for the summer and he mentioned a hiking trip to the mountains. I love how our friendship has grown over the years. It's rare to find someone who truly understands you without needing many words.",
                "happy", 6, false, 110
            ),

            // Entries spread over the past month
            (
                "Feeling a bit overwhelmed with everything going on. Work deadlines are piling up and I haven't been sleeping well. Need to take a step back and prioritize what actually matters. Maybe I should try that meditation app Lisa recommended.",
                "anxious", 9, false, 60
            ),
            (
                "Beautiful sunset tonight from the rooftop. Took some photos but they don't capture how it really looked. Orange and pink streaks across the sky, the city lights just starting to flicker on below. Moments like these remind me why I moved here.",
                "grateful", 11, true, 75
            ),
            (
                "Had a tough conversation with my manager about the project timeline. I was nervous going in, but I'm glad I spoke up about the unrealistic expectations. She actually listened and we came up with a better plan together. Standing up for myself is getting easier.",
                "calm", 13, false, 90
            ),
            (
                "Tried a new recipe for Thai green curry tonight and it turned out amazing. The secret is fresh lemongrass and a good coconut milk. Shared it with my neighbor and she loved it. Cooking for others brings me so much joy.",
                "happy", 15, false, 100
            ),
            (
                "Rainy day. Stayed in and finished the book I've been reading for weeks. The ending was bittersweet but beautiful. Started sketching in my notebook afterwards, just abstract patterns. Sometimes creativity flows best when there's nothing else to do.",
                "calm", 17, false, 130
            ),
            (
                "Missing home today. Saw a family at the park that reminded me of weekends with my siblings growing up. We used to spend hours playing outside until the streetlights came on. Need to plan a trip back soon.",
                "sad", 19, false, 55
            ),
            (
                "Great yoga class this morning. The instructor guided us through a meditation at the end that left me feeling completely at peace. I've noticed that regular practice is making a real difference in how I handle stress throughout the day.",
                "calm", 21, false, 70
            ),
            (
                "Volunteered at the community garden today. Planted tomatoes, herbs, and sunflowers with a group of amazing people. There's something deeply satisfying about working with your hands in the soil. Met a retired teacher named Margaret who told the most wonderful stories.",
                "grateful", 23, true, 180
            ),
            (
                "Exhausted after a long week. Barely made it through the day. Sometimes you just need to acknowledge that you're running on empty and give yourself permission to rest. Tomorrow is a new day.",
                "tired", 25, false, 30
            ),
            (
                "Went to an art exhibition downtown with Emma. The modern art section was thought-provoking, especially the installation about climate change. We had great conversations about art and meaning over dinner afterwards.",
                "excited", 27, false, 95
            ),
            (
                "Set some new goals for the month. I want to read two books, exercise four times a week, and spend more time on my photography hobby. Writing down goals makes them feel more real and achievable. Feeling motivated and hopeful.",
                "excited", 28, false, 65
            ),
            (
                "Couldn't sleep last night. My mind kept racing about the upcoming changes at work. I know worrying doesn't help but sometimes it's hard to turn off the noise. Going to try the breathing exercises Dr. Chen suggested.",
                "anxious", 29, false, 40
            ),
            (
                "Perfect day for a bike ride along the waterfront. The breeze was cool and the sun warm. Stopped at a little bookshop I'd never noticed before and found a first edition poetry collection. Life has a way of surprising you when you slow down enough to notice.",
                "happy", 30, true, 140
            ),

            // Additional entries to populate Twin features (knowledge graph, predictions, personality card)
            (
                "Lunch with Sarah again today. She's been going through a rough patch at her new job and I'm glad she feels comfortable opening up to me. We talked about boundaries and how hard it is to say no. I gave her the same advice James once gave me — protect your energy first.",
                "calm", 7, false, 85
            ),
            (
                "Took my camera to the botanical gardens. Golden hour photography is becoming my favorite creative outlet. Captured some incredible macro shots of dew on rose petals. Sarah texted later saying my Instagram story inspired her to start painting again.",
                "happy", 8, false, 95
            ),
            (
                "Work meeting ran two hours over. The product launch deadline got moved up by a week and I can feel the pressure mounting. Mike pulled me aside after and said I handled the pushback really well. Small wins matter even on hard days.",
                "anxious", 10, false, 70
            ),
            (
                "Evening run along the river cleared my head. Been thinking about what Mom said last weekend — that I'm always chasing the next thing instead of appreciating where I am. She's right. Gratitude isn't passive, it takes practice. Hit a new 5K personal best though.",
                "grateful", 12, false, 55
            ),
            (
                "James and I finally booked the mountain hiking trip for next month. Three days, two peaks, zero cell service. Emma wants to join too which would make it even better. I've been researching trails and gear all evening. Adventure planning is its own kind of joy.",
                "excited", 14, false, 120
            ),
            (
                "Deep conversation with Lisa over video call tonight. She's starting therapy and was brave enough to share that with me. It made me reflect on my own mental health journey. Writing in this journal every day has been more therapeutic than I expected. The patterns I notice in my own words surprise me.",
                "calm", 16, false, 100
            ),
            (
                "Tried a new Mediterranean cooking class downtown. Made shakshuka and fresh pita from scratch. The instructor was from Tel Aviv and told the most vivid stories about food markets there. Brought leftovers to James and he said it was the best meal he'd had all month.",
                "happy", 18, false, 130
            ),
            (
                "Woke up at 5am and couldn't fall back asleep. Work deadlines keep invading my dreams. Decided to be productive about it — made a priority list and knocked out three tasks before the team was even online. Felt powerful turning anxiety into momentum.",
                "anxious", 20, false, 50
            ),
            (
                "Photography walk with Emma through the old town district. She has such a different eye than me — she captures people and emotions while I gravitate toward architecture and light. We're planning a joint exhibition at the community center. The creative energy between us is electric.",
                "excited", 22, false, 110
            ),
            (
                "Mom and Dad visited for the weekend. Dad helped me fix the leaky faucet he's been worried about for months. Mom reorganized my entire kitchen and cooked enough food for two weeks. The house feels warmer when they're here. Already miss them.",
                "grateful", 24, true, 160
            ),
            (
                "Sarah recommended a book about stoic philosophy and I devoured half of it today. The idea that we can't control events but can control our response to them really resonates. Applied it during a frustrating work call this afternoon and it genuinely helped. Growth feels tangible right now.",
                "calm", 26, false, 90
            ),
            (
                "Yoga and meditation combo this morning followed by journaling at the park. Lisa says I seem more centered lately and I think she's right. My relationship with stress is changing. I'm not running from it anymore, I'm learning to sit with it. Even my photography reflects this — more stillness, less chaos.",
                "calm", 31, false, 75
            ),
            (
                "Hosted a small dinner party. Sarah, James, Emma, and Lisa all came. Made grandma's pasta recipe and the Thai curry. Everyone brought wine and stories. James gave a toast about friendship that made Emma cry. These are the people who make life rich. Grateful doesn't even begin to cover it.",
                "grateful", 33, true, 170
            ),
            (
                "Work project finally launched. Three months of late nights and weekend sessions and it's live. Mike sent a company-wide email praising the team. I'm proud but also exhausted. Taking tomorrow off to recharge. Sarah says I earned it — and for once I believe her.",
                "excited", 35, true, 80
            ),
            (
                "Solo hike to the waterfall trail. No music, no podcasts, just birdsong and my own thoughts. Realized I've been more present this month than any time I can remember. The combination of journaling, exercise, and intentional friendship is working. Future me will thank present me for building these habits.",
                "happy", 37, false, 140
            ),
        ]

        // Keep the generated ids so the Twin fold below can attach each entry's
        // entities to the SAME row the timeline shows — otherwise the seeded
        // graph is anchored to entries that, as far as the index knows, do not exist.
        var seededIds: [UUID] = []
        for entry in entries {
            let diaryEntry = DiaryEntry(context: context)
            let id = UUID()
            diaryEntry.id = id
            seededIds.append(id)
            let entryDate = calendar.date(byAdding: .day, value: -entry.daysAgo, to: now)!
            // Set time to a reasonable hour (8am-9pm range)
            let hour = 8 + (entry.daysAgo * 3) % 14
            let dateWithTime = calendar.date(bySettingHour: hour, minute: Int.random(in: 0...59), second: 0, of: entryDate)!
            diaryEntry.date = dateWithTime
            diaryEntry.createdAt = dateWithTime
            diaryEntry.updatedAt = dateWithTime
            diaryEntry.text = entry.text
            diaryEntry.mood = entry.mood
            diaryEntry.isStarred = entry.starred
            diaryEntry.duration = entry.duration
        }

        do {
            try context.save()
        } catch {
            #if DEBUG
            print("ScreenshotDataSeeder: Failed to save entries - \(error)")
            #endif
        }

        // Process entries through DigitalTwinEngine so Twin tab populates
        for (entry, id) in zip(entries, seededIds) {
            let entryDate = calendar.date(byAdding: .day, value: -entry.daysAgo, to: now)!
            DigitalTwinEngine.shared.processEntry(
                text: entry.text,
                mood: entry.mood,
                date: entryDate,
                duration: entry.duration,
                entryId: id.uuidString
            )
        }

        seedBodyTwinFixtures(entries: entries, calendar: calendar, now: now)
    }

    // MARK: - Body Twin Fixtures (v1.5)

    /// Seeds Body Twin state through the same local stores the app uses at
    /// runtime, so every new surface (Twin-tab card, review sheet, Settings
    /// Health section, Insights Body & Mood card) has honest data to show.
    /// Screenshot-only: reachable exclusively behind the -ScreenshotMode gate.
    ///
    /// Pass -BodyTwinInviteDemo as well to force the not-yet-authorized state
    /// instead, so TodayView's one-time Health invite card is capturable.
    @MainActor
    private static func seedBodyTwinFixtures(
        entries: [(text: String, mood: String, daysAgo: Int, starred: Bool, duration: Double)],
        calendar: Calendar,
        now: Date
    ) {
        let defaults = UserDefaults.standard

        // The invite gate reads ReviewManager's saved-entry counter; 35 seeded
        // entries = 35 saved. Mark as already-reviewed so the StoreKit rating
        // prompt can never wander into a screenshot.
        defaults.set(entries.count, forKey: "reviewManager_entryCount")
        defaults.set(true, forKey: "reviewManager_hasReviewed")

        if ProcessInfo.processInfo.arguments.contains("-BodyTwinInviteDemo") {
            // Not-yet-authorized: the one-time "your Twin can learn what your
            // body felt" invite renders on TodayView's idle state.
            defaults.set(false, forKey: "bodyTwin_hasSeenInvite")
            defaults.removeObject(forKey: "com.dailyvox.bodytwin.hkRequested")
            PendingSnapshotQueue.shared.wipe()
            KeptSnapshotStore.shared.wipe()
            let store = FileBodyTwinStateStore()
            store.saveBodyTwin(BodyTwin(isAuthorized: false, isEnabledByUser: true))
            DigitalTwinEngine.configureBodyTwinStore(store)
            return
        }

        // Health connected, Body Twin mid-journey (.learning maturity).
        defaults.set(true, forKey: "bodyTwin_hasSeenInvite")
        defaults.set(true, forKey: "bodyTwin_enabled")
        // HealthKitService's persisted "the user has been asked" flag (the only
        // authorization signal read-only HealthKit exposes).
        defaults.set(true, forKey: "com.dailyvox.bodytwin.hkRequested")

        // Kept snapshots: one per day across the last three weeks, whose sleep
        // and steps honestly track the seeded entries' moods — brighter days
        // slept longer and moved more — so the Body & Mood insights card shows
        // patterns the data actually contains. Morning HRV appears on only
        // some days (like real life), staying below the 14-day insight bar.
        var kept: [KeptSnapshot] = []
        for entry in entries where (1...21).contains(entry.daysAgo) && entry.daysAgo != 13 {
            let day = calendar.date(byAdding: .day, value: -entry.daysAgo, to: now)!
            let capturedAt = calendar.date(bySettingHour: 9, minute: (entry.daysAgo * 13) % 60, second: 0, of: day)!
            let jitter = Double((entry.daysAgo * 7) % 5)   // deterministic, small
            let (sleep, steps): (Double, Int) = {
                switch entry.mood {
                case "happy", "excited", "grateful": return (7.4 + jitter * 0.08, 9200 + entry.daysAgo * 90)
                case "calm":                         return (7.0 + jitter * 0.06, 7600 + entry.daysAgo * 70)
                case "tired":                        return (6.3, 5200)
                case "anxious":                      return (5.7 + jitter * 0.10, 3900 + entry.daysAgo * 60)
                default:                             return (5.9, 3800)   // sad
                }
            }()
            var snapshot = HealthSnapshot(
                capturedAt: capturedAt,
                activityContext: .atRest,
                sleepHours: sleep,
                stepsToday: steps,
                activityConfidence: 0.9
            )
            if entry.daysAgo % 2 == 0 {   // HRV on ~10 of 20 days
                snapshot.morningHRVMs = 34 + Double((entry.daysAgo * 11) % 18)
            }
            kept.append(KeptSnapshot(id: UUID(), snapshot: snapshot, keptAt: capturedAt))
        }
        KeptSnapshotStore.shared.wipe()
        KeptSnapshotStore.shared.restore(kept)

        // Review queue: two snapshots waiting, exactly as capture would leave
        // them — a short-sleep evening at rest, and a mid-walk morning where
        // the rest-dependent fields are honestly absent. (No .postWorkout
        // here: v1.5 requests no Workouts read access, so screenshots must
        // not depict a state the shipping detector cannot produce.)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let eveningAt = calendar.date(bySettingHour: 21, minute: 37, second: 0, of: yesterday)!
        let evening = HealthSnapshot(
            capturedAt: eveningAt,
            activityContext: .atRest,
            sleepHours: 5.0 + 50.0 / 60.0,   // 5h 50m
            morningHRVMs: 38,
            restingHRBpm: 64,
            stepsToday: 4100,
            activityConfidence: 0.92
        )
        let morningAt = calendar.date(bySettingHour: 8, minute: 12, second: 0, of: now)!
        let morning = HealthSnapshot(
            capturedAt: morningAt,
            activityContext: .active,
            stepsToday: 6800,
            activityConfidence: 0.85
        )
        PendingSnapshotQueue.shared.wipe()
        PendingSnapshotQueue.shared.restore([
            PendingSnapshot(id: UUID(), snapshot: evening, createdAt: eveningAt),
            PendingSnapshot(id: UUID(), snapshot: morning, createdAt: morningAt)
        ])

        // Engine state: authorized + enabled, 22 kept moments (.learning),
        // baseline consistent with the kept snapshots above.
        let newestKeptAt = kept.map(\.keptAt).max() ?? now
        var baseline = PersonalBaseline()
        baseline.averageSleepHours = 6.9
        baseline.samplesFolded = 22
        baseline.sleepSamplesFolded = 20
        baseline.lastRefreshed = newestKeptAt
        let store = FileBodyTwinStateStore()
        store.saveBodyTwin(BodyTwin(
            isAuthorized: true,
            isEnabledByUser: true,
            baseline: baseline,
            entriesWithSnapshot: 22,
            lastSnapshotAt: newestKeptAt
        ))
        DigitalTwinEngine.configureBodyTwinStore(store)
    }
}

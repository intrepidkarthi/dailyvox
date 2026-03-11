//
//  ScreenshotDataSeeder.swift
//  solyn
//
//  Seeds realistic diary entries for App Store screenshot generation.
//  Only activates when launched with the -ScreenshotMode argument.
//

import Foundation
import CoreData

struct ScreenshotDataSeeder {

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
        ]

        for entry in entries {
            let diaryEntry = DiaryEntry(context: context)
            diaryEntry.id = UUID()
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
        for entry in entries {
            let entryDate = calendar.date(byAdding: .day, value: -entry.daysAgo, to: now)!
            DigitalTwinEngine.shared.processEntry(
                text: entry.text,
                mood: entry.mood,
                date: entryDate,
                duration: entry.duration
            )
        }
    }
}

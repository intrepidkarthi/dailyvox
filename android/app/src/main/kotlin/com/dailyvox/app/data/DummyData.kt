package com.dailyvox.app.data

import java.util.UUID

/**
 * Seed entries so every screen has something real to render before recording works,
 * mirroring iOS ScreenshotDataSeeder.
 *
 * Two rules carried over from the iOS seeder, both learned the hard way:
 *   - valence and entities are COMPUTED by the real Sentiment and NameDetector,
 *     not hand-written. Hand-written values make the pipeline look correct while
 *     hiding whether it works, which is exactly the bug the iOS entity-graph
 *     wiring shipped with for months.
 *   - dates spread across weeks and months so streaks, the 30-night strip and the
 *     mood curve have real shape rather than a single cluster.
 */
object DummyData {

    /** Sleep hours, cycled across the seed. Nulls are deliberate — a phone with
     *  no wearable has gaps, and the Body row has to survive them. */
    private val SLEEP = listOf(
        7.2f, 6.1f, null, 7.9f, 4.8f, 7.0f, 8.1f, null, 6.4f, 7.5f,
        6.8f, 7.2f, 5.9f, 8.4f, null, 6.6f, 7.8f, 5.2f, 7.1f, 6.9f,
        8.0f, null, 6.3f, 7.4f, 4.9f, 7.7f,
    )

    private val texts = listOf(
        "Walked before anyone was up. Sarah's flight lands tonight and I'm more nervous than I expected. The house feels different when someone is about to come back to it, like it has been holding its breath." to 52,
        "The review went sideways. James pushed back on the timeline and I let it get to me. I should have said less and listened longer, and I knew that while it was happening." to 78,
        "Emma called out of nowhere and we talked for two hours. Nothing important, all of it important. I forget how much lighter I am afterwards until I hang up." to 41,
        "Long hike up the ridge trail with Sarah. We got rained on half a mile below the summit and neither of us had a jacket. Best afternoon in weeks and neither of us said so out loud." to 96,
        "Slept badly again. Work is sitting on my chest at three in the morning and I cannot put it down. Need to fix this before it fixes me." to 64,
        "Priya sent photos from the wedding. The mango cake, the power cut halfway through dinner, a speech that ran twenty minutes long. I laughed out loud on the bus and did not care." to 71,
        "Quiet Sunday. Cooked properly for the first time in a fortnight, read on the balcony, did not open the laptop once. Calm, and I noticed it while it was happening." to 58,
        "Told Sarah about the job thing finally. She was steadier about it than I was. Grateful is the word, though it feels too small for what she did." to 83,
        "Frustrated with myself today. Same argument with James, same shape as last month. I keep choosing to be right instead of useful." to 67,
        "Ran the loop around the reservoir. Headwind both directions somehow. Legs tired, head clear, which is the trade I keep making and keep being glad about." to 45,
        "Emma is moving to Mumbai in March. Happy for her and quietly gutted. Both, all day, without either one winning." to 55,
        "Good week. Shipped the thing, slept seven hours three nights running, and nothing broke. Writing it down so I remember it happened." to 62,
        "Coffee with Adyah before work. She asked what I actually want this year and I did not have an answer ready, which told me something." to 49,
        "The flat is too quiet with Sarah away. Put music on and cooked badly. It helped more than it should have." to 44,
        "Long day at the studio with Rahul. We rebuilt the whole second half and it is better, but I am running on fumes." to 88,
        "Rain all afternoon. Read by the window and let the phone stay in the other room. I should protect these hours more carefully." to 39,
        "James apologised, properly, without me asking. I did not expect it and I did not handle it well. Better than last month though." to 72,
        "Saw Priya and the baby. Held her for an hour and got nothing else done. Best hour of the month by a distance." to 47,
        "Grey mood, no particular reason. Walked to the market anyway and bought too many oranges. Small wins count." to 51,
        "Sarah is back. The house sounds right again. We stayed up far too late and I regret nothing about it." to 66,
        "Presented to the board and it went fine, which after three weeks of dread feels almost anticlimactic." to 74,
        "Nothing happened today and that was the point. First Saturday in months with no plans at all." to 36,
        "Adyah's leaving do at the noodle place. Loud, warm, slightly too long, exactly right. Mumbai is lucky." to 59,
        "Woke at four and could not get back down. Made tea at five and watched it get light. Strangely peaceful once I stopped fighting it." to 61,
        "Trail run with Rahul in the fog. Could not see twenty feet ahead and it was the best hour of the week." to 53,
        "Difficult call with the team. Said the honest thing instead of the easy thing and it cost me the afternoon." to 81,
        "Emma sent a photo of her new place in Mumbai. Bare walls, good light. She sounds like herself again." to 43,
        "Slept nine hours and it changed everything about today. I keep relearning this lesson and keep forgetting it." to 38,
        "Sarah cooked, I washed up, we argued about a film neither of us liked. An ordinary evening and I would keep it." to 57,
        "Back on the reservoir loop after a fortnight off. Slower than I wanted, happier than I expected." to 46,
        "James and I finally agreed on the timeline. Took three weeks longer than it should have and I own most of that." to 69,
        "Quiet week, steady work, nothing to report. Writing that down feels like its own kind of progress." to 41,
        "Priya asked how I actually am, and waited for the real answer. Not many people do that." to 54,
        "Walked to the ridge trail alone at dawn. Nobody there. Sat for twenty minutes and came back different." to 63,
        "Bad news about the funding. Sat with it, told Sarah, felt better. Still bad news, but carryable." to 77,
        "First proper sun in weeks. Worked from the balcony and got more done than in a week of the desk." to 48,
        "Rahul is going freelance. Nervous for him and slightly envious, which is worth noticing." to 52,
        "Two months of this now. Looking back at the early ones, I sound like someone else. That is the whole point of it." to 65,
    )

    fun entries(): List<Entry> {
        val now = System.currentTimeMillis()
        val day = 86_400_000L
        // Spread across ~13 weeks, with an unbroken run of 21 recent days.
        //
        // Deliberately dense. The first seed was twelve entries over five weeks,
        // which rendered a Twin constellation of twelve sparse dots, a "Day 4"
        // counter and 6% resolution. Every store screenshot was therefore
        // advertising an app that looked barely used — the Twin is the product's
        // hero screen and it was nearly empty. iOS seeds 140 stars for the same
        // reason.
        val offsets = (0L..20L).toList() +
            listOf(22L, 24, 26, 29, 32, 35, 39, 43, 47, 52, 58, 64, 71, 78, 86, 91, 95)
        val corpus = mutableListOf<Entry>()
        texts.forEachIndexed { i, (text, dur) ->
            val (mid, lower) = com.dailyvox.twin.NameDetector.vocabulary(texts.map { it.first })
            corpus.add(
                Entry(
                    id = UUID.randomUUID().toString(),
                    text = text,
                    // Evening times, bounded so the stagger can NEVER cross midnight.
                    // The previous version subtracted i hours cumulatively, so
                    // by the 13th entry it had walked back past midnight and
                    // merged two days — which silently broke the consecutive run
                    // and showed "Day 7" for a 21-day seed.
                    createdAt = now - offsets[i] * day - ((i % 5) * 1_800_000L),
                    durationSec = dur,
                    valence = com.dailyvox.twin.Sentiment.valence(text),
                    entities = com.dailyvox.twin.NameDetector.extract(text, mid, lower).joinToString(","),
                    // Cycled, not indexed. This was a fixed 12-element list read
                    // at [i] while the loop grew to 38 entries — an
                    // IndexOutOfBoundsException on launch, and one that only
                    // appeared because the seed got bigger. Any per-entry list
                    // here has to be modulo-safe or it is a landmine for the
                    // next person who adds a text.
                    sleepHours = SLEEP[i % SLEEP.size],
                )
            )
        }
        return corpus
    }
}

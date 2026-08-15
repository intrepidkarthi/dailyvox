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

    private val texts = listOf(
        "Walked before anyone was up. Sarah's flight lands tonight and I'm more nervous than I expected. The house feels different when someone's about to come back to it." to 52,
        "The review went sideways. James pushed back on the timeline and I let it get to me. I should have said less and listened longer." to 78,
        "Emma called out of nowhere. Two hours. Nothing important, all of it important." to 41,
        "Long hike up the ridge trail with Sarah. We got rained on half a mile below the summit and neither of us had a jacket. Best afternoon in weeks." to 96,
        "Slept badly again. Work is sitting on my chest at 3am and I cannot put it down. Need to fix this before it fixes me." to 64,
        "Priya sent photos from the wedding. The mango cake, the power cut halfway through dinner, a speech that ran twenty minutes long. I laughed out loud on the bus." to 71,
        "Quiet Sunday. Cooked properly for the first time in a fortnight, read on the balcony, did not open the laptop once. Calm, and I noticed it while it was happening." to 58,
        "Told Sarah about the job thing finally. She was steadier about it than I was. Grateful is the word, though it feels too small." to 83,
        "Frustrated with myself today. Same argument with James, same shape as last month. I keep choosing to be right instead of useful." to 67,
        "Ran the loop around the reservoir. Headwind both directions somehow. Legs tired, head clear, which is the trade I keep making." to 45,
        "Emma's moving to Mumbai in March. Happy for her and quietly gutted. Both, all day." to 55,
        "Good week. Shipped the thing, slept seven hours three nights running, and nothing broke. Writing it down so I remember it happened." to 62,
    )

    fun entries(): List<Entry> {
        val now = System.currentTimeMillis()
        val day = 86_400_000L
        // Spread across ~5 weeks, with a recent run of consecutive days so the
        // streak counter and the 30-night strip both have something to show.
        val offsets = listOf(0L, 1, 2, 3, 5, 8, 11, 15, 19, 24, 29, 34)
        val corpus = mutableListOf<Entry>()
        texts.forEachIndexed { i, (text, dur) ->
            val (mid, lower) = NameDetector.vocabulary(texts.map { it.first })
            corpus.add(
                Entry(
                    id = UUID.randomUUID().toString(),
                    text = text,
                    createdAt = now - offsets[i] * day - (i * 3_600_000L),
                    durationSec = dur,
                    valence = Sentiment.valence(text),
                    entities = NameDetector.extract(text, mid, lower).joinToString(","),
                    sleepHours = listOf(7.2f, 6.1f, null, 7.9f, 4.8f, 7.0f, 8.1f, null, 6.4f, 7.5f, 6.8f, 7.2f)[i],
                )
            )
        }
        return corpus
    }
}

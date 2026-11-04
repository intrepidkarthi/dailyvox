package com.dailyvox.app

import com.dailyvox.app.data.Entry
import com.dailyvox.app.system.DailyQuestion
import com.dailyvox.app.system.DailyQuestion.Question
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * The question of the day. Three promises: it is a function of the local
 * date, so it holds all day; the research pilot's plain days land exactly
 * where iOS puts them; and a name is only handed back when the user said it,
 * as written, in an entry that is still there and did not read as hard.
 */
class DailyQuestionTest {

    private val la = ZoneId.of("America/Los_Angeles")
    private val tokyo = ZoneId.of("Asia/Tokyo")
    private var seq = 0

    private fun at(d: LocalDate, h: Int = 21, m: Int = 0, zone: ZoneId = la): Long =
        LocalDateTime.of(d.year, d.month, d.dayOfMonth, h, m).atZone(zone).toInstant().toEpochMilli()

    private fun entry(
        text: String,
        on: LocalDate,
        entities: String = "",
        valence: Float = 0.3f,
        suggested: String? = null,
        label: String? = null,
    ) = Entry(id = "e${seq++}", text = text, createdAt = at(on), durationSec = 40,
              valence = valence, entities = entities, suggestedMood = suggested, selfLabel = label)

    /** A Tuesday that is not a pilot day: 2026-10-13, day 286. */
    private val tuesday = LocalDate.of(2026, 10, 13)
    /** Something already in the journal, so the day is not a first visit. */
    private val old = entry("Long walk, quiet evening.", LocalDate.of(2026, 1, 5))

    private fun lead(all: List<Entry>, day: LocalDate, pilot: Boolean = false, h: Int = 21) =
        DailyQuestion.forDay(all, at(day, h), la, pilot)

    // ── One question a day ──────────────────────────────────────────────────

    @Test
    fun `the same question all day, from just after midnight to just before`() {
        val day = LocalDate.of(2026, 10, 14)
        val morning = DailyQuestion.forDay(listOf(old), at(day, 0, 1), la, false)
        val night = DailyQuestion.forDay(listOf(old), at(day, 23, 59), la, false)
        assertEquals(morning, night)
        // A relaunch is a fresh call with the same inputs: nothing to remember.
        assertEquals(morning, DailyQuestion.forDay(listOf(old), at(day, 12), la, false))
    }

    @Test
    fun `tomorrow asks something else`() {
        var day = LocalDate.of(2026, 10, 14)
        repeat(60) {
            assertNotEquals(lead(listOf(old), day), lead(listOf(old), day.plusDays(1)))
            day = day.plusDays(1)
        }
    }

    @Test
    fun `the day is the local calendar day`() {
        // 2026-10-14 08:00 in Tokyo is still the 13th in Los Angeles.
        val now = at(LocalDate.of(2026, 10, 14), 8, zone = tokyo)
        val inTokyo = DailyQuestion.sequence(listOf(old), now, tokyo, false).last()
        val inLa = DailyQuestion.sequence(listOf(old), now, la, false).last()
        assertNotEquals(inTokyo, inLa)
        assertEquals(DailyQuestion.everydayIndex(LocalDate.of(2026, 10, 14)),
                     (DailyQuestion.forDay(listOf(old), now, tokyo, false) as Question.Everyday).index)
        assertEquals(DailyQuestion.everydayIndex(LocalDate.of(2026, 10, 13)),
                     (DailyQuestion.forDay(listOf(old), now, la, false) as Question.Everyday).index)
    }

    @Test
    fun `every question comes up before any repeats`() {
        val start = LocalDate.of(2026, 3, 1)
        val seen = (0 until DailyQuestion.EVERYDAY_COUNT)
            .map { DailyQuestion.everydayIndex(start.plusDays(it.toLong())) }
        assertEquals(DailyQuestion.EVERYDAY_COUNT, seen.toSet().size)
    }

    @Test
    fun `a first visit gets the original question`() {
        assertEquals(Question.Everyday(0), lead(emptyList(), LocalDate.of(2026, 10, 14)))
    }

    @Test
    fun `another question walks the whole list and comes back round`() {
        val day = LocalDate.of(2026, 10, 14)
        val seqd = DailyQuestion.sequence(listOf(old), at(day), la, false)
        assertEquals(DailyQuestion.EVERYDAY_COUNT, seqd.size)
        assertEquals(DailyQuestion.EVERYDAY_COUNT, seqd.toSet().size)
        assertEquals(seqd[0], DailyQuestion.forDay(listOf(old), at(day), la, false, turn = seqd.size))
        assertEquals(seqd[3], DailyQuestion.forDay(listOf(old), at(day), la, false, turn = 3))
        // A neighbour in the list is never the next tap.
        assertNotEquals(1, Math.floorMod((seqd[1] as Question.Everyday).index -
                                         (seqd[0] as Question.Everyday).index, DailyQuestion.EVERYDAY_COUNT))
    }

    // ── The words ───────────────────────────────────────────────────────────

    private val strings = java.io.File("src/main/res/values/strings.xml").readText()

    private fun array(name: String): List<String> {
        val body = Regex("<string-array name=\"$name\">(.*?)</string-array>", RegexOption.DOT_MATCHES_ALL)
            .find(strings)!!.groupValues[1]
        return Regex("<item>(.*?)</item>").findAll(body).map { it.groupValues[1] }.toList()
    }

    @Test
    fun `the counts match strings xml and the original line is first`() {
        val everyday = array("daily_questions")
        assertEquals(DailyQuestion.EVERYDAY_COUNT, everyday.size)
        assertEquals("How was your day, really?", everyday[0])
        assertEquals(everyday.size, everyday.toSet().size)
        assertEquals(DailyQuestion.PLAIN_COUNT, array("daily_questions_plain").size)
    }

    @Test
    fun `grounded questions use the name and no pronoun`() {
        val templates = Regex("<string name=\"daily_question_grounded_\\w+\">(.*?)</string>")
            .findAll(strings).map { it.groupValues[1] }.toList()
        assertEquals(3, templates.size)
        val pronoun = Regex("\\b(he|she|him|her|his|hers|they|them|their|theirs)\\b", RegexOption.IGNORE_CASE)
        templates.forEach {
            assertTrue(it, it.contains("%1\$s"))
            assertFalse(it, pronoun.containsMatchIn(it))
        }
    }

    // ── The research pilot ──────────────────────────────────────────────────

    @Test
    fun `pilot days lead with a plain question, every third day of the year, as iOS`() {
        var day = LocalDate.of(2028, 1, 1) // a leap year, so day 366 is in range
        while (day.year == 2028) {
            val q = lead(listOf(old), day, pilot = true)
            if (day.dayOfYear % 3 == 0) {
                assertEquals(day.toString(), Question.Plain((day.dayOfYear / 3) % 2), q)
            } else {
                assertFalse(day.toString(), q is Question.Plain)
            }
            day = day.plusDays(1)
        }
    }

    @Test
    fun `without the pilot no day is plain`() {
        var day = LocalDate.of(2026, 1, 1)
        repeat(400) {
            assertTrue(DailyQuestion.sequence(listOf(old), at(day), la, false).none { it is Question.Plain })
            day = day.plusDays(1)
        }
    }

    @Test
    fun `a plain day still offers every everyday question after it`() {
        val day = LocalDate.of(2026, 10, 15) // day 288
        val seqd = DailyQuestion.sequence(listOf(old), at(day), la, true)
        assertEquals(Question.Plain(0), seqd.first())
        assertEquals(1 + DailyQuestion.EVERYDAY_COUNT, seqd.size)
    }

    @Test
    fun `a plain day stays plain even when a name could be grounded`() {
        val plainTuesday = LocalDate.of(2026, 10, 27) // Tuesday, day 300
        assertEquals(DayOfWeek.TUESDAY, plainTuesday.dayOfWeek)
        val e = entry("Dinner with Priya at the new place.", plainTuesday.minusDays(2), "Priya")
        val seqd = DailyQuestion.sequence(listOf(old, e), at(plainTuesday), la, true)
        assertEquals(Question.Plain(0), seqd.first())
        assertTrue(seqd.none { it is Question.Grounded })
        // The same day without the pilot does ground it.
        assertEquals(Question.Grounded("Priya", 2), lead(listOf(old, e), plainTuesday))
    }

    // ── Grounded ────────────────────────────────────────────────────────────

    private val priya = "Dinner with Priya at the new place. Good food."

    @Test
    fun `a name from a recent entry leads on a grounded day`() {
        val e = entry(priya, tuesday.minusDays(3), "Priya")
        assertEquals(Question.Grounded("Priya", 3), lead(listOf(old, e), tuesday))
    }

    @Test
    fun `at most two days a week, never back to back`() {
        val e = entry(priya, tuesday.minusDays(1), "Priya")
        var grounded = 0
        for (i in 0L until 7L) {
            val day = tuesday.plusDays(i)
            val recent = e.copy(createdAt = at(day.minusDays(1)))
            if (lead(listOf(old, recent), day) is Question.Grounded) grounded++
        }
        assertEquals(2, grounded)
        assertTrue(DayOfWeek.WEDNESDAY !in DailyQuestion.GROUNDED_DAYS)
        assertTrue(DayOfWeek.SUNDAY !in DailyQuestion.GROUNDED_DAYS)
    }

    @Test
    fun `only the last thirteen days, and not today`() {
        val edge = entry(priya, tuesday.minusDays(13), "Priya")
        assertEquals(Question.Grounded("Priya", 13), DailyQuestion.grounded(listOf(edge), at(tuesday), la))
        val tooOld = entry(priya, tuesday.minusDays(14), "Priya")
        assertNull(DailyQuestion.grounded(listOf(tooOld), at(tuesday), la))
        val today = entry(priya, tuesday, "Priya")
        assertNull(DailyQuestion.grounded(listOf(today), at(tuesday), la))
        // Said yesterday and again today: tonight would only echo it.
        val yesterday = entry(priya, tuesday.minusDays(1), "Priya")
        assertNull(DailyQuestion.grounded(listOf(yesterday, today), at(tuesday), la))
    }

    @Test
    fun `a deleted entry gives nothing back`() {
        val kept = entry("Long day at work, made soup after.", tuesday.minusDays(2), "")
        val deleted = entry(priya, tuesday.minusDays(2), "Priya")
        assertEquals(Question.Grounded("Priya", 2), DailyQuestion.grounded(listOf(kept, deleted), at(tuesday), la))
        // The table without it is all the selector ever sees.
        assertNull(DailyQuestion.grounded(listOf(kept), at(tuesday), la))
    }

    @Test
    fun `the name must be in the text as written, as a whole word`() {
        val now = at(tuesday)
        // The detector filed it, but the text (edited since) no longer says it.
        assertNull(DailyQuestion.grounded(listOf(entry("Dinner at the new place.", tuesday.minusDays(2), "Priya")), now, la))
        // Not inside a longer word.
        assertNull(DailyQuestion.grounded(listOf(entry("New Samsung phone came today.", tuesday.minusDays(2), "Sam")), now, la))
        // Not in another case.
        assertNull(DailyQuestion.grounded(listOf(entry("I will call tomorrow.", tuesday.minusDays(2), "Will")), now, la))
        // A possessive still counts.
        assertEquals(Question.Grounded("Sam", 2),
            DailyQuestion.grounded(listOf(entry("Went to Sam's for lunch.", tuesday.minusDays(2), "Sam")), now, la))
    }

    @Test
    fun `a word the user also says lowercase is not a name`() {
        val e = entry("Will this rain ever stop. I will stay in.", tuesday.minusDays(2), "Will")
        assertNull(DailyQuestion.grounded(listOf(e), at(tuesday), la))
    }

    @Test
    fun `lowercase or sentence-sized detections are not names`() {
        assertFalse(DailyQuestion.looksLikeName("priya"))
        assertFalse(DailyQuestion.looksLikeName("P"))
        assertFalse(DailyQuestion.looksLikeName("Told Sarah About The"))
        assertTrue(DailyQuestion.looksLikeName("Priya"))
        assertTrue(DailyQuestion.looksLikeName("New York"))
    }

    @Test
    fun `a name from an entry that read as hard is never brought back`() {
        val now = at(tuesday)
        val d = tuesday.minusDays(2)
        assertNull(DailyQuestion.grounded(listOf(entry(priya, d, "Priya", suggested = "sadness")), now, la))
        assertNull(DailyQuestion.grounded(listOf(entry(priya, d, "Priya", label = "anger")), now, la))
        assertNull(DailyQuestion.grounded(listOf(entry(priya, d, "Priya", label = "anxious")), now, la))
        assertNull(DailyQuestion.grounded(listOf(entry(priya, d, "Priya", valence = -0.4f)), now, la))
        // Scored positive, and still the last thing to ask about.
        val funeral = entry("Priya's grandmother died. Everyone was so kind.", d, "Priya", valence = 0.6f)
        assertNull(DailyQuestion.grounded(listOf(funeral), now, la))
    }

    @Test
    fun `one hard entry rules the name out even beside happy ones`() {
        val happy = entry(priya, tuesday.minusDays(2), "Priya")
        // Three weeks back, outside the window but inside the month.
        val hard = entry("Priya and I had a fight.", tuesday.minusDays(21), "Priya", valence = -0.5f)
        assertNull(DailyQuestion.grounded(listOf(happy, hard), at(tuesday), la))
        // Someone else from the same fortnight is still fine.
        val arjun = entry("Coffee with Arjun, lots of laughing.", tuesday.minusDays(4), "Arjun")
        assertEquals(Question.Grounded("Arjun", 4), DailyQuestion.grounded(listOf(happy, hard, arjun), at(tuesday), la))
    }

    @Test
    fun `a longer name is ruled out by a hard entry that says part of it`() {
        val now = at(tuesday)
        val aunt = entry("Had lunch with Aunt Priya.", tuesday.minusDays(3), "Aunt Priya")
        assertEquals(Question.Grounded("Aunt Priya", 3), DailyQuestion.grounded(listOf(aunt), now, la))
        val died = entry("Priya died this morning.", tuesday.minusDays(2), "Priya", valence = -0.6f)
        assertNull(DailyQuestion.grounded(listOf(aunt, died), now, la))

        val full = entry("Priya Sharma came over for tea.", tuesday.minusDays(4), "Priya Sharma")
        val fight = entry("Priya and I had a huge fight.", tuesday.minusDays(1), "Priya", valence = -0.5f)
        assertNull(DailyQuestion.grounded(listOf(full, fight), now, la))
        // The detector's filing counts too, even when the text puts it another way.
        val filed = entry("Hard night. Didn't sleep.", tuesday.minusDays(1), "Priya", valence = -0.5f)
        assertNull(DailyQuestion.grounded(listOf(full, filed), now, la))
        // Someone else is still fine.
        val arjun = entry("Coffee with Arjun, lots of laughing.", tuesday.minusDays(4), "Arjun")
        assertEquals(Question.Grounded("Arjun", 4), DailyQuestion.grounded(listOf(full, fight, arjun), now, la))
    }

    @Test
    fun `the name said most often wins, then the most recent`() {
        val a1 = entry("Lunch with Arjun.", tuesday.minusDays(6), "Arjun")
        val a2 = entry("Arjun called about the trip.", tuesday.minusDays(5), "Arjun")
        val p = entry(priya, tuesday.minusDays(1), "Priya")
        assertEquals(Question.Grounded("Arjun", 5), DailyQuestion.grounded(listOf(a1, a2, p), at(tuesday), la))
        assertEquals(Question.Grounded("Priya", 1), DailyQuestion.grounded(listOf(a1, p), at(tuesday), la))
    }

    @Test
    fun `grounded leads, then the everyday list follows`() {
        val e = entry(priya, tuesday.minusDays(3), "Priya")
        val seqd = DailyQuestion.sequence(listOf(old, e), at(tuesday), la, false)
        assertEquals(Question.Grounded("Priya", 3), seqd.first())
        assertEquals(1 + DailyQuestion.EVERYDAY_COUNT, seqd.size)
        assertEquals(Question.Everyday(DailyQuestion.everydayIndex(tuesday)), seqd[1])
    }

    // ── A0-10: grounded only where the sensitive guard can read ─────────────

    @Test
    fun `a Spanish bereavement entry never yields a grounded question`() {
        // "Priya's grandmother died today. The whole family was there, very calm."
        // The English guard reads nothing in it, and VADER scores it 0.
        val es = entry("La abuela de Priya murió hoy. Toda la familia estaba allí, muy tranquila.",
            tuesday.minusDays(2), "Priya", valence = 0f)
        assertNull(DailyQuestion.grounded(listOf(es), at(tuesday), la))
        assertEquals(Question.Everyday(DailyQuestion.everydayIndex(tuesday)), lead(listOf(old, es), tuesday))
    }

    @Test
    fun `an unreadable entry anywhere in the guarded month turns grounding off`() {
        val english = entry(priya, tuesday.minusDays(3), "Priya")
        val hindi = entry("आज प्रिया की दादी का देहांत हो गया", tuesday.minusDays(20))
        assertNull(DailyQuestion.grounded(listOf(english, hindi), at(tuesday), la))
        // Older than the guarded month: no longer in the way.
        val longAgo = entry("आज अच्छा दिन था", tuesday.minusDays(DailyQuestion.SENSITIVE_WINDOW_DAYS + 5))
        assertEquals(Question.Grounded("Priya", 3), DailyQuestion.grounded(listOf(english, longAgo), at(tuesday), la))
    }

    @Test
    fun `English grounding is unchanged`() {
        val e = entry(priya, tuesday.minusDays(3), "Priya")
        assertEquals(Question.Grounded("Priya", 3), DailyQuestion.grounded(listOf(old, e), at(tuesday), la))
    }
}

package com.dailyvox.app

import com.dailyvox.app.data.Entry
import com.dailyvox.app.system.Exporters
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The CSV writer is the one export where a naive implementation looks correct
 * on the happy path and corrupts the file on the first real transcript. Speech
 * output is full of commas; a user quoting someone produces embedded quotation
 * marks; and a long entry can carry a newline. Each of those breaks an unquoted
 * writer by shifting every later column, and the damage is silent — the file
 * opens, it is simply wrong.
 *
 * These tests parse the output back rather than string-matching it, so they
 * fail if the quoting is wrong regardless of how it is wrong.
 */
class ExportersTest {

    private fun entry(text: String, entities: String = "") = Entry(
        id = "t", text = text, createdAt = 1_700_000_000_000L, durationSec = 42,
        valence = 0.5f, entities = entities, sleepHours = 7.25f,
    )

    /** Minimal RFC 4180 reader: enough to prove the writer round-trips. */
    private fun parse(csv: String): List<List<String>> {
        val rows = mutableListOf<List<String>>()
        var row = mutableListOf<String>()
        val field = StringBuilder()
        var inQuotes = false
        var i = 0
        while (i < csv.length) {
            val c = csv[i]
            when {
                inQuotes && c == '"' && i + 1 < csv.length && csv[i + 1] == '"' -> {
                    field.append('"'); i++
                }
                c == '"' -> inQuotes = !inQuotes
                !inQuotes && c == ',' -> { row.add(field.toString()); field.clear() }
                !inQuotes && c == '\n' -> {
                    row.add(field.toString()); field.clear()
                    rows.add(row); row = mutableListOf()
                }
                else -> field.append(c)
            }
            i++
        }
        if (field.isNotEmpty() || row.isNotEmpty()) { row.add(field.toString()); rows.add(row) }
        return rows
    }

    @Test
    fun `csv survives commas, quotes and newlines in a transcript`() {
        val nasty = "Sarah said \"it's fine, really\", and I believed her.\nThen, later, I didn't."
        val rows = parse(Exporters.csv(listOf(entry(nasty, "Sarah"))))

        assertEquals("header plus one record", 2, rows.size)
        assertEquals("every row has 6 columns", 6, rows[0].size)
        assertEquals("the record must not be split by its own punctuation", 6, rows[1].size)
        // The transcript has to come back byte-identical, not merely present.
        assertEquals(nasty, rows[1][5])
        assertEquals("Sarah", rows[1][4])
    }

    @Test
    fun `csv columns line up with the header`() {
        val rows = parse(Exporters.csv(listOf(entry("Plain entry.", "Emma; James"))))
        val header = rows[0]
        val record = rows[1]
        assertEquals("seconds", header[1]); assertEquals("42", record[1])
        assertEquals("sleep_hours", header[3]); assertEquals("7.25", record[3])
        assertEquals("people", header[4]); assertEquals("Emma; James", record[4])
    }

    @Test
    fun `csv leaves sleep empty rather than writing a zero`() {
        // A missing wearable reading is not "slept 0 hours". Writing 0 here
        // would drag every downstream average toward zero.
        val e = entry("No wearable.").copy(sleepHours = null)
        val record = parse(Exporters.csv(listOf(e)))[1]
        assertEquals("", record[3])
    }

    @Test
    fun `markdown renders one heading per entry in chronological order`() {
        val first = entry("Oldest.").copy(createdAt = 1_700_000_000_000L)
        val last = entry("Newest.").copy(createdAt = 1_700_600_000_000L)
        val md = Exporters.markdown(listOf(last, first))

        assertEquals("one heading per entry", 2, Regex("(?m)^## ").findAll(md).count())
        assertTrue("chronological, not the list order it was handed",
                   md.indexOf("Oldest.") < md.indexOf("Newest."))
        assertTrue("entry count is stated", md.contains("2 entries"))
    }
}

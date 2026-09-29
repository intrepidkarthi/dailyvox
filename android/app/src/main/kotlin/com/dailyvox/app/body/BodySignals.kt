package com.dailyvox.app.body

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Body signals from Health Connect — the Android peer of the engine's
 * `HealthSnapshot` (DailyVoxTwinEngine/BodyTwin/BodyTwin.swift:87).
 *
 * READ ONLY, and only four fields. Health Connect will happily grant read
 * access to dozens of record types; asking for one the app does not use would be
 * indefensible on a screen that lists every permission it holds.
 *
 * Be precise about what each one earns, because this comment used to say all
 * four were "fields the Twin actually correlates against" and only half of them
 * are:
 *
 *   sleep  -> shown on the entry AND correlated  (engine Insights.kt:97)
 *   steps  -> shown on the entry AND correlated  (engine Insights.kt:108)
 *
 * v1.0 used to read HRV and resting heart rate as well. Nothing analysed them --
 * they were a number beside the entry -- and Play's minimum-necessary rule for
 * health permissions is exactly the test that fails. Both were dropped before
 * the first release. The Entry columns stay (nullable, and entries from builds
 * that read them keep their values); add the reads back when the engine
 * correlates them, not before. See playstore/HEALTH_DECLARATION.md.
 *
 * NOTHING is requested until the user turns the feature on. That is why the
 * library adds no permissions to the manifest by default and why the ledger in
 * Settings still reads the same for anyone who never enables it — the two
 * health permissions are declared, but declared is not held.
 *
 * The data never leaves the phone. Health Connect is an on-device datastore;
 * this reads from it and folds numbers into the same local database as
 * everything else. No account, no sync, no network permission involved.
 */
class BodySignals(private val context: Context) {

    data class Snapshot(
        val sleepHours: Double? = null,
        val morningHrvMs: Double? = null,
        val restingHrBpm: Double? = null,
        val stepsToday: Int? = null,
    ) {
        val any: Boolean
            get() = sleepHours != null || morningHrvMs != null ||
                restingHrBpm != null || stepsToday != null
    }

    companion object {
        /** Exactly what is read, and nothing else. */
        val PERMISSIONS: Set<String> = setOf(
            HealthPermission.getReadPermission(SleepSessionRecord::class),
            HealthPermission.getReadPermission(StepsRecord::class),
        )
    }

    /**
     * Three states, not two. "Not installed" and "installed but not granted" are
     * different problems with different fixes, and collapsing them into a single
     * "unavailable" would send half the users to the wrong place.
     */
    enum class Availability { AVAILABLE, NEEDS_UPDATE, UNSUPPORTED }

    fun availability(): Availability = when (HealthConnectClient.getSdkStatus(context)) {
        HealthConnectClient.SDK_AVAILABLE -> Availability.AVAILABLE
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> Availability.NEEDS_UPDATE
        else -> Availability.UNSUPPORTED
    }

    private fun client(): HealthConnectClient? =
        runCatching { HealthConnectClient.getOrCreate(context) }.getOrNull()

    suspend fun granted(): Boolean {
        val c = client() ?: return false
        return runCatching {
            c.permissionController.getGrantedPermissions().containsAll(PERMISSIONS)
        }.getOrDefault(false)
    }

    /**
     * Reads the window the engine's correlations expect. Every field is
     * independently optional: a phone with a step counter but no wearable should
     * report steps and stay silent about sleep, rather than reporting nothing.
     */
    suspend fun read(): Snapshot {
        val c = client() ?: return Snapshot()
        if (!granted()) return Snapshot()

        val zone = ZoneId.systemDefault()
        val now = Instant.now()
        val todayStart = LocalDate.now(zone).atStartOfDay(zone).toInstant()

        // Last night: 18:00 yesterday to now, which is the window that catches a
        // normal night without swallowing the previous one.
        val sleepFrom = LocalDate.now(zone).minusDays(1).atTime(18, 0).atZone(zone).toInstant()

        val sleepHours = runCatching {
            c.readRecords(
                ReadRecordsRequest(
                    SleepSessionRecord::class,
                    TimeRangeFilter.between(sleepFrom, now),
                )
            ).records
                .sumOf { Duration.between(it.startTime, it.endTime).toMinutes() }
                .takeIf { it > 0 }
                ?.let { it / 60.0 }
        }.getOrNull()

        val steps = runCatching {
            c.aggregate(
                AggregateRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(todayStart, now),
                )
            )[StepsRecord.COUNT_TOTAL]?.toInt()
        }.getOrNull()

        return Snapshot(sleepHours = sleepHours, stepsToday = steps)
    }
}

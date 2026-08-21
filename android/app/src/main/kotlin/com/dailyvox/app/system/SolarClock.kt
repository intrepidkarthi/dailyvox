package com.dailyvox.app.system

import java.util.Calendar
import java.util.TimeZone
import kotlin.math.acos
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.tan

/**
 * When the sun actually sets here today — the Swift port of iOS's `SolarClock`.
 *
 * The spec says the Sunset theme "follows the real sun" (§2.8). This was a fixed
 * 19:00-06:00 window, which is wrong by more than an hour at the solstices and
 * wrong all year at latitude. Naming a theme after a natural event and then not
 * tracking it is the kind of detail that is invisible until someone in Oslo
 * opens the app in June.
 *
 * NOAA's low-precision sunrise/sunset algorithm: accurate to about a minute, and
 * it needs nothing but the date and a latitude/longitude. There is no location
 * permission here and there will not be one — a journal does not get to ask
 * where you are in order to pick a colour. It reads the TIME ZONE the phone is
 * already set to, derives longitude from its UTC offset (fifteen degrees per
 * hour is the definition of a zone) and assumes a mid-latitude. That is good to
 * within a few minutes for most people, and above the Arctic circle it falls
 * back to the old fixed window, where "sunset" stops being a daily event.
 */
object SolarClock {

    fun isAfterSunset(
        nowMillis: Long = System.currentTimeMillis(),
        zone: TimeZone = TimeZone.getDefault(),
    ): Boolean {
        val times = sunTimes(nowMillis, zone) ?: run {
            val cal = Calendar.getInstance(zone).apply { timeInMillis = nowMillis }
            val h = cal.get(Calendar.HOUR_OF_DAY)
            return h >= 19 || h < 6
        }
        return nowMillis >= times.second || nowMillis < times.first
    }

    /** Sunrise to sunset, in epoch millis, or null where there is neither. */
    private fun sunTimes(nowMillis: Long, zone: TimeZone): Pair<Long, Long>? {
        val cal = Calendar.getInstance(zone).apply { timeInMillis = nowMillis }
        val dayOfYear = cal.get(Calendar.DAY_OF_YEAR)

        val offsetMinutes = zone.getOffset(nowMillis) / 60_000.0
        val longitude = (offsetMinutes / 60.0 * 15.0).coerceIn(-180.0, 180.0)
        val latitude = 40.0

        val startOfDay = (cal.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        // Fractional year, equation of time, declination, then the hour angle at
        // which the sun sits 90.833 degrees from vertical — the extra 0.833 is
        // refraction plus the solar disc's own radius.
        val gamma = 2 * Math.PI / 365 * (dayOfYear - 1)
        val eqTime = 229.18 * (0.000075
            + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        val decl = 0.006918 -
            0.399912 * cos(gamma) + 0.070257 * sin(gamma) -
            0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma) -
            0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)

        val latRad = Math.toRadians(latitude)
        val cosHa = cos(Math.toRadians(90.833)) / (cos(latRad) * cos(decl)) -
            tan(latRad) * tan(decl)
        // Polar day or polar night: there is no sunset to follow.
        if (cosHa < -1 || cosHa > 1) return null
        val ha = Math.toDegrees(acos(cosHa))

        val sunriseMin = 720 - 4 * (longitude + ha) - eqTime + offsetMinutes
        val sunsetMin = 720 - 4 * (longitude - ha) - eqTime + offsetMinutes

        return Pair(
            startOfDay + (sunriseMin * 60_000).toLong(),
            startOfDay + (sunsetMin * 60_000).toLong(),
        )
    }
}

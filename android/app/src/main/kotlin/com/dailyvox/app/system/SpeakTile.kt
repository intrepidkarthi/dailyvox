package com.dailyvox.app.system

import android.content.Intent
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.dailyvox.app.MainActivity

/**
 * Quick Settings tile — two taps from any screen, including the lock screen.
 *
 * The design package wants recording to start without opening the app. That is
 * where the tile stops being simple: capturing audio from a TileService means a
 * microphone foreground service, and on API 34+ starting one from a tile is a
 * documented BackgroundStartNotAllowed crash unless the app is already visible.
 *
 * So this tile launches the app INTO the recording state instead. One tap,
 * recording begins, and the mic is only ever live with an Activity in front of
 * it — which is also the only version an audience that chose this app for its
 * privacy claims would want.
 */
class SpeakTile : TileService() {

    override fun onStartListening() {
        qsTile?.apply {
            state = Tile.STATE_INACTIVE
            label = "DailyVox"
            subtitle = "Tap to speak"
            updateTile()
        }
    }

    override fun onClick() {
        val intent = Intent(this, MainActivity::class.java)
            .putExtra("start_recording", true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)

        // startActivityAndCollapse takes a PendingIntent from API 34 and throws
        // UnsupportedOperationException on the Intent overload. Both paths kept.
        if (android.os.Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(
                android.app.PendingIntent.getActivity(
                    this, 0, intent,
                    android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT,
                )
            )
        } else {
            @Suppress("DEPRECATION") startActivityAndCollapse(intent)
        }
    }
}

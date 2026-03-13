package com.nextfin

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Rational
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.media.app.NotificationCompat.MediaStyle
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var mediaSession: MediaSessionCompat? = null
    private var playbackReceiverRegistered = false
    private var playbackActive = false
    private var autoEnterPip = true
    private var playbackAspectRatio = Rational(16, 9)

    private val playbackReceiver =
        object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                val method =
                    when (action) {
                        ACTION_PLAY_PAUSE -> "playPause"
                        ACTION_STOP -> "stop"
                        else -> return
                    }
                Handler(Looper.getMainLooper()).post {
                    channel?.invokeMethod("mediaAction", method)
                }
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    val available = supportsPip()
                    if (available) {
                        enterPip(
                        width = call.argument<Int>("width") ?: 16,
                        height = call.argument<Int>("height") ?: 9,
                    )
                    }
                    result.success(available)
                }

                "setMediaSession" -> {
                    updatePlaybackSession(
                        title = call.argument<String>("title") ?: "Nextfin",
                        playing = call.argument<Boolean>("playing") == true,
                        position = call.argument<Int>("position") ?: 0,
                        duration = call.argument<Int>("duration") ?: 0,
                        allowAutoPip = call.argument<Boolean>("allowAutoPip") != false,
                    )
                    result.success(null)
                }

                "clearMediaSession" -> {
                    clearPlaybackSession()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        registerPlaybackReceiver()
    }

    override fun onDestroy() {
        clearPlaybackSession()
        if (playbackReceiverRegistered) {
            unregisterReceiver(playbackReceiver)
            playbackReceiverRegistered = false
        }
        channel?.setMethodCallHandler(null)
        channel = null
        super.onDestroy()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        channel?.invokeMethod("pipChanged", isInPictureInPictureMode)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (playbackActive && autoEnterPip && !isInPictureInPictureMode && supportsPip()) {
            enterPip(playbackAspectRatio.numerator, playbackAspectRatio.denominator)
        }
    }

    private fun supportsPip(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun enterPip(width: Int, height: Int) {
        if (!supportsPip()) {
            return
        }
        if (isInPictureInPictureMode) {
            return
        }
        val aspectRatio = Rational(width.coerceAtLeast(1), height.coerceAtLeast(1))
        playbackAspectRatio = aspectRatio
        val paramsBuilder =
            PictureInPictureParams.Builder()
                .setAspectRatio(aspectRatio)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            paramsBuilder.setAutoEnterEnabled(playbackActive)
            paramsBuilder.setSeamlessResizeEnabled(true)
        }
        setPictureInPictureParams(paramsBuilder.build())
        enterPictureInPictureMode(paramsBuilder.build())
    }

    private fun updatePlaybackSession(
        title: String,
        playing: Boolean,
        position: Int,
        duration: Int,
        allowAutoPip: Boolean,
    ) {
        playbackActive = playing
        autoEnterPip = allowAutoPip
        if (supportsPip()) {
            val paramsBuilder =
                PictureInPictureParams.Builder()
                    .setAspectRatio(playbackAspectRatio)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                paramsBuilder.setAutoEnterEnabled(playing && autoEnterPip)
                paramsBuilder.setSeamlessResizeEnabled(true)
            }
            setPictureInPictureParams(paramsBuilder.build())
        }
        val session = mediaSession ?: MediaSessionCompat(this, "Nextfin").also {
            it.isActive = true
            mediaSession = it
        }

        val playbackState =
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_STOP,
                )
                .setState(
                    if (playing) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED,
                    position.toLong(),
                    if (playing) 1f else 0f,
                )
                .build()
        session.setPlaybackState(playbackState)
        session.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration.toLong())
                .build(),
        )

        val notification =
            NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setContentTitle(title)
                .setContentText(if (playing) "Playing in Nextfin" else "Paused in Nextfin")
                .setOnlyAlertOnce(true)
                .setOngoing(playing)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .addAction(
                    NotificationCompat.Action(
                        if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                        if (playing) "Pause" else "Play",
                        mediaActionIntent(ACTION_PLAY_PAUSE, 1),
                    ),
                )
                .addAction(
                    NotificationCompat.Action(
                        android.R.drawable.ic_menu_close_clear_cancel,
                        "Stop",
                        mediaActionIntent(ACTION_STOP, 2),
                    ),
                )
                .setStyle(MediaStyle().setMediaSession(session.sessionToken).setShowActionsInCompactView(0, 1))
                .build()

        NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, notification)
    }

    private fun clearPlaybackSession() {
        playbackActive = false
        autoEnterPip = true
        NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID)
        mediaSession?.isActive = false
        mediaSession?.release()
        mediaSession = null
    }

    private fun registerPlaybackReceiver() {
        if (playbackReceiverRegistered) {
            return
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_PLAY_PAUSE)
            addAction(ACTION_STOP)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(playbackReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(playbackReceiver, filter)
        }
        playbackReceiverRegistered = true
    }

    private fun mediaActionIntent(action: String, requestCode: Int): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(
            this,
            requestCode,
            Intent(action).setPackage(packageName),
            flags,
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel =
            NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Nextfin playback",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Playback controls for Nextfin"
            }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_NAME = "nextfin/player"
        private const val NOTIFICATION_CHANNEL_ID = "nextfin_playback"
        private const val NOTIFICATION_ID = 48021
        private const val ACTION_PLAY_PAUSE = "com.nextfin.action.PLAY_PAUSE"
        private const val ACTION_STOP = "com.nextfin.action.STOP"
    }
}

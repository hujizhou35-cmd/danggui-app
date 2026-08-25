package com.danggui.memo

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

class AlarmRingingService : Service() {
    private val store by lazy { AlarmStore(this) }
    private val audioManager by lazy { getSystemService(AudioManager::class.java) }
    private val handler = Handler(Looper.getMainLooper())
    private var mediaPlayer: MediaPlayer? = null
    private var toneGenerator: ToneGenerator? = null
    private var focusRequest: AudioFocusRequest? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var vibrating = false

    private val toneRunnable =
        object : Runnable {
            override fun run() {
                toneGenerator?.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 850)
                handler.postDelayed(this, 1_400L)
            }
        }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        AlarmChannels.ensureRingingChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val records = store.ringing()
        if (records.isEmpty()) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        AlarmChannels.ensureRingingChannel(this, records.first().localeTag)
        val notification = buildNotification(records)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        acquireWakeLock()
        if (mediaPlayer == null && toneGenerator == null) startAlarmAudio()
        updateVibration(records.any { it.vibrationEnabled })
        return START_STICKY
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopOutputs()
        super.onDestroy()
    }

    private fun buildNotification(records: List<AlarmRecord>): Notification {
        val textContext = AlarmLocale.contextFor(this, records.first().localeTag)
        val title =
            if (records.size == 1) {
                records.first().title.ifBlank {
                    textContext.getString(R.string.alarm_default_title)
                }
            } else {
                textContext.getString(R.string.alarm_multiple_title, records.size)
            }
        val body =
            if (records.size == 1) {
                records.first().body.ifBlank {
                    textContext.getString(R.string.alarm_default_body)
                }
            } else {
                records.take(3).joinToString(" · ") {
                    it.title.ifBlank { textContext.getString(R.string.alarm_default_title) }
                }
            }
        val activityIntent =
            PendingIntent.getActivity(
                this,
                FULL_SCREEN_REQUEST_CODE,
                Intent(this, AlarmActivity::class.java).apply {
                    action = ACTION_OPEN_RINGING_SCREEN
                    flags =
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val defaultSnooze = records.first().defaultSnoozeMinutes
        val snoozeIntent =
            PendingIntent.getBroadcast(
                this,
                SNOOZE_REQUEST_CODE,
                Intent(this, AlarmActionReceiver::class.java).apply {
                    action = AlarmActions.ACTION_SNOOZE
                    putExtra(AlarmActions.EXTRA_SNOOZE_MINUTES, defaultSnooze)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val stopIntent =
            PendingIntent.getBroadcast(
                this,
                STOP_REQUEST_CODE,
                Intent(this, AlarmActionReceiver::class.java).apply {
                    action = AlarmActions.ACTION_STOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
                    .setPriority(Notification.PRIORITY_MAX)
                    .setSound(null)
                    .setVibrate(null)
            }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder
            .setSmallIcon(R.drawable.ic_stat_danggui)
            .setColor(getColor(R.color.danggui_sage))
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setContentIntent(activityIntent)
            .setFullScreenIntent(activityIntent, true)
            .addAction(
                0,
                textContext.getString(R.string.alarm_snooze_action, defaultSnooze),
                snoozeIntent,
            )
            .addAction(0, textContext.getString(R.string.alarm_stop_action), stopIntent)
            .build()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val powerManager = getSystemService(PowerManager::class.java)
        wakeLock =
            powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "$packageName:alarm-ringing",
            ).apply { acquire() }
    }

    private fun startAlarmAudio() {
        requestAudioFocus()
        val alarmUri =
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        if (alarmUri != null && startMediaPlayer(alarmUri)) return
        startFallbackTone()
    }

    private fun startMediaPlayer(uri: Uri): Boolean {
        val player = MediaPlayer()
        mediaPlayer = player
        return runCatching {
            player.apply {
                setAudioAttributes(ALARM_AUDIO_ATTRIBUTES)
                setDataSource(applicationContext, uri)
                isLooping = true
                setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                setOnErrorListener { failedPlayer, _, _ ->
                    failedPlayer.release()
                    if (mediaPlayer === failedPlayer) mediaPlayer = null
                    startFallbackTone()
                    true
                }
                prepare()
                start()
            }
            true
        }.getOrElse {
            runCatching { player.release() }
            if (mediaPlayer === player) mediaPlayer = null
            false
        }
    }

    private fun startFallbackTone() {
        if (toneGenerator != null) return
        toneGenerator =
            runCatching {
                ToneGenerator(AudioManager.STREAM_ALARM, ToneGenerator.MAX_VOLUME)
            }.getOrNull()
        if (toneGenerator != null) handler.post(toneRunnable)
    }

    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request =
                AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    .setAudioAttributes(ALARM_AUDIO_ATTRIBUTES)
                    .setAcceptsDelayedFocusGain(false)
                    .setOnAudioFocusChangeListener { }
                    .build()
            focusRequest = request
            audioManager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            )
        }
    }

    private fun updateVibration(shouldVibrate: Boolean) {
        if (shouldVibrate == vibrating) return
        cancelVibration()
        if (!shouldVibrate) return
        val pattern = longArrayOf(0L, 800L, 400L, 800L, 1_200L)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibrator = getSystemService(VibratorManager::class.java).defaultVibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                vibrator.vibrate(
                    VibrationEffect.createWaveform(pattern, 0),
                    VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM),
                )
            } else {
                vibrator.vibrate(
                    VibrationEffect.createWaveform(pattern, 0),
                    ALARM_AUDIO_ATTRIBUTES,
                )
            }
        } else {
            @Suppress("DEPRECATION")
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    VibrationEffect.createWaveform(pattern, 0),
                    ALARM_AUDIO_ATTRIBUTES,
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, 0)
            }
        }
        vibrating = true
    }

    private fun cancelVibration() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java).cancel()
        } else {
            @Suppress("DEPRECATION")
            (getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).cancel()
        }
        vibrating = false
    }

    private fun stopOutputs() {
        handler.removeCallbacks(toneRunnable)
        toneGenerator?.stopTone()
        toneGenerator?.release()
        toneGenerator = null
        mediaPlayer?.let { player ->
            runCatching { if (player.isPlaying) player.stop() }
            runCatching { player.release() }
        }
        mediaPlayer = null
        cancelVibration()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let(audioManager::abandonAudioFocusRequest)
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
        focusRequest = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    companion object {
        const val ACTION_REFRESH = "com.danggui.memo.action.REFRESH_RINGING_ALARM"
        const val ACTION_OPEN_RINGING_SCREEN = "com.danggui.memo.action.OPEN_RINGING_ALARM"
        const val CHANNEL_ID = "danggui-alarm-ringing-v1"
        const val NOTIFICATION_ID = 7100
        private const val FULL_SCREEN_REQUEST_CODE = 7110
        private const val SNOOZE_REQUEST_CODE = 7111
        private const val STOP_REQUEST_CODE = 7112

        private val ALARM_AUDIO_ATTRIBUTES =
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
    }
}

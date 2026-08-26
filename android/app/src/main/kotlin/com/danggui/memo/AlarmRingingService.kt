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
import android.os.SystemClock
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import java.util.UUID

class AlarmRingingService : Service() {
    private val store by lazy { AlarmStore(this) }
    private val audioManager by lazy { getSystemService(AudioManager::class.java) }
    private val handler = Handler(Looper.getMainLooper())
    private var mediaPlayer: MediaPlayer? = null
    private var toneGenerator: ToneGenerator? = null
    private var focusRequest: AudioFocusRequest? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var vibrating = false
    private var latestStartId = 0
    private val reportedAudioSessions = mutableSetOf<String>()
    private val reportedVibrationSessions = mutableSetOf<String>()

    private data class AudioCandidate(val uri: Uri, val milestone: String)

    private val toneRunnable =
        object : Runnable {
            override fun run() {
                toneGenerator?.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 850)
                handler.postDelayed(this, 1_400L)
            }
        }

    private val cutoffRunnable =
        Runnable {
            expireCompletedSessions()
            renderSession(latestStartId, includeFullScreenIntent = false)
        }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        AlarmChannels.ensureRingingChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        latestStartId = startId
        if (intent?.action == ACTION_FIRE) {
            val provisional = validatedFireRecord(intent)
                ?: return startExistingSessionOrStop(startId)
            AlarmChannels.ensureRingingChannel(this, provisional.localeTag)
            // This is deliberately the first notification posted for a validated FIRE. FSI on a
            // later update is not sufficient on Android, while unverified starts must never get it.
            if (!promoteToForeground(buildNotification(listOf(provisional), includeFullScreenIntent = true))) {
                stopSelfResult(startId)
                return START_NOT_STICKY
            }
            acquireBoundedWakeLock()
            val ringing =
                store.markRingingAndAppendDelivered(
                    reminderId = provisional.reminderId,
                    scheduleRevision = provisional.scheduleRevision,
                    occurredAtEpochMs = System.currentTimeMillis(),
                    sessionId = requireNotNull(provisional.sessionId),
                    ringStartedElapsedRealtimeMs =
                        requireNotNull(provisional.ringStartedElapsedRealtimeMs),
                )
            if (ringing == null) return startExistingSessionOrStop(startId)
            store.appendEvent(eventFor(ringing, "foreground"))
            sendSessionChanged()
            expireCompletedSessions()
            return renderSession(startId, includeFullScreenIntent = true)
        }

        val records = store.ringing()
        if (records.isEmpty()) return stopEmptySession(startId)
        AlarmChannels.ensureRingingChannel(this, records.first().localeTag)
        if (!promoteToForeground(buildNotification(records, includeFullScreenIntent = false))) {
            stopSelfResult(startId)
            return START_NOT_STICKY
        }
        acquireBoundedWakeLock()
        expireCompletedSessions()
        return renderSession(startId, includeFullScreenIntent = false)
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopOutputs()
        super.onDestroy()
    }

    private fun validatedFireRecord(intent: Intent): AlarmRecord? {
        val reminderId = intent.getStringExtra(AlarmScheduler.EXTRA_REMINDER_ID) ?: return null
        val scheduleRevision =
            intent.getLongExtra(AlarmScheduler.EXTRA_SCHEDULE_REVISION, Long.MIN_VALUE)
        if (scheduleRevision == Long.MIN_VALUE) return null
        val record = store.get(reminderId, scheduleRevision) ?: return null
        if (!store.isDeliverable(record)) return null

        val now = System.currentTimeMillis()
        return when (AlarmDeliveryPolicy.decide(record.triggerAtEpochMs, now)) {
            AlarmDeliveryDecision.TOO_EARLY -> {
                store.appendEvent(
                    eventFor(record, "error", detailCode = "early_delivery_rejected"),
                )
                null
            }
            AlarmDeliveryDecision.MISSED -> {
                store.expireDeliverable(reminderId, scheduleRevision, now)
                sendSessionChanged()
                null
            }
            AlarmDeliveryDecision.DELIVER ->
                record.copy(
                    state = AlarmRecord.STATE_RINGING,
                    sessionId = UUID.randomUUID().toString(),
                    ringStartedElapsedRealtimeMs = SystemClock.elapsedRealtime(),
                )
        }
    }

    private fun startExistingSessionOrStop(startId: Int): Int {
        val records = store.ringing()
        if (records.isEmpty()) return stopEmptySession(startId)
        AlarmChannels.ensureRingingChannel(this, records.first().localeTag)
        if (!promoteToForeground(buildNotification(records, includeFullScreenIntent = false))) {
            stopSelfResult(startId)
            return START_NOT_STICKY
        }
        acquireBoundedWakeLock()
        expireCompletedSessions()
        return renderSession(startId, includeFullScreenIntent = false)
    }

    private fun renderSession(startId: Int, includeFullScreenIntent: Boolean): Int {
        val records = store.ringing()
        if (records.isEmpty()) {
            return stopEmptySession(startId)
        }

        AlarmChannels.ensureRingingChannel(this, records.first().localeTag)
        if (!promoteToForeground(buildNotification(records, includeFullScreenIntent))) {
            records.forEach { record ->
                store.appendEvent(eventFor(record, "error", detailCode = "foreground_failed"))
            }
            stopSelfResult(startId)
            return START_NOT_STICKY
        }
        if (mediaPlayer == null && toneGenerator == null) {
            startAlarmAudio()
        } else {
            reportMilestone("audio", "shared_active_output")
        }
        updateVibration(records.any { it.vibrationEnabled })
        scheduleNextCutoff(records)
        sendSessionChanged()
        return START_STICKY
    }

    private fun stopEmptySession(startId: Int): Int {
        handler.removeCallbacks(cutoffRunnable)
        stopOutputs()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelfResult(startId)
        return START_NOT_STICKY
    }

    private fun promoteToForeground(notification: Notification): Boolean =
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        }.isSuccess

    private fun buildNotification(
        records: List<AlarmRecord>,
        includeFullScreenIntent: Boolean,
    ): Notification {
        val first = records.first()
        val textContext = AlarmLocale.contextFor(this, first.localeTag)
        val title =
            if (records.size == 1) {
                first.title.ifBlank { textContext.getString(R.string.alarm_default_title) }
            } else {
                textContext.getString(R.string.alarm_multiple_title, records.size)
            }
        val body =
            if (records.size == 1) {
                first.body.ifBlank { textContext.getString(R.string.alarm_default_body) }
            } else {
                records.take(3).joinToString(" · ") {
                    it.title.ifBlank { textContext.getString(R.string.alarm_default_title) }
                }
            }
        val activityIntent = alarmActivityPendingIntent()
        val defaultSnooze = first.defaultSnoozeMinutes
        val snoozeIntent =
            actionPendingIntent(
                action = AlarmActions.ACTION_SNOOZE,
                record = first,
                requestCode = SNOOZE_REQUEST_CODE,
                snoozeMinutes = defaultSnooze,
            )
        val stopIntent =
            actionPendingIntent(
                action = AlarmActions.ACTION_STOP,
                record = first,
                requestCode = STOP_REQUEST_CODE,
            )

        val builder = notificationBuilder()
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
            .addAction(
                0,
                textContext.getString(R.string.alarm_snooze_action, defaultSnooze),
                snoozeIntent,
            )
            .addAction(0, textContext.getString(R.string.alarm_stop_action), stopIntent)
        if (includeFullScreenIntent) builder.setFullScreenIntent(activityIntent, true)
        return builder.build()
    }

    private fun notificationBuilder(): Notification.Builder {
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
    }

    private fun alarmActivityPendingIntent(): PendingIntent =
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

    private fun actionPendingIntent(
        action: String,
        record: AlarmRecord,
        requestCode: Int,
        snoozeMinutes: Int? = null,
    ): PendingIntent =
        PendingIntent.getBroadcast(
            this,
            requestCode,
            Intent(this, AlarmActionReceiver::class.java).apply {
                this.action = action
                data =
                    Uri.Builder()
                        .scheme("danggui")
                        .authority("alarm-action")
                        .appendPath(action.substringAfterLast('.'))
                        .appendPath(record.reminderId)
                        .appendPath(record.scheduleRevision.toString())
                        .appendPath(record.sessionId.orEmpty())
                        .build()
                putExtra(AlarmActions.EXTRA_REMINDER_ID, record.reminderId)
                putExtra(AlarmActions.EXTRA_SCHEDULE_REVISION, record.scheduleRevision)
                putExtra(AlarmActions.EXTRA_SESSION_ID, record.sessionId)
                snoozeMinutes?.let { putExtra(AlarmActions.EXTRA_SNOOZE_MINUTES, it) }
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun acquireBoundedWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        val powerManager = getSystemService(PowerManager::class.java)
        wakeLock =
            powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "$packageName:alarm-ringing",
            ).apply {
                setReferenceCounted(false)
                acquire(SERVICE_WAKE_LOCK_TIMEOUT_MILLIS)
            }
    }

    private fun startAlarmAudio() {
        requestAudioFocus()
        val candidates =
            listOfNotNull(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)?.let {
                    AudioCandidate(it, "system_alarm_uri")
                },
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)?.let {
                    AudioCandidate(it, "system_notification_uri")
                },
            ).distinctBy { it.uri.toString() }
        startMediaCandidate(candidates, 0)
    }

    private fun startMediaCandidate(candidates: List<AudioCandidate>, index: Int) {
        if (store.ringing().isEmpty()) return
        if (index >= candidates.size) {
            startFallbackTone("media_candidates_exhausted")
            return
        }
        val candidate = candidates[index]
        val player = MediaPlayer()
        mediaPlayer = player
        val configured = runCatching {
            player.apply {
                setAudioAttributes(ALARM_AUDIO_ATTRIBUTES)
                setDataSource(applicationContext, candidate.uri)
                isLooping = true
                setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                setOnPreparedListener { prepared ->
                    if (mediaPlayer !== prepared || store.ringing().isEmpty()) {
                        runCatching { prepared.release() }
                        if (mediaPlayer === prepared) mediaPlayer = null
                        return@setOnPreparedListener
                    }
                    runCatching { prepared.start() }
                        .onSuccess { reportMilestone("audio", candidate.milestone) }
                        .onFailure {
                            advanceMediaCandidate(
                                player = prepared,
                                candidates = candidates,
                                nextIndex = index + 1,
                                errorCode = "${candidate.milestone}_start_failed",
                            )
                        }
                }
                setOnErrorListener { failedPlayer, _, _ ->
                    advanceMediaCandidate(
                        player = failedPlayer,
                        candidates = candidates,
                        nextIndex = index + 1,
                        errorCode = "${candidate.milestone}_prepare_failed",
                    )
                    true
                }
                prepareAsync()
            }
        }.isSuccess
        if (!configured) {
            runCatching { player.release() }
            if (mediaPlayer === player) mediaPlayer = null
            reportError("${candidate.milestone}_source_failed")
            startMediaCandidate(candidates, index + 1)
        }
    }

    private fun advanceMediaCandidate(
        player: MediaPlayer,
        candidates: List<AudioCandidate>,
        nextIndex: Int,
        errorCode: String,
    ) {
        if (mediaPlayer !== player) {
            runCatching { player.release() }
            return
        }
        mediaPlayer = null
        runCatching { player.release() }
        reportError(errorCode)
        handler.post { startMediaCandidate(candidates, nextIndex) }
    }

    private fun startFallbackTone(reason: String) {
        if (toneGenerator != null || store.ringing().isEmpty()) return
        toneGenerator =
            runCatching {
                ToneGenerator(AudioManager.STREAM_ALARM, ToneGenerator.MAX_VOLUME)
            }.getOrNull()
        if (toneGenerator != null) {
            handler.post(toneRunnable)
            reportMilestone("audio", "tone_fallback:$reason")
        } else {
            reportError("tone_fallback_failed")
        }
    }

    private fun requestAudioFocus() {
        val granted =
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val request =
                        AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                            .setAudioAttributes(ALARM_AUDIO_ATTRIBUTES)
                            .setAcceptsDelayedFocusGain(false)
                            .setOnAudioFocusChangeListener { }
                            .build()
                    focusRequest = request
                    audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
                } else {
                    @Suppress("DEPRECATION")
                    audioManager.requestAudioFocus(
                        null,
                        AudioManager.STREAM_ALARM,
                        AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
                    ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
                }
            }.getOrDefault(false)
        if (!granted) reportError("audio_focus_denied")
    }

    private fun updateVibration(shouldVibrate: Boolean) {
        if (!shouldVibrate) {
            cancelVibration()
            return
        }
        if (vibrating) {
            reportMilestone("vibration", "shared_active_output")
            return
        }
        val pattern = longArrayOf(0L, 800L, 400L, 800L, 1_200L)
        val started =
            runCatching {
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
            }.isSuccess
        if (started) {
            vibrating = true
            reportMilestone("vibration", "alarm_usage")
        } else {
            reportError("vibration_failed")
        }
    }

    private fun cancelVibration() {
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(VibratorManager::class.java).cancel()
            } else {
                @Suppress("DEPRECATION")
                (getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).cancel()
            }
        }
        vibrating = false
    }

    private fun scheduleNextCutoff(records: List<AlarmRecord>) {
        handler.removeCallbacks(cutoffRunnable)
        val nowEpochMs = System.currentTimeMillis()
        val nowElapsedRealtimeMs = SystemClock.elapsedRealtime()
        val nextDelay =
            records.minOfOrNull { record ->
                AlarmDeliveryPolicy.remainingRingingMillis(
                    triggerAtEpochMs = record.triggerAtEpochMs,
                    ringStartedElapsedRealtimeMs = record.ringStartedElapsedRealtimeMs,
                    nowEpochMs = nowEpochMs,
                    nowElapsedRealtimeMs = nowElapsedRealtimeMs,
                )
            } ?: return
        handler.postDelayed(cutoffRunnable, nextDelay.coerceAtLeast(1L))
    }

    private fun expireCompletedSessions() {
        val nowEpochMs = System.currentTimeMillis()
        val nowElapsedRealtimeMs = SystemClock.elapsedRealtime()
        store.ringing()
            .filter { record ->
                AlarmDeliveryPolicy.isRingingExpired(
                    triggerAtEpochMs = record.triggerAtEpochMs,
                    ringStartedElapsedRealtimeMs = record.ringStartedElapsedRealtimeMs,
                    nowEpochMs = nowEpochMs,
                    nowElapsedRealtimeMs = nowElapsedRealtimeMs,
                )
            }
            .forEach { record ->
                store.removeRingingAndAppendStopped(
                    expected = record,
                    occurredAtEpochMs = nowEpochMs,
                    detailCode = "automatic_cutoff",
                )
            }
    }

    private fun reportMilestone(type: String, detailCode: String) {
        store.ringing().forEach { record ->
            val sessionId = record.sessionId ?: return@forEach
            val reported =
                when (type) {
                    "audio" -> reportedAudioSessions.add(sessionId)
                    "vibration" -> reportedVibrationSessions.add(sessionId)
                    else -> true
                }
            if (reported) store.appendEvent(eventFor(record, type, detailCode))
        }
    }

    private fun reportError(detailCode: String) {
        store.ringing().forEach { record ->
            store.appendEvent(eventFor(record, "error", detailCode))
        }
    }

    private fun eventFor(
        record: AlarmRecord,
        type: String,
        detailCode: String? = null,
    ): AlarmEvent =
        AlarmEvent(
            reminderId = record.reminderId,
            taskId = record.taskId,
            scheduleRevision = record.scheduleRevision,
            type = type,
            sessionId = record.sessionId,
            detailCode = detailCode,
        )

    private fun sendSessionChanged() {
        sendBroadcast(
            Intent(AlarmActions.ACTION_SESSION_CHANGED).apply { setPackage(packageName) },
        )
    }

    private fun stopOutputs() {
        handler.removeCallbacks(cutoffRunnable)
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
            focusRequest?.let { request ->
                runCatching { audioManager.abandonAudioFocusRequest(request) }
            }
        } else {
            @Suppress("DEPRECATION")
            runCatching { audioManager.abandonAudioFocus(null) }
        }
        focusRequest = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    companion object {
        const val ACTION_FIRE = "com.danggui.memo.action.FIRE_RINGING_SERVICE"
        const val ACTION_REFRESH = "com.danggui.memo.action.REFRESH_RINGING_ALARM"
        const val ACTION_OPEN_RINGING_SCREEN = "com.danggui.memo.action.OPEN_RINGING_ALARM"
        const val CHANNEL_ID = "danggui-alarm-ringing-v1"
        const val NOTIFICATION_ID = 7100
        private const val FULL_SCREEN_REQUEST_CODE = 7110
        private const val SNOOZE_REQUEST_CODE = 7111
        private const val STOP_REQUEST_CODE = 7112
        private const val SERVICE_WAKE_LOCK_TIMEOUT_MILLIS = 16 * 60_000L

        private val ALARM_AUDIO_ATTRIBUTES =
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
    }
}

package com.yuandex

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class ReplyForegroundService : Service() {
    private var currentTitle: String = "AI 正在回复"
    private var currentText: String = "后台运行中，请稍候..."
    private var startedAtMs: Long = System.currentTimeMillis()
    private var isForegroundStarted = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_UPDATE -> {
                applyIntent(intent)
                refreshNotification()
                return START_STICKY
            }

            ACTION_START, null -> {
                applyIntent(intent)
                ensureForeground()
                return START_STICKY
            }

            else -> {
                applyIntent(intent)
                refreshNotification()
                return START_STICKY
            }
        }
    }

    override fun onDestroy() {
        isForegroundStarted = false
        super.onDestroy()
    }

    private fun applyIntent(intent: Intent?) {
        if (intent == null) return
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty().trim()
        val text = intent.getStringExtra(EXTRA_TEXT).orEmpty().trim()
        val started = intent.getLongExtra(EXTRA_STARTED_AT_MS, 0L)
        if (title.isNotEmpty()) currentTitle = title
        if (text.isNotEmpty()) currentText = text
        if (started > 0L) startedAtMs = started
    }

    private fun ensureForeground() {
        createNotificationChannelIfNeeded()
        startForeground(NOTIFICATION_ID, buildNotification())
        isForegroundStarted = true
    }

    private fun refreshNotification() {
        if (!isForegroundStarted) {
            ensureForeground()
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, pendingFlags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(currentTitle)
            .setContentText(currentText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(currentText))
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setWhen(startedAtMs)
            .setUsesChronometer(true)
            .build()
    }

    private fun createNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "AI 回复进程",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "后台防中断模式：显示 AI 当前回复进程"
            setShowBadge(false)
            enableVibration(false)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_START = "com.yuandex.reply_guard.START"
        const val ACTION_UPDATE = "com.yuandex.reply_guard.UPDATE"
        const val ACTION_STOP = "com.yuandex.reply_guard.STOP"

        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_TEXT = "extra_text"
        const val EXTRA_STARTED_AT_MS = "extra_started_at_ms"

        private const val CHANNEL_ID = "ai_reply_guard_channel"
        private const val NOTIFICATION_ID = 90211
    }
}

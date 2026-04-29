package com.example.ai_mobile_coder_ui

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class LocalRuntimeService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                LocalRuntimeManager.stopRuntimeStateOnly(this)
                stopAsForegroundService()
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_START, null -> {
                LocalRuntimeManager.startRuntimeStateOnly(this)
                ensureForeground()
                return START_STICKY
            }

            else -> {
                ensureForeground()
                return START_STICKY
            }
        }
    }

    override fun onDestroy() {
        LocalRuntimeManager.stopRuntimeStateOnly(this)
        super.onDestroy()
    }

    private fun ensureForeground() {
        createNotificationChannelIfNeeded()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    private fun stopAsForegroundService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun buildNotification(): Notification {
        val status = LocalRuntimeManager.getStatus(this)
        val workspaceId = status["activeWorkspaceId"]?.toString().orEmpty()
        val text = if (workspaceId.isBlank()) {
            "Local runtime is ready. Workspace mirror not prepared yet."
        } else {
            "Local runtime is ready. Active workspace: $workspaceId"
        }
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, pendingFlags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Local coding runtime")
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Local coding runtime",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps the local coding runtime alive on Android."
            setShowBadge(false)
            enableVibration(false)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_START = "com.example.ai_mobile_coder_ui.local_runtime.START"
        const val ACTION_STOP = "com.example.ai_mobile_coder_ui.local_runtime.STOP"

        private const val CHANNEL_ID = "local_coding_runtime_channel"
        private const val NOTIFICATION_ID = 90212
    }
}

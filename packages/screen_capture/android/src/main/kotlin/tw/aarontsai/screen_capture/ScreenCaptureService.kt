package tw.aarontsai.screen_capture

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class ScreenCaptureService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val callback = pendingStart
        pendingStart = null

        val error = try {
            enterForeground()
            null
        } catch (e: Exception) {
            stopSelf()
            e.message ?: e.toString()
        }
        callback?.invoke(error)

        return START_NOT_STICKY
    }

    private fun enterForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "螢幕錄影", NotificationManager.IMPORTANCE_LOW)
            )
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val launch = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE)
        }

        return builder
            .setSmallIcon(R.drawable.screen_capture_notification)
            .setContentTitle("${applicationInfo.loadLabel(packageManager)} 正在錄影")
            .setContentText("活動結束後會自動停止")
            .setContentIntent(launch)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "screen_capture"
        private const val NOTIFICATION_ID = 0x5C2E

        private var pendingStart: ((String?) -> Unit)? = null

        fun start(context: Context, completion: (String?) -> Unit) {
            pendingStart = completion
            val intent = Intent(context, ScreenCaptureService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                pendingStart = null
                completion(e.message ?: e.toString())
            }
        }

        fun stop(context: Context) {
            pendingStart = null
            context.stopService(Intent(context, ScreenCaptureService::class.java))
        }
    }
}

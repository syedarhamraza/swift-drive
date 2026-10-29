package com.swiftdrive.launcher.services

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationManagerCompat

/**
 * Required for MediaSessionManager.getActiveSessions and for the compact notification list.
 * Contents are kept only in memory, trimmed, and never persisted or uploaded.
 */
class LauncherNotificationListener : NotificationListenerService() {

    private val handler = Handler(Looper.getMainLooper())
    private val publishRunnable = Runnable { publish() }

    override fun onListenerConnected() {
        instance = this
        publish()
    }

    override fun onListenerDisconnected() {
        instance = null
        onChange?.invoke(emptyList())
        requestRebind(ComponentName(this, LauncherNotificationListener::class.java))
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) = schedulePublish()
    override fun onNotificationRemoved(sbn: StatusBarNotification) = schedulePublish()

    // Bursts of notifications (group updates) collapse into one update for Flutter.
    private fun schedulePublish() {
        handler.removeCallbacks(publishRunnable)
        handler.postDelayed(publishRunnable, 300)
    }

    private fun publish() {
        onChange?.invoke(snapshot())
    }

    fun snapshot(): List<Map<String, Any?>> {
        val active = runCatching { activeNotifications }.getOrNull() ?: return emptyList()
        val ranking = Ranking()
        val rankings = runCatching { currentRanking }.getOrNull()
        return active.mapNotNull { sbn -> compact(sbn, rankings?.let { if (it.getRanking(sbn.key, ranking)) ranking.importance else null }) }
            .sortedByDescending { it["postTime"] as Long }
            .take(MAX_ITEMS)
    }

    private fun compact(sbn: StatusBarNotification, importance: Int?): Map<String, Any?>? {
        val n = sbn.notification
        if (sbn.packageName == packageName || sbn.isOngoing) return null
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return null
        if (n.extras.containsKey(Notification.EXTRA_MEDIA_SESSION)) return null // Shown by the media widget instead.
        if (n.visibility == Notification.VISIBILITY_SECRET) return null
        // Private notifications show only their public version (or nothing beyond the app name).
        val source = if (n.visibility == Notification.VISIBILITY_PRIVATE) n.publicVersion else n
        return mapOf(
            "key" to sbn.key,
            "packageName" to sbn.packageName,
            "appLabel" to appLabel(this, sbn.packageName),
            "title" to source?.extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.take(60),
            "text" to source?.extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.take(MAX_TEXT),
            "postTime" to sbn.postTime,
            "clearable" to sbn.isClearable,
            "category" to n.category,
            "importance" to importance,
        )
    }

    companion object {
        private const val MAX_ITEMS = 30
        const val MAX_TEXT = 120

        @Volatile
        var instance: LauncherNotificationListener? = null
            private set

        /** Set by NotificationBridge while Flutter listens. Always invoked on the main thread. */
        var onChange: ((List<Map<String, Any?>>) -> Unit)? = null

        fun isEnabled(context: Context) =
            NotificationManagerCompat.getEnabledListenerPackages(context).contains(context.packageName)

        fun appLabel(context: Context, pkg: String): String = try {
            val pm = context.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            pkg
        }
    }
}

package com.swiftdrive.launcher.platform

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.util.LruCache
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/** Installed-app discovery and launching through PackageManager. No QUERY_ALL_PACKAGES: see <queries>. */
class AppManager(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val pm: PackageManager = context.packageManager
    private val iconCache = LruCache<String, ByteArray>(256)
    private var receiver: BroadcastReceiver? = null

    init {
        MethodChannel(messenger, "swiftdrive/apps").setMethodCallHandler(this)
        EventChannel(messenger, "swiftdrive/apps/events").setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> result.guardAsync("apps") { installedApps() }
            "launchApp" -> result.guard("apps") {
                launch(call.argument<String>("packageName")!!, call.argument<String>("activityName"))
                true
            }
            "isLaunchable" -> result.guard("apps") {
                resolveLaunchIntent(call.argument<String>("packageName")!!, call.argument<String>("activityName")) != null
            }
            "openGeo" -> result.guard("apps") {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("uri")!!))
                call.argument<String>("packageName")?.let(intent::setPackage)
                startChecked(intent)
                true
            }
            "dial" -> result.guard("apps") {
                startChecked(Intent(Intent.ACTION_DIAL))
                true
            }
            else -> result.notImplemented()
        }
    }

    private fun installedApps(): List<Map<String, Any?>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .filter { it.activityInfo.packageName != context.packageName }
            .map { ri ->
                val info = ri.activityInfo
                val key = "${info.packageName}/${info.name}"
                mapOf(
                    "packageName" to info.packageName,
                    "activityName" to info.name,
                    "label" to ri.loadLabel(pm).toString(),
                    "system" to ((info.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                    "icon" to (iconCache.get(key) ?: renderIcon(ri.loadIcon(pm)).also { iconCache.put(key, it) }),
                )
            }
    }

    private fun renderIcon(drawable: Drawable): ByteArray {
        val size = 96
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(Canvas(bitmap))
        return ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            bitmap.recycle()
            out.toByteArray()
        }
    }

    private fun resolveLaunchIntent(packageName: String, activityName: String?): Intent? {
        if (activityName != null) {
            val explicit = Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .setComponent(ComponentName(packageName, activityName))
            if (explicit.resolveActivity(pm) != null) return explicit
        }
        // The launch activity may have changed since it was pinned; fall back to the package's current one.
        return pm.getLaunchIntentForPackage(packageName)
    }

    private fun launch(packageName: String, activityName: String?) {
        val intent = resolveLaunchIntent(packageName, activityName)
            ?: throw ChannelException(Codes.ACTIVITY_NOT_FOUND, "$packageName is not launchable")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        context.startActivity(intent)
    }

    private fun startChecked(intent: Intent) {
        if (intent.resolveActivity(pm) == null) throw ChannelException(Codes.ACTIVITY_NOT_FOUND, "no handler for ${intent.action}")
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                val pkg = intent.data?.schemeSpecificPart ?: return
                iconCache.snapshot().keys.filter { it.startsWith("$pkg/") }.forEach(iconCache::remove)
                events.success(pkg)
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_CHANGED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addDataScheme("package")
        }
        // Package broadcasts come from the system; EXPORTED is required to receive them on API 33+.
        ContextCompat.registerReceiver(context, r, filter, ContextCompat.RECEIVER_EXPORTED)
        receiver = r
    }

    override fun onCancel(arguments: Any?) {
        receiver?.let { runCatching { context.unregisterReceiver(it) } }
        receiver = null
    }
}

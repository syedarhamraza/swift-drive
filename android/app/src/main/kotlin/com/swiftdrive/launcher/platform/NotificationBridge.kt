package com.swiftdrive.launcher.platform

import android.content.Context
import com.swiftdrive.launcher.services.LauncherNotificationListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NotificationBridge(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    init {
        MethodChannel(messenger, "swiftdrive/notifications").setMethodCallHandler(this)
        EventChannel(messenger, "swiftdrive/notifications/events").setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasAccess" -> result.guard("notifications") { LauncherNotificationListener.isEnabled(context) }
            "dismiss" -> result.guard("notifications") {
                val listener = LauncherNotificationListener.instance
                    ?: throw ChannelException(Codes.SERVICE_UNAVAILABLE, "listener not connected")
                listener.cancelNotification(call.argument<String>("key")!!)
                true
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        LauncherNotificationListener.onChange = { items -> events.success(items) }
        events.success(LauncherNotificationListener.instance?.snapshot() ?: emptyList<Any>())
    }

    override fun onCancel(arguments: Any?) {
        LauncherNotificationListener.onChange = null
    }
}

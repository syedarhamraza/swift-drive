package com.swiftdrive.launcher.platform

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/**
 * Battery and connection type for the rail's status row, from public broadcasts and callbacks.
 * Both sources fire often (voltage, temperature, link quality), so only changes to shown values are sent.
 */
class DeviceStatusBridge(private val context: Context, messenger: BinaryMessenger) :
    EventChannel.StreamHandler {

    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var battery: Intent? = null
    private var last: Map<String, Any?>? = null

    init {
        EventChannel(messenger, "swiftdrive/status/events").setStreamHandler(this)
    }

    private fun network(): String {
        val cm = connectivity ?: return "none"
        val caps = runCatching { cm.getNetworkCapabilities(cm.activeNetwork) }.getOrNull() ?: return "none"
        return when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            else -> "other"
        }
    }

    private fun emit() {
        val b = battery
        val level = b?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = b?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        // Head units usually report no battery; the rail then shows none.
        val present = b?.getBooleanExtra(BatteryManager.EXTRA_PRESENT, false) == true
        val status = mapOf(
            "battery" to if (present && level >= 0 && scale > 0) level * 100 / scale else null,
            "charging" to (present && (b?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0),
            "network" to network(),
        )
        if (status == last) return
        last = status
        sink?.success(status)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                battery = intent
                emit()
            }
        }
        // ACTION_BATTERY_CHANGED is sticky: registering returns the current state.
        battery = ContextCompat.registerReceiver(
            context, r, IntentFilter(Intent.ACTION_BATTERY_CHANGED), ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        receiver = r
        val cb = object : ConnectivityManager.NetworkCallback() {
            // Called on a connectivity thread; the sink must be used on the main thread.
            override fun onAvailable(network: Network) { main.post { emit() } }
            override fun onLost(network: Network) { main.post { emit() } }
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                main.post { emit() }
            }
        }
        if (connectivity != null && runCatching { connectivity.registerDefaultNetworkCallback(cb) }.isSuccess) {
            callback = cb
        }
        emit()
    }

    override fun onCancel(arguments: Any?) {
        receiver?.let { runCatching { context.unregisterReceiver(it) } }
        callback?.let { runCatching { connectivity?.unregisterNetworkCallback(it) } }
        receiver = null
        callback = null
        battery = null
        last = null
        sink = null
        main.removeCallbacksAndMessages(null)
    }
}

package com.swiftdrive.launcher.platform

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Public Bluetooth state only. This is unrelated to a head unit's proprietary HFP calling stack,
 * which is never touched; calling is delegated to the user-selected phone app.
 */
class BluetoothBridge(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val adapter: BluetoothAdapter? =
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?)?.adapter
    private val proxies = HashMap<Int, BluetoothProfile>()
    private var receiver: BroadcastReceiver? = null
    private var sink: EventChannel.EventSink? = null

    init {
        MethodChannel(messenger, "swiftdrive/bluetooth").setMethodCallHandler(this)
        EventChannel(messenger, "swiftdrive/bluetooth/events").setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.guard("bluetooth") { status() }
            else -> result.notImplemented()
        }
    }

    private fun hasConnectPermission() = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
        ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission") // Guarded by hasConnectPermission().
    private fun status(): Map<String, Any?> {
        val permission = hasConnectPermission()
        val connected = if (permission) {
            proxies.values.flatMap { p -> runCatching { p.connectedDevices }.getOrDefault(emptyList()) }
                .distinctBy(BluetoothDevice::getAddress)
                .map { runCatching { it.name }.getOrNull() ?: "Unknown device" }
        } else {
            emptyList()
        }
        return mapOf(
            "supported" to (adapter != null),
            "enabled" to runCatching { adapter?.isEnabled == true }.getOrDefault(false),
            "permission" to permission,
            "connectedDevices" to connected,
        )
    }

    private fun emit() {
        sink?.success(runCatching { status() }.getOrNull())
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        val a = adapter
        if (a != null && hasConnectPermission()) {
            val listener = object : BluetoothProfile.ServiceListener {
                override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                    proxies[profile] = proxy
                    emit()
                }
                override fun onServiceDisconnected(profile: Int) {
                    proxies.remove(profile)
                    emit()
                }
            }
            runCatching {
                a.getProfileProxy(context, listener, BluetoothProfile.A2DP)
                a.getProfileProxy(context, listener, BluetoothProfile.HEADSET)
            }
        }
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) = emit()
        }
        val filter = IntentFilter().apply {
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
        }
        ContextCompat.registerReceiver(context, r, filter, ContextCompat.RECEIVER_EXPORTED)
        receiver = r
        emit()
    }

    override fun onCancel(arguments: Any?) {
        receiver?.let { runCatching { context.unregisterReceiver(it) } }
        receiver = null
        proxies.forEach { (profile, proxy) -> runCatching { adapter?.closeProfileProxy(profile, proxy) } }
        proxies.clear()
        sink = null
    }
}

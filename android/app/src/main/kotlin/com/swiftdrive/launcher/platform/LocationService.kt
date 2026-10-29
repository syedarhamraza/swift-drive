package com.swiftdrive.launcher.platform

import android.Manifest
import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import android.os.SystemClock
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Framework LocationManager only (head units often lack Play Services). Updates run only while Flutter
 * listens, and Flutter cancels the stream when the app goes to the background.
 */
class LocationService(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager?
    private var sink: EventChannel.EventSink? = null
    private var providerReceiver: BroadcastReceiver? = null
    private var registered = false

    // Explicit overrides: on API < 30 these are abstract, and a missing override crashes at runtime.
    private val listener = object : LocationListener {
        override fun onLocationChanged(location: Location) = emitFix(location)
        override fun onProviderEnabled(provider: String) = emitStatus()
        override fun onProviderDisabled(provider: String) = emitStatus()
        @Deprecated("Deprecated in API 29")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
    }

    init {
        MethodChannel(messenger, "swiftdrive/location").setMethodCallHandler(this)
        EventChannel(messenger, "swiftdrive/location/events").setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.guard("location") { status() }
            // Called after the user grants permission so an active stream starts delivering fixes.
            "restart" -> result.guard("location") { stopUpdates(); startUpdates(); true }
            else -> result.notImplemented()
        }
    }

    private fun hasPermission() =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun enabled(provider: String) = runCatching { lm?.isProviderEnabled(provider) == true }.getOrDefault(false)

    fun status(): Map<String, Any?> {
        val providers = lm?.allProviders.orEmpty()
        return mapOf(
            "type" to "status",
            "permission" to hasPermission(),
            "serviceAvailable" to (lm != null),
            "gpsAvailable" to providers.contains(LocationManager.GPS_PROVIDER),
            "gpsEnabled" to enabled(LocationManager.GPS_PROVIDER),
            "networkAvailable" to providers.contains(LocationManager.NETWORK_PROVIDER),
            "networkEnabled" to enabled(LocationManager.NETWORK_PROVIDER),
            "locationEnabled" to (lm?.isLocationEnabled == true),
        )
    }

    private fun emitStatus() {
        sink?.success(status())
    }

    private fun emitFix(loc: Location) {
        val ageMs = (SystemClock.elapsedRealtimeNanos() - loc.elapsedRealtimeNanos) / 1_000_000
        sink?.success(
            mapOf(
                "type" to "fix",
                "provider" to loc.provider,
                "lat" to loc.latitude,
                "lon" to loc.longitude,
                "accuracy" to if (loc.hasAccuracy()) loc.accuracy.toDouble() else null,
                "speed" to if (loc.hasSpeed()) loc.speed.toDouble() else null,
                "speedAccuracy" to if (loc.hasSpeedAccuracy()) loc.speedAccuracyMetersPerSecond.toDouble() else null,
                "bearing" to if (loc.hasBearing()) loc.bearing.toDouble() else null,
                "ageMs" to ageMs,
            )
        )
    }

    @SuppressLint("MissingPermission") // Checked by hasPermission().
    private fun startUpdates() {
        emitStatus()
        val manager = lm ?: return
        if (!hasPermission()) return
        val providers = manager.allProviders
        try {
            if (providers.contains(LocationManager.GPS_PROVIDER)) {
                manager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, listener, Looper.getMainLooper())
                manager.getLastKnownLocation(LocationManager.GPS_PROVIDER)?.let { last ->
                    if (SystemClock.elapsedRealtimeNanos() - last.elapsedRealtimeNanos < 10_000_000_000L) emitFix(last)
                }
            }
            // Network fixes improve the map position indoors; they are never used for speed (see Dart speed model).
            if (providers.contains(LocationManager.NETWORK_PROVIDER)) {
                manager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 5000L, 0f, listener, Looper.getMainLooper())
            }
            registered = true
        } catch (e: SecurityException) {
            emitStatus()
        } catch (e: IllegalArgumentException) {
            emitStatus()
        }
    }

    private fun stopUpdates() {
        if (registered) runCatching { lm?.removeUpdates(listener) }
        registered = false
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                stopUpdates()
                startUpdates()
            }
        }
        ContextCompat.registerReceiver(
            context, r, IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION), ContextCompat.RECEIVER_EXPORTED
        )
        providerReceiver = r
        startUpdates()
    }

    override fun onCancel(arguments: Any?) {
        stopUpdates()
        providerReceiver?.let { runCatching { context.unregisterReceiver(it) } }
        providerReceiver = null
        sink = null
    }
}

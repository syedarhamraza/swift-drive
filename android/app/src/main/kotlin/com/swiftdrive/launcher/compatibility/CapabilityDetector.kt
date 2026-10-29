package com.swiftdrive.launcher.compatibility

import android.Manifest
import android.app.ActivityManager
import android.bluetooth.BluetoothManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.LocationManager
import android.media.session.MediaSessionManager
import android.os.Build
import android.speech.tts.TextToSpeech
import androidx.core.content.ContextCompat
import androidx.core.content.pm.PackageInfoCompat
import com.swiftdrive.launcher.services.LauncherNotificationListener

data class Capability(val id: String, val label: String, val status: CapabilityStatus, val detail: String = "") {
    fun toMap() = mapOf("id" to id, "label" to label, "status" to status.name, "detail" to detail)
}

/** Non-privileged capability checks. Anything that would need a hidden API is reported, not probed. */
class CapabilityDetector(private val context: Context, private val adapter: HeadUnitAdapter) {

    private val pm = context.packageManager

    private fun granted(p: String) = ContextCompat.checkSelfPermission(context, p) == PackageManager.PERMISSION_GRANTED

    fun detect(isDefaultHome: Boolean): List<Capability> = listOf(
        Capability("home", "Default HOME app", if (isDefaultHome) CapabilityStatus.AVAILABLE else CapabilityStatus.UNAVAILABLE,
            if (isDefaultHome) "SwiftDrive is the default launcher" else "Running as a normal app"),
        notificationAccess(),
        mediaSessions(),
        gps(),
        networkLocation(),
        bluetooth(),
        playServices(),
        Capability("tts", "Text-to-speech",
            if (pm.queryIntentServices(Intent(TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE), 0).isNotEmpty()) CapabilityStatus.AVAILABLE else CapabilityStatus.UNAVAILABLE),
        Capability("geocoder", "Place names (Geocoder)", if (Geocoder.isPresent()) CapabilityStatus.AVAILABLE else CapabilityStatus.UNAVAILABLE),
        Capability("radio", "FM radio control", adapter.radio(), "Use the Radio shortcut to open the factory radio app"),
        Capability("calling", "Bluetooth calling control", adapter.bluetoothCalling(), "Use the Phone shortcut to open the factory phone app"),
        Capability("vehicleData", "Vehicle data", adapter.vehicleData(), "No verified vehicle adapter"),
        Capability("steering", "Steering-wheel controls", adapter.steeringWheelControls(), "Handled by Android/factory software; not verified"),
        Capability("reverseCamera", "Reverse camera", adapter.reverseCamera(), "Handled by the factory system; must be verified in the vehicle"),
        Capability("headlights", "Headlight state", adapter.headlightState(), "Night mode uses time/sun data instead"),
    )

    private fun notificationAccess() = if (LauncherNotificationListener.isEnabled(context)) {
        Capability("notifications", "Notification access", CapabilityStatus.AVAILABLE)
    } else {
        Capability("notifications", "Notification access", CapabilityStatus.PERMISSION_REQUIRED, "Needed for media and notifications")
    }

    private fun mediaSessions(): Capability {
        if (!LauncherNotificationListener.isEnabled(context)) {
            return Capability("media", "Media sessions", CapabilityStatus.PERMISSION_REQUIRED, "Enable notification access")
        }
        return try {
            val msm = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
            val count = msm.getActiveSessions(ComponentName(context, LauncherNotificationListener::class.java)).size
            Capability("media", "Media sessions", CapabilityStatus.AVAILABLE, "$count active")
        } catch (e: SecurityException) {
            Capability("media", "Media sessions", CapabilityStatus.ERROR, "Denied by system")
        }
    }

    private fun locationPermission() =
        granted(Manifest.permission.ACCESS_FINE_LOCATION) || granted(Manifest.permission.ACCESS_COARSE_LOCATION)

    private fun gps(): Capability {
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager?
        val label = "GPS"
        return when {
            lm == null || !lm.allProviders.contains(LocationManager.GPS_PROVIDER) ->
                Capability("gps", label, CapabilityStatus.UNAVAILABLE, "No GPS provider on this device")
            !locationPermission() -> Capability("gps", label, CapabilityStatus.PERMISSION_REQUIRED)
            !runCatching { lm.isProviderEnabled(LocationManager.GPS_PROVIDER) }.getOrDefault(false) ->
                Capability("gps", label, CapabilityStatus.UNAVAILABLE, "GPS is turned off")
            else -> Capability("gps", label, CapabilityStatus.AVAILABLE)
        }
    }

    private fun networkLocation(): Capability {
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager?
        val present = lm?.allProviders?.contains(LocationManager.NETWORK_PROVIDER) == true
        return Capability("networkLocation", "Network location",
            if (present) CapabilityStatus.AVAILABLE else CapabilityStatus.UNAVAILABLE)
    }

    private fun bluetooth(): Capability {
        val adapter = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?)?.adapter
            ?: return Capability("bluetooth", "Bluetooth", CapabilityStatus.UNSUPPORTED, "No Bluetooth adapter")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !granted(Manifest.permission.BLUETOOTH_CONNECT)) {
            return Capability("bluetooth", "Bluetooth", CapabilityStatus.PERMISSION_REQUIRED, "Needed to show connected devices")
        }
        val on = runCatching { adapter.isEnabled }.getOrDefault(false)
        return Capability("bluetooth", "Bluetooth", if (on) CapabilityStatus.AVAILABLE else CapabilityStatus.UNAVAILABLE,
            if (on) "On" else "Off")
    }

    private fun playServices(): Capability {
        val present = runCatching { pm.getPackageInfo(GMS_PACKAGE, 0); true }.getOrDefault(false)
        return Capability("playServices", "Google Play Services",
            if (present) CapabilityStatus.AVAILABLE else CapabilityStatus.UNAVAILABLE, "Not required by SwiftDrive")
    }

    fun deviceInfo(): Map<String, Any?> {
        val metrics = context.resources.displayMetrics
        val (w, h) = displaySize()
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mem = ActivityManager.MemoryInfo().also(am::getMemoryInfo)
        val launchable = pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0).size
        val self = pm.getPackageInfo(context.packageName, 0)
        return mapOf(
            "appVersion" to self.versionName,
            "appBuild" to PackageInfoCompat.getLongVersionCode(self),
            "sdkInt" to Build.VERSION.SDK_INT,
            "release" to Build.VERSION.RELEASE,
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "hardware" to Build.HARDWARE,
            "abis" to Build.SUPPORTED_ABIS.toList(),
            "displayWidthPx" to w,
            "displayHeightPx" to h,
            "densityDpi" to metrics.densityDpi,
            "density" to metrics.density.toDouble(),
            "totalMemMb" to mem.totalMem / (1024 * 1024),
            "availMemMb" to mem.availMem / (1024 * 1024),
            "lowRamDevice" to am.isLowRamDevice,
            "memoryClassMb" to am.memoryClass,
            "launchableApps" to launchable,
            "adapter" to adapter.displayName,
        )
    }

    /** Opt-in only: identifiers that are not personal but are more specific than needed by default. */
    fun extraDetails(): Map<String, Any?> = mapOf(
        "fingerprint" to Build.FINGERPRINT,
        "display" to Build.DISPLAY,
        "board" to Build.BOARD,
        "product" to Build.PRODUCT,
        "launchablePackages" to pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
            .map { it.activityInfo.packageName }.distinct().sorted(),
        "homePackages" to pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)
            .map { it.activityInfo.packageName }.distinct().sorted(),
    )

    @Suppress("DEPRECATION") // getRealMetrics is the only option below API 30.
    private fun displaySize(): Pair<Int, Int> {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val b = wm.maximumWindowMetrics.bounds
            b.width() to b.height()
        } else {
            val m = android.util.DisplayMetrics()
            wm.defaultDisplay.getRealMetrics(m)
            m.widthPixels to m.heightPixels
        }
    }

    private companion object {
        const val GMS_PACKAGE = "com.google.android.gms"
    }
}

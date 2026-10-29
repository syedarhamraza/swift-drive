package com.swiftdrive.launcher.platform

import android.content.Context
import android.location.Geocoder
import com.swiftdrive.launcher.compatibility.CapabilityDetector
import com.swiftdrive.launcher.compatibility.HeadUnitManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class DeviceDiagnostics(private val context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {

    private val detector = CapabilityDetector(context, HeadUnitManager.adapter)

    init {
        MethodChannel(messenger, "swiftdrive/device").setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getReport" -> result.guardAsync("device") {
                val extra = call.argument<Boolean>("extra") == true
                mapOf(
                    "adapter" to mapOf("id" to HeadUnitManager.adapter.id, "name" to HeadUnitManager.adapter.displayName),
                    "device" to detector.deviceInfo(),
                    "capabilities" to detector.detect(isDefaultHome(context)).map { it.toMap() },
                    "extra" to if (extra) detector.extraDetails() else null,
                )
            }
            "reverseGeocode" -> result.guardAsync("device") {
                if (!Geocoder.isPresent()) return@guardAsync null
                @Suppress("DEPRECATION") // The listener variant is API 33+; this runs on a background thread.
                Geocoder(context, Locale.getDefault())
                    .getFromLocation(call.argument<Double>("lat")!!, call.argument<Double>("lon")!!, 1)
                    ?.firstOrNull()
                    ?.let { it.locality ?: it.subAdminArea ?: it.adminArea }
            }
            else -> result.notImplemented()
        }
    }
}

package com.swiftdrive.launcher

import android.content.ActivityNotFoundException
import com.swiftdrive.launcher.compatibility.CapabilityStatus
import com.swiftdrive.launcher.compatibility.GenericAndroidAdapter
import com.swiftdrive.launcher.compatibility.HeadUnitManager
import com.swiftdrive.launcher.compatibility.SuzukiSwiftAdapter
import com.swiftdrive.launcher.platform.ChannelException
import com.swiftdrive.launcher.platform.Codes
import com.swiftdrive.launcher.platform.guard
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class ChannelContractTest {
    private class Recorder : MethodChannel.Result {
        var value: Any? = null
        var code: String? = null
        override fun success(result: Any?) { value = result }
        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) { code = errorCode }
        override fun notImplemented() { code = "NOT_IMPLEMENTED" }
    }

    private fun codeFor(e: Throwable) = Recorder().also { r -> r.guard("test") { throw e } }.code

    @Test
    fun successPassesValueThrough() {
        val r = Recorder().also { it.guard("test") { 42 } }
        assertEquals(42, r.value)
        assertNull(r.code)
    }

    // These strings must match PlatformFailure.kindForCode in lib/core/platform/platform_failure.dart.
    @Test
    fun exceptionsMapToDartErrorCodes() {
        assertEquals(Codes.PERMISSION_DENIED, codeFor(ChannelException(Codes.PERMISSION_DENIED, "x")))
        assertEquals(Codes.ACTIVITY_NOT_FOUND, codeFor(ActivityNotFoundException("x")))
        assertEquals(Codes.SECURITY, codeFor(SecurityException("x")))
        assertEquals(Codes.UNSUPPORTED, codeFor(UnsupportedOperationException("x")))
        assertEquals(Codes.INTERNAL, codeFor(IllegalStateException("x")))
    }

    @Test
    fun noAdapterClaimsUnverifiedVehicleFeatures() {
        for (a in listOf(GenericAndroidAdapter(), SuzukiSwiftAdapter())) {
            for (s in listOf(a.radio(), a.bluetoothCalling(), a.vehicleData(), a.steeringWheelControls(), a.reverseCamera(), a.headlightState())) {
                assert(s != CapabilityStatus.AVAILABLE) { "${a.id} claims a vehicle feature" }
            }
        }
    }

    @Test
    fun suzukiProfileIsNotSelectedUntilVerified() {
        assertFalse(SuzukiSwiftAdapter().matches())
        assertEquals("generic", HeadUnitManager.adapter.id)
    }
}

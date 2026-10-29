package com.swiftdrive.launcher.compatibility

/** Status of one capability. Untested capabilities are UNKNOWN, never AVAILABLE. */
enum class CapabilityStatus { AVAILABLE, UNAVAILABLE, PERMISSION_REQUIRED, UNKNOWN, UNSUPPORTED, ERROR }

/**
 * Device-specific integration point. A verified adapter may later report real support for vendor
 * features; until then every vehicle capability stays UNSUPPORTED/UNKNOWN and the launcher falls
 * back to launching the factory apps the user selected.
 */
interface HeadUnitAdapter {
    val id: String
    val displayName: String
    fun matches(): Boolean
    fun radio(): CapabilityStatus
    fun bluetoothCalling(): CapabilityStatus
    fun vehicleData(): CapabilityStatus
    fun steeringWheelControls(): CapabilityStatus
    fun reverseCamera(): CapabilityStatus
    fun headlightState(): CapabilityStatus
}

class GenericAndroidAdapter : HeadUnitAdapter {
    override val id = "generic"
    override val displayName = "Generic Android"
    override fun matches() = true
    override fun radio() = CapabilityStatus.UNSUPPORTED
    override fun bluetoothCalling() = CapabilityStatus.UNSUPPORTED
    override fun vehicleData() = CapabilityStatus.UNSUPPORTED
    // Standard media buttons are routed by Android to the active media session, not to SwiftDrive.
    override fun steeringWheelControls() = CapabilityStatus.UNKNOWN
    // Handled entirely by the factory system; SwiftDrive does not intercept it.
    override fun reverseCamera() = CapabilityStatus.UNKNOWN
    override fun headlightState() = CapabilityStatus.UNSUPPORTED
}

/**
 * Placeholder for the Suzuki Swift GLX CVT 2026 (Pakistan) head unit. Its firmware, packages and MCU
 * protocol are unverified, so it matches nothing yet. See docs/HARDWARE_TESTING.md for how to collect
 * the information needed to implement it.
 */
class SuzukiSwiftAdapter : HeadUnitAdapter {
    override val id = "suzuki-swift-2026-pk"
    override val displayName = "Suzuki Swift (unverified)"
    // TODO: match on verified Build.MANUFACTURER / Build.MODEL / Build.DEVICE values once collected from the vehicle.
    override fun matches() = false
    override fun radio() = CapabilityStatus.UNKNOWN
    override fun bluetoothCalling() = CapabilityStatus.UNKNOWN
    override fun vehicleData() = CapabilityStatus.UNKNOWN
    override fun steeringWheelControls() = CapabilityStatus.UNKNOWN
    override fun reverseCamera() = CapabilityStatus.UNKNOWN
    override fun headlightState() = CapabilityStatus.UNKNOWN
}

object HeadUnitManager {
    private val profiles: List<HeadUnitAdapter> = listOf(SuzukiSwiftAdapter())

    val adapter: HeadUnitAdapter by lazy { profiles.firstOrNull { it.matches() } ?: GenericAndroidAdapter() }
}

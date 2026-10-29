package com.swiftdrive.launcher.platform

import android.Manifest
import android.app.Activity
import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import com.swiftdrive.launcher.services.LauncherNotificationListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * HOME role, launcher recovery, settings shortcuts, runtime permissions and document export.
 * Every change to the default HOME app goes through the system UI; nothing is changed silently.
 */
class LauncherBridge(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "swiftdrive/launcher")
    private val pm = activity.packageManager
    private var pendingRole: MethodChannel.Result? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var pendingExport: Pair<MethodChannel.Result, String>? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getHomeStatus" -> result.guard("launcher") { homeStatus() }
            "requestHomeRole" -> requestHomeRole(result)
            "openHomeSettings" -> result.guard("launcher") { openHomeSettings(); true }
            "launchHome" -> result.guard("launcher") {
                val component = ComponentName(call.argument<String>("packageName")!!, call.argument<String>("activityName")!!)
                activity.startActivity(
                    Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).setComponent(component)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                true
            }
            "openSettings" -> result.guard("launcher") { openSettings(call.argument<String>("page")!!); true }
            "getPermissions" -> result.guard("launcher") { permissions() }
            "requestPermission" -> requestPermission(call.argument<String>("name")!!, result)
            "exportFile" -> exportFile(call.argument<String>("fileName")!!, call.argument<String>("content")!!, result)
            else -> result.notImplemented()
        }
    }

    /** Called by MainActivity when HOME is pressed while SwiftDrive is already on top. */
    fun notifyHomePressed() = channel.invokeMethod("homePressed", null)

    private fun homeIntent() = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)

    private fun isDefaultHome() = isDefaultHome(activity)

    private fun homeStatus(): Map<String, Any?> {
        val others = pm.queryIntentActivities(homeIntent(), 0)
            .map { it.activityInfo }
            .filter { it.packageName != activity.packageName }
            // AOSP's FallbackHome only exists for direct-boot and is not a usable launcher.
            .filter { it.name != "com.android.settings.FallbackHome" }
            .map { mapOf("packageName" to it.packageName, "activityName" to it.name, "label" to it.loadLabel(pm).toString()) }
        val roleAvailable = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            activity.getSystemService(RoleManager::class.java)?.isRoleAvailable(RoleManager.ROLE_HOME) == true
        return mapOf("isDefault" to isDefaultHome(), "roleAvailable" to roleAvailable, "otherHomes" to others)
    }

    private fun requestHomeRole(result: MethodChannel.Result) {
        try {
            val rm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) activity.getSystemService(RoleManager::class.java) else null
            if (rm != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && rm.isRoleAvailable(RoleManager.ROLE_HOME)) {
                if (rm.isRoleHeld(RoleManager.ROLE_HOME)) return result.success(true)
                pendingRole?.success(null)
                pendingRole = result
                activity.startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_HOME), REQ_ROLE)
            } else {
                openHomeSettings()
                result.success(null) // Outcome unknown: the user chooses in system settings.
            }
        } catch (e: Exception) {
            pendingRole = null
            result.guard("launcher") { throw e }
        }
    }

    private fun openHomeSettings() {
        val candidates = listOf(Intent(Settings.ACTION_HOME_SETTINGS), Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS), Intent(Settings.ACTION_SETTINGS))
        startFirstResolvable(candidates)
    }

    private fun openSettings(page: String) {
        val self = Uri.fromParts("package", activity.packageName, null)
        val primary = when (page) {
            "appDetails" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, self)
            "location" -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            "bluetooth" -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
            "notificationAccess" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                    Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                    ComponentName(activity, LauncherNotificationListener::class.java).flattenToString(),
                )
            } else {
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            }
            "home" -> Intent(Settings.ACTION_HOME_SETTINGS)
            "tts" -> Intent("com.android.settings.TTS_SETTINGS")
            else -> Intent(Settings.ACTION_SETTINGS)
        }
        val fallbacks = if (page == "notificationAccess") listOf(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)) else emptyList()
        startFirstResolvable(listOf(primary) + fallbacks + Intent(Settings.ACTION_SETTINGS))
    }

    private fun startFirstResolvable(intents: List<Intent>) {
        val intent = intents.firstOrNull { it.resolveActivity(pm) != null }
            ?: throw ChannelException(Codes.ACTIVITY_NOT_FOUND, "no settings activity")
        activity.startActivity(intent)
    }

    private fun granted(permission: String) =
        ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED

    private fun permissions(): Map<String, Boolean> = mapOf(
        "location" to (granted(Manifest.permission.ACCESS_FINE_LOCATION) || granted(Manifest.permission.ACCESS_COARSE_LOCATION)),
        "bluetooth" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || granted(Manifest.permission.BLUETOOTH_CONNECT)),
    )

    private fun requestPermission(name: String, result: MethodChannel.Result) {
        val perms = when (name) {
            "location" -> arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
            "bluetooth" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) arrayOf(Manifest.permission.BLUETOOTH_CONNECT) else emptyArray()
            else -> return result.error(Codes.UNSUPPORTED, "unknown permission $name", null)
        }
        if (perms.isEmpty() || perms.any(::granted)) return result.success(true)
        pendingPermission?.success(false)
        pendingPermission = result
        activity.requestPermissions(perms, REQ_PERMISSION)
    }

    private fun exportFile(fileName: String, content: String, result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("application/json")
            .putExtra(Intent.EXTRA_TITLE, fileName)
        if (intent.resolveActivity(pm) == null) return result.error(Codes.UNSUPPORTED, "no document provider", null)
        pendingExport?.first?.success(false)
        pendingExport = result to content
        activity.startActivityForResult(intent, REQ_EXPORT)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQ_ROLE -> {
                pendingRole?.success(isDefaultHome())
                pendingRole = null
            }
            REQ_EXPORT -> {
                val (result, content) = pendingExport ?: return true
                pendingExport = null
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) return true.also { result.success(false) }
                result.guardAsync("export") {
                    activity.contentResolver.openOutputStream(uri)?.use { it.write(content.toByteArray()) }
                        ?: throw ChannelException(Codes.SERVICE_UNAVAILABLE, "cannot open document")
                    true
                }
            }
            else -> return false
        }
        return true
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQ_PERMISSION) return false
        pendingPermission?.success(grantResults.any { it == PackageManager.PERMISSION_GRANTED })
        pendingPermission = null
        return true
    }

    private companion object {
        const val REQ_ROLE = 4101
        const val REQ_PERMISSION = 4102
        const val REQ_EXPORT = 4103
    }
}

fun isDefaultHome(context: Context): Boolean {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        val rm = context.getSystemService(RoleManager::class.java)
        if (rm != null && rm.isRoleAvailable(RoleManager.ROLE_HOME)) return rm.isRoleHeld(RoleManager.ROLE_HOME)
    }
    val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
    return context.packageManager.resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName == context.packageName
}

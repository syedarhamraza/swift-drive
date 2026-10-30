package com.swiftdrive.launcher

import android.content.Intent
import com.swiftdrive.launcher.platform.AppManager
import com.swiftdrive.launcher.platform.BluetoothBridge
import com.swiftdrive.launcher.platform.DeviceDiagnostics
import com.swiftdrive.launcher.platform.DeviceStatusBridge
import com.swiftdrive.launcher.platform.LauncherBridge
import com.swiftdrive.launcher.platform.LocationService
import com.swiftdrive.launcher.platform.MediaManager
import com.swiftdrive.launcher.platform.NotificationBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Single activity. Registered both as a HOME candidate and as a normal launcher entry, so SwiftDrive
 * also works as an ordinary app when the firmware does not allow changing the default launcher.
 * No overlays, foreground services or window flags that could hide the factory reverse-camera UI.
 */
class MainActivity : FlutterActivity() {

    private var launcher: LauncherBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        launcher = LauncherBridge(this, messenger)
        AppManager(applicationContext, messenger)
        LocationService(applicationContext, messenger)
        MediaManager(applicationContext, messenger)
        NotificationBridge(applicationContext, messenger)
        BluetoothBridge(applicationContext, messenger)
        DeviceDiagnostics(applicationContext, messenger)
        DeviceStatusBridge(applicationContext, messenger)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // HOME pressed while SwiftDrive is already running: return to the dashboard.
        if (intent.hasCategory(Intent.CATEGORY_HOME)) launcher?.notifyHomePressed()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (launcher?.onActivityResult(requestCode, resultCode, data) != true) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (launcher?.onRequestPermissionsResult(requestCode, grantResults) != true) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }
}

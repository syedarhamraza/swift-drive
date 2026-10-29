package com.swiftdrive.launcher.platform

import android.content.ActivityNotFoundException
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Error codes mirrored by `PlatformFailure.kindForCode` on the Dart side. */
object Codes {
    const val PERMISSION_DENIED = "PERMISSION_DENIED"
    const val UNSUPPORTED = "UNSUPPORTED"
    const val SERVICE_UNAVAILABLE = "SERVICE_UNAVAILABLE"
    const val ACTIVITY_NOT_FOUND = "ACTIVITY_NOT_FOUND"
    const val SECURITY = "SECURITY"
    const val INTERNAL = "INTERNAL"
}

class ChannelException(val code: String, message: String) : Exception(message)

object Background {
    val executor: ExecutorService = Executors.newSingleThreadExecutor()
    val main = Handler(Looper.getMainLooper())
}

private fun MethodChannel.Result.fail(tag: String, e: Throwable) {
    Log.w("SwiftDrive/$tag", "channel call failed", e)
    when (e) {
        is ChannelException -> error(e.code, e.message, null)
        is ActivityNotFoundException -> error(Codes.ACTIVITY_NOT_FOUND, e.message, null)
        is SecurityException -> error(Codes.SECURITY, e.message, null)
        is UnsupportedOperationException -> error(Codes.UNSUPPORTED, e.message, null)
        else -> error(Codes.INTERNAL, e.message ?: e.javaClass.simpleName, null)
    }
}

/** Runs [block] on the calling (main) thread and never lets an exception escape into the engine. */
fun MethodChannel.Result.guard(tag: String, block: () -> Any?) {
    try {
        success(block())
    } catch (e: Throwable) {
        fail(tag, e)
    }
}

/** Runs [block] on the background executor and replies on the main thread. */
fun MethodChannel.Result.guardAsync(tag: String, block: () -> Any?) {
    Background.executor.execute {
        val outcome = runCatching(block)
        Background.main.post {
            outcome.fold({ success(it) }, { fail(tag, it) })
        }
    }
}

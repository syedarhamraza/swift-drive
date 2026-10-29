package com.swiftdrive.launcher.platform

import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.SystemClock
import com.swiftdrive.launcher.services.LauncherNotificationListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Observes other apps' public media sessions. Callback-driven: no polling. Playback position is sent
 * with its timestamp so Flutter can extrapolate progress locally. The launcher never takes audio focus.
 */
class MediaManager(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val msm = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager?
    private val component = ComponentName(context, LauncherNotificationListener::class.java)
    private val controllers = LinkedHashMap<String, Pair<MediaController, MediaController.Callback>>()
    private val sentArt = HashMap<String, String>() // session id -> art key last sent
    private var sink: EventChannel.EventSink? = null
    private val emitRunnable = Runnable { emit() }

    private val sessionsListener = MediaSessionManager.OnActiveSessionsChangedListener { list -> sync(list.orEmpty()) }

    init {
        MethodChannel(messenger, "swiftdrive/media").setMethodCallHandler(this)
        EventChannel(messenger, "swiftdrive/media/events").setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasAccess" -> result.guard("media") { LauncherNotificationListener.isEnabled(context) }
            "refresh" -> result.guard("media") { detach(); attach(); true }
            "command" -> result.guard("media") {
                val controller = controllers[call.argument<String>("id")!!]?.first
                    ?: throw ChannelException(Codes.SERVICE_UNAVAILABLE, "session ended")
                val controls = controller.transportControls
                when (call.argument<String>("action")) {
                    "play" -> controls.play()
                    "pause" -> controls.pause()
                    "next" -> controls.skipToNext()
                    "previous" -> controls.skipToPrevious()
                    "seekTo" -> controls.seekTo((call.argument<Number>("position")!!).toLong())
                    else -> throw ChannelException(Codes.UNSUPPORTED, "unknown action")
                }
                true
            }
            else -> result.notImplemented()
        }
    }

    private fun idOf(c: MediaController) = "${c.packageName}:${c.sessionToken.hashCode()}"

    private fun attach() {
        val manager = msm
        if (manager == null || !LauncherNotificationListener.isEnabled(context)) return emitNoAccess()
        try {
            manager.addOnActiveSessionsChangedListener(sessionsListener, component, Background.main)
            sync(manager.getActiveSessions(component))
        } catch (e: SecurityException) {
            emitNoAccess()
        }
    }

    private fun detach() {
        runCatching { msm?.removeOnActiveSessionsChangedListener(sessionsListener) }
        controllers.values.forEach { (c, cb) -> c.unregisterCallback(cb) }
        controllers.clear()
        sentArt.clear()
    }

    private fun sync(list: List<MediaController>) {
        val incoming = list.associateBy(::idOf)
        (controllers.keys - incoming.keys).forEach { id ->
            controllers.remove(id)?.let { (c, cb) -> c.unregisterCallback(cb) }
            sentArt.remove(id)
        }
        incoming.forEach { (id, c) ->
            if (id in controllers) return@forEach
            val cb = object : MediaController.Callback() {
                override fun onPlaybackStateChanged(state: PlaybackState?) = scheduleEmit()
                override fun onMetadataChanged(metadata: MediaMetadata?) = scheduleEmit()
                override fun onSessionDestroyed() = scheduleEmit()
            }
            c.registerCallback(cb, Background.main)
            controllers[id] = c to cb
        }
        scheduleEmit()
    }

    // Metadata and state usually change together; coalesce them into one event.
    private fun scheduleEmit() {
        Background.main.removeCallbacks(emitRunnable)
        Background.main.postDelayed(emitRunnable, 80)
    }

    private fun emitNoAccess() {
        sink?.success(mapOf("access" to false, "sessions" to emptyList<Any>()))
    }

    private fun emit() {
        val out = sink ?: return
        val sessions = controllers.map { (id, pair) ->
            val c = pair.first
            val state = c.playbackState
            val meta = c.metadata
            val art = meta?.let { it.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART) ?: it.getBitmap(MediaMetadata.METADATA_KEY_ART) }
            val title = meta?.getString(MediaMetadata.METADATA_KEY_TITLE)
                ?: meta?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
            val album = meta?.getString(MediaMetadata.METADATA_KEY_ALBUM)
            val artKey = art?.let { "$title|$album|${it.width}x${it.height}" }
            val sendArt = artKey != null && sentArt[id] != artKey
            if (sendArt) sentArt[id] = artKey!!
            mapOf(
                "id" to id,
                "packageName" to c.packageName,
                "appLabel" to LauncherNotificationListener.appLabel(context, c.packageName),
                "state" to (state?.state ?: PlaybackState.STATE_NONE),
                "position" to (state?.position ?: 0L),
                "updateTime" to (state?.lastPositionUpdateTime ?: 0L),
                "speed" to (state?.playbackSpeed?.toDouble() ?: 0.0),
                "actions" to (state?.actions ?: 0L),
                "title" to title,
                "artist" to (meta?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: meta?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)),
                "album" to album,
                "duration" to (meta?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L),
                "artKey" to artKey,
                "art" to if (sendArt) encodeArt(art!!) else null,
            )
        }
        out.success(mapOf("access" to true, "now" to SystemClock.elapsedRealtime(), "sessions" to sessions))
    }

    private fun encodeArt(bitmap: Bitmap): ByteArray? = runCatching {
        val max = 256
        val scale = minOf(1f, max.toFloat() / maxOf(bitmap.width, bitmap.height))
        val scaled = if (scale < 1f) {
            Bitmap.createScaledBitmap(bitmap, (bitmap.width * scale).toInt(), (bitmap.height * scale).toInt(), true)
        } else {
            bitmap
        }
        ByteArrayOutputStream().use { out ->
            scaled.compress(Bitmap.CompressFormat.JPEG, 85, out)
            if (scaled !== bitmap) scaled.recycle()
            out.toByteArray()
        }
    }.getOrNull()

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        attach()
    }

    override fun onCancel(arguments: Any?) {
        detach()
        Background.main.removeCallbacks(emitRunnable)
        sink = null
    }
}

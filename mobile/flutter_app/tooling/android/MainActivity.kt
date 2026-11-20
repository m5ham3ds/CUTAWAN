package com.m5ham3ds.cutawan_mobile

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "com.cutawan.mobile/media"
    private val openVideoRequestCode = 4102
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickVideo" -> openVideoPicker(result)
                    "inspectVideo" -> {
                        val rawUri = call.argument<String>("uri")
                        if (rawUri.isNullOrBlank()) {
                            result.error("INVALID_URI", "A video URI is required.", null)
                        } else {
                            inspectVideo(rawUri, result, requirePersistedGrant = true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun openVideoPicker(result: MethodChannel.Result) {
        if (pendingPickerResult != null) {
            result.error("PICKER_BUSY", "A video selection is already in progress.", null)
            return
        }

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "video/*"
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }

        pendingPickerResult = result
        try {
            startActivityForResult(intent, openVideoRequestCode)
        } catch (error: ActivityNotFoundException) {
            pendingPickerResult = null
            result.error("PICKER_UNAVAILABLE", "No document picker is available.", error.message)
        }
    }

    @Deprecated("Uses the Activity result contract to support the existing FlutterActivity template.")
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != openVideoRequestCode) return

        val reply = pendingPickerResult ?: return
        pendingPickerResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            reply.success(null)
            return
        }

        val uri = data.data!!
        try {
            val readFlag = data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
            if (readFlag == 0) {
                throw SecurityException("The document provider did not grant read access.")
            }
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
            val persisted = contentResolver.persistedUriPermissions.any {
                it.uri == uri && it.isReadPermission
            }
            if (!persisted) {
                throw SecurityException("Android did not persist access to the selected video.")
            }
        } catch (error: SecurityException) {
            reply.error("PERSIST_PERMISSION_FAILED", error.message, uri.toString())
            return
        }

        inspectVideo(uri.toString(), reply, requirePersistedGrant = true)
    }

    private fun inspectVideo(
        rawUri: String,
        reply: MethodChannel.Result,
        requirePersistedGrant: Boolean
    ) {
        ioExecutor.execute {
            try {
                val uri = Uri.parse(rawUri)
                if (requirePersistedGrant) {
                    val hasGrant = contentResolver.persistedUriPermissions.any {
                        it.uri == uri && it.isReadPermission
                    }
                    if (!hasGrant) {
                        throw SecurityException("No persistent read permission exists for this video.")
                    }
                }
                val metadata = readVideoMetadata(uri)
                mainHandler.post { reply.success(metadata) }
            } catch (error: Exception) {
                mainHandler.post {
                    reply.error(
                        "VIDEO_METADATA_FAILED",
                        error.message ?: "Could not inspect the selected video.",
                        rawUri
                    )
                }
            }
        }
    }

    private fun readVideoMetadata(uri: Uri): Map<String, Any> {
        var displayName = uri.lastPathSegment ?: "video"
        var sizeBytes = 0L
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0) displayName = cursor.getString(nameIndex) ?: displayName
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                        sizeBytes = cursor.getLong(sizeIndex).coerceAtLeast(0L)
                    }
                }
            }

        val retriever = MediaMetadataRetriever()
        val durationMs: Long
        val width: Int
        val height: Int
        val rotation: Int
        try {
            retriever.setDataSource(this, uri)
            durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
            width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                ?.toIntOrNull() ?: 0
            height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                ?.toIntOrNull() ?: 0
            rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
        } finally {
            retriever.release()
        }

        if (durationMs <= 0 || width <= 0 || height <= 0) {
            throw IllegalArgumentException("The selected file has no readable video stream or metadata.")
        }
        if (sizeBytes <= 0L) {
            // Some cloud providers omit OpenableColumns.SIZE; the URI remains streamable.
            sizeBytes = 0L
        }

        return mapOf(
            "uri" to uri.toString(),
            "displayName" to displayName,
            "mimeType" to (contentResolver.getType(uri) ?: "video/*"),
            "sizeBytes" to sizeBytes,
            "durationMs" to durationMs,
            "width" to width,
            "height" to height,
            "rotationDegrees" to rotation,
            "importedAtUtc" to utcNowIso()
        )
    }

    private fun utcNowIso(): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(Date())
    }

    override fun onDestroy() {
        pendingPickerResult = null
        ioExecutor.shutdown()
        super.onDestroy()
    }
}

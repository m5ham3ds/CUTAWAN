package com.m5ham3ds.cutawan_mobile

import android.content.ContentValues
import android.content.ClipData
import android.os.Build
import android.os.BatteryManager
import android.os.Debug
import android.os.PowerManager
import android.os.Environment
import android.provider.MediaStore
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.CanvasOverlay
import androidx.media3.effect.MatrixTransformation
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Effects
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import java.io.FileInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.security.MessageDigest
import android.app.Activity
import android.app.ActivityManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.text.Layout
import android.text.SpannableString
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import android.text.style.ForegroundColorSpan
import android.graphics.PointF
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.FaceDetector
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.os.SystemClock
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.max
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkInfo
import androidx.work.WorkManager
import java.util.UUID
import java.util.concurrent.TimeUnit

@OptIn(UnstableApi::class)
class MainActivity : FlutterActivity() {
    private val channelName = "com.cutawan.mobile/media"
    private val openVideoRequestCode = 4102
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingPickerResult: MethodChannel.Result? = null
    private data class ReframeSegment(
        val startMs: Long,
        val endMs: Long,
        val mode: String,
        val x: Float = 0f,
        val y: Float = 0f,
        val width: Float = 1f,
        val height: Float = 1f
    )
    private data class CaptionWordCue(
        val text: String,
        val startMs: Long,
        val endMs: Long,
        val startOffset: Int,
        val endOffset: Int
    )

    private data class TimedCaptionCue(
        val startMs: Long,
        val endMs: Long,
        val text: String,
        val words: List<CaptionWordCue>
    )

    private data class CaptionRenderStyle(
        val fontFamily: String,
        val fontScale: Float,
        val uppercase: Boolean,
        val textColor: Int,
        val highlightColor: Int,
        val highlightBoxColor: Int?,
        val outlineColor: Int,
        val outlineWidth: Float,
        val shadow: Float,
        val bold: Boolean,
        val positionY: Float
    )


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickVideo" -> openVideoPicker(result)
                    "getAvailableStorageBytes" -> {
                        result.success(StatFs(filesDir.absolutePath).availableBytes)
                    }
                    "releasePersistedPermission" -> {
                        val rawUri = call.argument<String>("uri")
                        if (rawUri.isNullOrBlank()) {
                            result.error("INVALID_URI", "A content URI is required.", null)
                        } else {
                            try {
                                val uri = Uri.parse(rawUri)
                                if (uri.scheme != "content") {
                                    throw IllegalArgumentException("Only content URIs have SAF permissions.")
                                }
                                val hasGrant = contentResolver.persistedUriPermissions.any {
                                    it.uri == uri && it.isReadPermission
                                }
                                if (hasGrant) {
                                    contentResolver.releasePersistableUriPermission(
                                        uri,
                                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                                    )
                                }
                                result.success(null)
                            } catch (error: Exception) {
                                result.error("RELEASE_PERMISSION_FAILED", error.message, rawUri)
                            }
                        }
                    }
                    "inspectVideo" -> {
                        val rawUri = call.argument<String>("uri")
                        if (rawUri.isNullOrBlank()) {
                            result.error("INVALID_URI", "A video URI is required.", null)
                        } else {
                            inspectVideo(rawUri, result, requirePersistedGrant = true)
                        }
                    }
                    "extractAudio" -> {
                        val rawUri = call.argument<String>("uri")
                        if (rawUri.isNullOrBlank()) {
                            result.error("INVALID_URI", "A video URI is required.", null)
                        } else {
                            extractAudio(rawUri, result)
                        }
                    }
                    "createFilmstrip" -> {
                        val rawUri = call.argument<String>("uri")
                        val startMs = call.argument<Number>("startMs")?.toLong()
                        val endMs = call.argument<Number>("endMs")?.toLong()
                        val sampleCount = call.argument<Number>("sampleCount")?.toInt() ?: 7
                        if (rawUri.isNullOrBlank() || startMs == null || endMs == null) {
                            result.error("INVALID_FILMSTRIP", "A source URI and trim range are required.", null)
                        } else if (startMs < 0L || endMs <= startMs || sampleCount !in 3..10) {
                            result.error("INVALID_FILMSTRIP", "The requested filmstrip range or sample count is invalid.", null)
                        } else {
                            createFilmstrip(rawUri, startMs, endMs, sampleCount, result)
                        }
                    }
                    "analyzeFaces" -> {
                        val rawUri = call.argument<String>("uri")
                        if (rawUri.isNullOrBlank()) {
                            result.error("INVALID_URI", "A video URI is required.", null)
                        } else {
                            analyzeFaces(rawUri, result)
                        }
                    }
                    "fingerprintVideo" -> {
                        val rawUri = call.argument<String>("uri")
                        if (rawUri.isNullOrBlank()) {
                            result.error("INVALID_URI", "A video URI is required.", null)
                        } else {
                            fingerprintVideo(rawUri, result)
                        }
                    }
                    "startRender" -> startRender(call, result)
                    "getRenderProgress" -> getRenderProgress(call, result)
                    "cancelRender" -> cancelBackgroundRender(call, result)
                    "cancelBackgroundRenderForProject" -> cancelBackgroundRenderForProject(call, result)
                    "releaseRender" -> result.success(null)
                    "getCompletedRender" -> getCompletedRender(call, result)
                    "acknowledgeCompletedRender" -> acknowledgeCompletedRender(call, result)
                    "hasActiveBackgroundRender" -> hasActiveBackgroundRender(call, result)
                    "getDeviceAcceptanceDiagnostics" -> {
                        try {
                            result.success(readDeviceAcceptanceDiagnostics())
                        } catch (error: Exception) {
                            result.error(
                                "DEVICE_DIAGNOSTICS_FAILED",
                                error.message ?: "Could not collect Android device diagnostics.",
                                null
                            )
                        }
                    }
                    "openExport" -> openExport(call, result)
                    "shareExport" -> shareExport(call, result)
                    "deleteExport" -> deleteExport(call, result)
                    "verifyExport" -> verifyExport(call, result)
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
        val hadPersistedReadGrant = contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission
        }
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
        } catch (error: Exception) {
            if (!hadPersistedReadGrant) {
                try {
                    contentResolver.releasePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                } catch (_: Exception) { }
            }
            reply.error("PERSIST_PERMISSION_FAILED", error.message, uri.toString())
            return
        }

        inspectVideo(
            uri.toString(),
            reply,
            requirePersistedGrant = true,
            releaseGrantOnFailure = !hadPersistedReadGrant
        )
    }

    private fun inspectVideo(
        rawUri: String,
        reply: MethodChannel.Result,
        requirePersistedGrant: Boolean,
        releaseGrantOnFailure: Boolean = false
    ) {
        ioExecutor.execute {
            try {
                val uri = Uri.parse(rawUri)
                when (uri.scheme) {
                    "content" -> if (requirePersistedGrant) {
                        val hasGrant = contentResolver.persistedUriPermissions.any {
                            it.uri == uri && it.isReadPermission
                        }
                        if (!hasGrant) {
                            throw SecurityException("No persistent read permission exists for this video.")
                        }
                    }
                    "file" -> {
                        val selectedFile = java.io.File(uri.path ?: throw IllegalArgumentException("File URI has no path."))
                        val canonicalPath = selectedFile.canonicalPath
                        val filesRoot = java.io.File(filesDir, "app_flutter").canonicalPath
                        val filesBase = filesDir.canonicalPath
                        val cacheBase = cacheDir.canonicalPath
                        val allowed = canonicalPath.startsWith(filesRoot + java.io.File.separator) ||
                            canonicalPath.startsWith(filesBase + java.io.File.separator) ||
                            canonicalPath.startsWith(cacheBase + java.io.File.separator)
                        if (!selectedFile.isFile || !allowed) {
                            throw SecurityException("Local video is outside Cutawan's private storage.")
                        }
                    }
                    else -> throw IllegalArgumentException("Unsupported video URI scheme.")
                }
                val metadata = readVideoMetadata(uri)
                mainHandler.post { reply.success(metadata) }
            } catch (error: Exception) {
                if (releaseGrantOnFailure) {
                    try {
                        val failedUri = Uri.parse(rawUri)
                        if (failedUri.scheme == "content") {
                            val hasGrant = contentResolver.persistedUriPermissions.any {
                                it.uri == failedUri && it.isReadPermission
                            }
                            if (hasGrant) {
                                contentResolver.releasePersistableUriPermission(
                                    failedUri,
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                                )
                            }
                        }
                    } catch (_: Exception) { }
                }
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
        val localFile = if (uri.scheme == "file") java.io.File(uri.path!!) else null
        if (localFile != null) {
            displayName = localFile.name
            sizeBytes = localFile.length().coerceAtLeast(0L)
        } else {
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
        }

        val retriever = MediaMetadataRetriever()
        val durationMs: Long
        val width: Int
        val height: Int
        val rotation: Int
        try {
            if (localFile != null) {
                retriever.setDataSource(localFile.absolutePath)
            } else {
                retriever.setDataSource(this, uri)
            }
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



    /**
     * Decode the selected source's first audio track to WAV. SAF permission
     * checks are repeated here because this is a separate long-running call.
     */
    private fun extractAudio(rawUri: String, reply: MethodChannel.Result) {
        ioExecutor.execute {
            var cleanupOutput: File? = null
            var cleanupPartial: File? = null
            var cleanupWriter: RandomAccessFile? = null
            var cleanupDecoder: MediaCodec? = null
            val extractor = MediaExtractor()
            try {
                val uri = Uri.parse(rawUri)
                when (uri.scheme) {
                    "content" -> {
                        val hasGrant = contentResolver.persistedUriPermissions.any {
                            it.uri == uri && it.isReadPermission
                        }
                        if (!hasGrant) {
                            throw SecurityException(
                                "No persistent read permission exists for this video."
                            )
                        }
                        extractor.setDataSource(this, uri, null)
                    }
                    "file" -> {
                        val selectedFile = File(
                            uri.path ?: throw IllegalArgumentException("File URI has no path.")
                        )
                        val canonicalPath = selectedFile.canonicalPath
                        val filesRoot = File(filesDir, "app_flutter").canonicalPath
                        val filesBase = filesDir.canonicalPath
                        val cacheBase = cacheDir.canonicalPath
                        val allowed =
                            canonicalPath.startsWith(filesRoot + File.separator) ||
                            canonicalPath.startsWith(filesBase + File.separator) ||
                            canonicalPath.startsWith(cacheBase + File.separator)
                        if (!selectedFile.isFile || !allowed) {
                            throw SecurityException(
                                "Local video is outside Cutawan's private storage."
                            )
                        }
                        extractor.setDataSource(selectedFile.absolutePath)
                    }
                    else -> throw IllegalArgumentException("Unsupported video URI scheme.")
                }

                var audioTrack = -1
                var inputFormat: MediaFormat? = null
                for (index in 0 until extractor.trackCount) {
                    val candidate = extractor.getTrackFormat(index)
                    val mime = candidate.getString(MediaFormat.KEY_MIME) ?: continue
                    if (mime.startsWith("audio/")) {
                        audioTrack = index
                        inputFormat = candidate
                        break
                    }
                }
                if (audioTrack < 0 || inputFormat == null) {
                    throw IllegalArgumentException(
                        "The selected video has no readable audio track."
                    )
                }

                val inputMime = inputFormat.getString(MediaFormat.KEY_MIME)
                    ?: throw IllegalArgumentException("Audio codec MIME type is missing.")
                extractor.selectTrack(audioTrack)
                val codec = MediaCodec.createDecoderByType(inputMime)
                cleanupDecoder = codec
                codec.configure(inputFormat, null, null, 0)
                codec.start()

                val outputDirectory = File(cacheDir, "cutawan_audio").apply {
                    if (!exists() && !mkdirs()) {
                        throw IllegalStateException("Could not create the audio cache directory.")
                    }
                    // Do not delete WAV files that may still be read by
                    // an active Whisper session. Each extraction has a unique
                    // name; only clean crash leftovers older than 24 hours.
                    val staleBeforeMillis =
                        System.currentTimeMillis() - 24L * 60L * 60L * 1000L
                    listFiles()?.forEach { stale ->
                        if (stale.isFile &&
                            (stale.name.endsWith(".wav") ||
                                stale.name.endsWith(".wav.part")) &&
                            (stale.lastModified() <= 0L ||
                                stale.lastModified() < staleBeforeMillis)
                        ) {
                            stale.delete()
                        }
                    }
                }
                val partialFile = File(
                    outputDirectory,
                    "audio_" + System.nanoTime() + ".wav.part"
                )
                val finalFile = File(
                    outputDirectory,
                    partialFile.name.removeSuffix(".part")
                )
                cleanupPartial = partialFile
                cleanupOutput = finalFile
                val writer = RandomAccessFile(partialFile, "rw")
                cleanupWriter = writer
                writer.setLength(0)
                writer.write(ByteArray(44))

                var sampleRate = inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                var channels = inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                var pcmEncoding = AudioFormat.ENCODING_PCM_16BIT
                var inputEnded = false
                var outputEnded = false
                var pcmBytesWritten = 0L
                val deadline = SystemClock.elapsedRealtime() + 6L * 60L * 60L * 1000L
                val info = MediaCodec.BufferInfo()

                while (!outputEnded) {
                    if (SystemClock.elapsedRealtime() > deadline) {
                        throw IllegalStateException(
                            "Audio extraction exceeded the six-hour safety limit."
                        )
                    }

                    if (!inputEnded) {
                        val inputIndex = codec.dequeueInputBuffer(10_000)
                        if (inputIndex >= 0) {
                            val inputBuffer = codec.getInputBuffer(inputIndex)
                                ?: throw IllegalStateException(
                                    "Audio decoder input buffer is unavailable."
                                )
                            val sampleSize = extractor.readSampleData(inputBuffer, 0)
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(
                                    inputIndex,
                                    0,
                                    0,
                                    0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                )
                                inputEnded = true
                            } else {
                                codec.queueInputBuffer(
                                    inputIndex,
                                    0,
                                    sampleSize,
                                    extractor.sampleTime.coerceAtLeast(0),
                                    extractor.sampleFlags
                                )
                                extractor.advance()
                            }
                        }
                    }

                    when (val outputIndex = codec.dequeueOutputBuffer(info, 10_000)) {
                        MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            val outputFormat = codec.outputFormat
                            sampleRate = outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                            channels = outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                            if (outputFormat.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                                pcmEncoding =
                                    outputFormat.getInteger(MediaFormat.KEY_PCM_ENCODING)
                            }
                        }
                        MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                        else -> if (outputIndex >= 0) {
                            if (info.size > 0) {
                                val outputBuffer = codec.getOutputBuffer(outputIndex)
                                    ?: throw IllegalStateException(
                                        "Audio decoder output buffer is unavailable."
                                    )
                                val pcm = outputBuffer.duplicate()
                                    .order(ByteOrder.LITTLE_ENDIAN)
                                pcm.position(info.offset)
                                pcm.limit(info.offset + info.size)

                                val bytesWritten = when (pcmEncoding) {
                                    AudioFormat.ENCODING_PCM_16BIT -> {
                                        val bytes = ByteArray(pcm.remaining())
                                        pcm.get(bytes)
                                        writer.write(bytes)
                                        bytes.size.toLong()
                                    }
                                    AudioFormat.ENCODING_PCM_FLOAT -> {
                                        val samples = pcm.remaining() / 4
                                        val bytes = ByteArray(samples * 2)
                                        val target = ByteBuffer.wrap(bytes)
                                            .order(ByteOrder.LITTLE_ENDIAN)
                                        repeat(samples) {
                                            val value = pcm.float.coerceIn(-1.0f, 1.0f)
                                            val converted = (value * 32767.0f).toInt()
                                                .coerceIn(
                                                    Short.MIN_VALUE.toInt(),
                                                    Short.MAX_VALUE.toInt()
                                                )
                                            target.putShort(converted.toShort())
                                        }
                                        writer.write(bytes)
                                        bytes.size.toLong()
                                    }
                                    AudioFormat.ENCODING_PCM_8BIT -> {
                                        val bytes = ByteArray(pcm.remaining() * 2)
                                        val target = ByteBuffer.wrap(bytes)
                                            .order(ByteOrder.LITTLE_ENDIAN)
                                        while (pcm.hasRemaining()) {
                                            val signed = (pcm.get().toInt() and 0xff) - 128
                                            target.putShort((signed shl 8).toShort())
                                        }
                                        writer.write(bytes)
                                        bytes.size.toLong()
                                    }
                                    else -> throw IllegalArgumentException(
                                        "Unsupported decoded PCM encoding: " + pcmEncoding
                                    )
                                }
                                pcmBytesWritten += bytesWritten
                                if (pcmBytesWritten > 0xffffffffL - 44L) {
                                    throw IllegalArgumentException(
                                        "Decoded audio is too large for a WAV file."
                                    )
                                }
                            }
                            outputEnded =
                                (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                            codec.releaseOutputBuffer(outputIndex, false)
                        }
                    }
                }

                if (sampleRate !in 8_000..192_000 ||
                    channels !in 1..8 ||
                    pcmBytesWritten < 2L
                ) {
                    throw IllegalArgumentException(
                        "Decoded audio format or duration is invalid."
                    )
                }
                writeWavHeader(writer, pcmBytesWritten, sampleRate, channels)
                writer.fd.sync()
                writer.close()
                cleanupWriter = null
                if (!partialFile.renameTo(finalFile)) {
                    throw IllegalStateException(
                        "Could not finalize the extracted WAV file."
                    )
                }
                cleanupPartial = null

                val visualSamples = sampleVisualChanges(uri)
                val response = mapOf(
                    "path" to finalFile.absolutePath,
                    "sampleRate" to sampleRate,
                    "channels" to channels,
                    "pcmBytes" to pcmBytesWritten,
                    "visualSamples" to visualSamples
                )
                mainHandler.post { reply.success(response) }
            } catch (error: Exception) {
                try { cleanupWriter?.close() } catch (_: Exception) { }
                try { cleanupPartial?.delete() } catch (_: Exception) { }
                try { cleanupOutput?.delete() } catch (_: Exception) { }
                mainHandler.post {
                    reply.error(
                        "AUDIO_EXTRACTION_FAILED",
                        error.message ?: "Could not decode source audio.",
                        rawUri
                    )
                }
            } finally {
                try { cleanupDecoder?.stop() } catch (_: Exception) { }
                try { cleanupDecoder?.release() } catch (_: Exception) { }
                try { extractor.release() } catch (_: Exception) { }
            }
        }
    }

    private fun writeWavHeader(
        output: RandomAccessFile,
        dataBytes: Long,
        sampleRate: Int,
        channels: Int
    ) {
        val bitsPerSample = 16
        val blockAlign = channels * bitsPerSample / 8
        val byteRate = sampleRate * blockAlign
        output.seek(0)
        output.writeBytes("RIFF")
        writeLe32(output, (36L + dataBytes).toInt())
        output.writeBytes("WAVE")
        output.writeBytes("fmt ")
        writeLe32(output, 16)
        writeLe16(output, 1)
        writeLe16(output, channels)
        writeLe32(output, sampleRate)
        writeLe32(output, byteRate)
        writeLe16(output, blockAlign)
        writeLe16(output, bitsPerSample)
        output.writeBytes("data")
        writeLe32(output, dataBytes.toInt())
    }

    private fun writeLe16(output: RandomAccessFile, value: Int) {
        output.write(value and 0xff)
        output.write((value ushr 8) and 0xff)
    }

    private fun writeLe32(output: RandomAccessFile, value: Int) {
        output.write(value and 0xff)
        output.write((value ushr 8) and 0xff)
        output.write((value ushr 16) and 0xff)
        output.write((value ushr 24) and 0xff)
    }

    /**
     * Compare low-resolution frames at a bounded sampling rate. This is scene
     * change evidence only, not semantic vision, face detection, or diarization.
     */
    /**
     * Bounded frontal-face sampling for conservative mobile reframing.
     * This is a focus-track signal, not an audiovisual active-speaker model.
     */
    private fun createFilmstrip(
        rawUri: String,
        startMs: Long,
        endMs: Long,
        sampleCount: Int,
        reply: MethodChannel.Result
    ) {
        ioExecutor.execute {
            val retriever = MediaMetadataRetriever()
            try {
                val uri = Uri.parse(rawUri)
                when (uri.scheme) {
                    "content" -> {
                        val hasGrant = contentResolver.persistedUriPermissions.any {
                            it.uri == uri && it.isReadPermission
                        }
                        if (!hasGrant) {
                            throw SecurityException("The video read permission is no longer available.")
                        }
                        retriever.setDataSource(this, uri)
                    }
                    "file" -> {
                        val selectedFile = File(uri.path ?: throw IllegalArgumentException("File URI has no path."))
                        val canonicalPath = selectedFile.canonicalPath
                        val filesRoot = File(filesDir, "app_flutter").canonicalPath
                        val filesBase = filesDir.canonicalPath
                        val cacheBase = cacheDir.canonicalPath
                        val allowed = canonicalPath.startsWith(filesRoot + File.separator) ||
                            canonicalPath.startsWith(filesBase + File.separator) ||
                            canonicalPath.startsWith(cacheBase + File.separator)
                        if (!selectedFile.isFile || !allowed) {
                            throw SecurityException("Local video is outside Cutawan's private storage.")
                        }
                        retriever.setDataSource(selectedFile.absolutePath)
                    }
                    "http", "https" -> retriever.setDataSource(rawUri, emptyMap())
                    else -> throw IllegalArgumentException("Unsupported filmstrip source URI scheme.")
                }

                val durationMs = retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_DURATION
                )?.toLongOrNull() ?: 0L
                if (durationMs <= 0L || startMs >= durationMs || endMs > durationMs) {
                    throw IllegalArgumentException("The filmstrip trim range is outside the source duration.")
                }

                val frames = mutableListOf<Map<String, Any>>()
                for (index in 0 until sampleCount) {
                    val timestampMs = startMs +
                        ((endMs - startMs - 1L) * index / (sampleCount - 1).toLong())
                    val sourceFrame = retriever.getFrameAtTime(
                        timestampMs * 1000L,
                        MediaMetadataRetriever.OPTION_CLOSEST
                    ) ?: continue

                    try {
                        val scale = minOf(
                            1.0,
                            240.0 / sourceFrame.width.toDouble(),
                            240.0 / sourceFrame.height.toDouble()
                        )
                        val width = max(1, (sourceFrame.width * scale).toInt())
                        val height = max(1, (sourceFrame.height * scale).toInt())
                        val previewFrame = if (
                            width == sourceFrame.width && height == sourceFrame.height
                        ) {
                            sourceFrame
                        } else {
                            Bitmap.createScaledBitmap(sourceFrame, width, height, true)
                        }

                        try {
                            val output = ByteArrayOutputStream()
                            if (!previewFrame.compress(Bitmap.CompressFormat.JPEG, 68, output)) {
                                throw IllegalStateException("Could not encode a filmstrip thumbnail.")
                            }
                            val bytes = output.toByteArray()
                            if (bytes.isEmpty() || bytes.size > 1024 * 1024) {
                                throw IllegalStateException("A filmstrip thumbnail exceeded its size limit.")
                            }
                            frames.add(
                                mapOf(
                                    "timestampMs" to timestampMs,
                                    "imageBytes" to bytes,
                                    "width" to width,
                                    "height" to height
                                )
                            )
                        } finally {
                            if (previewFrame !== sourceFrame && !previewFrame.isRecycled) {
                                previewFrame.recycle()
                            }
                        }
                    } finally {
                        if (!sourceFrame.isRecycled) sourceFrame.recycle()
                    }
                }

                if (frames.isEmpty()) {
                    throw IllegalStateException("Android could not decode any frame in the selected trim range.")
                }
                mainHandler.post { reply.success(frames) }
            } catch (error: Exception) {
                mainHandler.post {
                    reply.error(
                        "FILMSTRIP_EXTRACTION_FAILED",
                        error.message ?: "Android filmstrip extraction failed.",
                        rawUri
                    )
                }
            } finally {
                try { retriever.release() } catch (_: Exception) { }
            }
        }
    }

    private fun analyzeFaces(rawUri: String, reply: MethodChannel.Result) {
        ioExecutor.execute {
            val retriever = MediaMetadataRetriever()
            try {
                val uri = Uri.parse(rawUri)
                when (uri.scheme) {
                    "content" -> {
                        val hasGrant = contentResolver.persistedUriPermissions.any {
                            it.uri == uri && it.isReadPermission
                        }
                        if (!hasGrant) {
                            throw SecurityException("The video read permission is no longer available.")
                        }
                        retriever.setDataSource(this, uri)
                    }
                    "file" -> {
                        if (!uri.authority.isNullOrEmpty() || uri.path.isNullOrBlank() || !uri.path!!.startsWith("/")) {
                            throw IllegalArgumentException("Only app-private absolute file URIs are supported.")
                        }
                        retriever.setDataSource(File(uri.path!!).absolutePath)
                    }
                    else -> throw IllegalArgumentException("Only persisted content:// and app-private file:// URIs are supported.")
                }

                val durationMs = retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_DURATION
                )?.toLongOrNull() ?: 0L
                if (durationMs <= 0L) {
                    throw IllegalArgumentException("The video duration could not be read.")
                }

                val sampleCountLimit = 160
                val stepMs = max(500L, (durationMs / sampleCountLimit).coerceAtLeast(1L))
                val samples = mutableListOf<Map<String, Any?>>()
                var previousCenterX: Float? = null
                var timestampMs = 0L

                while (timestampMs < durationMs && samples.size < sampleCountLimit) {
                    var sample: Map<String, Any?> = mapOf(
                        "timestampMs" to timestampMs,
                        "box" to null,
                        "confidence" to 0.0
                    )
                    val frame = try {
                        retriever.getFrameAtTime(
                            timestampMs * 1000L,
                            MediaMetadataRetriever.OPTION_CLOSEST
                        )
                    } catch (_: Exception) {
                        null
                    }

                    if (frame != null) {
                        try {
                            val scale = minOf(
                                320.0 / frame.width.toDouble(),
                                320.0 / frame.height.toDouble()
                            )
                            val sampleWidth = max(64, (frame.width * scale).toInt())
                            val sampleHeight = max(64, (frame.height * scale).toInt())
                            val scaled = Bitmap.createScaledBitmap(
                                frame,
                                sampleWidth,
                                sampleHeight,
                                true
                            )
                            val rgb565 = if (scaled.config == Bitmap.Config.RGB_565) {
                                scaled
                            } else {
                                scaled.copy(Bitmap.Config.RGB_565, false)
                                    ?: throw IllegalStateException("Could not prepare RGB_565 face-analysis frame.")
                            }
                            if (rgb565 !== scaled) scaled.recycle()

                            try {
                                val detector = FaceDetector(rgb565.width, rgb565.height, 6)
                                val detected = arrayOfNulls<FaceDetector.Face>(6)
                                val count = detector.findFaces(rgb565, detected)
                                val candidates = mutableListOf<Map<String, Any>>()
                                for (faceIndex in 0 until count) {
                                    val face = detected[faceIndex] ?: continue
                                    val confidence = face.confidence().toDouble()
                                    val eyesDistance = face.eyesDistance().toDouble()
                                    if (!confidence.isFinite() || confidence < 0.35 ||
                                        !eyesDistance.isFinite() || eyesDistance < 8.0
                                    ) continue

                                    val midpoint = PointF()
                                    face.getMidPoint(midpoint)
                                    val faceWidth = eyesDistance * 3.0
                                    val faceHeight = eyesDistance * 3.6
                                    val left = (midpoint.x - faceWidth / 2.0)
                                        .coerceIn(0.0, rgb565.width - 1.0)
                                    val top = (midpoint.y - eyesDistance * 1.25)
                                        .coerceIn(0.0, rgb565.height - 1.0)
                                    val right = (midpoint.x + faceWidth / 2.0)
                                        .coerceIn(left + 1.0, rgb565.width.toDouble())
                                    val bottom = (top + faceHeight)
                                        .coerceIn(top + 1.0, rgb565.height.toDouble())
                                    val centerX = ((left + right) / 2.0 / rgb565.width)
                                        .coerceIn(0.0, 1.0)
                                    val continuity = previousCenterX?.let {
                                        1.0 - kotlin.math.abs(centerX - it).coerceIn(0.0, 1.0)
                                    } ?: 0.5
                                    val sizeSignal = (eyesDistance / minOf(
                                        rgb565.width.toDouble(),
                                        rgb565.height.toDouble()
                                    ) * 4.0).coerceIn(0.0, 1.0)
                                    val focusScore = (
                                        confidence * 0.80 +
                                            continuity * 0.15 +
                                            sizeSignal * 0.05
                                        ).coerceIn(0.0, 1.0)

                                    candidates.add(
                                        mapOf(
                                            "x" to left / rgb565.width,
                                            "y" to top / rgb565.height,
                                            "width" to (right - left) / rgb565.width,
                                            "height" to (bottom - top) / rgb565.height,
                                            "centerX" to centerX,
                                            "confidence" to focusScore
                                        )
                                    )
                                }

                                val selected = candidates.maxByOrNull {
                                    (it["confidence"] as Number).toDouble()
                                }
                                if (selected != null) {
                                    previousCenterX = (selected["centerX"] as Number).toFloat()
                                    sample = mapOf(
                                        "timestampMs" to timestampMs,
                                        "box" to selected.filterKeys { it != "centerX" },
                                        "confidence" to selected["confidence"]!!
                                    )
                                }
                            } finally {
                                rgb565.recycle()
                                if (scaled !== rgb565 && !scaled.isRecycled) scaled.recycle()
                            }
                        } finally {
                            if (!frame.isRecycled) frame.recycle()
                        }
                    }
                    samples.add(sample)
                    timestampMs += stepMs
                }

                val response = mapOf(
                    "sourceDurationMs" to durationMs,
                    "sampleIntervalMs" to stepMs,
                    "sampleCount" to samples.size,
                    "samples" to samples
                )
                mainHandler.post { reply.success(response) }
            } catch (error: Exception) {
                mainHandler.post {
                    reply.error(
                        "FACE_ANALYSIS_FAILED",
                        error.message ?: "Android face analysis failed.",
                        null
                    )
                }
            } finally {
                try { retriever.release() } catch (_: Exception) { }
            }
        }
    }

    private fun sampleVisualChanges(uri: Uri): List<Map<String, Any>> {
        val retriever = MediaMetadataRetriever()
        val samples = mutableListOf<Map<String, Any>>()
        try {
            if (uri.scheme == "file") {
                retriever.setDataSource(File(uri.path!!).absolutePath)
            } else {
                retriever.setDataSource(this, uri)
            }
            val durationMs = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION
            )?.toLongOrNull() ?: return emptyList()
            if (durationMs <= 0L) return emptyList()

            val stepMs = max(1500L, durationMs / 120L)
            var previous: IntArray? = null
            var timestamp = 0L
            while (timestamp < durationMs && samples.size < 120) {
                val frame = try {
                    retriever.getFrameAtTime(
                        timestamp * 1000L,
                        MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                    )
                } catch (_: Exception) {
                    null
                }
                if (frame != null) {
                    val small = Bitmap.createScaledBitmap(frame, 32, 18, true)
                    if (small !== frame) frame.recycle()
                    val pixels = IntArray(32 * 18)
                    small.getPixels(pixels, 0, 32, 0, 0, 32, 18)
                    small.recycle()
                    val luma = IntArray(pixels.size) { index ->
                        val color = pixels[index]
                        ((77 * ((color shr 16) and 0xff) +
                            150 * ((color shr 8) and 0xff) +
                            29 * (color and 0xff)) shr 8)
                    }
                    val before = previous
                    val score = if (before == null) {
                        0.0
                    } else {
                        var difference = 0L
                        for (index in luma.indices) {
                            difference += abs(luma[index] - before[index])
                        }
                        (difference.toDouble() / (luma.size * 255.0))
                            .coerceIn(0.0, 1.0)
                    }
                    samples.add(
                        mapOf(
                            "timestampMs" to timestamp,
                            "changeScore" to score
                        )
                    )
                    previous = luma
                }
                timestamp += stepMs
            }
        } catch (_: Exception) {
            return emptyList()
        } finally {
            try { retriever.release() } catch (_: Exception) { }
        }
        return samples
    }


    private fun hasPersistedReadGrant(uri: Uri): Boolean =
        contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission
        }

    private fun validateReadableSource(uri: Uri) {
        when (uri.scheme) {
            "content" -> if (!hasPersistedReadGrant(uri)) {
                throw SecurityException("No persistent read permission exists for this video.")
            }
            "file" -> {
                val file = File(uri.path ?: throw IllegalArgumentException("File URI has no path."))
                val canonical = file.canonicalPath
                val filesBase = filesDir.canonicalPath
                val cacheBase = cacheDir.canonicalPath
                val allowed = canonical.startsWith(filesBase + File.separator) ||
                    canonical.startsWith(cacheBase + File.separator)
                if (!file.isFile || !allowed) {
                    throw SecurityException("Local video is outside Cutawan's private storage.")
                }
            }
            else -> throw IllegalArgumentException("Unsupported video URI scheme.")
        }
    }

    private fun openReadableSource(uri: Uri): InputStream {
        validateReadableSource(uri)
        return if (uri.scheme == "content") {
            contentResolver.openInputStream(uri)
                ?: throw IllegalStateException("Could not open the selected video.")
        } else {
            FileInputStream(File(uri.path!!))
        }
    }

    private fun fingerprintVideo(rawUri: String, reply: MethodChannel.Result) {
        ioExecutor.execute {
            try {
                val uri = Uri.parse(rawUri)
                val digest = MessageDigest.getInstance("SHA-256")
                openReadableSource(uri).use { input ->
                    val buffer = ByteArray(1024 * 1024)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        if (count > 0) digest.update(buffer, 0, count)
                    }
                }
                val hex = digest.digest().joinToString("") { "%02x".format(it) }
                mainHandler.post { reply.success(mapOf("sha256" to hex)) }
            } catch (error: Exception) {
                mainHandler.post { reply.error("SOURCE_FINGERPRINT_FAILED", error.message, null) }
            }
        }
    }

    private fun startRender(call: io.flutter.plugin.common.MethodCall, reply: MethodChannel.Result) {
        val rawArguments = call.arguments as? Map<*, *>
        if (rawArguments == null) {
            reply.error("INVALID_RENDER", "Render arguments are missing.", null)
            return
        }
        val request = linkedMapOf<String, Any?>()
        for ((key, value) in rawArguments) {
            val name = key as? String
            if (name == null) {
                reply.error("INVALID_RENDER", "Render argument names must be strings.", null)
                return
            }
            request[name] = value
        }
        val renderKey = request["renderKey"] as? String
        if (renderKey == null || !renderKey.matches(Regex("^[a-f0-9]{64}$"))) {
            reply.error("INVALID_RENDER_KEY", "A SHA-256 render fingerprint is required.", null)
            return
        }
        val projectId = request["projectId"] as? String
        if (projectId.isNullOrBlank() || !projectId.matches(Regex("^[A-Za-z0-9_-]{1,160}$"))) {
            reply.error("INVALID_PROJECT_ID", "A valid project identity is required for background rendering.", null)
            return
        }
        val workManager = WorkManager.getInstance(applicationContext)
        ioExecutor.execute {
            try {
                val completed = NativeRenderStore.readCompletion(applicationContext, renderKey)
                if (completed != null) {
                    val existingId = completed["renderId"] as? String
                        ?: throw IllegalStateException("Completed render has no identity.")
                    mainHandler.post { reply.success(mapOf("renderId" to existingId)) }
                    return@execute
                }

                val uniqueName = NativeRenderStore.uniqueWorkName(renderKey)
                val previousId = NativeRenderStore.readKey(applicationContext, renderKey)
                if (previousId != null) {
                    val previousWork = workManager.getWorkInfoById(UUID.fromString(previousId))
                        .get(20, TimeUnit.SECONDS)
                    if (previousWork != null &&
                        previousWork.state in setOf(
                            WorkInfo.State.RUNNING,
                            WorkInfo.State.ENQUEUED,
                            WorkInfo.State.BLOCKED,
                            WorkInfo.State.SUCCEEDED
                        )
                    ) {
                        mainHandler.post { reply.success(mapOf("renderId" to previousId)) }
                        return@execute
                    }
                    NativeRenderStore.cleanFailedRequest(applicationContext, renderKey, previousId)
                }

                val renderId = UUID.randomUUID()
                NativeRenderStore.writeRequest(applicationContext, renderId.toString(), request)
                NativeRenderStore.writeKey(applicationContext, renderKey, renderId.toString())
                val workRequest = OneTimeWorkRequest.Builder(NativeRenderWorker::class.java)
                    .setId(renderId)
                    .setInputData(
                        Data.Builder()
                            .putString(NativeRenderWorker.KEY_RENDER_ID, renderId.toString())
                            .putString(NativeRenderWorker.KEY_RENDER_KEY, renderKey)
                            .putString(NativeRenderWorker.KEY_PROJECT_ID, projectId)
                            .build()
                    )
                    .addTag("cutawan-video-render")
                    .addTag("cutawan-project-$projectId")
                    .build()
                try {
                    workManager.enqueueUniqueWork(
                        uniqueName,
                        ExistingWorkPolicy.APPEND_OR_REPLACE,
                        workRequest
                    ).result.get(20, TimeUnit.SECONDS)
                } catch (error: Exception) {
                    NativeRenderStore.cleanFailedRequest(applicationContext, renderKey, renderId.toString())
                    throw error
                }
                mainHandler.post { reply.success(mapOf("renderId" to renderId.toString())) }
            } catch (error: Exception) {
                mainHandler.post {
                    reply.error(
                        "RENDER_START_FAILED",
                        error.message ?: "Could not queue the background render.",
                        null
                    )
                }
            }
        }
    }

    private fun getRenderProgress(call: io.flutter.plugin.common.MethodCall, reply: MethodChannel.Result) {
        val rawId = call.argument<String>("renderId")
        val renderId = try {
            UUID.fromString(rawId ?: throw IllegalArgumentException("Render identity is missing."))
        } catch (error: Exception) {
            reply.error("INVALID_RENDER_ID", error.message, rawId)
            return
        }
        val future = WorkManager.getInstance(applicationContext).getWorkInfoById(renderId)
        future.addListener(
            {
                try {
                    val info = future.get()
                        ?: throw IllegalStateException("The background render record was not found.")
                    val state = when (info.state) {
                        WorkInfo.State.ENQUEUED, WorkInfo.State.BLOCKED -> "queued"
                        WorkInfo.State.RUNNING -> "running"
                        WorkInfo.State.SUCCEEDED -> "completed"
                        WorkInfo.State.CANCELLED -> "cancelled"
                        WorkInfo.State.FAILED -> "failed"
                    }
                    val resultJson = info.outputData.getString(NativeRenderWorker.KEY_RESULT_JSON)
                    val payload = if (resultJson.isNullOrBlank()) {
                        emptyMap<String, Any?>()
                    } else {
                        NativeRenderStore.decodeJson(resultJson)
                    }
                    val progress = if (state == "completed") 100 else
                        info.progress.getInt(NativeRenderWorker.KEY_PROGRESS, 0).coerceIn(0, 99)
                    val error = info.outputData.getString(NativeRenderWorker.KEY_ERROR) ?: ""
                    reply.success(
                        mapOf(
                            "renderId" to renderId.toString(),
                            "status" to state,
                            "progress" to progress,
                            "error" to error,
                            "result" to payload
                        )
                    )
                } catch (error: Exception) {
                    reply.error("RENDER_STATUS_FAILED", error.message, rawId)
                }
            },
            ContextCompat.getMainExecutor(this)
        )
    }

    private fun cancelBackgroundRender(call: io.flutter.plugin.common.MethodCall, reply: MethodChannel.Result) {
        val rawId = call.argument<String>("renderId")
        val renderId = try {
            UUID.fromString(rawId ?: throw IllegalArgumentException("Render identity is missing."))
        } catch (error: Exception) {
            reply.error("INVALID_RENDER_ID", error.message, rawId)
            return
        }
        WorkManager.getInstance(applicationContext).cancelWorkById(renderId)
        reply.success(true)
    }

    private fun cancelBackgroundRenderForProject(
        call: io.flutter.plugin.common.MethodCall,
        reply: MethodChannel.Result
    ) {
        val projectId = call.argument<String>("projectId")
        if (projectId.isNullOrBlank() ||
            !projectId.matches(Regex("^[A-Za-z0-9_-]{1,160}$"))
        ) {
            reply.error("INVALID_PROJECT_ID", "A valid project identity is required.", null)
            return
        }
        // The durable worker is tagged with the owning project. Cancelling this
        // tag stops both the running clip and queued clips belonging to the project.
        ioExecutor.execute {
            try {
                WorkManager.getInstance(applicationContext)
                    .cancelAllWorkByTag("cutawan-project-$projectId")
                    .result
                    .get(30, TimeUnit.SECONDS)
                mainHandler.post { reply.success(true) }
            } catch (error: Exception) {
                mainHandler.post {
                    reply.error(
                        "BACKGROUND_RENDER_CANCEL_FAILED",
                        error.message ?: "Could not cancel the project's background render.",
                        projectId
                    )
                }
            }
        }
    }

    private fun getCompletedRender(call: io.flutter.plugin.common.MethodCall, reply: MethodChannel.Result) {
        val renderKey = call.argument<String>("renderKey")
        if (renderKey.isNullOrBlank() || !renderKey.matches(Regex("^[a-f0-9]{64}$"))) {
            reply.error("INVALID_RENDER_KEY", "A SHA-256 render fingerprint is required.", null)
            return
        }
        ioExecutor.execute {
            try {
                val payload = NativeRenderStore.readCompletion(applicationContext, renderKey)
                if (payload == null) {
                    mainHandler.post { reply.success(null) }
                } else {
                    val renderId = payload["renderId"] as? String
                        ?: throw IllegalStateException("Completed render has no identity.")
                    mainHandler.post {
                        reply.success(mapOf("renderId" to renderId, "result" to payload))
                    }
                }
            } catch (error: Exception) {
                mainHandler.post {
                    reply.error("COMPLETED_RENDER_READ_FAILED", error.message, null)
                }
            }
        }
    }

    private fun hasActiveBackgroundRender(call: io.flutter.plugin.common.MethodCall, reply: MethodChannel.Result) {
        val projectId = call.argument<String>("projectId")
        if (projectId.isNullOrBlank() ||
            !projectId.matches(Regex("^[A-Za-z0-9_-]{1,160}$"))
        ) {
            reply.error("INVALID_PROJECT_ID", "A valid project identity is required.", null)
            return
        }
        val future = WorkManager.getInstance(applicationContext)
            .getWorkInfosByTag("cutawan-project-$projectId")
        future.addListener(
            {
                try {
                    val infos = future.get()
                    val active = infos.any { info ->
                        when (info.state) {
                            WorkInfo.State.RUNNING,
                            WorkInfo.State.ENQUEUED,
                            WorkInfo.State.BLOCKED -> true
                            WorkInfo.State.SUCCEEDED ->
                                NativeRenderStore.hasPendingCompletionForProject(
                                    applicationContext,
                                    projectId
                                )
                            WorkInfo.State.CANCELLED,
                            WorkInfo.State.FAILED -> false
                        }
                    }
                    reply.success(active)
                } catch (error: Exception) {
                    reply.error("BACKGROUND_RENDER_LOOKUP_FAILED", error.message, projectId)
                }
            },
            ContextCompat.getMainExecutor(this)
        )
    }

    private fun acknowledgeCompletedRender(call: io.flutter.plugin.common.MethodCall, reply: MethodChannel.Result) {
        val renderKey = call.argument<String>("renderKey")
        val sha256 = call.argument<String>("sha256")
        if (renderKey.isNullOrBlank() || sha256.isNullOrBlank()) {
            reply.error("INVALID_RENDER_ACK", "Render fingerprint and SHA-256 are required.", null)
            return
        }
        ioExecutor.execute {
            val acknowledged = try {
                NativeRenderStore.acknowledgeCompletion(applicationContext, renderKey, sha256)
            } catch (_: Exception) {
                false
            }
            mainHandler.post { reply.success(acknowledged) }
        }
    }

    private data class TrackDecodeStats(
        val outputBufferCount: Long,
        val outputByteCount: Long
    )

    private data class FullDecodeSummary(
        val hasAudio: Boolean,
        val decodedVideoBuffers: Long,
        val decodedAudioBuffers: Long
    )

    private data class ValidatedRender(
        val sha256: String,
        val sizeBytes: Long,
        val durationMs: Long,
        val width: Int,
        val height: Int,
        val hasAudio: Boolean,
        val decodedVideoBuffers: Long,
        val decodedAudioBuffers: Long
    )

    private fun parseReframeSegments(
        raw: List<*>?,
        clipDurationMs: Long
    ): List<ReframeSegment> {
        if (raw == null || raw.isEmpty()) return emptyList()
        if (raw.size > 2000) {
            throw IllegalArgumentException("A clip cannot contain more than 2000 reframe segments.")
        }
        val result = mutableListOf<ReframeSegment>()
        var cursor = 0L
        for (item in raw) {
            val map = item as? Map<*, *>
                ?: throw IllegalArgumentException("Reframe segment must be an object.")
            val start = (map["startMs"] as? Number)?.toLong()
                ?: throw IllegalArgumentException("Reframe segment start is missing.")
            val end = (map["endMs"] as? Number)?.toLong()
                ?: throw IllegalArgumentException("Reframe segment end is missing.")
            val mode = map["mode"] as? String
                ?: throw IllegalArgumentException("Reframe segment mode is missing.")
            if (start != cursor || end <= start || end > clipDurationMs ||
                (mode != "fit" && mode != "crop")
            ) {
                throw IllegalArgumentException("Reframe segments must be contiguous, ordered and within the clip.")
            }
            if (mode == "fit") {
                if (map["region"] != null) {
                    throw IllegalArgumentException("Fit segments cannot include a crop region.")
                }
                result.add(ReframeSegment(start, end, mode))
            } else {
                val region = map["region"] as? Map<*, *>
                    ?: throw IllegalArgumentException("Crop segments require a frame region.")
                val x = (region["x"] as? Number)?.toFloat()
                    ?: throw IllegalArgumentException("Crop region x is missing.")
                val y = (region["y"] as? Number)?.toFloat()
                    ?: throw IllegalArgumentException("Crop region y is missing.")
                val width = (region["width"] as? Number)?.toFloat()
                    ?: throw IllegalArgumentException("Crop region width is missing.")
                val height = (region["height"] as? Number)?.toFloat()
                    ?: throw IllegalArgumentException("Crop region height is missing.")
                if (!x.isFinite() || !y.isFinite() || !width.isFinite() || !height.isFinite() ||
                    x < 0f || y < 0f || width <= 0f || height <= 0f ||
                    x + width > 1.0001f || y + height > 1.0001f
                ) {
                    throw IllegalArgumentException("Crop region must be normalized and remain inside the source frame.")
                }
                result.add(ReframeSegment(start, end, mode, x, y, width, height))
            }
            cursor = end
        }
        if (cursor != clipDurationMs) {
            throw IllegalArgumentException("Reframe segments must cover the complete clip duration.")
        }
        return result
    }

    private fun createReframeTransformation(
        segments: List<ReframeSegment>,
        sourceAspectRatio: Float,
        targetAspectRatio: Float
    ): MatrixTransformation {
        return object : MatrixTransformation {
            override fun getMatrix(presentationTimeUs: Long): Matrix {
                val timeMs = (presentationTimeUs / 1000L).coerceAtLeast(0L)
                val segment = segments.firstOrNull {
                    timeMs >= it.startMs && timeMs < it.endMs
                } ?: segments.lastOrNull()
                val values = if (segment == null || segment.mode == "fit") {
                    val scaleX: Float
                    val scaleY: Float
                    if (sourceAspectRatio > targetAspectRatio) {
                        scaleX = 1f
                        scaleY = targetAspectRatio / sourceAspectRatio
                    } else {
                        scaleX = sourceAspectRatio / targetAspectRatio
                        scaleY = 1f
                    }
                    floatArrayOf(
                        scaleX, 0f, 0f,
                        0f, scaleY, 0f,
                        0f, 0f, 1f
                    )
                } else {
                    val scaleX = 1f / segment.width
                    val scaleY = 1f / segment.height
                    val translateX =
                        (1f - 2f * segment.x - segment.width) / segment.width
                    val translateY =
                        (2f * segment.y + segment.height - 1f) / segment.height
                    floatArrayOf(
                        scaleX, 0f, translateX,
                        0f, scaleY, translateY,
                        0f, 0f, 1f
                    )
                }
                return Matrix().apply { setValues(values) }
            }
        }
    }


    private fun parseCaptionCues(
        raw: List<*>?,
        clipDurationMs: Long
    ): List<TimedCaptionCue> {
        if (raw == null || raw.isEmpty()) return emptyList()
        if (raw.size > 2000) {
            throw IllegalArgumentException("A clip cannot contain more than 2000 caption cues.")
        }
        val cues = mutableListOf<TimedCaptionCue>()
        var previousStart = -1L
        for (item in raw) {
            val map = item as? Map<*, *>
                ?: throw IllegalArgumentException("Caption cue must be an object.")
            val start = (map["startMs"] as? Number)?.toLong()
                ?: throw IllegalArgumentException("Caption cue start is missing.")
            val end = (map["endMs"] as? Number)?.toLong()
                ?: throw IllegalArgumentException("Caption cue end is missing.")
            val text = map["text"] as? String
                ?: throw IllegalArgumentException("Caption cue text is missing.")
            val rawWords = map["words"] as? List<*>
                ?: throw IllegalArgumentException("Caption cue words are missing.")
            if (start < 0 || end <= start || end > clipDurationMs ||
                start < previousStart || text.isBlank() || text.length > 1200 ||
                rawWords.isEmpty() || rawWords.size > 100
            ) {
                throw IllegalArgumentException("Caption cue timing or text is invalid.")
            }
            previousStart = start
            val words = mutableListOf<CaptionWordCue>()
            for (rawWord in rawWords) {
                val word = rawWord as? Map<*, *>
                    ?: throw IllegalArgumentException("Caption word must be an object.")
                val wordText = word["text"] as? String
                    ?: throw IllegalArgumentException("Caption word text is missing.")
                val wordStart = (word["startMs"] as? Number)?.toLong()
                    ?: throw IllegalArgumentException("Caption word start is missing.")
                val wordEnd = (word["endMs"] as? Number)?.toLong()
                    ?: throw IllegalArgumentException("Caption word end is missing.")
                val offsetStart = (word["startOffset"] as? Number)?.toInt()
                    ?: throw IllegalArgumentException("Caption word text start is missing.")
                val offsetEnd = (word["endOffset"] as? Number)?.toInt()
                    ?: throw IllegalArgumentException("Caption word text end is missing.")
                if (wordText.isBlank() || wordStart < start || wordEnd <= wordStart ||
                    wordEnd > end || offsetStart < 0 || offsetEnd <= offsetStart ||
                    offsetEnd > text.length ||
                    text.substring(offsetStart, offsetEnd) != wordText
                ) {
                    throw IllegalArgumentException("Caption word does not match its timed text range.")
                }
                words.add(
                    CaptionWordCue(
                        wordText,
                        wordStart,
                        wordEnd,
                        offsetStart,
                        offsetEnd
                    )
                )
            }
            cues.add(TimedCaptionCue(start, end, text, words))
        }
        return cues
    }

    private fun parseCaptionStyle(raw: Map<*, *>?): CaptionRenderStyle {
        val value = raw ?: throw IllegalArgumentException("Caption style is required.")
        val family = value["fontFamily"] as? String
            ?: throw IllegalArgumentException("Caption font family is missing.")
        val scale = (value["fontScale"] as? Number)?.toFloat()
            ?: throw IllegalArgumentException("Caption font scale is missing.")
        val uppercase = value["uppercase"] as? Boolean
            ?: throw IllegalArgumentException("Caption uppercase preference is missing.")
        val textColor = parseCaptionColor(value["textColor"], "textColor")
        val highlightColor = parseCaptionColor(value["highlightColor"], "highlightColor")
        val outlineColor = parseCaptionColor(value["outlineColor"], "outlineColor")
        val boxRaw = value["highlightBoxColor"]
        val box = if (boxRaw == null) null else parseCaptionColor(boxRaw, "highlightBoxColor")
        val outlineWidth = (value["outlineWidth"] as? Number)?.toFloat()
            ?: throw IllegalArgumentException("Caption outline width is missing.")
        val shadow = (value["shadow"] as? Number)?.toFloat()
            ?: throw IllegalArgumentException("Caption shadow is missing.")
        val bold = value["bold"] as? Boolean
            ?: throw IllegalArgumentException("Caption bold preference is missing.")
        val positionY = (value["positionY"] as? Number)?.toFloat()
            ?: throw IllegalArgumentException("Caption vertical position is missing.")
        if (family.isBlank() || !scale.isFinite() || scale <= 0f ||
            !outlineWidth.isFinite() || outlineWidth < 0f ||
            !shadow.isFinite() || shadow < 0f ||
            !positionY.isFinite() || positionY <= 0f || positionY >= 1f
        ) {
            throw IllegalArgumentException("Caption style values are outside supported bounds.")
        }
        return CaptionRenderStyle(
            family,
            scale,
            uppercase,
            textColor,
            highlightColor,
            box,
            outlineColor,
            outlineWidth,
            shadow,
            bold,
            positionY
        )
    }

    private fun parseCaptionColor(raw: Any?, name: String): Int {
        val value = raw as? String
            ?: throw IllegalArgumentException("Caption " + name + " is missing.")
        if (!value.matches(Regex("^#[0-9A-Fa-f]{6}$"))) {
            throw IllegalArgumentException("Caption " + name + " must be #RRGGBB.")
        }
        return Color.parseColor(value)
    }

    private class TimedCaptionOverlay(
        private val cues: List<TimedCaptionCue>,
        private val captionStyle: CaptionRenderStyle,
        private val animationId: String
    ) : CanvasOverlay(true) {
        private var cachedCueIndex = -1
        private var cachedWordIndex = -2
        private var cachedWidth = -1
        private var cachedHeight = -1
        private var cachedFillLayout: StaticLayout? = null
        private var cachedOutlineLayout: StaticLayout? = null

        override fun onDraw(canvas: Canvas, presentationTimeUs: Long) {
            val timeMs = (presentationTimeUs / 1000L).coerceAtLeast(0L)
            val cueIndex = cues.indexOfFirst {
                timeMs >= it.startMs && timeMs < it.endMs
            }
            if (cueIndex < 0) return
            val cue = cues[cueIndex]
            val activeWordIndex = if (animationId == "karaoke_fill") {
                cue.words.indexOfFirst {
                    timeMs >= it.startMs && timeMs < it.endMs
                }
            } else {
                -1
            }
            if (cueIndex != cachedCueIndex ||
                activeWordIndex != cachedWordIndex ||
                canvas.width != cachedWidth ||
                canvas.height != cachedHeight
            ) {
                rebuildLayouts(cue, cueIndex, activeWordIndex, canvas.width, canvas.height)
            }
            val fill = cachedFillLayout ?: return
            val left = (canvas.width - fill.width) / 2f
            val top = (canvas.height * captionStyle.positionY - fill.height / 2f)
                .coerceIn(0f, (canvas.height - fill.height).coerceAtLeast(0).toFloat())
            if (captionStyle.highlightBoxColor != null) {
                val paddingX = canvas.width * 0.018f
                val paddingY = fill.height * 0.12f
                val rect = RectF(
                    left - paddingX,
                    top - paddingY,
                    left + fill.width + paddingX,
                    top + fill.height + paddingY
                )
                val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = captionStyle.highlightBoxColor
                    style = Paint.Style.FILL
                }
                canvas.drawRoundRect(
                    rect,
                    (canvas.height * 0.012f).coerceAtLeast(8f),
                    (canvas.height * 0.012f).coerceAtLeast(8f),
                    backgroundPaint
                )
            }
            canvas.save()
            canvas.translate(left, top)
            cachedOutlineLayout?.draw(canvas)
            fill.draw(canvas)
            canvas.restore()
        }

        private fun rebuildLayouts(
            cue: TimedCaptionCue,
            cueIndex: Int,
            activeWordIndex: Int,
            canvasWidth: Int,
            canvasHeight: Int
        ) {
            val value = if (captionStyle.uppercase) cue.text.uppercase(Locale.ROOT) else cue.text
            val styled = SpannableString(value)
            if (animationId == "karaoke_fill" && activeWordIndex >= 0) {
                val word = cue.words[activeWordIndex]
                val start = if (captionStyle.uppercase) {
                    cue.text.substring(0, word.startOffset).uppercase(Locale.ROOT).length
                } else {
                    word.startOffset
                }
                val end = if (captionStyle.uppercase) {
                    cue.text.substring(0, word.endOffset).uppercase(Locale.ROOT).length
                } else {
                    word.endOffset
                }
                if (start >= 0 && end > start && end <= styled.length) {
                    styled.setSpan(
                        ForegroundColorSpan(captionStyle.highlightColor),
                        start,
                        end,
                        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                    )
                }
            }
            val textSize = (canvasHeight * captionStyle.fontScale).coerceIn(20f, canvasHeight * 0.12f)
            val typeface = when {
                captionStyle.fontFamily.contains("Anton", ignoreCase = true) ->
                    Typeface.create("sans-serif-condensed", if (captionStyle.bold) Typeface.BOLD else Typeface.NORMAL)
                captionStyle.fontFamily.contains("Medium", ignoreCase = true) ->
                    Typeface.create("sans-serif-medium", Typeface.NORMAL)
                else -> Typeface.create("sans-serif", if (captionStyle.bold) Typeface.BOLD else Typeface.NORMAL)
            }
            val maxWidth = (canvasWidth * 0.90f).toInt().coerceAtLeast(120)
            val fillPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                color = captionStyle.textColor
                this.textSize = textSize
                this.typeface = typeface
                style = Paint.Style.FILL
                if (captionStyle.shadow > 0f) {
                    setShadowLayer(
                        captionStyle.shadow * textSize * 0.12f,
                        0f,
                        captionStyle.shadow * textSize * 0.05f,
                        Color.BLACK
                    )
                }
            }
            val outlinePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                color = captionStyle.outlineColor
                this.textSize = textSize
                this.typeface = typeface
                style = Paint.Style.STROKE
                strokeJoin = Paint.Join.ROUND
                strokeWidth = captionStyle.outlineWidth * (textSize / 48f)
            }
            cachedFillLayout = buildCaptionLayout(styled, fillPaint, maxWidth)
            cachedOutlineLayout = if (captionStyle.outlineWidth > 0f) {
                buildCaptionLayout(styled, outlinePaint, maxWidth)
            } else {
                null
            }
            cachedCueIndex = cueIndex
            cachedWordIndex = activeWordIndex
            cachedWidth = canvasWidth
            cachedHeight = canvasHeight
        }

        private fun buildCaptionLayout(
            text: CharSequence,
            paint: TextPaint,
            width: Int
        ): StaticLayout {
            return StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
                .setAlignment(Layout.Alignment.ALIGN_CENTER)
                .setTextDirection(TextDirectionHeuristics.FIRSTSTRONG_RTL)
                .setIncludePad(false)
                .setMaxLines(2)
                .setLineSpacing(0f, 1.04f)
                .build()
        }
    }

    private fun validateRenderedVideo(output: File, expectedDurationMs: Long): ValidatedRender {
        if (!output.isFile || output.length() < 2048L) {
            throw IllegalStateException("Media3 completed without a usable output file.")
        }
        val retriever = MediaMetadataRetriever()
        var durationMs = -1L
        var width = -1
        var height = -1
        try {
            retriever.setDataSource(output.absolutePath)
            durationMs = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION
            )?.toLongOrNull() ?: -1L
            width = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH
            )?.toIntOrNull() ?: -1
            height = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT
            )?.toIntOrNull() ?: -1
        } finally {
            try { retriever.release() } catch (_: Exception) { }
        }
        if (durationMs <= 0L || width <= 0 || height <= 0) {
            throw IllegalStateException("Rendered MP4 has missing duration or video dimensions.")
        }
        val tolerance = max(1500L, expectedDurationMs / 10L)
        if (kotlin.math.abs(durationMs - expectedDurationMs) > tolerance) {
            throw IllegalStateException(
                "Rendered duration " + durationMs + " ms differs from requested " +
                    expectedDurationMs + " ms."
            )
        }
        val extractor = MediaExtractor()
        var hasVideo = false
        var hasAudio = false
        try {
            extractor.setDataSource(output.absolutePath)
            for (index in 0 until extractor.trackCount) {
                val mime = extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("video/")) hasVideo = true
                if (mime.startsWith("audio/")) hasAudio = true
            }
        } finally {
            try { extractor.release() } catch (_: Exception) { }
        }
        if (!hasVideo) throw IllegalStateException("Rendered MP4 contains no video track.")

        // Metadata probing alone can accept truncated files. Decode every audio/video
        // track through its end-of-stream marker before publishing the output.
        val decode = decodeMediaFully(Uri.fromFile(output))
        if (decode.hasAudio != hasAudio || decode.decodedVideoBuffers <= 0L ||
            (hasAudio && decode.decodedAudioBuffers <= 0L)
        ) {
            throw IllegalStateException("Rendered MP4 did not fully decode all media tracks.")
        }
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(output).use { input ->
            val buffer = ByteArray(1024 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                if (count > 0) digest.update(buffer, 0, count)
            }
        }
        return ValidatedRender(
            sha256 = digest.digest().joinToString("") { "%02x".format(it) },
            sizeBytes = output.length(),
            durationMs = durationMs,
            width = width,
            height = height,
            hasAudio = hasAudio,
            decodedVideoBuffers = decode.decodedVideoBuffers,
            decodedAudioBuffers = decode.decodedAudioBuffers
        )
    }

    /**
     * Decode every audio/video track to BUFFER_FLAG_END_OF_STREAM. No media
     * payload is retained; decoded output is counted and discarded to bound memory.
     */
    private fun decodeMediaFully(uri: Uri): FullDecodeSummary {
        val metadataExtractor = MediaExtractor()
        val videoTracks = mutableListOf<Int>()
        val audioTracks = mutableListOf<Int>()
        try {
            when (uri.scheme) {
                "content" -> metadataExtractor.setDataSource(this, uri, null)
                "file" -> metadataExtractor.setDataSource(
                    File(uri.path ?: throw IllegalArgumentException("Media URI has no path.")).absolutePath
                )
                else -> throw IllegalArgumentException("Unsupported media URI scheme for full decode.")
            }
            for (index in 0 until metadataExtractor.trackCount) {
                val mime = metadataExtractor.getTrackFormat(index)
                    .getString(MediaFormat.KEY_MIME) ?: continue
                when {
                    mime.startsWith("video/") -> videoTracks.add(index)
                    mime.startsWith("audio/") -> audioTracks.add(index)
                }
            }
        } finally {
            try { metadataExtractor.release() } catch (_: Exception) { }
        }
        if (videoTracks.isEmpty()) {
            throw IllegalStateException("Media contains no decodable video track.")
        }

        var decodedVideoBuffers = 0L
        var decodedAudioBuffers = 0L
        for (trackIndex in videoTracks) {
            decodedVideoBuffers += decodeTrackFully(uri, trackIndex).outputBufferCount
        }
        for (trackIndex in audioTracks) {
            decodedAudioBuffers += decodeTrackFully(uri, trackIndex).outputBufferCount
        }
        return FullDecodeSummary(
            hasAudio = audioTracks.isNotEmpty(),
            decodedVideoBuffers = decodedVideoBuffers,
            decodedAudioBuffers = decodedAudioBuffers
        )
    }

    private fun decodeTrackFully(uri: Uri, trackIndex: Int): TrackDecodeStats {
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        try {
            when (uri.scheme) {
                "content" -> extractor.setDataSource(this, uri, null)
                "file" -> extractor.setDataSource(
                    File(uri.path ?: throw IllegalArgumentException("Media URI has no path.")).absolutePath
                )
                else -> throw IllegalArgumentException("Unsupported media URI scheme for decode.")
            }
            if (trackIndex !in 0 until extractor.trackCount) {
                throw IllegalArgumentException("Media track index is no longer available.")
            }
            val format = extractor.getTrackFormat(trackIndex)
            val mime = format.getString(MediaFormat.KEY_MIME)
                ?: throw IllegalStateException("Media track has no codec MIME type.")
            extractor.selectTrack(trackIndex)
            val codec = MediaCodec.createDecoderByType(mime)
            decoder = codec
            codec.configure(format, null, null, 0)
            codec.start()

            val info = MediaCodec.BufferInfo()
            var inputEnded = false
            var outputEnded = false
            var outputBufferCount = 0L
            var outputByteCount = 0L
            val deadline = SystemClock.elapsedRealtime() + 30L * 60L * 1000L

            while (!outputEnded) {
                if (SystemClock.elapsedRealtime() > deadline) {
                    throw IllegalStateException("Full media decode exceeded the 30-minute safety limit.")
                }

                if (!inputEnded) {
                    val inputIndex = codec.dequeueInputBuffer(10_000)
                    if (inputIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inputIndex)
                            ?: throw IllegalStateException("Media decoder input buffer is unavailable.")
                        inputBuffer.clear()
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(
                                inputIndex,
                                0,
                                0,
                                0L,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            inputEnded = true
                        } else {
                            codec.queueInputBuffer(
                                inputIndex,
                                0,
                                sampleSize,
                                extractor.sampleTime.coerceAtLeast(0L),
                                extractor.sampleFlags
                            )
                            extractor.advance()
                        }
                    }
                }

                when (val outputIndex = codec.dequeueOutputBuffer(info, 10_000)) {
                    MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> Unit
                    else -> if (outputIndex >= 0) {
                        if (info.size > 0) {
                            outputBufferCount++
                            outputByteCount += info.size.toLong()
                        }
                        val endOfStream =
                            (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                        codec.releaseOutputBuffer(outputIndex, false)
                        if (endOfStream) outputEnded = true
                    }
                }
            }

            if (outputBufferCount <= 0L || outputByteCount <= 0L) {
                throw IllegalStateException("Media decoder reached EOS without decoded output.")
            }
            return TrackDecodeStats(outputBufferCount, outputByteCount)
        } finally {
            decoder?.let { codec ->
                try { codec.stop() } catch (_: Exception) { }
                try { codec.release() } catch (_: Exception) { }
            }
            try { extractor.release() } catch (_: Exception) { }
        }
    }

    private fun publishRenderedVideo(source: File, clipId: String): Pair<Uri, String> {
        val displayName = "CUTAWAN_" + clipId.take(80) + "_" +
            System.currentTimeMillis() + ".mp4"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    Environment.DIRECTORY_MOVIES + "/CUTAWAN"
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Android could not create the Movies/CUTAWAN export.")
            try {
                contentResolver.openOutputStream(uri, "w")?.use { destination ->
                    FileInputStream(source).use { input -> input.copyTo(destination) }
                } ?: throw IllegalStateException("Android could not open the exported video destination.")
                val ready = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                contentResolver.update(uri, ready, null, null)
                return Pair(uri, displayName)
            } catch (error: Exception) {
                contentResolver.delete(uri, null, null)
                throw error
            }
        }
        val directory = File(
            getExternalFilesDir(Environment.DIRECTORY_MOVIES) ?: filesDir,
            "CUTAWAN"
        )
        if (!directory.exists() && !directory.mkdirs()) {
            throw IllegalStateException("Could not create the app-specific Movies/CUTAWAN folder.")
        }
        val target = File(directory, displayName)
        FileInputStream(source).use { input ->
            target.outputStream().use { destination -> input.copyTo(destination) }
        }
        return Pair(Uri.fromFile(target), displayName)
    }


    private data class OwnedExportTarget(val uri: Uri, val file: File?)

    private fun resolveOwnedExportTarget(rawUri: String): OwnedExportTarget {
        val parsed = Uri.parse(rawUri)
        return when (parsed.scheme) {
            "content" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                    parsed.authority != MediaStore.AUTHORITY
                ) {
                    throw SecurityException("Export URI is not owned by Android MediaStore.")
                }
                val cursor = contentResolver.query(
                    parsed,
                    arrayOf(
                        MediaStore.MediaColumns.RELATIVE_PATH,
                        MediaStore.MediaColumns.IS_PENDING,
                        MediaStore.MediaColumns.MIME_TYPE,
                        MediaStore.MediaColumns.DISPLAY_NAME,
                        MediaStore.MediaColumns.OWNER_PACKAGE_NAME
                    ),
                    null,
                    null,
                    null
                ) ?: throw IllegalStateException("Export is no longer available in MediaStore.")
                val owned = cursor.use {
                    if (!it.moveToFirst()) false
                    else {
                        val pathIndex = it.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH)
                        val pendingIndex = it.getColumnIndex(MediaStore.MediaColumns.IS_PENDING)
                        val mimeIndex = it.getColumnIndex(MediaStore.MediaColumns.MIME_TYPE)
                        val nameIndex = it.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                        val ownerIndex = it.getColumnIndex(MediaStore.MediaColumns.OWNER_PACKAGE_NAME)
                        if (pathIndex < 0 || pendingIndex < 0 || mimeIndex < 0 ||
                            nameIndex < 0 || ownerIndex < 0
                        ) {
                            false
                        } else {
                            val relativePath = it.getString(pathIndex)
                            val pending = it.getInt(pendingIndex)
                            val mime = it.getString(mimeIndex)
                            val name = it.getString(nameIndex)
                            val owner = it.getString(ownerIndex)
                            relativePath?.startsWith(Environment.DIRECTORY_MOVIES + "/CUTAWAN/") == true &&
                                pending == 0 &&
                                mime == "video/mp4" &&
                                name?.endsWith(".mp4", ignoreCase = true) == true &&
                                owner == packageName
                        }
                    }
                }
                if (!owned) {
                    throw SecurityException("Export URI is not a published CUTAWAN MP4.")
                }
                OwnedExportTarget(parsed, null)
            }
            "file" -> {
                val file = File(parsed.path ?: "").canonicalFile
                val directory = File(
                    getExternalFilesDir(Environment.DIRECTORY_MOVIES) ?: filesDir,
                    "CUTAWAN"
                ).canonicalFile
                val prefix = directory.path + File.separator
                if (!file.isFile ||
                    !file.path.startsWith(prefix) ||
                    !file.name.endsWith(".mp4", ignoreCase = true)
                ) {
                    throw SecurityException("Export file is outside CUTAWAN's app-owned export folder.")
                }
                val sharedUri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    file
                )
                OwnedExportTarget(sharedUri, file)
            }
            else -> throw IllegalArgumentException("Unsupported exported video URI scheme.")
        }
    }

    private fun openExport(call: io.flutter.plugin.common.MethodCall, reply: MethodChannel.Result) {
        val rawUri = call.argument<String>("outputUri")
        if (rawUri.isNullOrBlank()) {
            reply.error("INVALID_EXPORT_URI", "An exported video URI is required.", null)
            return
        }
        ioExecutor.execute {
            try {
                val target = resolveOwnedExportTarget(rawUri)
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(target.uri, "video/mp4")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    clipData = ClipData.newUri(contentResolver, "CUTAWAN video", target.uri)
                }
                mainHandler.post {
                    try {
                        startActivity(intent)
                        reply.success(true)
                    } catch (error: Exception) {
                        reply.error("EXPORT_OPEN_FAILED", error.message ?: "Could not open the exported video.", rawUri)
                    }
                }
            } catch (error: Exception) {
                mainHandler.post {
                    reply.error("EXPORT_OPEN_FAILED", error.message ?: "Could not open the exported video.", rawUri)
                }
            }
        }
    }

    private fun shareExport(call: io.flutter.plugin.common.MethodCall, reply: MethodChannel.Result) {
        val rawUri = call.argument<String>("outputUri")
        if (rawUri.isNullOrBlank()) {
            reply.error("INVALID_EXPORT_URI", "An exported video URI is required.", null)
            return
        }
        ioExecutor.execute {
            try {
                val target = resolveOwnedExportTarget(rawUri)
                val sendIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "video/mp4"
                    putExtra(Intent.EXTRA_STREAM, target.uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    clipData = ClipData.newUri(contentResolver, "CUTAWAN video", target.uri)
                }
                mainHandler.post {
                    try {
                        startActivity(Intent.createChooser(sendIntent, "مشاركة فيديو CUTAWAN"))
                        reply.success(true)
                    } catch (error: Exception) {
                        reply.error("EXPORT_SHARE_FAILED", error.message ?: "Could not share the exported video.", rawUri)
                    }
                }
            } catch (error: Exception) {
                mainHandler.post {
                    reply.error("EXPORT_SHARE_FAILED", error.message ?: "Could not share the exported video.", rawUri)
                }
            }
        }
    }

    private fun deleteExport(call: io.flutter.plugin.common.MethodCall, reply: MethodChannel.Result) {
        val rawUri = call.argument<String>("outputUri")
        if (rawUri.isNullOrBlank()) {
            reply.error("INVALID_EXPORT_URI", "An exported video URI is required.", null)
            return
        }
        ioExecutor.execute {
            try {
                val target = resolveOwnedExportTarget(rawUri)
                val deleted = if (target.file != null) {
                    target.file.exists() && target.file.delete()
                } else {
                    contentResolver.delete(target.uri, null, null) > 0
                }
                mainHandler.post { reply.success(deleted) }
            } catch (error: Exception) {
                mainHandler.post {
                    reply.error("EXPORT_DELETE_FAILED", error.message ?: "Could not delete the exported video.", rawUri)
                }
            }
        }
    }

    private fun verifyExport(call: io.flutter.plugin.common.MethodCall, reply: MethodChannel.Result) {
        val rawUri = call.argument<String>("outputUri")
        val expectedHash = call.argument<String>("sha256")
        val expectedSize = call.argument<Number>("sizeBytes")?.toLong()
        val expectedDuration = call.argument<Number>("durationMs")?.toLong()
        val expectedWidth = call.argument<Number>("width")?.toInt()
        val expectedHeight = call.argument<Number>("height")?.toInt()
        if (rawUri.isNullOrBlank() || expectedHash.isNullOrBlank() ||
            expectedSize == null || expectedDuration == null ||
            expectedWidth == null || expectedHeight == null
        ) {
            reply.error("INVALID_EXPORT_RECORD", "Export verification metadata is incomplete.", null)
            return
        }
        ioExecutor.execute {
            try {
                val uri = Uri.parse(rawUri)
                val inputStream = when (uri.scheme) {
                    "content" -> {
                        val cursor = contentResolver.query(
                            uri,
                            arrayOf(MediaStore.MediaColumns.RELATIVE_PATH, MediaStore.MediaColumns.IS_PENDING),
                            null,
                            null,
                            null
                        ) ?: throw IllegalStateException("Export is no longer available in MediaStore.")
                        val ownedPath = cursor.use {
                            if (!it.moveToFirst()) false
                            else {
                                val pathIndex = it.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH)
                                val pendingIndex = it.getColumnIndex(MediaStore.MediaColumns.IS_PENDING)
                                val path = if (pathIndex >= 0) it.getString(pathIndex) else null
                                val pending = if (pendingIndex >= 0) it.getInt(pendingIndex) else 0
                                path?.startsWith(Environment.DIRECTORY_MOVIES + "/CUTAWAN/") == true &&
                                    pending == 0
                            }
                        }
                        if (!ownedPath) {
                            throw SecurityException("Export URI is not a published CUTAWAN video.")
                        }
                        contentResolver.openInputStream(uri)
                            ?: throw IllegalStateException("Export content is no longer readable.")
                    }
                    "file" -> {
                        val file = File(uri.path ?: "")
                        val base = File(
                            getExternalFilesDir(Environment.DIRECTORY_MOVIES) ?: filesDir,
                            "CUTAWAN"
                        ).canonicalPath + File.separator
                        if (!file.isFile || !file.canonicalPath.startsWith(base)) {
                            throw SecurityException("Export file is outside CUTAWAN's app-owned export folder.")
                        }
                        FileInputStream(file)
                    }
                    else -> throw IllegalArgumentException("Unsupported exported video URI scheme.")
                }
                val digest = MessageDigest.getInstance("SHA-256")
                var sizeBytes = 0L
                inputStream.use { input ->
                    val buffer = ByteArray(1024 * 1024)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        if (count > 0) {
                            digest.update(buffer, 0, count)
                            sizeBytes += count.toLong()
                        }
                    }
                }
                val actualHash = digest.digest().joinToString("") { "%02x".format(it) }
                val retriever = MediaMetadataRetriever()
                var duration = -1L
                var width = -1
                var height = -1
                try {
                    if (uri.scheme == "content") retriever.setDataSource(this, uri)
                    else retriever.setDataSource(File(uri.path!!).absolutePath)
                    duration = retriever.extractMetadata(
                        MediaMetadataRetriever.METADATA_KEY_DURATION
                    )?.toLongOrNull() ?: -1L
                    width = retriever.extractMetadata(
                        MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH
                    )?.toIntOrNull() ?: -1
                    height = retriever.extractMetadata(
                        MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT
                    )?.toIntOrNull() ?: -1
                } finally {
                    try { retriever.release() } catch (_: Exception) { }
                }
                val extractor = MediaExtractor()
                var hasVideo = false
                var hasAudio = false
                try {
                    if (uri.scheme == "content") extractor.setDataSource(this, uri, null)
                    else extractor.setDataSource(File(uri.path!!).absolutePath)
                    for (index in 0 until extractor.trackCount) {
                        val mime = extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME) ?: continue
                        if (mime.startsWith("video/")) hasVideo = true
                        if (mime.startsWith("audio/")) hasAudio = true
                    }
                } finally {
                    try { extractor.release() } catch (_: Exception) { }
                }
                val decode = decodeMediaFully(uri)
                val valid = actualHash == expectedHash &&
                    sizeBytes == expectedSize &&
                    duration == expectedDuration &&
                    width == expectedWidth &&
                    height == expectedHeight &&
                    sizeBytes >= 2048L &&
                    hasVideo &&
                    decode.hasAudio == hasAudio &&
                    decode.decodedVideoBuffers > 0L &&
                    (!hasAudio || decode.decodedAudioBuffers > 0L)
                mainHandler.post {
                    reply.success(
                        mapOf(
                            "valid" to valid,
                            "sha256" to actualHash,
                            "sizeBytes" to sizeBytes,
                            "durationMs" to duration,
                            "width" to width,
                            "height" to height,
                            "hasVideo" to hasVideo,
                            "fullyDecodeValidated" to valid,
                            "decodedVideoBuffers" to decode.decodedVideoBuffers,
                            "decodedAudioBuffers" to decode.decodedAudioBuffers
                        )
                    )
                }
            } catch (error: Exception) {
                mainHandler.post {
                    reply.success(mapOf("valid" to false, "error" to (error.message ?: "Export verification failed.")))
                }
            }
        }
    }

    /**
     * Collects non-identifying device/runtime measurements for Phase 10 acceptance.
     * This deliberately excludes serial numbers, account data, file names and media content.
     */
    private fun readDeviceAcceptanceDiagnostics(): Map<String, Any> {
        val activityManager = getSystemService(ACTIVITY_SERVICE) as ActivityManager
        val systemMemory = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(systemMemory)

        val processMemory = Debug.MemoryInfo()
        Debug.getMemoryInfo(processMemory)

        val batteryManager = getSystemService(BATTERY_SERVICE) as BatteryManager
        val batteryPercent = batteryManager.getIntProperty(
            BatteryManager.BATTERY_PROPERTY_CAPACITY
        )
        val batteryIntent = registerReceiver(
            null,
            android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        )
        val batteryTemperatureTenthsC = batteryIntent?.getIntExtra(
            BatteryManager.EXTRA_TEMPERATURE,
            -1
        ) ?: -1

        val thermalStatus = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            (getSystemService(POWER_SERVICE) as PowerManager).currentThermalStatus
        } else {
            -1
        }
        val packageInfo = packageManager.getPackageInfo(packageName, 0)
        val appVersionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            packageInfo.versionCode.toLong()
        }
        val fingerprint = Build.FINGERPRINT.lowercase(Locale.ROOT)
        val emulatorMarkers = listOf("generic", "unknown", "emulator", "sdk_gphone", "goldfish", "ranchu")
        val isPhysicalDevice = emulatorMarkers.none { fingerprint.contains(it) }

        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "androidRelease" to Build.VERSION.RELEASE,
            "androidSdk" to Build.VERSION.SDK_INT,
            "isPhysicalDevice" to isPhysicalDevice,
            "cpuCoreCount" to Runtime.getRuntime().availableProcessors(),
            "totalMemoryBytes" to systemMemory.totalMem,
            "availableMemoryBytes" to systemMemory.availMem,
            "lowMemory" to systemMemory.lowMemory,
            "processPssKb" to processMemory.totalPss,
            "processPrivateDirtyKb" to processMemory.totalPrivateDirty,
            "batteryPercent" to batteryPercent,
            "batteryTemperatureTenthsC" to batteryTemperatureTenthsC,
            "thermalStatus" to thermalStatus,
            "availableStorageBytes" to StatFs(filesDir.absolutePath).availableBytes,
            "appVersionName" to (packageInfo.versionName ?: ""),
            "appVersionCode" to appVersionCode,
            "capturedAtUptimeMs" to SystemClock.elapsedRealtime()
        )
    }

    private fun utcNowIso(): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(Date())
    }

    override fun onDestroy() {
        // Media3 export is owned by NativeRenderWorker/WorkManager, not this Activity.
        // Destroying or recreating the UI must not cancel an in-flight user-initiated export.
        pendingPickerResult = null
        ioExecutor.shutdown()
        super.onDestroy()
    }
}

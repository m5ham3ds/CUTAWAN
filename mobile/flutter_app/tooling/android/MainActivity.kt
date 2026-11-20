package com.m5ham3ds.cutawan_mobile

import android.content.ContentValues
import android.os.Build
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
import java.io.InputStream
import java.security.MessageDigest
import android.app.Activity
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

@OptIn(UnstableApi::class)
class MainActivity : FlutterActivity() {
    private val channelName = "com.cutawan.mobile/media"
    private val openVideoRequestCode = 4102
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingPickerResult: MethodChannel.Result? = null
    private data class RenderSession(
        val id: String,
        val transformer: Transformer,
        val progressHolder: ProgressHolder,
        val outputFile: File,
        var status: String = "running",
        var progress: Int = 0,
        var error: String? = null,
        var result: Map<String, Any>? = null,
        var cancelRequested: Boolean = false
    )
    private val renderSessions = mutableMapOf<String, RenderSession>()
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
                    "getRenderProgress" -> {
                        val id = call.argument<String>("renderId")
                        val session = if (id.isNullOrBlank()) null else renderSessions[id]
                        if (session == null) {
                            result.error("RENDER_NOT_FOUND", "The render job was not found.", id)
                        } else {
                            if (session.status == "running") {
                                try {
                                    if (session.transformer.getProgress(session.progressHolder) ==
                                        Transformer.PROGRESS_STATE_AVAILABLE
                                    ) {
                                        session.progress = session.progressHolder.progress.coerceIn(0, 99)
                                    }
                                } catch (_: IllegalStateException) { }
                            }
                            result.success(
                                mapOf(
                                    "renderId" to session.id,
                                    "status" to session.status,
                                    "progress" to session.progress,
                                    "error" to (session.error ?: ""),
                                    "result" to (session.result ?: emptyMap<String, Any>())
                                )
                            )
                        }
                    }
                    "cancelRender" -> {
                        val id = call.argument<String>("renderId")
                        val session = if (id.isNullOrBlank()) null else renderSessions[id]
                        if (session == null) {
                            result.success(false)
                        } else {
                            session.cancelRequested = true
                            if (session.status == "running") {
                                session.status = "cancelled"
                                session.error = "Cancelled by user."
                                try { session.transformer.cancel() } catch (_: Exception) { }
                                if (session.outputFile.exists()) session.outputFile.delete()
                            }
                            result.success(true)
                        }
                    }
                    "releaseRender" -> {
                        val id = call.argument<String>("renderId")
                        if (id != null) renderSessions.remove(id)
                        result.success(null)
                    }
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
                    listFiles()?.forEach { stale ->
                        if (stale.isFile &&
                            (stale.name.endsWith(".wav") ||
                                stale.name.endsWith(".wav.part"))
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
        try {
            val rawUri = call.argument<String>("uri")
                ?: throw IllegalArgumentException("A source URI is required.")
            val clipId = call.argument<String>("clipId")
                ?: throw IllegalArgumentException("A clip ID is required.")
            val outputPath = call.argument<String>("outputPath")
                ?: throw IllegalArgumentException("An output path is required.")
            val startMs = call.argument<Number>("startMs")?.toLong()
                ?: throw IllegalArgumentException("A clip start time is required.")
            val endMs = call.argument<Number>("endMs")?.toLong()
                ?: throw IllegalArgumentException("A clip end time is required.")
            val aspectRatio = call.argument<Number>("aspectRatio")?.toFloat()
                ?: throw IllegalArgumentException("An output aspect ratio is required.")
            val sourceAspectRatio = call.argument<Number>("sourceAspectRatio")?.toFloat()
                ?: throw IllegalArgumentException("A source aspect ratio is required.")
            if (!clipId.matches(Regex("^[A-Za-z0-9_-]{1,160}$")) ||
                startMs < 0 || endMs <= startMs ||
                !aspectRatio.isFinite() || aspectRatio <= 0f || aspectRatio > 4f ||
                !sourceAspectRatio.isFinite() || sourceAspectRatio <= 0f || sourceAspectRatio > 8f
            ) {
                throw IllegalArgumentException("Clip ID, range or aspect ratio is invalid.")
            }
            val reframeSegments = parseReframeSegments(
                call.argument<List<*>>("reframeShots"),
                endMs - startMs
            )
            val captionCues = parseCaptionCues(
                call.argument<List<*>>("captionCues"),
                endMs - startMs
            )
            val captionStyle = if (captionCues.isEmpty()) {
                null
            } else {
                parseCaptionStyle(call.argument<Map<*, *>>("captionStyle"))
            }
            val captionAnimationId = call.argument<String>("captionAnimationId") ?: "static"
            if (renderSessions.values.any { it.status == "running" }) {
                throw IllegalStateException("Another video export is already running.")
            }
            val sourceUri = Uri.parse(rawUri)
            validateReadableSource(sourceUri)
            val outputFile = File(outputPath)
            val canonicalOutput = outputFile.canonicalPath
            val filesBase = filesDir.canonicalPath + File.separator
            if (!canonicalOutput.startsWith(filesBase) ||
                !canonicalOutput.endsWith(".mp4", ignoreCase = true)
            ) {
                throw SecurityException("Export output must remain inside Cutawan's private storage.")
            }
            val parent = outputFile.parentFile
                ?: throw IllegalArgumentException("Export output directory is missing.")
            if (!parent.exists() && !parent.mkdirs()) {
                throw IllegalStateException("Could not create the export directory.")
            }
            if (outputFile.exists() && !outputFile.delete()) {
                throw IllegalStateException("Could not replace the previous partial export.")
            }

            val renderId = "render_" + java.util.UUID.randomUUID().toString().replace("-", "")
            val mediaItem = MediaItem.Builder()
                .setUri(sourceUri)
                .setClippingConfiguration(
                    MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs(startMs)
                        .setEndPositionMs(endMs)
                        .build()
                )
                .build()
            val reframeTransformation = createReframeTransformation(
                reframeSegments,
                sourceAspectRatio,
                aspectRatio
            )
            val presentation = Presentation.createForAspectRatio(
                aspectRatio,
                Presentation.LAYOUT_STRETCH_TO_FIT
            )
            val videoEffects = mutableListOf<androidx.media3.common.Effect>(
                reframeTransformation,
                presentation
            )
            if (captionStyle != null && captionCues.isNotEmpty()) {
                videoEffects.add(
                    OverlayEffect(
                        listOf(
                            TimedCaptionOverlay(
                                captionCues,
                                captionStyle,
                                captionAnimationId
                            )
                        )
                    )
                )
            }
            val editedItem = EditedMediaItem.Builder(mediaItem)
                .setEffects(
                    Effects(
                        emptyList(),
                        videoEffects
                    )
                )
                .build()

            val transformer = Transformer.Builder(this)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(
                        composition: androidx.media3.transformer.Composition,
                        exportResult: ExportResult
                    ) {
                        val session = renderSessions[renderId] ?: return
                        if (session.cancelRequested || session.status == "cancelled") {
                            if (outputFile.exists()) outputFile.delete()
                            session.status = "cancelled"
                            return
                        }
                        try {
                            val validated = validateRenderedVideo(outputFile, endMs - startMs)
                            val published = publishRenderedVideo(outputFile, clipId)
                            session.result = mapOf(
                                "outputUri" to published.first.toString(),
                                "displayName" to published.second,
                                "sha256" to validated.sha256,
                                "sizeBytes" to validated.sizeBytes,
                                "durationMs" to validated.durationMs,
                                "width" to validated.width,
                                "height" to validated.height,
                                "hasAudio" to validated.hasAudio,
                                "validated" to true
                            )
                            session.progress = 100
                            session.status = "completed"
                            if (outputFile.exists()) outputFile.delete()
                        } catch (error: Exception) {
                            if (outputFile.exists()) outputFile.delete()
                            session.status = "failed"
                            session.error = error.message ?: "Rendered video validation failed."
                        }
                    }

                    override fun onError(
                        composition: androidx.media3.transformer.Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        val session = renderSessions[renderId] ?: return
                        session.status = if (session.cancelRequested) "cancelled" else "failed"
                        session.error = if (session.cancelRequested) "Cancelled by user."
                            else (exportException.message ?: "Media3 export failed.")
                        if (outputFile.exists()) outputFile.delete()
                    }
                })
                .build()
            renderSessions[renderId] = RenderSession(
                id = renderId,
                transformer = transformer,
                progressHolder = ProgressHolder(),
                outputFile = outputFile
            )
            transformer.start(editedItem, outputFile.absolutePath)
            reply.success(mapOf("renderId" to renderId))
        } catch (error: Exception) {
            reply.error("RENDER_START_FAILED", error.message, null)
        }
    }

    private data class ValidatedRender(
        val sha256: String,
        val sizeBytes: Long,
        val durationMs: Long,
        val width: Int,
        val height: Int,
        val hasAudio: Boolean
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
                val word = rawWord as? Map<*>
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
        private val style: CaptionRenderStyle,
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
            val top = (canvas.height * style.positionY - fill.height / 2f)
                .coerceIn(0f, (canvas.height - fill.height).coerceAtLeast(0).toFloat())
            if (style.highlightBoxColor != null) {
                val paddingX = canvas.width * 0.018f
                val paddingY = fill.height * 0.12f
                val rect = RectF(
                    left - paddingX,
                    top - paddingY,
                    left + fill.width + paddingX,
                    top + fill.height + paddingY
                )
                val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = style.highlightBoxColor
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
            val value = if (style.uppercase) cue.text.uppercase(Locale.ROOT) else cue.text
            val styled = SpannableString(value)
            if (animationId == "karaoke_fill" && activeWordIndex >= 0) {
                val word = cue.words[activeWordIndex]
                val start = if (style.uppercase) {
                    cue.text.substring(0, word.startOffset).uppercase(Locale.ROOT).length
                } else {
                    word.startOffset
                }
                val end = if (style.uppercase) {
                    cue.text.substring(0, word.endOffset).uppercase(Locale.ROOT).length
                } else {
                    word.endOffset
                }
                if (start >= 0 && end > start && end <= styled.length) {
                    styled.setSpan(
                        ForegroundColorSpan(style.highlightColor),
                        start,
                        end,
                        SpannableString.SPAN_EXCLUSIVE_EXCLUSIVE
                    )
                }
            }
            val textSize = (canvasHeight * style.fontScale).coerceIn(20f, canvasHeight * 0.12f)
            val typeface = when {
                style.fontFamily.contains("Anton", ignoreCase = true) ->
                    Typeface.create("sans-serif-condensed", if (style.bold) Typeface.BOLD else Typeface.NORMAL)
                style.fontFamily.contains("Medium", ignoreCase = true) ->
                    Typeface.create("sans-serif-medium", Typeface.NORMAL)
                else -> Typeface.create("sans-serif", if (style.bold) Typeface.BOLD else Typeface.NORMAL)
            }
            val maxWidth = (canvasWidth * 0.90f).toInt().coerceAtLeast(120)
            val fillPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                color = style.textColor
                textSize = textSize
                this.typeface = typeface
                style = Paint.Style.FILL
                if (style.shadow > 0f) {
                    setShadowLayer(
                        style.shadow * textSize * 0.12f,
                        0f,
                        style.shadow * textSize * 0.05f,
                        Color.BLACK
                    )
                }
            }
            val outlinePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                color = style.outlineColor
                textSize = textSize
                this.typeface = typeface
                style = Paint.Style.STROKE
                strokeJoin = Paint.Join.ROUND
                strokeWidth = style.outlineWidth * (textSize / 48f)
            }
            cachedFillLayout = buildCaptionLayout(styled, fillPaint, maxWidth)
            cachedOutlineLayout = if (style.outlineWidth > 0f) {
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
            hasAudio = hasAudio
        )
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
                try {
                    if (uri.scheme == "content") extractor.setDataSource(this, uri, null)
                    else extractor.setDataSource(File(uri.path!!).absolutePath)
                    for (index in 0 until extractor.trackCount) {
                        val mime = extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME) ?: continue
                        if (mime.startsWith("video/")) hasVideo = true
                    }
                } finally {
                    try { extractor.release() } catch (_: Exception) { }
                }
                val valid = actualHash == expectedHash &&
                    sizeBytes == expectedSize &&
                    duration == expectedDuration &&
                    width == expectedWidth &&
                    height == expectedHeight &&
                    sizeBytes >= 2048L &&
                    hasVideo
                mainHandler.post {
                    reply.success(
                        mapOf(
                            "valid" to valid,
                            "sha256" to actualHash,
                            "sizeBytes" to sizeBytes,
                            "durationMs" to duration,
                            "width" to width,
                            "height" to height,
                            "hasVideo" to hasVideo
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

    private fun utcNowIso(): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(Date())
    }

    override fun onDestroy() {
        pendingPickerResult = null
        renderSessions.values.filter { it.status == "running" }.forEach { session ->
            try { session.transformer.cancel() } catch (_: Exception) { }
            if (session.outputFile.exists()) session.outputFile.delete()
        }
        renderSessions.clear()
        ioExecutor.shutdown()
        super.onDestroy()
    }
}

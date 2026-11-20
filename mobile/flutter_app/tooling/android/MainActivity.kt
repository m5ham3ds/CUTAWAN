package com.m5ham3ds.cutawan_mobile

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Bitmap
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

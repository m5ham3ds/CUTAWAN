package com.m5ham3ds.cutawan_mobile

import android.content.ContentValues
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
import androidx.media3.effect.TextureOverlay
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
import android.content.Context
import android.content.ContextWrapper
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

@OptIn(UnstableApi::class)
class NativeRenderEngine(context: Context) : ContextWrapper(context.applicationContext) {
    private data class ReframeSegment(
        val startMs: Long, val endMs: Long, val mode: String,
        val x: Float = 0f, val y: Float = 0f,
        val width: Float = 1f, val height: Float = 1f
    )
    private data class CaptionWordCue(val text: String, val startMs: Long, val endMs: Long, val startOffset: Int, val endOffset: Int)
    private data class TimedCaptionCue(val startMs: Long, val endMs: Long, val text: String, val words: List<CaptionWordCue>)
    private data class CaptionRenderStyle(val fontFamily: String, val fontScale: Float, val uppercase: Boolean, val textColor: Int, val highlightColor: Int, val highlightBoxColor: Int?, val outlineColor: Int, val outlineWidth: Float, val shadow: Float, val bold: Boolean, val positionY: Float)

    private fun hasPersistedReadGrant(uri: Uri): Boolean =
        contentResolver.persistedUriPermissions.any { it.uri == uri && it.isReadPermission }

    private fun validateReadableSource(uri: Uri) {
        when (uri.scheme) {
            "content" -> if (!hasPersistedReadGrant(uri)) throw SecurityException("No persistent read permission exists for this video.")
            "file" -> {
                val file = File(uri.path ?: throw IllegalArgumentException("File URI has no path."))
                val canonical = file.canonicalPath
                val filesBase = filesDir.canonicalPath
                val cacheBase = cacheDir.canonicalPath
                val allowed = canonical.startsWith(filesBase + File.separator) || canonical.startsWith(cacheBase + File.separator)
                if (!file.isFile || !allowed) throw SecurityException("Local video is outside Cutawan's private storage.")
            }
            else -> throw IllegalArgumentException("Unsupported video URI scheme.")
        }
    }


    @OptIn(UnstableApi::class)
    fun render(
        request: Map<String, Any?>,
        onProgress: (Int) -> Unit,
        shouldStop: () -> Boolean
    ): Map<String, Any> {
        val rawUri = request["uri"] as? String
            ?: throw IllegalArgumentException("A source URI is required.")
        val clipId = request["clipId"] as? String
            ?: throw IllegalArgumentException("A clip ID is required.")
        val outputPath = request["outputPath"] as? String
            ?: throw IllegalArgumentException("An output path is required.")
        val startMs = (request["startMs"] as? Number)?.toLong()
            ?: throw IllegalArgumentException("A clip start time is required.")
        val endMs = (request["endMs"] as? Number)?.toLong()
            ?: throw IllegalArgumentException("A clip end time is required.")
        val aspectRatio = (request["aspectRatio"] as? Number)?.toFloat()
            ?: throw IllegalArgumentException("An output aspect ratio is required.")
        val sourceAspectRatio = (request["sourceAspectRatio"] as? Number)?.toFloat()
            ?: throw IllegalArgumentException("A source aspect ratio is required.")
        if (!clipId.matches(Regex("^[A-Za-z0-9_-]{1,160}$")) ||
            startMs < 0 || endMs <= startMs ||
            !aspectRatio.isFinite() || aspectRatio <= 0f || aspectRatio > 4f ||
            !sourceAspectRatio.isFinite() || sourceAspectRatio <= 0f || sourceAspectRatio > 8f
        ) {
            throw IllegalArgumentException("Clip ID, range or aspect ratio is invalid.")
        }
        if (shouldStop()) throw InterruptedException("Render was stopped before it started.")

        val reframeSegments = parseReframeSegments(
            request["reframeShots"] as? List<*>,
            endMs - startMs
        )
        val captionCues = parseCaptionCues(
            request["captionCues"] as? List<*>,
            endMs - startMs
        )
        val captionStyle = if (captionCues.isEmpty()) {
            null
        } else {
            parseCaptionStyle(request["captionStyle"] as? Map<*, *>)
        }
        val captionAnimationId = request["captionAnimationId"] as? String ?: "static"
        val fadeInMs = (request["fadeInMs"] as? Number)?.toLong() ?: 0L
        val fadeOutMs = (request["fadeOutMs"] as? Number)?.toLong() ?: 0L
        if (fadeInMs !in 0L..1500L || fadeOutMs !in 0L..1500L ||
            fadeInMs + fadeOutMs > endMs - startMs
        ) {
            throw IllegalArgumentException(
                "Visual fades must be 0–1500ms each and fit inside the selected clip."
            )
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

        val mediaItem = MediaItem.Builder()
            .setUri(sourceUri)
            .setClippingConfiguration(
                MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(startMs)
                    .setEndPositionMs(endMs)
                    .build()
            )
            .build()
        val videoEffects = mutableListOf<androidx.media3.common.Effect>(
            createReframeTransformation(reframeSegments, sourceAspectRatio, aspectRatio),
            Presentation.createForAspectRatio(aspectRatio, Presentation.LAYOUT_STRETCH_TO_FIT)
        )
        val overlays = mutableListOf<TextureOverlay>()
        if (captionStyle != null && captionCues.isNotEmpty()) {
            overlays.add(TimedCaptionOverlay(captionCues, captionStyle, captionAnimationId))
        }
        if (fadeInMs > 0L || fadeOutMs > 0L) {
            overlays.add(TimedBlackFadeOverlay(endMs - startMs, fadeInMs, fadeOutMs))
        }
        if (overlays.isNotEmpty()) {
            videoEffects.add(OverlayEffect(overlays))
        }
        val editedItem = EditedMediaItem.Builder(mediaItem)
            .setEffects(Effects(emptyList(), videoEffects))
            .build()

        val completion = CountDownLatch(1)
        val resultRef = AtomicReference<Map<String, Any>?>(null)
        val errorRef = AtomicReference<Throwable?>(null)
        val validationExecutor = Executors.newSingleThreadExecutor()
        val progressHolder = ProgressHolder()
        val transformer = try {
            runOnMainThread {
                Transformer.Builder(this)
                    .setLooper(Looper.getMainLooper())
                    .setVideoMimeType(MimeTypes.VIDEO_H264)
                    .setAudioMimeType(MimeTypes.AUDIO_AAC)
                    .addListener(object : Transformer.Listener {
                        override fun onCompleted(
                            composition: androidx.media3.transformer.Composition,
                            exportResult: ExportResult
                        ) {
                            validationExecutor.execute {
                                try {
                                    if (shouldStop()) throw InterruptedException("Render was cancelled.")
                                    val validated = validateRenderedVideo(outputFile, endMs - startMs, shouldStop)
                                    if (shouldStop()) throw InterruptedException("Render was cancelled.")
                                    val published = publishRenderedVideo(outputFile, clipId)
                                    if (outputFile.exists()) outputFile.delete()
                                    resultRef.set(
                                        mapOf(
                                            "outputUri" to published.first.toString(),
                                            "displayName" to published.second,
                                            "sha256" to validated.sha256,
                                            "sizeBytes" to validated.sizeBytes,
                                            "durationMs" to validated.durationMs,
                                            "width" to validated.width,
                                            "height" to validated.height,
                                            "hasAudio" to validated.hasAudio,
                                            "fullyDecodeValidated" to true,
                                            "decodedVideoBuffers" to validated.decodedVideoBuffers,
                                            "decodedAudioBuffers" to validated.decodedAudioBuffers,
                                            "validated" to true
                                        )
                                    )
                                } catch (error: Throwable) {
                                    errorRef.set(error)
                                    if (outputFile.exists()) outputFile.delete()
                                } finally {
                                    completion.countDown()
                                }
                            }
                        }

                        override fun onError(
                            composition: androidx.media3.transformer.Composition,
                            exportResult: ExportResult,
                            exportException: ExportException
                        ) {
                            errorRef.set(exportException)
                            if (outputFile.exists()) outputFile.delete()
                            completion.countDown()
                        }
                    })
                    .build()
            }
        } catch (error: Throwable) {
            validationExecutor.shutdownNow()
            throw error
        }

        try {
            runOnMainThread { transformer.start(editedItem, outputFile.absolutePath) }
            onProgress(0)
            while (true) {
                if (completion.await(500, TimeUnit.MILLISECONDS)) break
                if (shouldStop()) {
                    runOnMainThread { try { transformer.cancel() } catch (_: Exception) { } }
                    if (outputFile.exists()) outputFile.delete()
                    throw InterruptedException("Render was cancelled.")
                }
                val progress = try {
                    runOnMainThread {
                        if (transformer.getProgress(progressHolder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                            progressHolder.progress.coerceIn(0, 99)
                        } else {
                            -1
                        }
                    }
                } catch (_: IllegalStateException) {
                    -1
                }
                if (progress >= 0) onProgress(progress)
            }
            errorRef.get()?.let { throw it }
            return resultRef.get()
                ?: throw IllegalStateException("Media3 completed without a validated render result.")
        } catch (error: Throwable) {
            try { runOnMainThread { transformer.cancel() } } catch (_: Exception) { }
            if (outputFile.exists()) outputFile.delete()
            throw error
        } finally {
            validationExecutor.shutdown()
        }
    }

    private fun <T> runOnMainThread(block: () -> T): T {
        if (Looper.myLooper() == Looper.getMainLooper()) return block()
        val latch = CountDownLatch(1)
        val value = AtomicReference<T?>()
        val failure = AtomicReference<Throwable?>()
        mainHandler.post {
            try {
                value.set(block())
            } catch (error: Throwable) {
                failure.set(error)
            } finally {
                latch.countDown()
            }
        }
        var interrupted = false
        try {
            val deadline = SystemClock.elapsedRealtime() + 30_000L
            while (latch.count > 0L) {
                val remaining = deadline - SystemClock.elapsedRealtime()
                if (remaining <= 0L) {
                    throw IllegalStateException("Timed out waiting for the Media3 application looper.")
                }
                try {
                    latch.await(remaining, TimeUnit.MILLISECONDS)
                } catch (_: InterruptedException) {
                    // A WorkManager stop interrupts the worker thread. Still run
                    // Transformer.cancel on its owning looper before propagating it.
                    interrupted = true
                }
            }
            failure.get()?.let { throw it }
            @Suppress("UNCHECKED_CAST")
            return value.get() as T
        } finally {
            if (interrupted) Thread.currentThread().interrupt()
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())


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

    private class TimedBlackFadeOverlay(
        private val durationMs: Long,
        private val fadeInMs: Long,
        private val fadeOutMs: Long
    ) : CanvasOverlay(true) {
        override fun onDraw(canvas: Canvas, presentationTimeUs: Long) {
            val timeMs = (presentationTimeUs / 1000L).coerceAtLeast(0L)
            var opacity = 0f
            if (fadeInMs > 0L) {
                val incoming = (1f - timeMs.toFloat() / fadeInMs.toFloat())
                    .coerceIn(0f, 1f)
                opacity = maxOf(opacity, incoming)
            }
            if (fadeOutMs > 0L) {
                val fadeOutStartMs = durationMs - fadeOutMs
                val outgoing = ((timeMs - fadeOutStartMs).toFloat() / fadeOutMs.toFloat())
                    .coerceIn(0f, 1f)
                opacity = maxOf(opacity, outgoing)
            }
            val alpha = (opacity * 255f).toInt().coerceIn(0, 255)
            if (alpha == 0) return
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(alpha, 0, 0, 0)
                style = Paint.Style.FILL
            }
            canvas.drawRect(0f, 0f, canvas.width.toFloat(), canvas.height.toFloat(), paint)
        }
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

    private fun validateRenderedVideo(output: File, expectedDurationMs: Long, shouldStop: () -> Boolean): ValidatedRender {
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
        val decode = decodeMediaFully(Uri.fromFile(output), shouldStop)
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
    private fun decodeMediaFully(uri: Uri, shouldStop: () -> Boolean = { false }): FullDecodeSummary {
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
            decodedVideoBuffers += decodeTrackFully(uri, trackIndex, shouldStop).outputBufferCount
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

    private fun decodeTrackFully(uri: Uri, trackIndex: Int, shouldStop: () -> Boolean = { false }): TrackDecodeStats {
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
                if (shouldStop()) throw InterruptedException("Full media validation was cancelled.")
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
}

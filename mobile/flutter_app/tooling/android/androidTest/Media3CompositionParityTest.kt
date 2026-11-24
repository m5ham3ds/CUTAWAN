package com.m5ham3ds.cutawan_mobile

import android.graphics.Color
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.media3.common.util.UnstableApi
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class Media3CompositionParityTest {
    @OptIn(UnstableApi::class)
    @Test
    fun dipToBlackTransitionIsRenderedIntoTheMp4Frames() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val fixture = File(context.filesDir, "media3-red-blue-fixture.mp4")
        val output = File(context.filesDir, "exports/media3-transition-parity.mp4")
        var publishedUri: Uri? = null
        var retriever: MediaMetadataRetriever? = null

        try {
            fixture.outputStream().use { destination ->
                instrumentation.context.assets.open("red-blue-transition.mp4").use { source ->
                    source.copyTo(destination)
                }
            }
            output.parentFile?.mkdirs()

            val sourceUri = Uri.fromFile(fixture).toString()
            val result = NativeRenderEngine(context).render(
                request = mapOf(
                    "renderType" to "composition",
                    "projectId" to "parity_project",
                    "clipId" to "parity_composition",
                    "outputPath" to output.absolutePath,
                    "sourceDurationMs" to 2000,
                    "expectedDurationMs" to 2000,
                    "aspectRatio" to (4.0 / 3.0),
                    "tracks" to listOf(
                        mapOf(
                            "id" to "track_video_main",
                            "type" to "video",
                            "clips" to listOf(
                                mapOf(
                                    "itemId" to "item_video_001",
                                    "candidateId" to "clip_001",
                                    "sourceUri" to sourceUri,
                                    "sourceStartMs" to 0,
                                    "sourceEndMs" to 1000,
                                    "timelineStartMs" to 0,
                                    "transitionAfter" to mapOf(
                                        "type" to "dipToBlack",
                                        "durationMs" to 600,
                                    ),
                                ),
                                mapOf(
                                    "itemId" to "item_video_002",
                                    "candidateId" to "clip_002",
                                    "sourceUri" to sourceUri,
                                    "sourceStartMs" to 1000,
                                    "sourceEndMs" to 2000,
                                    "timelineStartMs" to 1000,
                                ),
                            ),
                        ),
                    ),
                ),
                onProgress = { },
                shouldStop = { false },
            )

            assertEquals(true, result["validated"])
            assertEquals(true, result["fullyDecodeValidated"])
            assertEquals(2000L, (result["durationMs"] as Number).toLong())
            assertEquals(160, (result["width"] as Number).toInt())
            assertEquals(120, (result["height"] as Number).toInt())

            val outputUri = Uri.parse(result["outputUri"] as String)
            publishedUri = outputUri
            retriever = MediaMetadataRetriever().apply {
                setDataSource(context, outputUri)
            }

            fun sampleCenter(timeMs: Long): Int {
                val frame = assertNotNullFrame(
                    retriever?.getFrameAtTime(
                        timeMs * 1000L,
                        MediaMetadataRetriever.OPTION_CLOSEST,
                    ),
                    timeMs,
                )
                return try {
                    frame.getPixel(frame.width / 2, frame.height / 2)
                } finally {
                    frame.recycle()
                }
            }

            val redBeforeTransition = sampleCenter(200)
            val redDuringFadeOut = sampleCenter(866)
            val transitionJoin = sampleCenter(1000)
            val blueDuringFadeIn = sampleCenter(1133)
            val blueAfterTransition = sampleCenter(1800)

            assertTrue(
                "Expected a bright red frame before the transition, got ${describe(redBeforeTransition)}",
                Color.red(redBeforeTransition) > 150 &&
                    Color.green(redBeforeTransition) < 90 &&
                    Color.blue(redBeforeTransition) < 90,
            )
            assertTrue(
                "Expected a dimmed red frame during fade-out, got ${describe(redDuringFadeOut)}",
                Color.red(redDuringFadeOut) in 25..210 &&
                    Color.green(redDuringFadeOut) < 90 &&
                    Color.blue(redDuringFadeOut) < 90,
            )
            assertTrue(
                "Expected a near-black frame at the transition join, got ${describe(transitionJoin)}",
                maxOf(
                    Color.red(transitionJoin),
                    Color.green(transitionJoin),
                    Color.blue(transitionJoin),
                ) < 80,
            )
            assertTrue(
                "Expected a dimmed blue frame during fade-in, got ${describe(blueDuringFadeIn)}",
                Color.blue(blueDuringFadeIn) in 25..210 &&
                    Color.red(blueDuringFadeIn) < 90 &&
                    Color.green(blueDuringFadeIn) < 90,
            )
            assertTrue(
                "Expected a bright blue frame after the transition, got ${describe(blueAfterTransition)}",
                Color.blue(blueAfterTransition) > 150 &&
                    Color.red(blueAfterTransition) < 90 &&
                    Color.green(blueAfterTransition) < 90,
            )
        } finally {
            try {
                retriever?.release()
            } catch (_: Exception) {
            }
            publishedUri?.let { uri ->
                try {
                    context.contentResolver.delete(uri, null, null)
                } catch (_: Exception) {
                }
            }
            if (output.exists()) output.delete()
            if (fixture.exists()) fixture.delete()
        }
    }

    private fun assertNotNullFrame(frame: android.graphics.Bitmap?, timeMs: Long): android.graphics.Bitmap {
        assertNotNull("Media3 export has no decodable frame at ${timeMs}ms", frame)
        return frame!!
    }

    private fun describe(color: Int): String =
        "R=${Color.red(color)}, G=${Color.green(color)}, B=${Color.blue(color)}"
}

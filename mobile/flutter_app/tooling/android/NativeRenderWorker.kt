package com.m5ham3ds.cutawan_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.ServiceInfo
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.Data
import androidx.work.ForegroundInfo
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

object NativeRenderStore {
    private const val ROOT = "cutawan_renders"

    fun requestFile(context: Context, renderId: String): File {
        require(renderId.matches(Regex("^[a-f0-9-]{36}$"))) { "Render identity is invalid." }
        return File(File(context.filesDir, "$ROOT/requests"), "$renderId.json")
    }

    fun completionFile(context: Context, renderKey: String): File {
        validateKey(renderKey)
        return File(File(context.filesDir, "$ROOT/completed"), "$renderKey.json")
    }

    fun keyFile(context: Context, renderKey: String): File {
        validateKey(renderKey)
        return File(File(context.filesDir, "$ROOT/keys"), "$renderKey.txt")
    }

    fun uniqueWorkName(renderKey: String): String {
        validateKey(renderKey)
        return "cutawan-render-$renderKey"
    }

    fun writeRequest(context: Context, renderId: String, request: Map<String, Any?>) {
        writeJsonAtomic(requestFile(context, renderId), JSONObject(request))
    }

    fun readRequest(context: Context, renderId: String): Map<String, Any?> {
        require(renderId.matches(Regex("^[a-f0-9-]{36}$"))) { "Render identity is invalid." }
        val file = requestFile(context, renderId)
        if (!file.isFile) throw IllegalStateException("The persisted render request is missing.")
        return JSONObject(file.readText()).toMap()
    }

    fun writeCompletion(
        context: Context,
        renderKey: String,
        renderId: String,
        result: Map<String, Any>
    ) {
        val payload = JSONObject(result)
            .put("renderId", renderId)
            .put("renderKey", renderKey)
            .put("completedAtUtcMs", System.currentTimeMillis())
        writeJsonAtomic(completionFile(context, renderKey), payload)
    }

    fun readCompletion(context: Context, renderKey: String): Map<String, Any?>? {
        val file = completionFile(context, renderKey)
        if (!file.isFile) return null
        return JSONObject(file.readText()).toMap()
    }

    fun decodeJson(value: String): Map<String, Any?> = JSONObject(value).toMap()

    fun acknowledgeCompletion(
        context: Context,
        renderKey: String,
        expectedSha256: String
    ): Boolean {
        val payload = readCompletion(context, renderKey) ?: return false
        if (payload["sha256"] != expectedSha256) return false
        completionFile(context, renderKey).delete()
        keyFile(context, renderKey).delete()
        val renderId = payload["renderId"] as? String
        if (!renderId.isNullOrBlank()) requestFile(context, renderId).delete()
        return true
    }

    fun writeKey(context: Context, renderKey: String, renderId: String) {
        writeTextAtomic(keyFile(context, renderKey), renderId)
    }

    fun readKey(context: Context, renderKey: String): String? {
        val file = keyFile(context, renderKey)
        return if (file.isFile) file.readText().trim().takeIf { it.isNotEmpty() } else null
    }

    fun cleanFailedRequest(context: Context, renderKey: String, renderId: String) {
        keyFile(context, renderKey).delete()
        requestFile(context, renderId).delete()
        completionFile(context, renderKey).delete()
    }

    private fun validateKey(value: String) {
        require(value.matches(Regex("^[a-f0-9]{64}$"))) {
            "Render key must be a SHA-256 fingerprint."
        }
    }

    private fun writeJsonAtomic(target: File, value: JSONObject) {
        val temp = File(target.parentFile ?: throw IllegalStateException("Render storage directory is missing."), target.name + ".tmp")
        val parent = target.parentFile ?: throw IllegalStateException("Render storage directory is missing.")
        if (!parent.exists() && !parent.mkdirs()) {
            throw IllegalStateException("Could not create durable render storage.")
        }
        temp.writeText(value.toString())
        if (target.exists() && !target.delete()) {
            throw IllegalStateException("Could not replace durable render state.")
        }
        if (!temp.renameTo(target)) {
            temp.delete()
            throw IllegalStateException("Could not commit durable render state.")
        }
    }

    private fun writeTextAtomic(target: File, value: String) {
        val temp = File(target.parentFile ?: throw IllegalStateException("Render storage directory is missing."), target.name + ".tmp")
        val parent = target.parentFile ?: throw IllegalStateException("Render storage directory is missing.")
        if (!parent.exists() && !parent.mkdirs()) {
            throw IllegalStateException("Could not create durable render storage.")
        }
        temp.writeText(value)
        if (target.exists() && !target.delete()) {
            throw IllegalStateException("Could not replace durable render identity.")
        }
        if (!temp.renameTo(target)) {
            temp.delete()
            throw IllegalStateException("Could not commit durable render identity.")
        }
    }

    private fun JSONObject.toMap(): Map<String, Any?> {
        val result = linkedMapOf<String, Any?>()
        val keys = keys()
        while (keys.hasNext()) {
            val key = keys.next()
            result[key] = toPlainValue(opt(key))
        }
        return result
    }

    private fun toPlainValue(value: Any?): Any? = when (value) {
        JSONObject.NULL -> null
        is JSONObject -> value.toMap()
        is JSONArray -> (0 until value.length()).map { toPlainValue(value.opt(it)) }
        else -> value
    }
}

class NativeRenderWorker(
    context: Context,
    parameters: WorkerParameters
) : Worker(context, parameters) {

    override fun doWork(): Result {
        val renderId = inputData.getString(KEY_RENDER_ID)
            ?: return Result.failure(errorData("Render identity is missing."))
        val renderKey = inputData.getString(KEY_RENDER_KEY)
            ?: return Result.failure(errorData("Render fingerprint is missing."))
        val projectId = inputData.getString(KEY_PROJECT_ID)
            ?: return Result.failure(errorData("Project identity is missing."))
        if (!projectId.matches(Regex("^[A-Za-z0-9_-]{1,160}$"))) {
            return Result.failure(errorData("Project identity is invalid."))
        }

        return try {
            setForegroundAsync(foregroundInfo(0)).get(30, TimeUnit.SECONDS)
            val previous = NativeRenderStore.readCompletion(applicationContext, renderKey)
            if (previous != null) {
                return Result.success(
                    Data.Builder()
                        .putString(KEY_RESULT_JSON, JSONObject(previous).toString())
                        .putInt(KEY_PROGRESS, 100)
                        .build()
                )
            }
            val request = NativeRenderStore.readRequest(applicationContext, renderId)
            val engine = NativeRenderEngine(applicationContext)
            val result = engine.render(
                request = request,
                onProgress = { progress ->
                    val value = progress.coerceIn(0, 100)
                    setProgressAsync(Data.Builder().putInt(KEY_PROGRESS, value).build())
                    setForegroundAsync(foregroundInfo(value))
                },
                shouldStop = { isStopped || Thread.currentThread().isInterrupted }
            )
            if (isStopped) {
                throw InterruptedException("Render was cancelled.")
            }
            NativeRenderStore.writeCompletion(applicationContext, renderKey, renderId, result)
            Result.success(
                Data.Builder()
                    .putString(KEY_RESULT_JSON, JSONObject(result).toString())
                    .putInt(KEY_PROGRESS, 100)
                    .build()
            )
        } catch (error: InterruptedException) {
            Thread.currentThread().interrupt()
            Result.failure(errorData(error.message ?: "Render was cancelled."))
        } catch (error: Throwable) {
            Result.failure(errorData(error.message ?: "Background video export failed."))
        }
    }

    private fun errorData(message: String): Data =
        Data.Builder().putString(KEY_ERROR, message.take(1500)).build()

    private fun foregroundInfo(progress: Int): ForegroundInfo {
        ensureNotificationChannel()
        val cancelIntent = WorkManager.getInstance(applicationContext).createCancelPendingIntent(id)
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentTitle("CUTAWAN — تصدير الفيديو")
            .setContentText(
                if (progress <= 0) "جارٍ تجهيز التصدير"
                else "جارٍ إخراج المقطع · $progress%"
            )
            .setProgress(100, progress.coerceIn(0, 100), false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "إلغاء التصدير",
                cancelIntent
            )
            .build()
        val type = if (Build.VERSION.SDK_INT >= 35) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        } else {
            0
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ForegroundInfo(NOTIFICATION_ID, notification, type)
        } else {
            ForegroundInfo(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "تصدير الفيديو",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "حالة تصدير المقاطع في CUTAWAN"
                setShowBadge(false)
            }
        )
    }

    companion object {
        const val KEY_RENDER_ID = "renderId"
        const val KEY_RENDER_KEY = "renderKey"
        const val KEY_PROJECT_ID = "projectId"
        const val KEY_RESULT_JSON = "resultJson"
        const val KEY_ERROR = "error"
        const val KEY_PROGRESS = "progress"
        private const val CHANNEL_ID = "cutawan_video_exports"
        private const val NOTIFICATION_ID = 4109
    }
}

package com.smartbroker.smart_broker

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Microphone audio for offline dictation: 16 kHz mono 16-bit PCM, sent to
 * Flutter in ~100 ms chunks over an EventChannel while listening. Also answers
 * the device questions the dictation setup needs (RAM, free storage).
 *
 * Audio never leaves the phone: Dart feeds it straight to the on-device model.
 */
class DictationAudioPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val METHOD_CHANNEL = "smart_broker/dictation"
        private const val EVENT_CHANNEL = "smart_broker/dictation_audio"
        private const val PERMISSION_REQUEST_CODE = 8002
        private const val SAMPLE_RATE = 16000
        private const val CHUNK_SAMPLES = SAMPLE_RATE / 10 // 100 ms
    }

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var context: Context? = null
    private var activity: Activity? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private var events: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var recording = false
    private var recorder: AudioRecord? = null
    private var thread: Thread? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).also { it.setMethodCallHandler(this) }
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).also { it.setStreamHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopRecording()
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasMicPermission" -> result.success(hasMicPermission())
            "requestMicPermission" -> requestMicPermission(result)
            "deviceInfo" -> result.success(deviceInfo(call.argument<String>("path")))
            else -> result.notImplemented()
        }
    }

    private fun hasMicPermission(): Boolean {
        val ctx = context ?: return false
        return ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestMicPermission(result: MethodChannel.Result) {
        if (hasMicPermission()) {
            result.success(true)
            return
        }
        val act = activity ?: run {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }
        pendingPermissionResult?.success(false)
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(act, arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION_REQUEST_CODE)
    }

    /** Total RAM and free bytes on the volume holding [path] (the model's folder). */
    private fun deviceInfo(path: String?): Map<String, Any> {
        val info = mutableMapOf<String, Any>()
        val ctx = context
        if (ctx != null) {
            val am = ctx.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val mem = ActivityManager.MemoryInfo()
            am.getMemoryInfo(mem)
            info["totalRamBytes"] = mem.totalMem
        }
        try {
            val stat = StatFs(path ?: ctx?.filesDir?.path ?: "/data")
            info["freeStorageBytes"] = stat.availableBytes
        } catch (_: IllegalArgumentException) {
        }
        info["supportedAbis"] = android.os.Build.SUPPORTED_ABIS.toList()
        return info
    }

    // ── Audio stream: listening starts when Dart subscribes, stops when it cancels ──

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.events = events
        if (!hasMicPermission()) {
            events?.error("NO_PERMISSION", "Microphone permission not granted", null)
            return
        }
        startRecording()
    }

    override fun onCancel(arguments: Any?) {
        stopRecording()
        events = null
    }

    @SuppressLint("MissingPermission") // checked in onListen
    private fun startRecording() {
        if (recording) return
        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        val rec = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuffer, CHUNK_SAMPLES * 2 * 4)
            )
        } catch (e: Exception) {
            events?.error("MIC_UNAVAILABLE", e.message, null)
            return
        }
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            rec.release()
            events?.error("MIC_UNAVAILABLE", "The microphone is in use or unavailable", null)
            return
        }
        recorder = rec
        recording = true
        rec.startRecording()
        thread = Thread({
            val buffer = ByteArray(CHUNK_SAMPLES * 2)
            while (recording) {
                var filled = 0
                while (recording && filled < buffer.size) {
                    val n = rec.read(buffer, filled, buffer.size - filled)
                    if (n <= 0) break
                    filled += n
                }
                if (filled > 0) {
                    val chunk = buffer.copyOf(filled)
                    mainHandler.post { events?.success(chunk) }
                }
                if (filled == 0 && recording) {
                    mainHandler.post { events?.error("MIC_READ_FAILED", "The microphone stopped delivering audio", null) }
                    break
                }
            }
        }, "dictation-audio").also { it.start() }
    }

    private fun stopRecording() {
        recording = false
        thread?.join(500)
        thread = null
        recorder?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
            }
            it.release()
        }
        recorder = null
    }

    // ── ActivityAware ──

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
        return true
    }
}

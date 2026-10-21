package com.smartbroker.smart_broker

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class CallDetectionPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val METHOD_CHANNEL = "smart_broker/call_detection"
        private const val EVENT_CHANNEL = "smart_broker/call_events"
        private const val PERMISSION_REQUEST_CODE = 8001
    }

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var context: Context? = null
    private var activity: Activity? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    // ── FlutterPlugin ──────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        context = null
    }

    // ── MethodChannel handler ──────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startService" -> {
                val ctx = context ?: run {
                    result.error("NO_CONTEXT", "Context not available", null)
                    return
                }
                val intent = Intent(ctx, CallDetectionService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ctx.startForegroundService(intent)
                } else {
                    ctx.startService(intent)
                }
                result.success(true)
            }

            "stopService" -> {
                val ctx = context ?: run {
                    result.error("NO_CONTEXT", "Context not available", null)
                    return
                }
                ctx.stopService(Intent(ctx, CallDetectionService::class.java))
                result.success(true)
            }

            "isServiceRunning" -> {
                result.success(CallDetectionService.isRunning)
            }

            "requestPermission" -> {
                val act = activity
                if (act == null) {
                    result.error("NO_ACTIVITY", "Activity not available", null)
                    return
                }

                val hasPhoneState = ContextCompat.checkSelfPermission(act, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
                val hasCallLog = ContextCompat.checkSelfPermission(act, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED

                if (hasPhoneState && hasCallLog) {
                    result.success(true)
                    return
                }

                pendingPermissionResult = result
                ActivityCompat.requestPermissions(
                    act,
                    arrayOf(Manifest.permission.READ_PHONE_STATE, Manifest.permission.READ_CALL_LOG),
                    PERMISSION_REQUEST_CODE
                )
            }

            "isPermissionGranted" -> {
                val ctx = context ?: run {
                    result.error("NO_CONTEXT", "Context not available", null)
                    return
                }
                val granted = ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED &&
                              ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
                result.success(granted)
            }

            // Opens the phone's dialer with the number filled in; the person
            // presses call themselves, so no CALL_PHONE permission is needed.
            "dial" -> {
                val number = call.argument<String>("number").orEmpty()
                val ctx: Context? = activity ?: context
                if (ctx == null || number.isBlank()) {
                    result.success(false)
                    return
                }
                val intent = Intent(Intent.ACTION_DIAL, android.net.Uri.fromParts("tel", number, null))
                if (activity == null) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    ctx.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }

            // Opens the phone's messaging app with a new message to the number.
            "text" -> {
                val number = call.argument<String>("number").orEmpty()
                val ctx: Context? = activity ?: context
                if (ctx == null || number.isBlank()) {
                    result.success(false)
                    return
                }
                val intent = Intent(Intent.ACTION_SENDTO, android.net.Uri.fromParts("smsto", number, null))
                if (activity == null) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    ctx.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }

            else -> result.notImplemented()
        }
    }

    // ── EventChannel (stream call events to Flutter) ───────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        CallDetectionService.eventSink = { data ->
            activity?.runOnUiThread {
                events?.success(data)
            } ?: events?.success(data)
        }
    }

    override fun onCancel(arguments: Any?) {
        CallDetectionService.eventSink = null
    }

    // ── ActivityAware ──────────────────────────────────────────────

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

    // ── Permission result ──────────────────────────────────────────

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            // Both READ_PHONE_STATE and READ_CALL_LOG are needed.
            val granted = grantResults.isNotEmpty() &&
                    grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
            return true
        }
        return false
    }
}

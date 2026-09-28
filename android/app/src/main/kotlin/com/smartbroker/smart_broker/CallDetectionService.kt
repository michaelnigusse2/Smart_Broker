package com.smartbroker.smart_broker

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.CallLog
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class CallDetectionService : Service() {

    companion object {
        private const val TAG = "CallDetectionService"
        private const val CHANNEL_ID = "call_detection_channel"
        private const val NOTIFICATION_ID = 9001
        
        var eventSink: ((Map<String, Any>) -> Unit)? = null
    }

    private var telephonyManager: TelephonyManager? = null

    // State tracking
    private var lastState = TelephonyManager.CALL_STATE_IDLE
    private var lastProcessedCallDate: Long = 0

    // Listeners (one or the other depending on API level)
    private var legacyListener: PhoneStateListener? = null
    private var telephonyCallback: TelephonyCallback? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        registerListener()
        Log.d(TAG, "Service created and listener registered")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        unregisterListener()
        Log.d(TAG, "Service destroyed and listener unregistered")
        super.onDestroy()
    }

    private fun registerListener() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            registerModernListener()
        } else {
            registerLegacyListener()
        }
    }

    private fun unregisterListener() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyCallback?.let {
                telephonyManager?.unregisterTelephonyCallback(it)
            }
        } else {
            @Suppress("DEPRECATION")
            legacyListener?.let {
                telephonyManager?.listen(it, PhoneStateListener.LISTEN_NONE)
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun registerModernListener() {
        val callback = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
            override fun onCallStateChanged(state: Int) {
                handleCallState(state)
            }
        }
        telephonyCallback = callback
        telephonyManager?.registerTelephonyCallback(mainExecutor, callback)
    }

    @Suppress("DEPRECATION")
    private fun registerLegacyListener() {
        val listener = object : PhoneStateListener() {
            override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                handleCallState(state)
            }
        }
        legacyListener = listener
        telephonyManager?.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
    }

    private fun handleCallState(state: Int) {
        val stateStr = when(state) {
            TelephonyManager.CALL_STATE_RINGING -> "ringing"
            TelephonyManager.CALL_STATE_OFFHOOK -> "offhook"
            TelephonyManager.CALL_STATE_IDLE -> "idle"
            else -> "unknown"
        }
        Handler(Looper.getMainLooper()).post {
            eventSink?.invoke(mapOf("event" to "state", "state" to stateStr))
        }

        if (state == TelephonyManager.CALL_STATE_IDLE && lastState != TelephonyManager.CALL_STATE_IDLE) {
            // Call just ended. Wait 1.5 seconds for the system to write to the CallLog
            Handler(Looper.getMainLooper()).postDelayed({
                fetchLastCallFromLog()
            }, 1500)
        }
        lastState = state
    }

    private fun fetchLastCallFromLog() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            Log.e(TAG, "READ_CALL_LOG permission not granted")
            return
        }

        try {
            val cursor = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.TYPE, CallLog.Calls.DURATION, CallLog.Calls.DATE),
                null,
                null,
                CallLog.Calls.DATE + " DESC"
            )

            cursor?.use {
                if (it.moveToFirst()) {
                    val number = it.getString(0) ?: ""
                    val typeInt = it.getInt(1)
                    val duration = it.getInt(2)
                    val date = it.getLong(3)

                    // Dedup guard: ignore if we already processed this exact call log entry
                    if (date <= lastProcessedCallDate) {
                        Log.d(TAG, "Dedup: already processed this call log entry")
                        return
                    }
                    lastProcessedCallDate = date

                    val callType = when (typeInt) {
                        CallLog.Calls.INCOMING_TYPE -> "incoming"
                        CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                        CallLog.Calls.MISSED_TYPE, CallLog.Calls.REJECTED_TYPE -> "missed"
                        else -> "missed" // fallback
                    }

                    val eventData = mapOf<String, Any>(
                        "event" to "call_logged",
                        "phoneNumber" to number,
                        "type" to callType,
                        "duration" to duration,
                        "timestamp" to date
                    )

                    Log.d(TAG, "Call ended (from log): $eventData")
                    eventSink?.invoke(eventData)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query CallLog", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Detection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors phone calls for automatic logging"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SmartBroker")
            .setContentText("Call detection active")
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}

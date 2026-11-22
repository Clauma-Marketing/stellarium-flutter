package com.starregistration.planetarium

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hands tapped Klaviyo notifications to Dart.
 *
 * Klaviyo's push service builds the notification itself and reopens this
 * activity with the push payload as "com.klaviyo."-prefixed intent extras.
 * firebase_messaging does not treat that as an opened message, so without
 * this the open is never tracked and the payload never reaches the app.
 * KlaviyoService (Dart) takes the payload once Klaviyo is initialised.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingPush: HashMap<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "takePendingPush") {
                    result.success(pendingPush)
                    pendingPush = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A restored activity is handed its original intent again.
        if (savedInstanceState == null) capturePush(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        capturePush(intent)
    }

    private fun capturePush(intent: Intent?) {
        if (intent == null) return
        // Reopening from recents replays the intent that first started the task.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val extras = intent.extras ?: return

        val payload = HashMap<String, String>()
        for (key in extras.keySet()) {
            if (!key.startsWith(KLAVIYO_PREFIX)) continue
            val value = extras.getString(key) ?: continue
            payload[key.removePrefix(KLAVIYO_PREFIX)] = value
        }
        if (!payload.containsKey(KLAVIYO_TRACKING_KEY)) return

        // Count each tap once, even if this intent is delivered again.
        intent.removeExtra(KLAVIYO_PREFIX + KLAVIYO_TRACKING_KEY)
        pendingPush = payload
        // Reaches Dart only if it is already listening; otherwise Dart takes
        // the payload when it starts.
        channel?.invokeMethod("onPushOpened", null)
    }

    private companion object {
        const val CHANNEL = "com.starregistration.planetarium/klaviyo_push"
        const val KLAVIYO_PREFIX = "com.klaviyo."
        const val KLAVIYO_TRACKING_KEY = "_k"
    }
}

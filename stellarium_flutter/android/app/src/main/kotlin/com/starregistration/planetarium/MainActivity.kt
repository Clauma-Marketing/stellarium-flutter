package com.starregistration.planetarium

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hands tapped Klaviyo notifications to Dart and opens their web links.
 *
 * Klaviyo's push service builds the notification itself and reopens this
 * activity with the push payload as "com.klaviyo."-prefixed intent extras.
 * firebase_messaging does not treat that as an opened message, so without
 * this the open is never tracked and the payload never reaches the app.
 * KlaviyoService (Dart) takes the payload once Klaviyo is initialised.
 *
 * A push with a web link in Klaviyo's "Android deep link" field arrives as a
 * VIEW intent for that link (see the intent filter in AndroidManifest.xml).
 * The link is opened in the browser here, straight away, so it also works
 * when the tap starts the app.
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

    // The web links this activity receives belong in the browser; they are not
    // Flutter routes, and Flutter would report each one as an unknown route.
    override fun shouldHandleDeeplinking(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A restored activity is handed its original intent again.
        if (savedInstanceState == null) handleLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleLaunchIntent(intent)
    }

    private fun handleLaunchIntent(intent: Intent?) {
        if (intent == null) return
        // Reopening from recents replays the intent that first started the task.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return

        capturePush(intent)
        openWebLink(intent)
    }

    private fun capturePush(intent: Intent) {
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

    private fun openWebLink(intent: Intent) {
        if (intent.action != Intent.ACTION_VIEW) return
        val link: Uri = intent.data ?: return
        if (link.scheme != "https" && link.scheme != "http") return

        // Open each link once, even if this intent is delivered again.
        intent.data = null

        // CATEGORY_BROWSABLE keeps this from resolving back to this activity,
        // whose intent filter deliberately does not declare it.
        val browse = Intent(Intent.ACTION_VIEW, link)
            .addCategory(Intent.CATEGORY_BROWSABLE)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(browse)
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "No browser available to open a push link")
        }
    }

    private companion object {
        const val TAG = "MainActivity"
        const val CHANNEL = "com.starregistration.planetarium/klaviyo_push"
        const val KLAVIYO_PREFIX = "com.klaviyo."
        const val KLAVIYO_TRACKING_KEY = "_k"
    }
}

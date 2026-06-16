package com.scrolliq.app.reelcounter

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges [ReelCounterStore] + the AccessibilityService permission flow + the
 * overlay HUD lifecycle to Flutter.
 *
 *  com.scrolliq/reel_counter         (MethodChannel)
 *    isAccessibilityEnabled()        -> Boolean
 *    openAccessibilitySettings()     -> null
 *    canDrawOverlays()               -> Boolean
 *    openOverlaySettings()           -> null
 *    isOverlayRunning()              -> Boolean
 *    startOverlay()                  -> Boolean (true if launch attempted)
 *    stopOverlay()                   -> null
 *    isBatteryOptimizationIgnored()  -> Boolean
 *    openBatterySettings()           -> null
 *    getSnapshot()                   -> Map { date, total, perApp, ts }
 *    getHistory(days: Int)           -> List<Map { date, total, perApp }>
 *    reset()                         -> null
 *
 *  com.scrolliq/reel_counter/stream  (EventChannel)
 *    Emits the snapshot map every time the store mutates.
 */
class ReelCounterPlugin(
    private val appContext: Context,
    binaryMessenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannel = MethodChannel(binaryMessenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(binaryMessenger, EVENT_CHANNEL)

    private var eventSink: EventChannel.EventSink? = null
    private val listener = ReelCounterStore.Listener { snapshot ->
        eventSink?.success(snapshot.toMap())
    }

    init {
        ReelCounterStore.init(appContext)
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        ReelCounterStore.removeListener(listener)
        eventSink = null
    }

    // ---- MethodChannel --------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAccessibilityEnabled" ->
                result.success(ReelCounterAccessibilityService.isEnabled(appContext))

            "openAccessibilitySettings" -> {
                appContext.startActivity(
                    Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                result.success(null)
            }

            "canDrawOverlays" -> result.success(Settings.canDrawOverlays(appContext))

            "openOverlaySettings" -> {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:" + appContext.packageName),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                appContext.startActivity(intent)
                result.success(null)
            }

            "isOverlayRunning" -> result.success(OverlayService.isRunning())

            "startOverlay" -> {
                if (!Settings.canDrawOverlays(appContext)) {
                    result.success(false)
                } else {
                    OverlayService.start(appContext)
                    result.success(true)
                }
            }

            "stopOverlay" -> {
                OverlayService.stop(appContext)
                result.success(null)
            }

            "isBatteryOptimizationIgnored" -> {
                val pm = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
                val ignored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    pm.isIgnoringBatteryOptimizations(appContext.packageName)
                } else true
                result.success(ignored)
            }

            "openBatterySettings" -> {
                // Best-effort: deeplink to the per-app battery exemption prompt.
                // Falls back to the generic battery-optimization list if the
                // direct intent isn't available on the OEM ROM.
                val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    .setData(Uri.parse("package:" + appContext.packageName))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    appContext.startActivity(direct)
                } catch (_: Throwable) {
                    appContext.startActivity(fallback)
                }
                result.success(null)
            }

            "getSnapshot" -> result.success(ReelCounterStore.snapshot().toMap())

            "getHistory" -> {
                val days = (call.argument<Int>("days") ?: 7).coerceIn(1, 30)
                val history = ReelCounterStore.history(days)
                val out = history.map { (date, perApp) ->
                    mapOf(
                        "date" to date,
                        "total" to perApp.values.sum(),
                        "perApp" to perApp,
                    )
                }
                result.success(out)
            }

            "reset" -> {
                ReelCounterStore.reset()
                result.success(null)
            }

            // ---- Reel Tax config ----
            "getReelTaxConfig" -> {
                val mgr = ReelTaxManager(appContext)
                result.success(mapOf(
                    "enabled" to mgr.enabled,
                    "interval" to mgr.interval,
                    "durationSec" to mgr.durationSec,
                ))
            }
            "setReelTaxConfig" -> {
                val mgr = ReelTaxManager(appContext)
                call.argument<Boolean>("enabled")?.let { mgr.enabled = it }
                call.argument<Int>("interval")?.let { mgr.interval = it }
                call.argument<Int>("durationSec")?.let { mgr.durationSec = it }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    // ---- EventChannel ---------------------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        ReelCounterStore.addListener(listener)
        events?.success(ReelCounterStore.snapshot().toMap())
    }

    override fun onCancel(arguments: Any?) {
        ReelCounterStore.removeListener(listener)
        eventSink = null
    }

    private fun ReelCounterStore.Snapshot.toMap(): Map<String, Any> = mapOf(
        "date" to date,
        "total" to total,
        "perApp" to perApp,
        "ts" to ts,
    )

    companion object {
        private const val METHOD_CHANNEL = "com.scrolliq/reel_counter"
        private const val EVENT_CHANNEL = "com.scrolliq/reel_counter/stream"
    }
}

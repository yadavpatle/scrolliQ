package com.scrolliq.app

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings

import com.scrolliq.app.reelcounter.ReelCounterPlugin

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.scrolliq/usage_stats"

    private var reelCounterPlugin: ReelCounterPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Reel-counter bridge (MethodChannel + EventChannel).
        reelCounterPlugin = ReelCounterPlugin(
            appContext = applicationContext,
            binaryMessenger = flutterEngine.dartExecutor.binaryMessenger,
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasUsagePermission())
                "requestPermission" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(null)
                }
                "queryUsage" -> {
                    val start = call.argument<Long>("start") ?: 0L
                    val end   = call.argument<Long>("end")   ?: System.currentTimeMillis()
                    result.success(queryUsage(start, end))
                }
                "queryRangeMinutes" -> {
                    val start = call.argument<Long>("start") ?: 0L
                    val end   = call.argument<Long>("end")   ?: System.currentTimeMillis()
                    result.success(queryRangeMinutes(start, end))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        reelCounterPlugin?.dispose()
        reelCounterPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Returns a list of {packageName, appName, totalTimeMs} for the given window.
     * Uses INTERVAL_DAILY which aggregates by day.
     */
    private fun queryUsage(start: Long, end: Long): List<Map<String, Any>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val pm: PackageManager = packageManager

        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            start,
            end
        ) ?: return emptyList()

        // Aggregate by package (queryUsageStats can return multiple buckets).
        val totals = HashMap<String, Long>()
        for (s in stats) {
            if (s.totalTimeInForeground <= 0) continue
            totals[s.packageName] =
                (totals[s.packageName] ?: 0L) + s.totalTimeInForeground
        }

        return totals.entries.map { (pkg, ms) ->
            val label = try {
                pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
            } catch (_: Exception) { pkg }
            mapOf(
                "packageName" to pkg,
                "appName"     to label,
                "totalTimeMs" to ms,
            )
        }
    }

    /**
     * Returns total minutes of foreground app usage between [start, end].
     * Useful for late-night windows.
     */
    private fun queryRangeMinutes(start: Long, end: Long): Int {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(start, end)
        var total = 0L
        var lastResume = -1L

        val ev = android.app.usage.UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            when (ev.eventType) {
                android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED ->
                    lastResume = ev.timeStamp
                android.app.usage.UsageEvents.Event.ACTIVITY_PAUSED -> {
                    if (lastResume > 0) {
                        total += (ev.timeStamp - lastResume).coerceAtLeast(0)
                        lastResume = -1L
                    }
                }
            }
        }
        return (total / 60_000L).toInt()
    }
}

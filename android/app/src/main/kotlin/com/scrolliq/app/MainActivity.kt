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
     *
     * Uses event-based accounting (ACTIVITY_RESUMED / ACTIVITY_PAUSED pairs) per
     * package rather than [UsageStatsManager.queryUsageStats] with
     * INTERVAL_DAILY. The daily buckets returned by queryUsageStats routinely
     * overlap or extend beyond the requested [start, end] window, which inflates
     * and sometimes double-counts per-app totals (numbers end up far higher than
     * Android's Digital Wellbeing). Computing foreground durations from the event
     * stream keeps results bounded to [start, end] and consistent with
     * [queryRangeMinutes].
     */
    private fun queryUsage(start: Long, end: Long): List<Map<String, Any>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val pm: PackageManager = packageManager

        // Callers pass the end of the calendar day (23:59:59) as `end`. Clamp it
        // to the present so the still-foreground app isn't credited with future
        // time (which previously inflated "today" by many hours).
        val now = System.currentTimeMillis()
        val safeEnd = if (end > now) now else end

        val totals = HashMap<String, Long>()

        // Single foreground timeline: only one app is in the foreground at a
        // time. We track the currently-foreground package and the timestamp it
        // came to the foreground, then attribute the elapsed time to it when the
        // foreground changes (next RESUMED) or it gets PAUSED (e.g. screen off).
        //
        // The earlier per-package approach counted every dangling RESUMED up to
        // `now`, so several apps each accrued hours in parallel and the total
        // ballooned far beyond real screen time. Modelling a single timeline
        // removes that overlap.
        var curPkg: String? = null
        var curStart = 0L

        fun closeSegment(at: Long) {
            val pkg = curPkg ?: return
            val delta = (at - curStart).coerceAtLeast(0)
            if (delta > 0) totals[pkg] = (totals[pkg] ?: 0L) + delta
            curPkg = null
        }

        val events = usm.queryEvents(start, safeEnd)
        val ev = android.app.usage.UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            val pkg = ev.packageName ?: continue
            when (ev.eventType) {
                android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED -> {
                    // Foreground handed over to `pkg`: close out whoever was
                    // foreground before, then start a new segment.
                    closeSegment(ev.timeStamp)
                    curPkg = pkg
                    curStart = ev.timeStamp
                }
                android.app.usage.UsageEvents.Event.ACTIVITY_PAUSED -> {
                    // Only the current foreground app pausing ends the segment
                    // (covers screen-off / lock with no following RESUMED).
                    if (pkg == curPkg) closeSegment(ev.timeStamp)
                }
            }
        }

        // Whatever is still in the foreground when the window closes is counted
        // up to `now` — exactly one app, not every dangling resume.
        closeSegment(safeEnd)

        return totals.entries
            .filter { it.value > 0L }
            .map { (pkg, ms) ->
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

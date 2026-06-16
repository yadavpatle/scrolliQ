package com.scrolliq.app.reelcounter

import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Process-wide singleton holding today's reel counter. Persisted in
 * SharedPreferences so it survives service / process restarts.
 *
 * Layout in prefs:
 *   reel_counts_date         -> "yyyy-MM-dd"
 *   reel_counts_per_app      -> JSON {"com.instagram.android": 12, ...}
 *   reel_counts_total        -> Int (denormalized for fast read)
 *   reel_counts_history.<d>  -> JSON of that day's per_app map (kept 30 days)
 */
object ReelCounterStore {

    private const val PREFS = "scrolliq_reel_counter"
    private const val KEY_DATE = "reel_counts_date"
    private const val KEY_PER_APP = "reel_counts_per_app"
    private const val KEY_TOTAL = "reel_counts_total"
    private const val KEY_HISTORY_PREFIX = "reel_counts_history."
    private const val HISTORY_DAYS = 30

    /** Snapshot pushed to subscribers. */
    data class Snapshot(
        val date: String,
        val total: Int,
        val perApp: Map<String, Int>,
        val ts: Long,
    )

    fun interface Listener {
        fun onSnapshot(snapshot: Snapshot)
    }

    private val DATE_FMT = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    private val mainHandler = Handler(Looper.getMainLooper())
    private val listeners = CopyOnWriteArrayList<Listener>()

    @Volatile private var prefs: SharedPreferences? = null
    @Volatile private var currentDate: String = today()
    @Volatile private var perApp: MutableMap<String, Int> = mutableMapOf()
    @Volatile private var total: Int = 0

    fun init(context: Context) {
        if (prefs != null) return
        synchronized(this) {
            if (prefs != null) return
            val p = context.applicationContext
                .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs = p
            loadFromPrefs(p)
        }
    }

    private fun loadFromPrefs(p: SharedPreferences) {
        val storedDate = p.getString(KEY_DATE, null)
        val now = today()
        if (storedDate == null || storedDate != now) {
            // New day → roll today's counts (if any) into history, then reset.
            if (storedDate != null) {
                val previousJson = p.getString(KEY_PER_APP, "{}") ?: "{}"
                p.edit()
                    .putString(KEY_HISTORY_PREFIX + storedDate, previousJson)
                    .apply()
                pruneHistory(p, keepLast = HISTORY_DAYS)
            }
            currentDate = now
            perApp = mutableMapOf()
            total = 0
            p.edit()
                .putString(KEY_DATE, now)
                .putString(KEY_PER_APP, "{}")
                .putInt(KEY_TOTAL, 0)
                .apply()
            return
        }
        currentDate = storedDate
        total = p.getInt(KEY_TOTAL, 0)
        perApp = parseJson(p.getString(KEY_PER_APP, "{}") ?: "{}").toMutableMap()
    }

    private fun pruneHistory(p: SharedPreferences, keepLast: Int) {
        val keys = p.all.keys
            .filter { it.startsWith(KEY_HISTORY_PREFIX) }
            .sortedDescending()
        if (keys.size <= keepLast) return
        val editor = p.edit()
        keys.drop(keepLast).forEach { editor.remove(it) }
        editor.apply()
    }

    /** Increments today's counter for [packageName] by 1 and notifies listeners. */
    @Synchronized
    fun increment(packageName: String) {
        val p = prefs ?: return
        val now = today()
        if (now != currentDate) {
            // Day rolled over while service was alive.
            loadFromPrefs(p)
        }
        val next = (perApp[packageName] ?: 0) + 1
        perApp[packageName] = next
        total += 1
        p.edit()
            .putString(KEY_DATE, currentDate)
            .putString(KEY_PER_APP, JSONObject(perApp.toMap()).toString())
            .putInt(KEY_TOTAL, total)
            .apply()
        broadcast()
    }

    @Synchronized
    fun snapshot(): Snapshot {
        // Refresh in case caller is on a fresh day.
        prefs?.let { if (today() != currentDate) loadFromPrefs(it) }
        return Snapshot(
            date = currentDate,
            total = total,
            perApp = perApp.toMap(),
            ts = System.currentTimeMillis(),
        )
    }

    @Synchronized
    fun reset() {
        val p = prefs ?: return
        perApp = mutableMapOf()
        total = 0
        p.edit()
            .putString(KEY_PER_APP, "{}")
            .putInt(KEY_TOTAL, 0)
            .apply()
        broadcast()
    }

    /** Returns history for the last [days] days, oldest first, today included. */
    @Synchronized
    fun history(days: Int): Map<String, Map<String, Int>> {
        val p = prefs ?: return emptyMap()
        val out = LinkedHashMap<String, Map<String, Int>>()
        val cal = java.util.Calendar.getInstance()
        for (i in (days - 1) downTo 0) {
            val c = cal.clone() as java.util.Calendar
            c.add(java.util.Calendar.DAY_OF_YEAR, -i)
            val key = DATE_FMT.format(c.time)
            val map = if (key == currentDate) {
                perApp.toMap()
            } else {
                parseJson(p.getString(KEY_HISTORY_PREFIX + key, null) ?: "{}")
            }
            out[key] = map
        }
        return out
    }

    fun addListener(listener: Listener) { listeners.add(listener) }
    fun removeListener(listener: Listener) { listeners.remove(listener) }

    private fun broadcast() {
        val snap = snapshot()
        // Always deliver on the main thread so EventChannel sinks don't crash.
        mainHandler.post {
            for (l in listeners) {
                try { l.onSnapshot(snap) } catch (_: Throwable) { /* swallow */ }
            }
        }
    }

    private fun parseJson(raw: String): Map<String, Int> {
        return try {
            val obj = JSONObject(raw)
            buildMap {
                val it = obj.keys()
                while (it.hasNext()) {
                    val k = it.next()
                    put(k, obj.optInt(k, 0))
                }
            }
        } catch (_: Throwable) { emptyMap() }
    }

    private fun today(): String = DATE_FMT.format(Date())
}

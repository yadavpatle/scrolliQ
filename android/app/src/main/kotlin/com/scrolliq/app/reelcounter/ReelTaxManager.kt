package com.scrolliq.app.reelcounter

import android.content.Context
import android.content.SharedPreferences
import android.graphics.PixelFormat
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import com.scrolliq.app.R

/**
 * "Reel Tax" — a full-screen blocking overlay that fires every [interval]
 * reels and stays on-screen for [durationSec] seconds. Dismisses
 * automatically; the user cannot swipe it away.
 *
 * Uses the same SYSTEM_ALERT_WINDOW permission as the HUD bubble.
 *
 * The interrupt is opt-out — configurable via SharedPreferences or from the
 * Flutter settings screen.
 */
class ReelTaxManager(private val appContext: Context) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val prefs: SharedPreferences =
        appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    var interval: Int
        get() = prefs.getInt(KEY_INTERVAL, DEFAULT_INTERVAL)
        set(v) = prefs.edit().putInt(KEY_INTERVAL, v).apply()

    var enabled: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, true)
        set(v) = prefs.edit().putBoolean(KEY_ENABLED, v).apply()

    var durationSec: Int
        get() = prefs.getInt(KEY_DURATION, DEFAULT_DURATION)
        set(v) = prefs.edit().putInt(KEY_DURATION, v).apply()

    private var showing = false
    private var taxView: View? = null
    private var timer: CountDownTimer? = null

    /** Listener installed on [ReelCounterStore]. */
    val storeListener = ReelCounterStore.Listener { snapshot ->
        if (!enabled) return@Listener
        if (snapshot.total > 0 && snapshot.total % interval == 0) {
            showTax()
        }
    }

    fun init() {
        ReelCounterStore.addListener(storeListener)
    }

    fun dispose() {
        ReelCounterStore.removeListener(storeListener)
        dismissTax()
    }

    private fun showTax() {
        if (showing) return
        if (!Settings.canDrawOverlays(appContext)) return
        mainHandler.post { drawTax() }
    }

    private fun drawTax() {
        val wm = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val view = LayoutInflater.from(appContext)
            .inflate(R.layout.overlay_reel_tax, null, false)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.CENTER }

        try {
            wm.addView(view, params)
            taxView = view
            showing = true
            startCountdown(view)
        } catch (_: Throwable) {
            showing = false
        }
    }

    private fun startCountdown(view: View) {
        val tv = view.findViewById<TextView>(R.id.reel_tax_timer) ?: return
        val total = (durationSec * 1000).toLong()
        timer = object : CountDownTimer(total, 1000) {
            override fun onTick(remaining: Long) {
                tv.text = ((remaining / 1000) + 1).toString()
            }
            override fun onFinish() {
                dismissTax()
            }
        }.start()
    }

    private fun dismissTax() {
        timer?.cancel()
        timer = null
        val view = taxView ?: return
        try {
            val wm = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            wm.removeView(view)
        } catch (_: Throwable) { /* already gone */ }
        taxView = null
        showing = false
    }

    private fun overlayType(): Int =
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE

    companion object {
        private const val PREFS = "scrolliq_reel_tax"
        private const val KEY_INTERVAL = "interval"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_DURATION = "duration_sec"
        private const val DEFAULT_INTERVAL = 30
        private const val DEFAULT_DURATION = 5
    }
}

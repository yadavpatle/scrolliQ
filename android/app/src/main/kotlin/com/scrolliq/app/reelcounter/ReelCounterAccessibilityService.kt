package com.scrolliq.app.reelcounter

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.scrolliq.app.reelcounter.detectors.FacebookReelsDetector
import com.scrolliq.app.reelcounter.detectors.InstagramReelDetector
import com.scrolliq.app.reelcounter.detectors.SnapchatSpotlightDetector
import com.scrolliq.app.reelcounter.detectors.TikTokReelDetector
import com.scrolliq.app.reelcounter.detectors.YouTubeShortsDetector

/**
 * Routes per-app accessibility events to the matching [ReelDetector] and
 * increments [ReelCounterStore] when one fires.
 *
 * Debouncing: a single fling on Reels can emit 5–15 typeViewScrolled events.
 * We require at least [DEBOUNCE_MS] between two counted scrolls *per package*.
 */
class ReelCounterAccessibilityService : AccessibilityService() {

    private val detectors: Map<String, ReelDetector> = mapOf(
        "com.instagram.android"     to InstagramReelDetector(),
        "com.google.android.youtube" to YouTubeShortsDetector(),
        "com.zhiliaoapp.musically"  to TikTokReelDetector("com.zhiliaoapp.musically"),
        "com.ss.android.ugc.trill"  to TikTokReelDetector("com.ss.android.ugc.trill"),
        "com.snapchat.android"      to SnapchatSpotlightDetector(),
        "com.facebook.katana"       to FacebookReelsDetector("com.facebook.katana"),
        "com.facebook.lite"         to FacebookReelsDetector("com.facebook.lite"),
    )

    private val lastCountAtPerPkg: HashMap<String, Long> = HashMap()
    private var reelTaxManager: ReelTaxManager? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        ReelCounterStore.init(applicationContext)
        reelTaxManager = ReelTaxManager(applicationContext).also { it.init() }
        Log.i(TAG, "ReelCounter accessibility service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return
        val detector = detectors[pkg] ?: return

        val root = safeRoot()
        if (!detector.consume(event, root)) return

        val now = event.eventTime
        val last = lastCountAtPerPkg[pkg] ?: 0L
        if (now - last < DEBOUNCE_MS) return
        lastCountAtPerPkg[pkg] = now
        ReelCounterStore.increment(pkg)
        Log.i(TAG, "++ count $pkg total=${ReelCounterStore.snapshot().total}")
    }

    /**
     * [getRootInActiveWindow] can throw / return null on devices that briefly
     * lose focus. Wrap defensively so the service never crashes.
     */
    private fun safeRoot() = try {
        rootInActiveWindow
    } catch (_: Throwable) { null }

    override fun onInterrupt() { /* no-op */ }

    override fun onUnbind(intent: Intent?): Boolean {
        reelTaxManager?.dispose()
        reelTaxManager = null
        Log.i(TAG, "ReelCounter accessibility service unbound")
        return super.onUnbind(intent)
    }

    companion object {
        private const val TAG = "ReelCounterSvc"

        /** Minimum gap (ms) between two counted scrolls per package. */
        private const val DEBOUNCE_MS = 400L

        /**
         * Returns true when the user has enabled this accessibility service in
         * the system settings. Cheap; safe to call from the UI.
         */
        @JvmStatic
        fun isEnabled(context: Context): Boolean {
            val expected = context.packageName + "/" +
                ReelCounterAccessibilityService::class.java.canonicalName
            val flat = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            val splitter = TextUtils.SimpleStringSplitter(':')
            splitter.setString(flat)
            for (component in splitter) {
                if (component.equals(expected, ignoreCase = true)) return true
            }
            return false
        }
    }
}

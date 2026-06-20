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
import com.scrolliq.app.reelcounter.detectors.YouTubeShortsDetector

/**
 * Routes per-app accessibility events to the matching [ReelDetector] and
 * increments [ReelCounterStore] when one fires.
 *
 * Debouncing: a single fling on Reels can emit 5–15 typeViewScrolled events.
 * We require at least [DEBOUNCE_MS] between two counted scrolls *per package*.
 */
class ReelCounterAccessibilityService : AccessibilityService() {

    // Only the currently supported platforms are registered. TikTok/Snapchat
    // detectors remain in the codebase but are intentionally unregistered for
    // now — re-add their entries here (and the matching enum values + manifest
    // packageNames) to bring those platforms back.
    private val detectors: Map<String, ReelDetector> = mapOf(
        "com.instagram.android"     to InstagramReelDetector(),
        "com.google.android.youtube" to YouTubeShortsDetector(),
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
        val matched = detector.consume(event, root)

        // Always publish the latest feed-presence reading, even when this
        // particular event didn't represent a new reel. The detector updates
        // its inFeed flag as a side-effect of consume(), so this keeps the
        // overlay's count pill in sync with whatever the user is actually
        // looking at right now.
        ReelFeedState.set(detector.isInReelFeed)

        if (!matched) return

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
        // No more events will arrive — make sure the overlay pill doesn't
        // stay stuck on whatever the last detector reading was.
        ReelFeedState.set(false)
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

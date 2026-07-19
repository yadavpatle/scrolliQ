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
import com.scrolliq.app.reelcounter.detectors.YouTubeShortsDetector

/**
 * Routes per-app accessibility events to the matching [ReelDetector] and
 * increments [ReelCounterStore] when one fires.
 *
 * Debouncing: a single fling on Reels can emit 5–15 typeViewScrolled events.
 * We require at least [DEBOUNCE_MS] between two counted scrolls *per package*.
 */
class ReelCounterAccessibilityService : AccessibilityService() {

    // TikTok detector exists in the codebase but is intentionally unregistered
    // until verified on-device per the Debugging Playbook in CLAUDE.md.
    private val detectors: Map<String, ReelDetector> = mapOf(
        "com.instagram.android"      to InstagramReelDetector(),
        "com.google.android.youtube" to YouTubeShortsDetector(),
        "com.facebook.katana"        to FacebookReelsDetector("com.facebook.katana"),
        "com.facebook.lite"          to FacebookReelsDetector("com.facebook.lite"),
        "com.snapchat.android"       to SnapchatSpotlightDetector(),
    )

    private val lastCountAtPerPkg: HashMap<String, Long> = HashMap()
    private var reelTaxManager: ReelTaxManager? = null

    /**
     * Package of the app currently in the foreground, as last reported by a
     * non-transient TYPE_WINDOW_STATE_CHANGED event. Used to (a) hide the pill
     * the moment the user switches to a non-reel app, and (b) ignore stray
     * background events from a tracked app while another app is on top.
     */
    @Volatile private var foregroundPackage: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        ReelCounterStore.init(applicationContext)
        reelTaxManager = ReelTaxManager(applicationContext).also { it.init() }
        Log.i(
            TAG,
            "ReelCounter accessibility service connected " +
                "[detectors: ${detectors.keys.joinToString(",")}]",
        )
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return

        val isWindowChange =
            event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED

        val detector = detectors[pkg]
        if (detector == null) {
            // A non-tracked app is involved. If it has become the foreground
            // app, the user has left every reel/short surface — hide the pill.
            // We deliberately do NOT inspect this app's content (no safeRoot()
            // call): we only ever read its package name. This preserves the
            // "never query content outside the tracked apps" guarantee.
            //
            // NOTE: we do NOT latch `foregroundPackage` here. OEM skins
            // (ColorOS/MIUI/OneUI) fire TYPE_WINDOW_STATE_CHANGED from transient
            // system overlays (smart sidebar, floating notifications, gesture
            // pill…) whose package is neither systemui nor the IME. Latching
            // onto those wrongly marked a real reel app as "backgrounded" and
            // silently dropped its content events → intermittent under-counting
            // ("sometimes counts, sometimes doesn't"). The authoritative
            // foreground signal is now the active-window owner read below from
            // the tracked app's own root, so a stray overlay event can no
            // longer suppress counting.
            if (isWindowChange && !isTransientWindow(pkg)) {
                ReelFeedState.set(false)
            }
            return
        }

        // Read the tracked app's active-window root ONCE. Its owner package is
        // the authoritative "what's really on screen" signal — reliable even on
        // OEM skins, because their transient overlays are non-focusable and so
        // getRootInActiveWindow() still returns the underlying reel app. This
        // only ever reads a TRACKED app's tree, preserving the privacy
        // guarantee documented in accessibility_service_config.xml.
        val root = safeRoot()
        val activePkg = root?.packageName?.toString()

        when {
            // Tracked app genuinely owns the active window → it is foreground.
            activePkg == pkg -> foregroundPackage = pkg
            // The active window belongs to a real, different app → this is a
            // stray background event from the tracked app (e.g. audio playing
            // while the user is elsewhere). Do not count.
            activePkg != null -> return
            // Couldn't read the active root (brief focus loss, common on
            // ColorOS). Fall back to the latched foreground so we don't count
            // over another app. A null root can't be counted anyway (detectors
            // require a non-null tree), so this never loses a legitimate count.
            else -> {
                val fg = foregroundPackage
                if (fg != null && fg != pkg) return
            }
        }

        val matched = detector.consume(event, root)

        // Always publish the latest feed-presence reading, even when this
        // particular event didn't represent a new reel. The detector updates
        // its inFeed flag as a side-effect of consume(), so this keeps the
        // overlay's count pill in sync with whatever the user is actually
        // looking at right now. With no decay timer, the pill stays steady
        // through passive viewing and only hides when this turns false.
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
     * True for windows that overlay the current app rather than replacing it:
     * the system UI (status bar / shade / quick settings), the active input
     * method, and ScrollIQ's own overlay pill. Switching focus to one of these
     * does not mean the user left the reel app.
     */
    private fun isTransientWindow(pkg: String): Boolean {
        if (pkg.isEmpty()) return true
        if (pkg == packageName) return true
        if (pkg == SYSTEM_UI_PACKAGE) return true
        if (pkg == currentImePackage()) return true
        return false
    }

    /** Resolve the active input-method package so the keyboard never hides the pill. */
    private fun currentImePackage(): String? = try {
        Settings.Secure.getString(
            contentResolver,
            Settings.Secure.DEFAULT_INPUT_METHOD,
        )?.substringBefore('/')?.takeIf { it.isNotEmpty() }
    } catch (_: Throwable) {
        null
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
        foregroundPackage = null
        ReelFeedState.set(false)
        Log.i(TAG, "ReelCounter accessibility service unbound")
        return super.onUnbind(intent)
    }

    companion object {
        private const val TAG = "ReelCounterSvc"

        /** System UI package whose windows (status bar, shade, quick settings) overlay the current app. */
        private const val SYSTEM_UI_PACKAGE = "com.android.systemui"

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

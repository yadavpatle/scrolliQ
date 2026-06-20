package com.scrolliq.app.reelcounter

import android.os.Handler
import android.os.Looper
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Process-wide flag: "is the user currently parked on a reel / short / spotlight
 * feed?". Pushed by [ReelCounterAccessibilityService] from the per-package
 * detectors, observed by [OverlayService] to toggle the floating count pill.
 *
 * Visibility is fully edge-driven — there is deliberately **no** idle/decay
 * timer. The pill must stay rock-steady the entire time the user is on a reel
 * surface (including while passively watching a single reel that fires no
 * scroll events), and disappear only when they actually leave it. The
 * accessibility service guarantees a matching `false` whenever the user:
 *   • navigates away from the feed inside a tracked app (detector flips
 *     [ReelDetector.isInReelFeed] to false), or
 *   • switches to any other (untracked) foreground app — detected via that
 *     app's window-state-changed event, or
 *   • disables the service (onUnbind pushes false).
 *
 * All state changes and listener callbacks are dispatched on the main thread.
 */
object ReelFeedState {

    fun interface Listener {
        fun onChanged(inReelFeed: Boolean)
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val listeners = CopyOnWriteArrayList<Listener>()

    @Volatile private var inReelFeed: Boolean = false

    /** Current value; safe to call from any thread. */
    @JvmStatic
    fun isInReelFeed(): Boolean = inReelFeed

    /**
     * Push the latest reading from the accessibility service. The pill stays
     * visible until an explicit `false` arrives (leaving the feed or the app),
     * so passive viewing never hides it.
     */
    @JvmStatic
    fun set(value: Boolean) {
        mainHandler.post { setInternal(value) }
    }

    /** Adds [listener] and immediately delivers the current value. */
    @JvmStatic
    fun addListener(listener: Listener) {
        listeners.add(listener)
        val current = inReelFeed
        mainHandler.post {
            try { listener.onChanged(current) } catch (_: Throwable) { /* swallow */ }
        }
    }

    @JvmStatic
    fun removeListener(listener: Listener) {
        listeners.remove(listener)
    }

    private fun setInternal(value: Boolean) {
        if (inReelFeed == value) return
        inReelFeed = value
        for (l in listeners) {
            try { l.onChanged(value) } catch (_: Throwable) { /* swallow */ }
        }
    }
}

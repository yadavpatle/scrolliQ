package com.scrolliq.app.reelcounter

import android.os.Handler
import android.os.Looper
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Process-wide flag: "is the user currently parked on a reel / short / spotlight
 * feed?". Pushed by [ReelCounterAccessibilityService] from the per-package
 * detectors, observed by [OverlayService] to toggle the floating count pill.
 *
 * The accessibility service config only delivers events from the seven tracked
 * short-video apps, so when the user leaves those apps entirely we receive
 * nothing — the last detector's [ReelDetector.isInReelFeed] reading would stay
 * stale forever. To handle that we run a small decay timer: every "true" pulse
 * re-arms a [DECAY_MS] timeout that automatically flips back to `false` if no
 * fresh in-feed event arrives. Active reel viewing produces near-continuous
 * accessibility events so the decay never trips while the user is genuinely on
 * a reel surface.
 *
 * All state changes and listener callbacks are dispatched on the main thread.
 */
object ReelFeedState {

    /**
     * Idle window after which the state auto-decays to `false`. Real reel
     * scrolling/playback fires events every few hundred ms, so this short
     * timeout only trips when the user navigates to an untracked app (e.g.
     * presses home) where no further events arrive — hiding the pill promptly.
     */
    private const val DECAY_MS = 1_500L

    fun interface Listener {
        fun onChanged(inReelFeed: Boolean)
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val listeners = CopyOnWriteArrayList<Listener>()

    @Volatile private var inReelFeed: Boolean = false

    private val decayRunnable = Runnable { setInternal(false) }

    /** Current value; safe to call from any thread. */
    @JvmStatic
    fun isInReelFeed(): Boolean = inReelFeed

    /**
     * Push the latest reading from the accessibility service. Call after every
     * processed event so the decay timer stays armed while the user keeps
     * scrolling reels and trips when they leave.
     */
    @JvmStatic
    fun set(value: Boolean) {
        mainHandler.post {
            mainHandler.removeCallbacks(decayRunnable)
            if (value) {
                mainHandler.postDelayed(decayRunnable, DECAY_MS)
            }
            setInternal(value)
        }
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

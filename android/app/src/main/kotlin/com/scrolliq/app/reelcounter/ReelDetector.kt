package com.scrolliq.app.reelcounter

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Per-app strategy for "is this event a reel transition?".
 *
 * Implementations are deliberately heuristic — IG/YT/etc. reshuffle their
 * view-id-resource-name strings every release. We combine multiple weak signals
 * (class name + view-id substring + scroll geometry + content-change types) and
 * require ≥1 to match.
 *
 * The service forwards every accessibility event for the matching package via
 * [consume]; the detector tracks per-package state (e.g. "currently in feed")
 * and returns true when the event represents one new reel/short.
 */
interface ReelDetector {

    /** Package this detector handles, e.g. "com.instagram.android". */
    val packageName: String

    /**
     * Optional friendly tag the dashboard uses, e.g. "instagram_reels". Falls
     * back to [packageName] when null.
     */
    val tag: String get() = packageName

    /**
     * Inspect an accessibility event (any type allowed by the service config).
     * Return true exactly once per new reel/short the user scrolled to. The
     * service applies a global per-package debounce so detectors may err on
     * the side of permissive within reason.
     */
    fun consume(event: AccessibilityEvent, root: AccessibilityNodeInfo?): Boolean

    /**
     * True while the detector currently believes the user is parked on the
     * reel/short surface for this package. Updated as a side-effect of
     * [consume]; used to drive the floating count-pill overlay so it only
     * appears while the user is actively scrolling reels.
     *
     * Defaults to `false` so detectors that don't implement feed-presence
     * tracking simply don't trigger the pill.
     */
    val isInReelFeed: Boolean get() = false
}

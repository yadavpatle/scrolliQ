package com.scrolliq.app.reelcounter.detectors

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.scrolliq.app.reelcounter.ReelDetector

/**
 * Facebook Reels detector — content-description based.
 *
 * Facebook (katana / lite) strips practically every view-id-resource-name to
 * `(name removed)`, so the old pager-id matching never fired and nothing was
 * counted. Instead we rely on the rich accessibility content-descriptions FB
 * still exposes:
 *   • Reel-surface markers : "Create reel", "Tap to show video controls",
 *                            "View chapters", "View <creator>'s reels"
 *   • Per-reel identity     : creator handle ("Follow <creator>" /
 *                            "View <creator>'s reels")
 *   • Engagement rail       : "N comments", "N reactions", "Share, N shares"
 *
 * Counting mirrors the YouTube detector:
 *   1. Must be on the Reels surface (a reel marker seen within last 3s).
 *   2. Must NOT be an ad ("Sponsored").
 *   3. Must expose an engagement marker (real reel, not an ad/loading frame).
 *   4. +1 when the per-reel fingerprint (creator) changes, with a cooldown to
 *      absorb transition flicker while fields load in.
 */
class FacebookReelsDetector(
    override val packageName: String,
) : ReelDetector {

    override val tag: String = "facebook_reels"

    @Volatile private var inReels: Boolean = false
    @Volatile private var lastInFeedAt: Long = 0L
    @Volatile private var lastFingerprint: String = ""
    @Volatile private var lastCountAt: Long = 0L

    override val isInReelFeed: Boolean get() = inReels

    /**
     * Content-desc markers that indicate the Reels *viewing* surface — not the
     * bottom-nav "Reels, tab 2 of 5" label, which is always present.
     */
    private val reelMarkers = listOf(
        "tap to show video controls",
        "view chapters",
        "create reel",
        "'s reels",
        "navigate to your reels",
    )

    /** Explicit ad markers. Kept conservative to avoid false positives. */
    private val adSignals = listOf(
        "sponsored",
        "paid partnership",
    )

    /** Engagement markers — at least one proves it is a real reel, not an ad. */
    private val engagementSignals = listOf(
        "reaction",
        "comment",
        "share",
    )

    /**
     * Per-reel fingerprint sources, in priority order. We take the FIRST match
     * (not a concatenation) so the value stays stable as other fields load in.
     * Both encode the creator, which is stable while a reel plays and changes
     * on swipe.
     */
    private val fingerprintSignals = listOf(
        "'s reels",   // "view <creator>'s reels"
        "follow ",    // "follow <creator>"
    )

    override fun consume(
        event: AccessibilityEvent,
        root: AccessibilityNodeInfo?,
    ): Boolean {
        val nowWall = System.currentTimeMillis()
        if (root == null) return false

        val scan = scanTree(root)

        // Refresh reel-surface presence.
        if (scan.hasReelMarker) {
            inReels = true
            lastInFeedAt = nowWall
        } else if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            nowWall - lastInFeedAt > 1_200L) {
            inReels = false
        }

        if (!inReels) return false

        // Explicit ad → never count.
        if (scan.isAd) return false

        // Must be a verified reel: creator fingerprint + engagement rail.
        if (scan.fingerprint.isEmpty()) return false
        if (!scan.hasEngagement) return false

        val fp = scan.fingerprint
        if (fp == lastFingerprint) return false

        // Cooldown: absorb transient flips during the swipe transition.
        if (nowWall - lastCountAt < COUNT_COOLDOWN_MS) {
            lastFingerprint = fp
            return false
        }

        lastFingerprint = fp
        lastCountAt = nowWall
        return true
    }

    private data class Scan(
        val hasReelMarker: Boolean,
        val isAd: Boolean,
        val fingerprint: String,
        val hasEngagement: Boolean,
    )

    /** One bounded DFS over content-descriptions + text collecting all signals. */
    private fun scanTree(root: AccessibilityNodeInfo): Scan {
        var hasReelMarker = false
        var isAd = false
        var hasEngagement = false
        val fpFound = arrayOfNulls<String>(fingerprintSignals.size)
        var visited = 0
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.addLast(root)
        while (stack.isNotEmpty() && visited < 500) {
            val node = stack.removeLast()
            visited++
            val desc = node.contentDescription?.toString()?.lowercase()?.trim()
            val text = node.text?.toString()?.lowercase()?.trim()
            for (s in sequenceOf(desc, text)) {
                if (s == null || s.isEmpty()) continue
                if (!hasReelMarker && reelMarkers.any { s.contains(it) }) hasReelMarker = true
                if (!isAd && adSignals.any { s.contains(it) }) isAd = true
                if (!hasEngagement && engagementSignals.any { s.contains(it) }) hasEngagement = true
                for (i in fingerprintSignals.indices) {
                    if (fpFound[i] == null && s.contains(fingerprintSignals[i])) {
                        fpFound[i] = s
                    }
                }
            }
            for (i in 0 until node.childCount) {
                stack.addLast(node.getChild(i) ?: continue)
            }
        }
        return Scan(
            hasReelMarker = hasReelMarker,
            isAd = isAd,
            fingerprint = fpFound.firstOrNull { it != null } ?: "",
            hasEngagement = hasEngagement,
        )
    }

    companion object {
        /** Minimum gap between two counted reels; absorbs transition flips. */
        private const val COUNT_COOLDOWN_MS = 600L
    }
}

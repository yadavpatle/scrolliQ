package com.scrolliq.app.reelcounter.detectors

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.scrolliq.app.reelcounter.ReelDetector
import com.scrolliq.app.reelcounter.ReelNodeUtil

/**
 * YouTube Shorts detector — accuracy-first, matches BrainPal counting.
 *
 * Modern YouTube Shorts exposes no scrollable views or reliable
 * TYPE_VIEW_SCROLLED events, so we fingerprint the visible short from its
 * accessibility content-descriptions instead.
 *
 * Ad exclusion (the important part): an ORGANIC short always exposes an
 * engagement action rail — like / comment / remix / sound. Ads replace this
 * with a CTA ("Visit site", "Install", "Sponsored", …) and expose none of
 * those affordances. So we only count when the visible page has BOTH:
 *   • a channel handle  ("Go to channel @…")  -> used as the fingerprint, and
 *   • at least one engagement marker          -> proves it is a real short.
 * Pages with explicit ad signals are skipped outright. This is far more
 * robust than enumerating every possible ad CTA string.
 *
 * Counting:
 *   +1 when the fingerprint changes to a new organic short (with cooldown to
 *   absorb transition flicker while fields load in).
 */
class YouTubeShortsDetector : ReelDetector {

    override val packageName: String = "com.google.android.youtube"
    override val tag: String = "youtube_shorts"

    @Volatile private var inShortsFeed: Boolean = false
    @Volatile private var lastInFeedAt: Long = 0L
    @Volatile private var lastFingerprint: String = ""
    @Volatile private var lastCountAt: Long = 0L

    override val isInReelFeed: Boolean get() = inShortsFeed

    /** Pager-host ids that indicate the Shorts feed is on screen. */
    private val pagerIds = listOf(
        "reel_recycler",
        "reel_player_page_container",
        "reel_player_underlay",
        "reel_watch_player",
        "reel_player_page_content",
    )

    /**
     * Explicit ad markers (content-desc / text, lowercased substring). Kept
     * conservative — only phrases that virtually never occur in an organic
     * short's description/comments. The engagement-marker gate below is the
     * primary ad defense; this list is a fast belt-and-suspenders.
     */
    private val adSignals = listOf(
        "sponsored",
        "visit advertiser",
        "visit site",
        "includes paid promotion",
        "ad \u00b7",
    )

    /** Channel-handle marker — primary fingerprint, present on every short. */
    private val channelSignal = "go to channel"

    /**
     * Engagement markers — at least one proves the page is a real short, not
     * an ad. Ads never expose like/comment/remix/sound affordances.
     */
    private val engagementSignals = listOf(
        "like this video along with",
        "remix this short",
        "see more videos using this sound",
        "comment",                              // "View N comments" / "Comments"
    )

    override fun consume(
        event: AccessibilityEvent,
        root: AccessibilityNodeInfo?,
    ): Boolean {
        val nowWall = System.currentTimeMillis()

        // Refresh feed-presence cheaply per event.
        if (ReelNodeUtil.anyIdContains(root, pagerIds, maxNodes = 250)) {
            inShortsFeed = true
            lastInFeedAt = nowWall
        } else if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            nowWall - lastInFeedAt > 1_200L) {
            inShortsFeed = false
        }

        if (!inShortsFeed || root == null) return false

        // Single traversal collecting every signal we need.
        val scan = scanTree(root)

        // Explicit ad → never count.
        if (scan.isAd) return false

        // Must be a verified organic short: channel handle + engagement rail.
        if (scan.channel.isEmpty()) return false
        if (!scan.hasEngagement) return false

        // Fingerprint on the channel handle (appears atomically on swap).
        val fp = scan.channel
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
        val isAd: Boolean,
        val channel: String,
        val hasEngagement: Boolean,
    )

    /** One bounded DFS collecting ad / channel / engagement signals. */
    private fun scanTree(root: AccessibilityNodeInfo): Scan {
        var isAd = false
        var channel = ""
        var hasEngagement = false
        var visited = 0
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.addLast(root)
        while (stack.isNotEmpty() && visited < 450) {
            val node = stack.removeLast()
            visited++
            val desc = node.contentDescription?.toString()?.lowercase()?.trim()
            val text = node.text?.toString()?.lowercase()?.trim()
            for (s in sequenceOf(desc, text)) {
                if (s == null) continue
                if (!isAd && adSignals.any { s.contains(it) }) isAd = true
                if (channel.isEmpty() && s.contains(channelSignal)) channel = s
                if (!hasEngagement && engagementSignals.any { s.contains(it) }) {
                    hasEngagement = true
                }
            }
            for (i in 0 until node.childCount) {
                stack.addLast(node.getChild(i) ?: continue)
            }
        }
        return Scan(isAd, channel, hasEngagement)
    }

    companion object {
        /** Minimum gap between two counted shorts; absorbs transition flips. */
        private const val COUNT_COOLDOWN_MS = 600L
    }
}

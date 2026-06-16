package com.scrolliq.app.reelcounter.detectors

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.scrolliq.app.reelcounter.ReelDetector
import com.scrolliq.app.reelcounter.ReelNodeUtil

/**
 * YouTube Shorts detector — accuracy-first.
 *
 * One reel = one transition into a NEW short. Strongest signal:
 *   TYPE_WINDOW_CONTENT_CHANGED with
 *   - contentChangeTypes & CONTENT_CHANGE_TYPE_SUBTREE  (new subtree swapped in)
 *   - source view-id-resource-name matching the Shorts pager id
 *
 * Falls back to typeViewScrolled with vertical advance for older builds that
 * still dispatch scroll events.
 *
 * `inShortsFeed` is bounded by id scan (maxNodes 200) with 3s sticky timeout
 * so leaving Shorts immediately stops counting.
 */
class YouTubeShortsDetector : ReelDetector {

    override val packageName: String = "com.google.android.youtube"
    override val tag: String = "youtube_shorts"

    @Volatile private var inShortsFeed: Boolean = false
    @Volatile private var lastInFeedAt: Long = 0L

    /** Pager-host ids that indicate a real Shorts page swap (not UI tweak). */
    private val pagerIds = listOf(
        "reel_recycler",
        "reel_player_page_container",
        "reel_player_underlay",
        "shorts_player",
        "reel_watch",
    )

    override fun consume(
        event: AccessibilityEvent,
        root: AccessibilityNodeInfo?,
    ): Boolean {
        // Refresh feed-presence cheaply per event.
        val nowWall = System.currentTimeMillis()
        if (ReelNodeUtil.anyIdContains(root, pagerIds, maxNodes = 200)) {
            inShortsFeed = true
            lastInFeedAt = nowWall
        } else if (nowWall - lastInFeedAt > 3_000L) {
            inShortsFeed = false
        }

        if (!inShortsFeed) return false

        // Primary path: subtree-replacement on the actual pager view.
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            val isSubtree = (event.contentChangeTypes and
                AccessibilityEvent.CONTENT_CHANGE_TYPE_SUBTREE) != 0
            if (!isSubtree) return false
            val src = runCatching { event.source }.getOrNull() ?: return false
            return try {
                val id = src.viewIdResourceName?.lowercase()
                id != null && pagerIds.any { id.contains(it.lowercase()) }
            } finally {
                runCatching { src.recycle() }
            }
        }

        // Fallback: legacy scroll event with vertical advance.
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED) {
            return ReelNodeUtil.isVerticalAdvance(event)
        }
        return false
    }
}

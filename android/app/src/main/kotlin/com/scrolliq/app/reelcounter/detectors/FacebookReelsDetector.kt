package com.scrolliq.app.reelcounter.detectors

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.scrolliq.app.reelcounter.ReelDetector
import com.scrolliq.app.reelcounter.ReelNodeUtil

class FacebookReelsDetector(
    override val packageName: String,
) : ReelDetector {

    override val tag: String = "facebook_reels"

    @Volatile private var inReels: Boolean = false
    @Volatile private var lastInFeedAt: Long = 0L

    private val pagerIds = listOf(
        "reels_viewer",
        "reels_video_player",
        "reels_swipeable_view_pager",
        "video_home_full_screen_pager",
    )

    override fun consume(
        event: AccessibilityEvent,
        root: AccessibilityNodeInfo?,
    ): Boolean {
        val nowWall = System.currentTimeMillis()
        if (ReelNodeUtil.anyIdContains(root, pagerIds, maxNodes = 200)) {
            inReels = true
            lastInFeedAt = nowWall
        } else if (nowWall - lastInFeedAt > 3_000L) {
            inReels = false
        }

        if (!inReels) return false

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
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED) {
            return ReelNodeUtil.isVerticalAdvance(event)
        }
        return false
    }
}

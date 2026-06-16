package com.scrolliq.app.reelcounter.detectors

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.scrolliq.app.reelcounter.ReelDetector
import com.scrolliq.app.reelcounter.ReelNodeUtil

class SnapchatSpotlightDetector : ReelDetector {

    override val packageName: String = "com.snapchat.android"
    override val tag: String = "snapchat_spotlight"

    @Volatile private var inSpotlight: Boolean = false
    @Volatile private var lastInFeedAt: Long = 0L

    private val pagerIds = listOf(
        "spotlight",
        "ngs_spotlight_recycler_view",
        "spotlight_pager",
        "discover_feed_pager",
    )

    override fun consume(
        event: AccessibilityEvent,
        root: AccessibilityNodeInfo?,
    ): Boolean {
        val nowWall = System.currentTimeMillis()
        if (ReelNodeUtil.anyIdContains(root, pagerIds, maxNodes = 200)) {
            inSpotlight = true
            lastInFeedAt = nowWall
        } else if (nowWall - lastInFeedAt > 3_000L) {
            inSpotlight = false
        }

        if (!inSpotlight) return false

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

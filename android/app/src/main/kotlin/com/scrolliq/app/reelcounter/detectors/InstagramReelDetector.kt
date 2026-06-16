package com.scrolliq.app.reelcounter.detectors

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.scrolliq.app.reelcounter.ReelDetector
import com.scrolliq.app.reelcounter.ReelNodeUtil

class InstagramReelDetector : ReelDetector {

    override val packageName: String = "com.instagram.android"
    override val tag: String = "instagram"

    @Volatile private var inReelFeed: Boolean = false
    @Volatile private var lastInFeedAt: Long = 0L

    private val pagerIds = listOf(
        "clips_viewer",
        "reels_viewer",
        "clips_video_container",
        "clips_viewer_view_pager",
    )

    override fun consume(
        event: AccessibilityEvent,
        root: AccessibilityNodeInfo?,
    ): Boolean {
        val nowWall = System.currentTimeMillis()
        if (ReelNodeUtil.anyIdContains(root, pagerIds, maxNodes = 200)) {
            inReelFeed = true
            lastInFeedAt = nowWall
        } else if (nowWall - lastInFeedAt > 3_000L) {
            inReelFeed = false
        }

        if (!inReelFeed) return false

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

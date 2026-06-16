package com.scrolliq.app.reelcounter

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/** Shared traversal helpers for ReelDetector implementations. */
internal object ReelNodeUtil {

    /**
     * Returns true if any node in the subtree rooted at [root] has a
     * view-id-resource-name containing one of [needles] (case-insensitive
     * substring match). Bounded by [maxDepth] / [maxNodes] for safety.
     */
    fun anyIdContains(
        root: AccessibilityNodeInfo?,
        needles: List<String>,
        maxDepth: Int = 12,
        maxNodes: Int = 600,
    ): Boolean {
        if (root == null || needles.isEmpty()) return false
        val lowered = needles.map { it.lowercase() }
        var visited = 0
        val stack = ArrayDeque<Pair<AccessibilityNodeInfo, Int>>()
        stack.addLast(root to 0)
        while (stack.isNotEmpty()) {
            val (node, depth) = stack.removeLast()
            visited++
            if (visited > maxNodes) return false
            val id = node.viewIdResourceName?.lowercase()
            if (id != null && lowered.any { id.contains(it) }) return true
            if (depth < maxDepth) {
                for (i in 0 until node.childCount) {
                    val c = node.getChild(i) ?: continue
                    stack.addLast(c to depth + 1)
                }
            }
        }
        return false
    }

    /** True when [className] (the AccessibilityEvent.className) contains any needle. */
    fun classContains(className: CharSequence?, needles: List<String>): Boolean {
        if (className == null) return false
        val s = className.toString().lowercase()
        return needles.any { s.contains(it.lowercase()) }
    }

    /**
     * Heuristic: does this scroll event represent the user advancing to a new
     * reel/short? Combines two signals:
     *  - large vertical delta (>= 200px) — covers fling scrolls
     *  - fromIndex/toIndex change — covers snap-scrolls where deltaY shrinks
     *    to ~0 by the time the event fires (common on YouTube Shorts /
     *    TikTok which use ViewPager2 with snap helpers).
     *
     * Previously the check short-circuited when deltaY was non-zero, missing
     * snap-scroll events whose deltaY was small but whose visible-item index
     * had advanced.
     */
    fun isVerticalAdvance(event: AccessibilityEvent): Boolean {
        val deltaY = runCatching { event.scrollDeltaY }.getOrDefault(0)
        if (kotlin.math.abs(deltaY) >= 200) return true
        val from = event.fromIndex
        val to = event.toIndex
        return from != to && from >= 0 && to >= 0
    }
}

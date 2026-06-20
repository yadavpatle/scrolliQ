package com.scrolliq.app.reelcounter.detectors

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.scrolliq.app.reelcounter.ReelDetector
import com.scrolliq.app.reelcounter.ReelNodeUtil

/**
 * Instagram Reels detector — accuracy-first, mirrors [YouTubeShortsDetector].
 *
 * Why the rewrite: the previous implementation counted on every
 * TYPE_VIEW_SCROLLED with a vertical delta and on every SUBTREE
 * content-change inside the clips_viewer pager. Both signals fire many
 * times per fling on Instagram's ViewPager2, so a single user swipe was
 * counted as 3–8 reels (over-counting). It also had no ad filtering, so
 * sponsored reels inflated the total.
 *
 * New approach (matches YouTubeShortsDetector):
 *   1. Use pager-id presence to maintain `inReelFeed` (cheap, robust).
 *      Instagram still ships these resource ids on the clips host so the
 *      gate is reliable, just not the per-reel signal.
 *   2. Fingerprint the visible reel from accessibility content-descriptions.
 *      Instagram exposes several stable per-reel signals — audio attribution
 *      ("Original audio by @x") and creator handle ("@x's profile picture",
 *      "Follow @x"). The first one we encounter becomes the fingerprint.
 *   3. Require an engagement marker (like / comment / save / send post) to
 *      prove the page is a real reel, not an ad / loading frame / story.
 *   4. Filter explicit ad markers ("Sponsored", "Paid partnership").
 *   5. +1 only when the fingerprint changes, with a cooldown to absorb the
 *      transition flicker while fields load in mid-swipe.
 */
class InstagramReelDetector : ReelDetector {

    override val packageName: String = "com.instagram.android"
    override val tag: String = "instagram_reels"

    @Volatile private var inReelFeed: Boolean = false
    @Volatile private var lastInFeedAt: Long = 0L
    @Volatile private var lastFingerprint: String = ""
    @Volatile private var lastCountAt: Long = 0L

    override val isInReelFeed: Boolean get() = inReelFeed

    /** Pager-host ids that indicate the Reels feed is on screen. */
    private val pagerIds = listOf(
        "clips_viewer",
        "reels_viewer",
        "clips_video_container",
        "clips_viewer_view_pager",
    )

    /**
     * Explicit ad markers (content-desc / text, lowercased substring). Kept
     * conservative — only phrases that virtually never occur in an organic
     * reel's caption/comments. The engagement-marker gate below is the
     * primary ad defense; this list is a fast belt-and-suspenders.
     */
    private val adSignals = listOf(
        "sponsored",
        "paid partnership",
    )

    /**
     * Per-reel fingerprint sources, in priority order. We take the FIRST
     * match (not a concatenation) so the value stays stable as other fields
     * load in. All encode the creator/audio identity, which is stable while
     * a reel plays and changes on swipe.
     */
    private val fingerprintSignals = listOf(
        "original audio by",   // "Original audio by @username"
        "'s profile picture",  // "@username's profile picture"
        "follow ",             // "Follow @username"
    )

    /**
     * Engagement markers — at least one proves the page is a real reel, not
     * an ad / loading frame. Reels always expose the like/comment/save/send
     * action rail.
     */
    private val engagementSignals = listOf(
        "liked by",            // "Liked by @x and others"
        "view all comments",   // when comments exist
        "be the first to like",
        "send post",           // share button content-desc
        "save",                // save button
        "like",                // generic, paired with fingerprint above
        "comment",             // generic, paired with fingerprint above
    )

    override fun consume(
        event: AccessibilityEvent,
        root: AccessibilityNodeInfo?,
    ): Boolean {
        val nowWall = System.currentTimeMillis()

        // Refresh feed-presence cheaply per event.
        if (ReelNodeUtil.anyIdContains(root, pagerIds, maxNodes = 250)) {
            inReelFeed = true
            lastInFeedAt = nowWall
        } else if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            nowWall - lastInFeedAt > 1_200L) {
            inReelFeed = false
        }

        if (!inReelFeed || root == null) return false

        // Single traversal collecting every signal we need.
        val scan = scanTree(root)

        // Explicit ad → never count.
        if (scan.isAd) return false

        // Must be a verified organic reel: fingerprint + engagement rail.
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
        val isAd: Boolean,
        val fingerprint: String,
        val hasEngagement: Boolean,
    )

    /** One bounded DFS collecting ad / fingerprint / engagement signals. */
    private fun scanTree(root: AccessibilityNodeInfo): Scan {
        var isAd = false
        var hasEngagement = false
        val fpFound = arrayOfNulls<String>(fingerprintSignals.size)
        var visited = 0
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.addLast(root)
        while (stack.isNotEmpty() && visited < 450) {
            val node = stack.removeLast()
            visited++
            val desc = node.contentDescription?.toString()?.lowercase()?.trim()
            val text = node.text?.toString()?.lowercase()?.trim()
            for (s in sequenceOf(desc, text)) {
                if (s == null || s.isEmpty()) continue
                if (!isAd && adSignals.any { s.contains(it) }) isAd = true
                if (!hasEngagement && engagementSignals.any { s.contains(it) }) {
                    hasEngagement = true
                }
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

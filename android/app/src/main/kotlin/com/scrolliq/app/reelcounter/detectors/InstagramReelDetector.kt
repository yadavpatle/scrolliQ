package com.scrolliq.app.reelcounter.detectors

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.scrolliq.app.reelcounter.ReelDetector

/**
 * Instagram Reels detector — accuracy-first, mirrors [YouTubeShortsDetector] /
 * [FacebookReelsDetector].
 *
 * Why the rewrite: the previous implementation counted on every
 * TYPE_VIEW_SCROLLED with a vertical delta and on every SUBTREE
 * content-change inside the clips_viewer pager. Both signals fire many
 * times per fling on Instagram's ViewPager2, so a single user swipe was
 * counted as 3–8 reels (over-counting). It also had no ad filtering, so
 * sponsored reels inflated the total.
 *
 * ### Old vs new devices
 * The prior fingerprint rewrite still gated feed-presence *solely* on the
 * `clips_viewer*` resource-ids. That is the exact fragility that produced
 * **zero counts** for Facebook (see CLAUDE.md work-log #6): Instagram builds
 * differ widely across app/OS versions — some rename these ids, some strip
 * every `view-id-resource-name` to `(name removed)`. On any such device the
 * id gate never fires, `inReelFeed` stays false, and nothing is ever counted.
 *
 * To work on both old and new devices we now use a **dual gate**: the reels
 * surface is considered present if EITHER
 *   • a pager resource-id is seen (fast path, modern builds that keep ids), OR
 *   • a reels-surface content-description marker is seen (fallback for builds
 *     that strip/rename ids — the Facebook-detector strategy).
 * Both are collected in one bounded DFS. The fingerprint / engagement lists
 * are also broadened to cover phrasing that varies between IG versions.
 *
 * Counting (unchanged, robust against over-count):
 *   1. Must be on the reels surface (id OR content-desc marker).
 *   2. Must NOT be an ad ("Sponsored" / "Paid partnership").
 *   3. Must expose an engagement marker (real reel, not an ad/loading frame).
 *   4. +1 only when the per-reel fingerprint changes, with a 600ms cooldown to
 *      absorb the transition flicker while fields load in mid-swipe.
 */
class InstagramReelDetector : ReelDetector {

    override val packageName: String = "com.instagram.android"
    override val tag: String = "instagram_reels"

    @Volatile private var inReelFeed: Boolean = false
    @Volatile private var lastInFeedAt: Long = 0L
    @Volatile private var lastFingerprint: String = ""
    @Volatile private var lastCountAt: Long = 0L

    override val isInReelFeed: Boolean get() = inReelFeed

    /**
     * Pager-host resource-ids that indicate the Reels feed is on screen. Fast,
     * robust signal on builds that keep resource-ids. Kept broad to cover
     * both older and newer id spellings. Matched against
     * `view-id-resource-name` (substring, case-insensitive).
     */
    private val pagerIds = listOf(
        "clips_viewer",
        "reels_viewer",
        "clips_video_container",
        "clips_viewer_view_pager",
        "clips_swipe_refresh_container",
        "reel_feed_timeline",
        "clips_tab",
    )

    /**
     * Content-description markers for the reels *viewing* surface — the
     * fallback used when a build strips/renames resource-ids. Chosen to be
     * specific to the reel player (not the bottom-nav "Reels" tab label, which
     * is always present). These phrases have been stable across IG versions.
     */
    private val reelMarkers = listOf(
        "reel by",             // "Reel by <creator>"
        "original audio",      // "Original audio" / "Original audio by @x"
        "double tap to like",  // reel player affordance
        "audio page",          // "Go to audio page"
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
     * a reel plays and changes on swipe. Broadened to cover phrasing seen on
     * both older and newer IG builds.
     */
    private val fingerprintSignals = listOf(
        "reel by ",            // "Reel by <username>"  (very stable)
        "original audio by",   // "Original audio by @username"
        "'s profile picture",  // "@username's profile picture"
        "follow ",             // "Follow @username"
        "audio by ",           // "<song> by <artist>" / "Audio by @x"
    )

    /**
     * Engagement markers — at least one proves the page is a real reel, not
     * an ad / loading frame. Reels always expose the like/comment/save/send
     * action rail. Broadened for cross-version phrasing.
     */
    private val engagementSignals = listOf(
        "liked by",            // "Liked by @x and others"
        "view all comments",   // when comments exist
        "be the first to like",
        "send post",           // share button content-desc
        "reaction",            // some builds label reactions
        "save",                // save button
        "like",                // generic, paired with fingerprint above
        "comment",             // generic, paired with fingerprint above
        "share",               // generic, paired with fingerprint above
    )

    override fun consume(
        event: AccessibilityEvent,
        root: AccessibilityNodeInfo?,
    ): Boolean {
        val nowWall = System.currentTimeMillis()
        if (root == null) {
            // Can't read the tree this tick; let the feed flag decay on window
            // changes / timeout so the pill doesn't stick.
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                nowWall - lastInFeedAt > 1_200L) {
                inReelFeed = false
            }
            return false
        }

        // Single traversal collecting every signal we need (id + content-desc).
        val scan = scanTree(root)

        // Dual feed gate: resource-id OR content-desc reel-surface marker.
        if (scan.hasPagerId || scan.hasReelMarker) {
            inReelFeed = true
            lastInFeedAt = nowWall
        } else if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            nowWall - lastInFeedAt > 1_200L) {
            inReelFeed = false
        }

        if (!inReelFeed) return false

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
        val hasPagerId: Boolean,
        val hasReelMarker: Boolean,
        val isAd: Boolean,
        val fingerprint: String,
        val hasEngagement: Boolean,
    )

    /**
     * One bounded DFS collecting id / reel-marker / ad / fingerprint /
     * engagement signals in a single pass (cheaper than separate traversals).
     */
    private fun scanTree(root: AccessibilityNodeInfo): Scan {
        var hasPagerId = false
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

            if (!hasPagerId) {
                val id = node.viewIdResourceName?.lowercase()
                if (id != null && pagerIds.any { id.contains(it) }) hasPagerId = true
            }

            val desc = node.contentDescription?.toString()?.lowercase()?.trim()
            val text = node.text?.toString()?.lowercase()?.trim()
            for (s in sequenceOf(desc, text)) {
                if (s == null || s.isEmpty()) continue
                if (!hasReelMarker && reelMarkers.any { s.contains(it) }) hasReelMarker = true
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
            hasPagerId = hasPagerId,
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

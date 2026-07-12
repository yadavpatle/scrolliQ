package com.scrolliq.app.reelcounter.detectors

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.scrolliq.app.reelcounter.ReelDetector
import com.scrolliq.app.reelcounter.ReelNodeUtil

/**
 * TikTok For-You / following feed detector — content-description fingerprint.
 *
 * Mirrors the [YouTubeShortsDetector] / [FacebookReelsDetector] / Instagram
 * approach: a single bounded DFS per event collects feed-presence signals,
 * the per-reel fingerprint, an engagement marker, and any ad signal. We count
 * +1 only when the fingerprint changes to a new organic video (with cooldown
 * to absorb transition flicker while fields load in mid-swipe).
 *
 * Why the rewrite: the legacy detector counted on every TYPE_VIEW_SCROLLED
 * with a vertical delta + every SUBTREE content-change in the feed pager.
 * TikTok's ViewPager2 fires both signals many times per fling, so a single
 * swipe was counted as 3–8 videos. It also had no ad filter, so promoted
 * content inflated the total.
 *
 * **Verification status**: ports the proven pattern from the verified
 * detectors but the specific TikTok content-desc strings below have not yet
 * been confirmed against an on-device UI dump. Per the Debugging Playbook in
 * CLAUDE.md, capture `uiautomator dump` while parked on the FYP and tighten
 * the [creatorSignals] / [soundSignals] / [engagementSignals] / [adSignals]
 * lists to match what TikTok actually emits in your build/region.
 *
 * **Registration status**: this detector is intentionally NOT registered in
 * [com.scrolliq.app.reelcounter.ReelCounterAccessibilityService] yet. After
 * verifying on a device, add the package(s) below to the service's `detectors`
 * map and to `AppConstants.trackedApps` to bring TikTok back online.
 */
class TikTokReelDetector(
    override val packageName: String,
) : ReelDetector {

    override val tag: String = "tiktok"

    @Volatile private var inFeed: Boolean = false
    @Volatile private var lastInFeedAt: Long = 0L
    @Volatile private var lastFingerprint: String = ""
    @Volatile private var lastCountAt: Long = 0L

    override val isInReelFeed: Boolean get() = inFeed

    /**
     * Pager-host ids that indicate the For-You / video feed is on screen.
     * TikTok still ships these on most builds we've seen historically; if a
     * future release strips them we fall back to the content-desc surface
     * markers below to keep [inFeed] accurate.
     */
    private val pagerIds = listOf(
        "feed_recycler_view",
        "video_pager",
        "feed_video_pager",
        "tt_for_pager",
    )

    /**
     * Content-desc / text fragments that are only present while parked on a
     * single playing video (FYP, following, profile-grid playback). Used as a
     * fallback feed-presence signal when resource ids are stripped.
     */
    private val surfaceMarkers = listOf(
        "swipe up for next",         // FYP swipe coach mark
        "swipe down for previous",
        "tap to pause",
        "tap to play",
    )

    /**
     * Explicit ad markers. TikTok ads expose at least one of these in
     * content-desc or visible text. Kept conservative — these phrases very
     * rarely appear in organic captions.
     */
    private val adSignals = listOf(
        "sponsored",
        "paid partnership",
        "visit advertiser",
        "learn more",                // primary in-feed ad CTA
        "shop now",                  // commerce ad CTA
        "download now",              // app-install ad CTA
        "sign up",                   // lead-gen ad CTA
    )

    /**
     * Per-reel creator fingerprint sources, in priority order. We take the
     * FIRST match (not a concatenation) so the value stays stable as other
     * fields load in. All encode the creator handle, which is stable while
     * the video plays and changes on swipe.
     */
    private val creatorSignals = listOf(
        "'s profile picture",        // "@username's profile picture"
        "go to @",                   // "Go to @username"
        "view @",                    // "View @username"
        "profile of @",              // "Profile of @username"
    )

    /**
     * Sound/music fingerprint sources. Used as a secondary fingerprint when
     * the creator signal is missing (e.g. reposts, certain locale strings).
     * "original sound" alone isn't unique enough so we require it to be
     * paired with " - " (TikTok formats it as "Original sound - @creator").
     */
    private val soundSignals = listOf(
        "original sound - ",
        "use this sound",            // "Use this sound · {title}"
    )

    /**
     * Engagement markers — at least one proves the page is a real video, not
     * an ad / loading frame. Organic TikToks always expose the like / comment
     * / share / favorite rail; ads usually replace one or more with a CTA but
     * never expose all of them.
     */
    private val engagementSignals = listOf(
        "like",                      // like button content-desc
        "comment",                   // "View N comments" / "Comments"
        "share",                     // share button
        "favorite",                  // bookmark button
        "save video",                // alt save phrasing
    )

    override fun consume(
        event: AccessibilityEvent,
        root: AccessibilityNodeInfo?,
    ): Boolean {
        val nowWall = System.currentTimeMillis()

        // Cheap feed-presence refresh via pager ids (when present).
        val idMatch = ReelNodeUtil.anyIdContains(root, pagerIds, maxNodes = 250)
        if (idMatch) {
            inFeed = true
            lastInFeedAt = nowWall
        }

        if (root == null) return false

        // Single traversal collecting every signal we need.
        val scan = scanTree(root)

        // Surface fallback: if ids didn't match, content-desc markers can
        // still flip us in-feed (or keep us in-feed during pager-id churn).
        if (scan.hasSurfaceMarker) {
            inFeed = true
            lastInFeedAt = nowWall
        } else if (!idMatch &&
            (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                nowWall - lastInFeedAt > 1_200L)) {
            inFeed = false
        }

        if (!inFeed) return false

        // Explicit ad → never count.
        if (scan.isAd) return false

        // Must be a verified organic video: creator/sound + engagement rail.
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
        val hasSurfaceMarker: Boolean,
        val isAd: Boolean,
        val fingerprint: String,
        val hasEngagement: Boolean,
    )

    /** One bounded DFS collecting surface / ad / fingerprint / engagement signals. */
    private fun scanTree(root: AccessibilityNodeInfo): Scan {
        var hasSurfaceMarker = false
        var isAd = false
        var hasEngagement = false
        // Creator first, then sound — first non-null wins as the fingerprint.
        val fpFound = arrayOfNulls<String>(creatorSignals.size + soundSignals.size)
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
                if (!hasSurfaceMarker && surfaceMarkers.any { s.contains(it) }) {
                    hasSurfaceMarker = true
                }
                if (!isAd && adSignals.any { s.contains(it) }) isAd = true
                if (!hasEngagement && engagementSignals.any { s.contains(it) }) {
                    hasEngagement = true
                }
                for (i in creatorSignals.indices) {
                    if (fpFound[i] == null && s.contains(creatorSignals[i])) {
                        fpFound[i] = s
                    }
                }
                for (i in soundSignals.indices) {
                    val slot = creatorSignals.size + i
                    if (fpFound[slot] == null && s.contains(soundSignals[i])) {
                        fpFound[slot] = s
                    }
                }
            }
            for (i in 0 until node.childCount) {
                stack.addLast(node.getChild(i) ?: continue)
            }
        }
        return Scan(
            hasSurfaceMarker = hasSurfaceMarker,
            isAd = isAd,
            fingerprint = fpFound.firstOrNull { it != null } ?: "",
            hasEngagement = hasEngagement,
        )
    }

    companion object {
        /** Minimum gap between two counted videos; absorbs transition flips. */
        private const val COUNT_COOLDOWN_MS = 600L
    }
}

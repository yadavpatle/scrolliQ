package com.scrolliq.app.reelcounter.detectors

import android.graphics.Rect
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.scrolliq.app.reelcounter.ReelDetector

/**
 * Snapchat Spotlight detector — verified via on-device UI dump (Snap 13.x).
 *
 * **Why this detector is shaped differently from YT/IG/FB.** Snap's
 * accessibility tree surfaces almost no useful content-descriptions:
 *   • No creator handle in content-desc (no "posted by …" / "@username" /
 *     "view profile" — those phrases simply do not exist in the tree).
 *   • No engagement rail in content-desc (no "like" / "comment" / "send
 *     chat" / "share" labels — Snap's engagement buttons expose only
 *     resource-ids).
 *
 * What Snap *does* surface reliably (confirmed against `uiautomator dump`):
 *   • Resource-ids on the structural views:
 *       - `spotlight_container`  → "we are on the Spotlight surface"
 *       - `opera_viewer`         → "a snap is currently rendering" (vs. an
 *                                   inter-snap loading frame)
 *       - `favorite`             → bookmark button on every snap
 *   • Visible text on the active snap:
 *       - the creator handle (e.g. `sHizU🎵`)
 *       - the caption / hashtags (e.g. `Orrr💔#gymbody#funnny`)
 *       - view-count / like-count strings (`124K`, `7.7K`, `1`, `2`)
 *
 * Counting strategy:
 *   1. Surface gate    — at least one `spotlight_container` resource-id in
 *                        the tree (set [inSpotlight]).
 *   2. Realness gate   — at least one `opera_viewer` resource-id in the
 *                        tree (a snap is actually mounted, not a loading
 *                        frame between swipes).
 *   3. Ad gate         — drop on explicit ad strings.
 *   4. Fingerprint     — the **longest on-screen non-UI-label visible text**
 *                        in the tree. Spotlight is a vertical pager that keeps
 *                        the adjacent (preloaded) snaps mounted in the tree,
 *                        laid out off-screen above/below the active one. If we
 *                        picked the longest text *anywhere* in the tree the
 *                        fingerprint could lock onto a neighbour snap's caption
 *                        and either not change on swipe (undercount) or flip
 *                        independently of the visible snap (miscount). So we
 *                        only consider text whose on-screen bounds fall inside
 *                        the current viewport — that is reliably the active
 *                        snap's caption (or, on captionless snaps, its handle).
 *                        It changes atomically on swipe.
 *   5. Cooldown        — 700 ms (slightly longer than the YT 600 ms because
 *                        Snap's swipe transition is slower and pickers like
 *                        view-count text can briefly oscillate during the
 *                        crossfade).
 *
 * The classic engagement-gate that protects YT/IG/FB from counting ads is
 * deliberately omitted: Snap doesn't expose engagement words via a11y, and
 * the ad filter + caption/handle fingerprint already prevents the typical
 * over-count failure modes (loading frames have no caption, ads have ad
 * markers).
 */
class SnapchatSpotlightDetector : ReelDetector {

    override val packageName: String = "com.snapchat.android"
    override val tag: String = "snapchat_spotlight"

    @Volatile private var inSpotlight: Boolean = false
    @Volatile private var lastInFeedAt: Long = 0L
    @Volatile private var lastFingerprint: String = ""
    @Volatile private var lastCountAt: Long = 0L

    override val isInReelFeed: Boolean get() = inSpotlight

    /**
     * Resource-id substrings that mark "user is somewhere in Snap with a
     * Spotlight-related view in the tree". Includes the bottom-nav icon
     * `ngs_spotlight_icon_container` because the *Spotlight feed itself*
     * (`spotlight_container`) is present in the static `uiautomator dump`
     * but absent from the live tree the accessibility service receives —
     * so the bottom-nav icon is the only reliable surface signal we have
     * from the live tree.
     *
     * Caveat: this same icon is rendered on *every* Snap tab (Camera, Map,
     * Chat, Stories), so flipping `surface=true` here is permissive. The
     * counting gate is *not* `surface` alone — it requires a fingerprint
     * built from per-snap content (caption / handle / sound). The
     * fingerprint picker rejects Snap UI labels (see [constantUiLabels])
     * and Snap-internal namespace strings (see [isInternalNamespace]),
     * so on non-Spotlight tabs the fingerprint stays empty → no count.
     */
    private val surfaceIds = listOf(
        "spotlight_container",
        "spotlight_pager",
        "ngs_spotlight",
    )

    /** Resource-id substrings that prove a snap is actually mounted. */
    private val realSnapIds = listOf(
        "opera_viewer",
        "opera_page",
    )

    /** Explicit ad markers. Conservative — these never appear on organic snaps. */
    private val adSignals = listOf(
        "sponsored",
        "promoted",
        "swipe up for more",
        "swipe up to ",
        "ad \u00b7",
    )

    /**
     * Visible-text values that are constant Snap UI labels — not per-snap
     * content. Lowercased for the comparison. Keep this set small and
     * conservative; anything we miss here just means the *fingerprint*
     * picks the UI label as a candidate, but the longest-wins rule then
     * loses to any real caption / handle.
     */
    private val constantUiLabels = setOf(
        "camera", "chat", "map", "stories", "spotlight", "search",
        "add friends", "story sent", "send", "subscribe", "follow",
        // Snap inter-tab labels observed leaking into the fingerprint
        // picker when the user is navigating *to* Spotlight (e.g. swipes
        // through Camera/Map/Explore). Keeping the surface gate strict
        // (see `surfaceIds`) is the primary defense, but adding these
        // here is cheap belt-and-suspenders.
        "camera capture", "explore", "discover", "chat & calls",
        "memories", "friends", "communities",
    )

    /**
     * Minimum length for a text node to be considered as a fingerprint
     * candidate. Empirically, every legitimate Spotlight fingerprint we
     * have observed (caption, "username · sound", "Contains: …" sound
     * attribution, hashtag-rich captions) is ≥ 24 chars. The dangerous
     * false-positive strings on adjacent Snap tabs that the surface gate
     * lets through are all short (≤ 15 chars):
     *   • `"Original Lens"`     — Camera tab default lens label
     *   • `"fakeRightLens#1"`   — internal lens identifier
     *   • `"Camera Capture"`    — Camera tab title
     *   • `"Explore"`           — Map tab
     * 18 cleanly separates the two populations and is the primary defense
     * against false counts on Camera/Map navigation.
     */
    private val minFingerprintLen = 18

    override fun consume(
        event: AccessibilityEvent,
        root: AccessibilityNodeInfo?,
    ): Boolean {
        val nowWall = System.currentTimeMillis()
        if (root == null) return false

        // Single bounded DFS collecting every signal we need.
        val scan = scanTree(root)

        // Surface presence drives the floating pill via [isInReelFeed].
        if (scan.hasSurface) {
            inSpotlight = true
            lastInFeedAt = nowWall
        } else if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            nowWall - lastInFeedAt > 1_500L) {
            inSpotlight = false
        }

        if (!inSpotlight) return false

        // Realness gate: require Snap's `opera_*` content viewer in the
        // tree. It's present on Spotlight/Stories playback but absent on the
        // Camera capture screen, so this is what stops the Camera tab (which
        // shares the permissive `ngs_spotlight` bottom-nav surface signal)
        // from counting. We detect it by content-desc/resource-id substring
        // "opera" (see scanTree); gating on the `opera_viewer` resource-id
        // alone failed because that id is in the static uiautomator dump but
        // absent from the live accessibility tree.
        if (!scan.hasRealSnap) return false

        // Explicit ad → never count.
        if (scan.isAd) return false

        // Need a fingerprint to detect transitions.
        val fp = scan.fingerprint
        if (fp.isEmpty()) return false
        if (fp == lastFingerprint) return false

        // Cooldown: absorb transition flicker (text fields oscillate while
        // the crossfade animation runs and counters reload).
        if (nowWall - lastCountAt < COUNT_COOLDOWN_MS) {
            lastFingerprint = fp
            return false
        }

        lastFingerprint = fp
        lastCountAt = nowWall
        return true
    }

    private data class Scan(
        val hasSurface: Boolean,
        val hasRealSnap: Boolean,
        val isAd: Boolean,
        val fingerprint: String,
    )

    /**
     * One bounded DFS collecting structural ids + the longest non-UI-label
     * visible text. Both `viewIdResourceName` and `text`/`contentDescription`
     * are inspected per node.
     */
    private fun scanTree(root: AccessibilityNodeInfo): Scan {
        var hasSurface = false
        var hasRealSnap = false
        var isAd = false
        var bestText = ""
        var visited = 0

        // Viewport of the active window. Spotlight lays preloaded neighbour
        // snaps out off-screen (vertically), so a candidate's on-screen bounds
        // tell us whether its text belongs to the snap the user is actually
        // looking at. A degenerate viewport (0-area) means we couldn't read
        // bounds — fall back to accepting all nodes so we never regress to
        // zero counts on devices that don't report window bounds.
        val viewport = Rect().also { root.getBoundsInScreen(it) }
        val haveViewport = viewport.width() > 0 && viewport.height() > 0

        val nodeBounds = Rect()
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.addLast(root)
        while (stack.isNotEmpty() && visited < 500) {
            val node = stack.removeLast()
            visited++

            // Resource-id checks (Snap exposes structure here, not in
            // content-desc).
            val id = node.viewIdResourceName?.lowercase()
            if (id != null) {
                if (!hasSurface && surfaceIds.any { id.contains(it) }) hasSurface = true
                if (!hasRealSnap && realSnapIds.any { id.contains(it) }) hasRealSnap = true
            }

            // Is this node on the active (visible) page? Preloaded neighbour
            // snaps are mounted but laid out off-screen, so their bounds sit
            // above/below the viewport. Require the node's centre to fall
            // inside the viewport. When bounds are unavailable, `onScreen`
            // stays true (see `haveViewport`) so we don't lose all candidates.
            val onScreen = if (!haveViewport) {
                true
            } else {
                node.getBoundsInScreen(nodeBounds)
                nodeBounds.width() > 0 && nodeBounds.height() > 0 &&
                    Rect.intersects(nodeBounds, viewport) &&
                    nodeBounds.centerY() in viewport.top..viewport.bottom &&
                    nodeBounds.centerX() in viewport.left..viewport.right
            }

            // Text + content-desc both contribute to ad detection and
            // fingerprint candidacy. Ad detection is lowercased; fingerprint
            // preserves original case so swipes between snaps with similar
            // captions but different cases still flip.
            val rawText = node.text?.toString()?.trim()
            val rawDesc = node.contentDescription?.toString()?.trim()
            for (raw in sequenceOf(rawText, rawDesc)) {
                if (raw.isNullOrEmpty()) continue
                val lower = raw.lowercase()
                if (!isAd && adSignals.any { lower.contains(it) }) isAd = true
                // The `opera_*` content viewer is Snap's media-playback
                // surface (Spotlight / Stories). It appears in content-desc
                // (e.g. "opera_content_index:") on the live tree when a snap
                // is mounted, but is absent on the Camera capture screen —
                // so it's our realness gate that separates Spotlight from
                // Camera.
                if (!hasRealSnap && lower.contains("opera")) hasRealSnap = true
                // Fingerprint candidacy: must be on the visible page, be
                // substantial, not a pure number, not a known constant UI
                // label, and not an internal Snap namespace string (e.g.
                // "63849936178:namespace:LIVE_CAMERA_FRONT" — leaks into
                // the tree during tab transitions and false-counts).
                if (onScreen &&
                    raw.length >= minFingerprintLen &&
                    raw.length > bestText.length &&
                    lower !in constantUiLabels &&
                    !isPureCounterText(raw) &&
                    !isInternalNamespace(raw) &&
                    !isIdentifierLike(raw)
                ) {
                    bestText = raw
                }
            }

            for (i in 0 until node.childCount) {
                stack.addLast(node.getChild(i) ?: continue)
            }
        }
        return Scan(
            hasSurface = hasSurface,
            hasRealSnap = hasRealSnap,
            isAd = isAd,
            fingerprint = bestText,
        )
    }

    /**
     * True for strings that look like a Snap-internal identifier rather
     * than user-visible content. Examples observed in the live tree
     * during tab transitions:
     *   • `"63849936178:namespace:LIVE_CAMERA_FRONT"`
     *   • anything with the literal `":namespace:"` separator.
     * These leak into the tree mid-navigation and would otherwise win
     * the longest-text race for the fingerprint, causing false counts.
     */
    private fun isInternalNamespace(s: String): Boolean {
        if (s.contains(":namespace:")) return true
        // Heuristic: a long all-digits prefix followed by ':' (Snap's
        // numeric-id-prefixed internal handles).
        var i = 0
        while (i < s.length && s[i].isDigit()) i++
        return i >= 6 && i < s.length && s[i] == ':'
    }

    /**
     * True for strings shaped like an internal identifier / resource-id /
     * UI token rather than human-readable per-snap content. Heuristic:
     * a real caption, sound attribution, or "username · sound" string
     * always contains whitespace; the leaked tokens never do. So we reject
     * any whitespace-free string that also carries an identifier-ish
     * character (`_`, `:`, `#`, `/`). Observed false positives all caught:
     *   • `item_dismiss_button`    (underscores)
     *   • `opera_content_index:`   (underscores + trailing colon)
     *   • `fakeRightLens#1`        (hash)
     * Real fingerprints are never rejected:
     *   • `"Original sound · mastify_show"`  → has spaces → kept
     *   • `"The BALL rolling Along a ROPE!"` → has spaces → kept
     */
    private fun isIdentifierLike(s: String): Boolean {
        val hasWhitespace = s.any { it.isWhitespace() }
        if (hasWhitespace) return false
        return s.any { it == '_' || it == ':' || it == '#' || it == '/' }
    }

    /**
     * True for strings that are just a number or a number+suffix counter
     * like "1", "124K", "7.7K", "1.2M", "3,400". These change per snap
     * (view count) but are unreliable fingerprints because the counter
     * also re-renders mid-snap.
     */
    private fun isPureCounterText(s: String): Boolean {
        if (s.isEmpty()) return false
        var i = 0
        while (i < s.length) {
            val c = s[i]
            if (!c.isDigit() && c != '.' && c != ',' && c != ' ') break
            i++
        }
        if (i == 0) return false
        // Optional single-letter unit (K/M/B) and optional trailing whitespace.
        val tail = s.substring(i).trim().lowercase()
        return tail.isEmpty() || tail in setOf("k", "m", "b")
    }

    companion object {
        /** Minimum gap between two counted snaps; absorbs transition flips. */
        private const val COUNT_COOLDOWN_MS = 700L
    }
}

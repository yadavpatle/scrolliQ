package com.scrolliq.app.reelcounter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.util.DisplayMetrics
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import android.widget.ImageView
import android.widget.TextView
import com.scrolliq.app.MainActivity
import com.scrolliq.app.R
import kotlin.math.abs

/**
 * Foreground service that draws a draggable "brain + count" pill on top of
 * whatever app the user is currently looking at, using a TYPE_APPLICATION_OVERLAY
 * window.
 *
 * The bubble subscribes to [ReelCounterStore] so the count animates up live as
 * the AccessibilityService increments it.
 */
class OverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private var bubbleView: View? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var screenWidthPx: Int = 0
    private var screenHeightPx: Int = 0

    private val storeListener = ReelCounterStore.Listener { snapshot ->
        updateCount(snapshot.total)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        ReelCounterStore.init(applicationContext)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelfAndCleanup()
                return START_NOT_STICKY
            }
            else -> {
                if (!Settings.canDrawOverlays(this)) {
                    Log.w(TAG, "Overlay permission missing; service cannot draw bubble")
                    stopSelfAndCleanup()
                    return START_NOT_STICKY
                }
                startForegroundCompat()
                if (bubbleView == null) attachBubble()
                ReelCounterStore.removeListener(storeListener)
                ReelCounterStore.addListener(storeListener)
                // Push current value immediately so the bubble doesn't show stale 0.
                updateCount(ReelCounterStore.snapshot().total)
            }
        }
        // Sticky so Android brings us back if memory is reclaimed; user can
        // explicitly stop via the dashboard's "Hide HUD" button.
        return START_STICKY
    }

    override fun onDestroy() {
        stopSelfAndCleanup()
        super.onDestroy()
    }

    private fun stopSelfAndCleanup() {
        ReelCounterStore.removeListener(storeListener)
        try {
            bubbleView?.let { windowManager.removeView(it) }
        } catch (_: Throwable) { /* already detached */ }
        bubbleView = null
        layoutParams = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        running = false
    }

    // ---- Overlay --------------------------------------------------------

    private fun attachBubble() {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getMetrics(metrics)
        screenWidthPx = metrics.widthPixels
        screenHeightPx = metrics.heightPixels

        val view = LayoutInflater.from(this).inflate(R.layout.overlay_bubble, null, false)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (screenWidthPx * 0.7).toInt()
            y = (screenHeightPx * 0.18).toInt()
        }

        view.setOnTouchListener(BubbleTouchListener(view, params))
        bubbleView = view
        layoutParams = params

        try {
            windowManager.addView(view, params)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to add overlay view", t)
            bubbleView = null
            layoutParams = null
            stopSelfAndCleanup()
        }
    }

    private fun updateCount(total: Int) {
        val view = bubbleView ?: return
        val text = view.findViewById<TextView>(R.id.overlay_count) ?: return
        val icon = view.findViewById<ImageView>(R.id.overlay_brain_icon)
        view.post {
            text.text = total.toString()
            icon?.let { pulse(it) }
        }
    }

    /** Tiny scale bump on every count to draw the eye. */
    private fun pulse(target: View) {
        target.animate().cancel()
        target.scaleX = 1f
        target.scaleY = 1f
        target.animate()
            .scaleX(1.18f).scaleY(1.18f)
            .setDuration(120)
            .withEndAction {
                target.animate()
                    .scaleX(1f).scaleY(1f)
                    .setInterpolator(OvershootInterpolator())
                    .setDuration(140)
                    .start()
            }
            .start()
    }

    /** Drag with snap-to-edge, tap-to-open. */
    private inner class BubbleTouchListener(
        private val view: View,
        private val params: WindowManager.LayoutParams,
    ) : View.OnTouchListener {

        private var initialX = 0
        private var initialY = 0
        private var touchStartX = 0f
        private var touchStartY = 0f
        private var dragging = false
        private val touchSlop = (resources.displayMetrics.density * 8f)

        override fun onTouch(v: View, event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    touchStartX = event.rawX
                    touchStartY = event.rawY
                    dragging = false
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - touchStartX
                    val dy = event.rawY - touchStartY
                    if (!dragging && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                        dragging = true
                    }
                    if (dragging) {
                        params.x = (initialX + dx).toInt()
                            .coerceIn(0, screenWidthPx - view.width)
                        params.y = (initialY + dy).toInt()
                            .coerceIn(0, screenHeightPx - view.height)
                        try {
                            windowManager.updateViewLayout(view, params)
                        } catch (_: Throwable) { /* view detached mid-drag */ }
                    }
                    return true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (dragging) {
                        snapToEdge()
                    } else if (event.action == MotionEvent.ACTION_UP) {
                        openAppFromBubble()
                    }
                    return true
                }
            }
            return false
        }

        private fun snapToEdge() {
            val midX = params.x + view.width / 2
            params.x = if (midX < screenWidthPx / 2) 16 else screenWidthPx - view.width - 16
            try { windowManager.updateViewLayout(view, params) } catch (_: Throwable) {}
        }
    }

    private fun openAppFromBubble() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        }
        startActivity(intent)
    }

    // ---- Foreground notification ---------------------------------------

    private fun startForegroundCompat() {
        ensureNotificationChannel()
        val tapPi = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            },
            pendingIntentFlags(),
        )

        val notif: Notification = (
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                Notification.Builder(this, CHANNEL_ID)
            else
                @Suppress("DEPRECATION") Notification.Builder(this)
            )
            .setContentTitle(getString(R.string.overlay_notification_title))
            .setContentText(getString(R.string.overlay_notification_text))
            .setSmallIcon(R.drawable.ic_brain_mascot)
            .setContentIntent(tapPi)
            .setOngoing(true)
            .setShowWhen(false)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIF_ID,
                notif,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIF_ID, notif)
        }
        running = true
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.overlay_notification_channel),
            NotificationManager.IMPORTANCE_MIN,
        ).apply {
            setShowBadge(false)
            enableLights(false)
            enableVibration(false)
            description = getString(R.string.reel_counter_service_description)
        }
        nm.createNotificationChannel(channel)
    }

    private fun pendingIntentFlags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }

    private fun overlayWindowType(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE

    companion object {
        private const val TAG = "OverlaySvc"
        private const val CHANNEL_ID = "scrolliq_overlay"
        private const val NOTIF_ID = 4711
        const val ACTION_STOP = "com.scrolliq.app.OVERLAY_STOP"

        @Volatile private var running: Boolean = false

        @JvmStatic fun isRunning(): Boolean = running

        @JvmStatic
        fun start(context: Context) {
            val intent = Intent(context, OverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        @JvmStatic
        fun stop(context: Context) {
            val intent = Intent(context, OverlayService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }
}

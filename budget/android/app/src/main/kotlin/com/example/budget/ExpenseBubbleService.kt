package com.budget.tracker_app

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.*
import android.widget.TextView
import kotlin.math.abs

/** Started only by an explicit foreground user action. No background auto-launch. */
class ExpenseBubbleService : Service() {
    private var bubble: TextView? = null
    private lateinit var manager: WindowManager

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "close" || !Settings.canDrawOverlays(this)) {
            stopSelf(); return START_NOT_STICKY
        }
        val notifications = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) notifications.createNotificationChannel(
            NotificationChannel("expenseBubble", "زر تسجيل المصروفات", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 701, Intent(this, MainActivity::class.java)
            .putExtra("quickExpense", true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val close = PendingIntent.getService(this, 702, Intent(this, ExpenseBubbleService::class.java)
            .setAction("close"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "expenseBubble") else Notification.Builder(this)
        val notification = builder.setSmallIcon(R.drawable.notification_icon_android2)
            .setContentTitle("تسجيل مصروف سريع")
            .setContentText("اضغط الزر العائم للتسجيل، أو اضغط مطولًا لإغلاقه")
            .setContentIntent(open).setOngoing(true)
            .addAction(Notification.Action.Builder(null, "إغلاق الزر", close).build()).build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(600000010, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(600000010, notification)
        if (bubble == null) showBubble()
        return START_NOT_STICKY
    }

    private fun showBubble() {
        manager = getSystemService(WINDOW_SERVICE) as WindowManager
        val size = (56 * resources.displayMetrics.density).toInt()
        val params = WindowManager.LayoutParams(size, size,
            if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT)
        params.gravity = Gravity.TOP or Gravity.LEFT
        params.x = resources.displayMetrics.widthPixels - size
        params.y = resources.displayMetrics.heightPixels / 2
        val view = TextView(this).apply {
            text = "+"; textSize = 34f; gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            contentDescription = "تسجيل مصروف، اسحب لتحريك الزر، واضغط مطولًا لإغلاقه"
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Color.rgb(27, 68, 122)) }
            elevation = 8f
            setOnClickListener {
                startActivity(Intent(this@ExpenseBubbleService, MainActivity::class.java)
                    .putExtra("quickExpense", true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
            setOnLongClickListener { stopSelf(); true }
        }
        var downX = 0f; var downY = 0f; var startX = 0; var startY = 0; var moved = false
        val slop = ViewConfiguration.get(this).scaledTouchSlop
        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> { downX = event.rawX; downY = event.rawY; startX = params.x; startY = params.y; moved = false; false }
                MotionEvent.ACTION_MOVE -> {
                    if (abs(event.rawX - downX) > slop || abs(event.rawY - downY) > slop) moved = true
                    if (moved) {
                        params.x = (startX + event.rawX - downX).toInt().coerceIn(0, resources.displayMetrics.widthPixels - size)
                        params.y = (startY + event.rawY - downY).toInt().coerceIn(0, resources.displayMetrics.heightPixels - size)
                        manager.updateViewLayout(view, params)
                        view.cancelLongPress()
                    }
                    moved
                }
                MotionEvent.ACTION_UP -> moved
                else -> false
            }
        }
        try { manager.addView(view, params); bubble = view }
        catch (_: RuntimeException) { stopSelf() }
    }

    override fun onDestroy() {
        bubble?.let { try { manager.removeView(it) } catch (_: RuntimeException) {} }
        bubble = null
        super.onDestroy()
    }
}

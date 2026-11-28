package com.budget.tracker_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var permissionResult: MethodChannel.Result? = null
    private var pendingQuick = false
    private var pendingBankReview = false
    private val pendingBankCaptures = linkedMapOf<String, String>()
    private var inForeground = false
    private var quickWindow = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        acceptExpenseIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cashew/expense_tools")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumeLaunch" -> {
                    result.success(mapOf(
                        "quick" to pendingQuick,
                        "bank" to pendingBankReview,
                        "captures" to pendingBankCaptures.toMap()))
                    pendingBankCaptures.clear()
                    pendingQuick = false
                    pendingBankReview = false
                }
                "quickWindow" -> {
                    quickWindow = call.argument<Boolean>("enabled") == true
                    applyWindowSize()
                    result.success(null)
                }
                "finishQuickWindow" -> {
                    quickWindow = false
                    applyWindowSize()
                    moveTaskToBack(true)
                    result.success(null)
                }
                "overlayPermission" -> result.success(Settings.canDrawOverlays(this))
                "requestOverlayPermission" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")))
                    }
                    result.success(null)
                }
                "showBubble" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        if (call.argument<Boolean>("requestPermission") != false) {
                            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")))
                        }
                        result.success(false)
                    } else {
                        val service = Intent(this, ExpenseBubbleService::class.java)
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(service)
                        else startService(service)
                        result.success(true)
                    }
                }
                "backgroundApp" -> { moveTaskToBack(true); result.success(null) }
                "hideBubble" -> { stopService(Intent(this, ExpenseBubbleService::class.java)); result.success(null) }
                "smsPermission" -> result.success(checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED)
                "requestSmsPermission" -> {
                    if (checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED) result.success(true)
                    else if (permissionResult != null) result.error("busy", "Permission request already open", null)
                    else {
                        permissionResult = result
                        requestPermissions(arrayOf(Manifest.permission.RECEIVE_SMS), 1888)
                    }
                }
                "configureSms" -> {
                    BankSmsStore.preferences(this).edit()
                        .putBoolean("enabled", call.argument<Boolean>("enabled") == true)
                        .putBoolean("quickDebit", call.argument<Boolean>("quickDebit") == true)
                        .apply()
                    result.success(null)
                }
                "pendingSms" -> result.success(BankSmsStore.pending(this).toString())
                "dismissSms" -> {
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    BankSmsStore.remove(this, ids)
                    val manager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
                    ids.forEach { manager.cancel(it, 600000011) }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        acceptExpenseIntent(intent)
        if (pendingQuick) channel?.invokeMethod("quickEntry", null)
        if (pendingBankReview) channel?.invokeMethod("bankReview", null)
        if (pendingBankCaptures.isNotEmpty()) channel?.invokeMethod("bankCapture", null)
    }

    private fun acceptExpenseIntent(intent: Intent?) {
        val captureId = intent?.getStringExtra(BankSmsCapture.ID)
        if (captureId != null && BankSmsCapture.validId(captureId) &&
            BankSmsStore.preferences(this).getBoolean("enabled", false) &&
            BankSmsStore.preferences(this).getBoolean("quickDebit", false)) {
            val wantsWindow = intent?.getBooleanExtra(BankSmsCapture.AUTOMATIC, false) == true
            // A user already in Cashew keeps their normal full-size window.
            pendingBankCaptures[captureId] = when {
                !wantsWindow -> "manual"
                inForeground -> "inline"
                else -> "floating"
            }
        }
        intent?.removeExtra(BankSmsCapture.ID)
        intent?.removeExtra(BankSmsCapture.AUTOMATIC)
        if (intent?.getBooleanExtra("quickExpense", false) == true) {
            pendingQuick = true
            intent.removeExtra("quickExpense")
        }
        if (intent?.getBooleanExtra("bankReview", false) == true) {
            pendingBankReview = true
            intent.removeExtra("bankReview")
        }
    }

    override fun onResume() {
        super.onResume()
        inForeground = true
        applyWindowSize()
    }

    override fun onPause() {
        inForeground = false
        super.onPause()
    }

    private fun applyWindowSize() {
        if (quickWindow) {
            val metrics = resources.displayMetrics
            window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
            window.attributes = window.attributes.apply { dimAmount = 0.35f; gravity = Gravity.CENTER }
            window.setLayout((metrics.widthPixels * 0.94).toInt(), (metrics.heightPixels * 0.87).toInt())
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
            window.setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1888) {
            permissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }
}

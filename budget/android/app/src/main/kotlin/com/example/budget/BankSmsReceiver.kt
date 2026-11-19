package com.budget.tracker_app

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Telephony
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.util.Locale

object BankSmsStore {
    fun preferences(context: Context) = context.getSharedPreferences("bank_sms_inbox", Context.MODE_PRIVATE)
    @Synchronized fun pending(context: Context): JSONArray =
        try { JSONArray(preferences(context).getString("messages", "[]")) } catch (_: Exception) { JSONArray() }
    @Synchronized fun add(context: Context, row: JSONObject): Boolean {
        val messages = pending(context)
        for (i in 0 until messages.length()) if (messages.getJSONObject(i).getString("id") == row.getString("id")) return false
        messages.put(row)
        return preferences(context).edit().putString("messages", messages.toString()).commit()
    }
    @Synchronized fun remove(context: Context, ids: List<String>) {
        val messages = pending(context); val kept = JSONArray()
        for (i in 0 until messages.length()) {
            val row = messages.getJSONObject(i)
            if (row.getString("id") !in ids) kept.put(row)
        }
        preferences(context).edit().putString("messages", kept.toString()).commit()
    }
}

class BankSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION ||
            !BankSmsStore.preferences(context).getBoolean("enabled", false)) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (parts.isEmpty()) return
        val sender = (parts.first().originatingAddress ?: "").trim().uppercase(Locale.ROOT)
        if (sender !in setOf("18888", "18787", "NCB")) return
        if (parts.any { (it.originatingAddress ?: "").trim().uppercase(Locale.ROOT) != sender }) return
        val body = parts.joinToString("") { it.messageBody ?: "" }
        if (Regex("(?i)\\botp\\b|verification|رمز التحقق|كلمة المرور").containsMatchIn(body)) return
        if (!Regex("(?i)خصم|سحب|دفع|شراء|مدين|اضاف|إضاف|ايداع|إيداع|دائن|حوالة|تغذية|debit|credit|withdraw|purchase|deposit|received|spent").containsMatchIn(body)) return
        val timestamp = parts.first().timestampMillis
        val digest = MessageDigest.getInstance("SHA-256").digest("$sender\n$timestamp\n$body".toByteArray())
            .joinToString("") { "%02x".format(it) }
        val row = JSONObject().put("id", digest).put("sender", sender).put("body", body).put("timestamp", timestamp)
        if (!BankSmsStore.add(context, row)) return
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel("bankSmsReview", "مراجعة رسائل البنوك", NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(context, 703, Intent(context, MainActivity::class.java)
            .putExtra("bankReview", true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, "bankSmsReview") else Notification.Builder(context)
        manager.notify(600000011, builder.setSmallIcon(R.drawable.notification_icon_android2)
            .setContentTitle("وصلت رسالة مصرفية")
            .setContentText("اضغط لمراجعتها وربطها بالحساب قبل التسجيل")
            .setVisibility(Notification.VISIBILITY_PRIVATE).setContentIntent(open).setAutoCancel(true).build())
    }
}

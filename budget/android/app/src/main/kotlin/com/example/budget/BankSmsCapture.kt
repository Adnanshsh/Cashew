package com.budget.tracker_app

import android.content.Context
import android.content.Intent

internal object BankSmsCapture {
    const val ID = "bankCaptureId"
    const val AUTOMATIC = "bankCaptureAutomatic"

    private val balance = Regex("الرصيد|رصيدك|العمولة|الرسوم|balance|fees?", RegexOption.IGNORE_CASE)
    private val debit = Regex("خصم|سحب|مدين|شراء|تم\\s+دفع|\\b(?:debit(?:ed)?|withdraw(?:al|n)?|purchase|spent)\\b", RegexOption.IGNORE_CASE)
    private val credit = Regex("اضافة|ايداع|دائن|حوالة واردة|استرداد|ارجاع|\\b(?:refund(?:ed)?|credit(?:ed)?|deposit(?:ed)?|received)\\b", RegexOption.IGNORE_CASE)
    private val code = Regex("رمز التحقق|رمز التاكيد|كلمة المرور|\\botp\\b|one.?time|verification", RegexOption.IGNORE_CASE)

    private val lydAmount = Regex(
        """(?:[0-9٠-٩۰-۹][0-9٠-٩۰-۹,.٫٬]*\s*(?:د\s*\.?\s*ل\.?|دينار|\b(?:lyd|ld)\b)|\b(?:lyd|ld)\s*[0-9٠-٩۰-۹])""",
        RegexOption.IGNORE_CASE)
    private val foreign = Regex(
        """\b(?:usd|eur|gbp|sar|aed|tnd|egp|try|qar|kwd|bhd|omr|jod|dzd|mad|cad|aud|chf|cny|jpy|rub)\b|[€£¥]|دولار|يورو|ريال|درهم|جنيه|ليرة|تونسي""",
        RegexOption.IGNORE_CASE)

    fun isDebitCandidate(body: String): Boolean {
        val normalized = body.replace(Regex("[\\u064B-\\u065F\\u0670]"), "")
            .replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا')
        val payment = balance.split(normalized, limit = 2).first()
        return !code.containsMatchIn(normalized) && debit.containsMatchIn(payment) &&
            !credit.containsMatchIn(payment) && lydAmount.containsMatchIn(payment) &&
            '$' !in payment && !foreign.containsMatchIn(payment)
    }

    fun validId(id: String) = Regex("[a-f0-9]{64}").matches(id)

    fun intent(context: Context, id: String, automatic: Boolean) =
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .putExtra(ID, id).putExtra(AUTOMATIC, automatic)
}

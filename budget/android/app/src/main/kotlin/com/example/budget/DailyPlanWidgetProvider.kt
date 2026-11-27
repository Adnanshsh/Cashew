package com.budget.tracker_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Locale

class DailyPlanWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        val fields = data.getString("dailyPlanSnapshot", null)?.split("\n", limit = 3).orEmpty()
        val arabic = Locale.getDefault().language == "ar"
        val views = RemoteViews(context.packageName, R.layout.net_worth_widget_layout)
        views.setTextViewText(R.id.net_worth_title, if (arabic) "المتاح اليوم" else "Daily allowance")
        views.setTextViewText(R.id.net_worth_amount, fields.getOrNull(1) ?: "—")
        val stamp = fields.firstOrNull()?.take(16)?.replace('T', ' ')
        views.setTextViewText(R.id.net_worth_transactions_number,
            listOfNotNull(fields.getOrNull(2), stamp).joinToString(" · "))
        views.setOnClickPendingIntent(R.id.widget_container, HomeWidgetLaunchIntent.getActivity(
            context, MainActivity::class.java, Uri.parse("dailySpendingPlan")))
        ids.forEach { manager.updateAppWidget(it, views) }
    }
}

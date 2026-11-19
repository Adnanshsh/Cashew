import 'package:budget/functions.dart';
import 'package:budget/pages/expense_tools/bank_sms_page.dart';
import 'package:budget/struct/expense_tools/expense_tools.dart';
import 'package:budget/struct/expense_tools/reminder_times.dart';
import 'package:budget/struct/initializeNotifications.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/notificationsSettings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExpenseReminderSettings extends StatefulWidget {
  const ExpenseReminderSettings({super.key});
  @override
  State<ExpenseReminderSettings> createState() =>
      _ExpenseReminderSettingsState();
}

class _ExpenseReminderSettingsState extends State<ExpenseReminderSettings> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final minutes =
        expenseReminderMinutes(appStateSettings['expenseReminderMinutes']);
    return Card(
        child: Column(children: [
      SwitchListTile(
        title: Text(expenseText(context, 'تذكير المصروفات 4 مرات يوميًا',
            'Four daily expense reminders')),
        subtitle: Text(expenseText(
            context,
            'تستمر يوميًا حتى لو فتحت التطبيق. قد يؤخر أندرويد التنبيه قليلًا لتوفير البطارية.',
            'Repeat daily even after opening the app. Android may delay delivery to save battery.')),
        value: appStateSettings['notifications'] == true,
        onChanged: _busy
            ? null
            : (enabled) async {
                setState(() => _busy = true);
                try {
                  if (enabled) await initializeNotificationsPlatform();
                  await updateSettings('notifications', enabled,
                      updateGlobalState: false);
                  if (enabled)
                    await setDailyNotifications(context);
                  else
                    await cancelDailyNotification();
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
      ),
      if (appStateSettings['notifications'] == true)
        for (var i = 0; i < minutes.length; i++)
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(
                expenseText(context, 'التذكير ${i + 1}', 'Reminder ${i + 1}')),
            trailing: Text(
                '${(minutes[i] ~/ 60).toString().padLeft(2, '0')}:${(minutes[i] % 60).toString().padLeft(2, '0')}'),
            onTap: _busy
                ? null
                : () async {
                    final selected = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                            hour: minutes[i] ~/ 60, minute: minutes[i] % 60));
                    if (selected == null || !mounted) return;
                    final changed = [...minutes];
                    changed[i] = selected.hour * 60 + selected.minute;
                    if (changed.toSet().length != 4) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(expenseText(
                              context,
                              'اختر أربعة مواعيد مختلفة.',
                              'Choose four distinct times.'))));
                      return;
                    }
                    setState(() => _busy = true);
                    try {
                      await updateSettings('expenseReminderMinutes',
                          expenseReminderMinutes(changed),
                          updateGlobalState: false);
                      await setDailyNotifications(context);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          ),
    ]));
  }
}

class ExpenseToolsSettings extends StatefulWidget {
  const ExpenseToolsSettings({super.key});
  @override
  State<ExpenseToolsSettings> createState() => _ExpenseToolsSettingsState();
}

class _ExpenseToolsSettingsState extends State<ExpenseToolsSettings> {
  @override
  Widget build(BuildContext context) => Card(
          child: Column(children: [
        SwitchListTile(
          title: Text(expenseText(context, 'اهتزاز خفيف للوحة الأرقام',
              'Gentle number pad vibration')),
          value: appStateSettings['numberPadHapticFeedback'] == true,
          onChanged: (enabled) async {
            if (enabled) HapticFeedback.selectionClick();
            await updateSettings('numberPadHapticFeedback', enabled,
                updateGlobalState: false);
            if (mounted) setState(() {});
          },
        ),
        if (ExpenseTools.supported) ...[
          ListTile(
            leading: const Icon(Icons.bubble_chart_outlined),
            title: Text(expenseText(context, 'إظهار زر تسجيل المصروف العائم',
                'Show floating expense button')),
            subtitle: Text(expenseText(
                context,
                'اسحبه لتحريكه، واضغطه للتسجيل، واضغط مطولًا لإغلاقه.',
                'Drag to move, tap to record, or long-press to close.')),
            onTap: () async {
              final shown = await ExpenseTools.showBubble();
              if (!shown && mounted)
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(expenseText(
                        context,
                        'امنح إذن الظهور فوق التطبيقات، ثم اضغط الزر مرة أخرى.',
                        'Allow display over other apps, then tap this option again.'))));
            },
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: Text(expenseText(
                context, 'إخفاء الزر العائم', 'Hide floating button')),
            onTap: () => ExpenseTools.channel.invokeMethod('hideBubble'),
          ),
          ListTile(
            leading: const Icon(Icons.sms_outlined),
            title: Text(expenseText(context, 'رسائل البنوك وربط الحسابات',
                'Bank messages & linked accounts')),
            subtitle: const Text('18888 • 18787 • NCB'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushRoute(context, const BankSmsPage()),
          ),
        ],
      ]));
}

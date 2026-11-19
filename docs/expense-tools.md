# Expense entry tools (5.4.4 / 417)

Open Settings → Notifications to configure four daily reminder times, number-pad
haptics, the floating entry button, and Bank messages & linked accounts.

- The default device-local reminder times are 10:00, 14:00, 18:00, and 22:00.
  Four recurring notifications replace the previous finite daily schedule.
  Android uses inexact idle-aware alarms, so delivery can be delayed by the OS.
- A reminder opens a floating button when overlay access has been granted.
  Record now opens the existing transaction editor in a compact activity window.
  Drag the button to move it; long-press or use its ongoing notification to close.
  Overlay access is granted explicitly from the notifications settings page.
- Number pad feedback defaults to a gentle selection click on this upgrade and
  can be disabled again. System haptic settings still apply.
- Bank SMS reception is off until enabled and RECEIVE_SMS is granted. Only new
  SMS from exact sender IDs 18888 (شمال أفريقيا), 18787 (التنمية), and NCB
  (التجاري) are queued in private on-device preferences. The old SMS history is
  not queried. Multipart messages are combined before processing.
- Link each sender to the correct existing wallet. A unique matching Arabic
  wallet name is suggested; an explicit mapping takes precedence. Review the
  direction, amount, category and wallet in the normal editor before saving.
  Unknown or ambiguous amounts require manual entry. Full SMS bodies are not
  copied into transaction notes or sent by the new code to a server.
- An exact delivery ID gives each imported transaction a stable primary key.
  The inbox reconciles committed IDs before displaying pending entries, so
  reopening after a save/ack interruption does not create another transaction.
  Dismiss removes the private pending copy. Ordinary app backup/sync behavior
  continues to apply to saved transactions.
## Validation

Run existing database, western-digit and swipe tests, plus bank_sms_parser_test.
Build a release APK and verify that its certificate matches the existing key.

On an Android phone, test notifications with the app closed, reboot recovery,
overlay permission denial/grant, bubble dragging/closing, compact editor save
and cancel, and both debit and credit multipart SMS for each sender. Verify
that unrelated senders and OTPs are ignored, denying SMS permission leaves
manual entry working, and a duplicate delivery is not imported twice.

Parser fixtures are synthetic. Validate real bank message formats on-device;
unrecognized messages remain reviewable and are never auto-posted.

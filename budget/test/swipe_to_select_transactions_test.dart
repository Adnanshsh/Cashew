import 'package:budget/widgets/transactionEntry/swipeToSelectTransactions.dart';
import 'package:budget/widgets/transactionEntry/transactionEntry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _listId = 'swipe-selection-test';
const _firstKey = ValueKey('first-row');
const _secondKey = ValueKey('second-row');

class _HitTestCounter extends SingleChildRenderObjectWidget {
  const _HitTestCounter({required this.onHitTest, required super.child});

  final VoidCallback onHitTest;

  @override
  _HitTestCounterRenderBox createRenderObject(BuildContext context) =>
      _HitTestCounterRenderBox(onHitTest);

  @override
  void updateRenderObject(
    BuildContext context,
    _HitTestCounterRenderBox renderObject,
  ) {
    renderObject.onHitTest = onHitTest;
  }
}

class _HitTestCounterRenderBox extends RenderProxyBox {
  _HitTestCounterRenderBox(this.onHitTest);

  VoidCallback onHitTest;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    onHitTest();
    return super.hitTest(result, position: position);
  }
}

Widget _page({required VoidCallback onHitTest, bool transactionRows = true}) {
  Widget row(String id, Key key) {
    const color = Color(0xFF234567);
    final child = ColoredBox(key: key, color: color);
    return Expanded(
      child: transactionRows
          ? TransactionEntryBox(transactionKey: id, child: child)
          : child,
    );
  }

  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: SwipeToSelectTransactions(
          listID: _listId,
          child: _HitTestCounter(
            onHitTest: onHitTest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [row('first', _firstKey), row('second', _secondKey)],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, List<String>> previousSelection;
  late int previousSelectingMode;
  var hapticFeedbackCount = 0;

  setUp(() {
    previousSelection = globalSelectedID.value;
    previousSelectingMode = selectingTransactionsActive;
    globalSelectedID.value = {_listId: <String>[]};
    selectingTransactionsActive = 0;
    hapticFeedbackCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticFeedbackCount++;
      return null;
    });
  });

  tearDown(() {
    globalSelectedID.value = previousSelection;
    selectingTransactionsActive = previousSelectingMode;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (final transactionRows in [true, false]) {
    testWidgets(
        'inactive pointer moves avoid extra hit tests '
        '${transactionRows ? "on transactions" : "on other pages"}', (
      tester,
    ) async {
      var hitTests = 0;
      await tester.pumpWidget(
        _page(onHitTest: () => hitTests++, transactionRows: transactionRows),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_firstKey)),
      );
      // Pointer-down needs the normal framework hit test. Subsequent touch
      // moves reuse its route and should not trigger a second page hit test.
      hitTests = 0;
      await gesture.moveBy(const Offset(0, 10));
      await gesture.moveBy(const Offset(0, 10));
      expect(hitTests, 0);
      expect(globalSelectedID.value[_listId], isEmpty);
      expect(hapticFeedbackCount, 0);
      await gesture.up();
    });
  }

  testWidgets('active drag selects another row once and pointer up ends it', (
    tester,
  ) async {
    var hitTests = 0;
    await tester.pumpWidget(_page(onHitTest: () => hitTests++));
    // A long press on the first row has already selected the origin row.
    globalSelectedID.value[_listId]!.add('first');
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_firstKey)),
    );
    selectingTransactionsActive = 1;
    hitTests = 0;
    final destination = tester.getCenter(find.byKey(_secondKey));
    await gesture.moveTo(destination);
    expect(hitTests, greaterThan(0));
    expect(globalSelectedID.value[_listId], ['first', 'second']);
    await gesture.moveTo(destination + const Offset(1, 1));
    expect(globalSelectedID.value[_listId], ['first', 'second']);
    expect(hapticFeedbackCount, 1);
    await gesture.up();
    expect(selectingTransactionsActive, 0);
  });

  testWidgets('active deselection preserves unrelated selected rows', (
    tester,
  ) async {
    await tester.pumpWidget(_page(onHitTest: () {}));
    globalSelectedID.value[_listId]!.addAll(['second', 'unrelated']);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_firstKey)),
    );
    selectingTransactionsActive = -1;
    final destination = tester.getCenter(find.byKey(_secondKey));
    await gesture.moveTo(destination);
    expect(globalSelectedID.value[_listId], ['unrelated']);
    await gesture.moveTo(destination + const Offset(1, 1));
    expect(globalSelectedID.value[_listId], ['unrelated']);
    expect(hapticFeedbackCount, 1);
    await gesture.up();
    expect(selectingTransactionsActive, 0);
  });

  testWidgets('pointer cancellation ends selection before the next touch', (
    tester,
  ) async {
    var hitTests = 0;
    await tester.pumpWidget(_page(onHitTest: () => hitTests++));
    final cancelled = await tester.startGesture(
      tester.getCenter(find.byKey(_firstKey)),
    );
    selectingTransactionsActive = 1;
    await cancelled.cancel();
    expect(selectingTransactionsActive, 0);

    final next = await tester.startGesture(
      tester.getCenter(find.byKey(_secondKey)),
    );
    hitTests = 0;
    await next.moveBy(const Offset(1, 1));
    expect(hitTests, 0);
    expect(globalSelectedID.value[_listId], isEmpty);
    expect(hapticFeedbackCount, 0);
    await next.up();
  });
}

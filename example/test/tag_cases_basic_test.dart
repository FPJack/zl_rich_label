import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zl_rich_label/zl_rich_label.dart';
import 'package:zl_rich_label_example/demo_common.dart';
import 'package:zl_rich_label_example/tag_cases_basic.dart';

void main() {
  testWidgets('basic tag cases render, tap and toggle the checkbox',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final TapLog log = TapLog();
    addTearDown(log.dispose);
    final List<Widget> cases = basicTagCases(log);
    expect(cases.length, 16);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: cases),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(ZLTagRichLabel), findsNWidgets(16));

    // Case 1: tap "User Agreement" (h1) → onTagTap fallback.
    final RenderZLText render =
        tester.renderObject<RenderZLText>(find.byType(ZLTextLayout).first);
    final int start = render.content.string.indexOf('User Agreement');
    expect(start, greaterThan(0));
    final Rect rect =
        render.rectsForRange(TextRange(start: start, end: start + 4)).first;
    await tester.tapAt(render.localToGlobal(rect.center));
    await tester.pump();
    expect(log.last, isNotNull);
    expect(log.last!.info.name, 'h1');
    expect(log.last!.info.text, 'User Agreement');
    expect(log.last!.caseName, startsWith('1.'));

    // Case 11: the checkbox handles its own taps and does not log a tag tap.
    final int records = log.history.length;
    final Finder unchecked = find.byIcon(Icons.radio_button_unchecked);
    expect(unchecked, findsNWidgets(2)); // cases 11 and 16
    await tester.ensureVisible(unchecked.first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.radio_button_unchecked).first);
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    expect(log.history.length, records);

    // Case 11: tap the h1 tag text next to the checkbox.
    final RenderZLText render11 =
        tester.renderObject<RenderZLText>(find.byType(ZLTextLayout).at(10));
    final int h1 = render11.content.string.indexOf('User Agreement');
    final Rect rect11 =
        render11.rectsForRange(TextRange(start: h1, end: h1 + 4)).first;
    await tester.tapAt(render11.localToGlobal(rect11.center));
    await tester.pump();
    expect(log.last!.caseName, startsWith('11.'));
    expect(log.last!.info.name, 'h1');
    expect(tester.takeException(), isNull);
  });
}

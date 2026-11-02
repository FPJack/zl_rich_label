import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zl_rich_label/zl_rich_label.dart';
import 'package:zl_rich_label_example/advanced_cases.dart';
import 'package:zl_rich_label_example/demo_common.dart';

void main() {
  testWidgets('advanced cases 24 – 31 render and respond',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (MethodCall call) async => null);

    final TapLog log = TapLog();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: advancedCases(log)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    List<RenderZLText> renders() => tester
        .renderObjectList<RenderZLText>(find.byType(ZLTextLayout))
        .toList();
    RenderZLText renderWith(String text) => renders()
        .firstWhere((RenderZLText r) => r.content.string.contains(text));

    // 24: the first label is truncated with "… 全文"; 24b / 24c are not truncated.
    final List<RenderZLText> expandable = renders()
        .where(
            (RenderZLText r) => r.content.string.startsWith('ZLRichLabel 支持'))
        .toList();
    expect(expandable.first.isTruncated, isTrue);
    expect(renderWith('短内容').isTruncated, isFalse);
    expect(
        renderWith('collapseThreshold = 5：maxLines 仍为 3').isTruncated, isFalse);
    expect(
        renders()
            .firstWhere((RenderZLText r) =>
                r.content.string.startsWith('ZLRichLabel 支持') &&
                r.content.length > 300)
            .isTruncated,
        isTrue);

    final RenderZLText r24 = expandable.first;
    await tester.tapAt(r24.localToGlobal(r24.tokenRect!.center));
    await tester.pumpAndSettle();
    expect(log.last!.action, 'onExpandChanged(true)');
    expect(renders().first.isTruncated, isFalse);

    // 24e: tapping the token asks first and does not expand by itself.
    final RenderZLText r24e = renders()
        .where((RenderZLText r) =>
            r.isTruncated && r.content.string.startsWith('ZLRichLabel 支持'))
        .last;
    await tester.tapAt(r24e.localToGlobal(r24e.tokenRect!.center));
    await tester.pumpAndSettle();
    expect(log.last!.action, 'onExpandTokenTap(wantsExpand: true)');
    expect(find.text('展开全文？'), findsOneWidget);
    await tester.tap(find.text('展开（toggleExpanded）'));
    await tester.pumpAndSettle();
    expect(log.last!.action, 'onExpandChanged(true)');

    // 26: long press selects the mention as a whole and maps it to the raw text.
    final RenderZLText r26 = renderWith('👤alice');
    final int mention = r26.content.string.indexOf('👤alice');
    await tester.longPressAt(r26.localToGlobal(r26
        .rectsForRange(TextRange(start: mention, end: mention + 7))
        .first
        .center));
    await tester.pumpAndSettle();
    expect(find.textContaining('selectedRawText = "@alice"'), findsOneWidget);
    // Tap elsewhere clears the selection.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // 27: tapping the nested link calls the <a> handler with its href.
    final RenderZLText r27 = renderWith('GitHub');
    final int github = r27.content.string.indexOf('GitHub');
    await tester.tapAt(r27.localToGlobal(r27
        .rectsForRange(TextRange(start: github, end: github + 6))
        .first
        .center));
    await tester.pumpAndSettle();
    expect(log.last!.action, '打开 https://github.com');
    expect(find.byIcon(Icons.star), findsOneWidget);

    // 28: capsules, gradients and the baseline-shifted badge.
    expect(find.text('NEW'), findsNWidgets(2));

    // 30: every inline widget follows its placeholder, also after resizing.
    expect(find.textContaining('结论：所有 Widget 已跟随 label 尺寸更新'), findsOneWidget);
    await tester.drag(
        find.byKey(const Key('case30Slider')), const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('结论：所有 Widget 已跟随 label 尺寸更新'), findsOneWidget);
    await tester.tap(find.text('+ 关注'));
    await tester.pumpAndSettle();
    expect(find.text('✓ 已关注'), findsOneWidget);
    expect(find.textContaining('结论：所有 Widget 已跟随 label 尺寸更新'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}

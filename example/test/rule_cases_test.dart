import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zl_rich_label/zl_rich_label.dart';
import 'package:zl_rich_label_example/demo_common.dart';
import 'package:zl_rich_label_example/rule_cases.dart';

void main() {
  testWidgets('rule cases 17 – 23 render and respond',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final TapLog log = TapLog();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: ruleCases(log),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    List<RenderZLText> renders() => tester
        .renderObjectList<RenderZLText>(find.byType(ZLTextLayout))
        .toList();
    RenderZLText renderWith(String text) => renders()
        .firstWhere((RenderZLText r) => r.content.string.contains(text));

    // 17: link replaced, mention tappable.
    final RenderZLText r17 = renderWith('🔗网页链接');
    expect(r17.content.string,
        'Hi @alice and @bob_99, join #SwiftUI# talk: 🔗网页链接');
    await tester.tapAt(r17.localToGlobal(
        r17.rectsForRange(const TextRange(start: 3, end: 9)).first.center));
    await tester.pump();
    expect(log.last!.action, contains('mention'));
    expect(log.last!.info.text, '@alice');
    // The card lists the matches (read after the first frame).
    expect(find.textContaining('规则命中 matches（共 4 个）'),
        findsNWidgets(2)); // 17 and 20
    expect(find.textContaining('规则命中 matches（共 6 个）'), findsOneWidget); // 18

    // 18: icons and variables.
    expect(renderWith('Hello Alice').content.string,
        startsWith('Hello Alice \uFFFC, you have 3 new messages'));

    // 19: priorities.
    final List<RenderZLText> call = renders()
        .where((RenderZLText r) => r.content.string.startsWith('Call '))
        .toList();
    expect(call[0].content.string,
        'Call <h1>13800138000</h1> or 400-123-4567, order 2024.');
    expect(call[1].content.string,
        'Call 13800138000 or 400-123-4567, order 2024.');

    // 21: the box grows.
    final Finder box = find.byKey(const Key('case21-box'));
    await tester.ensureVisible(box);
    await tester.pumpAndSettle();
    final double before = tester.getSize(box).width;
    await tester.tap(box);
    await tester.pump();
    expect(tester.getSize(box).width, greaterThan(before));
    await tester.tap(find.byKey(const Key('case21-like')));
    await tester.pump();
    expect(find.text('👍 1'), findsOneWidget);

    // 22: dark mode re-renders the {mode} rule.
    expect(renderWith('Appearance:').content.string, contains('☀️ Light'));
    await tester.ensureVisible(find.text('深色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pump();
    expect(renderWith('Appearance:').content.string, contains('🌙 Dark'));
    await tester.tap(find.text('AX3'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 23: highlight change reuses every handler.
    expect(find.textContaining('首次渲染'), findsOneWidget);
    await tester.ensureVisible(find.text('改按下高亮'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('改按下高亮'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('handler 执行 0 次，复用 600 个命中'), findsOneWidget);

    await tester.tap(find.text('只刷新 @提及'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('handler 执行 200 次，复用 400 个命中'), findsOneWidget);

    await tester.tap(find.text('layout ×100'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('getDryLayout ×100'), findsOneWidget);
    expect(find.textContaining('文本排版 0 次'), findsOneWidget);

    await tester.tap(find.text('解析 1.5 万命中'));
    await tester.pump();
    expect(find.textContaining('生效命中 15000 个'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zl_rich_label/zl_rich_label.dart';
import 'package:zl_rich_label_example/attributed_label_demo_page.dart';
import 'package:zl_rich_label_example/declarative_demo_page.dart';
import 'package:zl_rich_label_example/demo_common.dart';
import 'package:zl_rich_label_example/main.dart';

void _tallView(WidgetTester tester, double height) {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

List<RenderZLText> _renders(WidgetTester tester) =>
    tester.renderObjectList<RenderZLText>(find.byType(ZLTextLayout)).toList();

/// Global centre of the first box of [text] in the first label containing it.
Offset _centerOfText(WidgetTester tester, String text, {bool last = false}) {
  final RenderZLText render = _renders(tester)
      .firstWhere((RenderZLText r) => r.content.string.contains(text));
  final int start = last
      ? render.content.string.lastIndexOf(text)
      : render.content.string.indexOf(text);
  return render.localToGlobal(render
      .rectsForRange(TextRange(start: start, end: start + text.length))
      .first
      .center);
}

void main() {
  testWidgets('ZLAttributedLabel page renders and links respond',
      (WidgetTester tester) async {
    _tallView(tester, 6000);
    await tester.pumpWidget(const MaterialApp(home: AttributedLabelDemoPage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tapAt(_centerOfText(tester, '点我计数'));
    await tester.pumpAndSettle();
    expect(find.textContaining('第 1 次'), findsOneWidget);

    await tester.tapAt(_centerOfText(tester, '橙色胶囊'));
    await tester.pumpAndSettle();
    expect(find.textContaining('自定义'), findsWidgets);

    // Inactive style while a dialog is shown.
    await tester.tap(find.text('弹出 alert 查看失活样式'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('declarative page: tags, dynamic text, expand sync',
      (WidgetTester tester) async {
    _tallView(tester, 3000);
    await tester.pumpWidget(const MaterialApp(home: DeclarativeDemoPage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tapAt(_centerOfText(tester, '《用户协议》'));
    await tester.pumpAndSettle();
    expect(find.textContaining('onTagTap  <h1> 《用户协议》'), findsOneWidget);

    // Dynamic text: the label follows the text field.
    await tester.enterText(
        find.byKey(const Key('dynamicTextField')), 'Hello <h1>world</h1>');
    await tester.pump();
    expect(
        _renders(tester)
            .any((RenderZLText r) => r.content.string == 'Hello world'),
        isTrue);

    // Expand state driven by the parent switch.
    RenderZLText expandable() => _renders(tester).firstWhere(
        (RenderZLText r) => r.content.string.startsWith('在 Flutter 中直接使用'));
    expect(expandable().isTruncated, isTrue);
    await tester.tap(find.descendant(
        of: find.byKey(const Key('expandSwitch')),
        matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(expandable().isTruncated, isFalse);
    // ...and the collapse token updates the parent switch.
    await tester.tapAt(_centerOfText(tester, '收起', last: true));
    await tester.pumpAndSettle();
    expect(expandable().isTruncated, isTrue);
    expect(
        tester.widget<SwitchRow>(find.byKey(const Key('expandSwitch'))).value,
        isFalse);

    await tester.tapAt(_centerOfText(tester, '#Dart#'));
    await tester.pumpAndSettle();
    expect(find.textContaining('话题 #Dart#'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app: home page and both list modes build',
      (WidgetTester tester) async {
    _tallView(tester, 1600);
    await tester.pumpWidget(const ZLRichLabelExampleApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('ZLRichLabel Demo'), findsOneWidget);

    await tester.tap(find.text('ListView'));
    await tester.pumpAndSettle();
    expect(find.text('ListView Demo'), findsOneWidget);
    await tester.fling(
        find.byKey(const Key('richDemoList')), const Offset(0, -20000), 5000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('声明式'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Base'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

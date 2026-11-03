import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zl_rich_label/zl_rich_label.dart';

Widget _app(Widget child, {double width = 300}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

RenderZLText _render(WidgetTester tester) =>
    tester.renderObject<RenderZLText>(find.byType(ZLTextLayout).first);

/// Global centre of a display range of the first label.
Offset _centerOf(WidgetTester tester, TextRange range) {
  final RenderZLText render = _render(tester);
  final Rect rect = render.rectsForRange(range).first;
  return render.localToGlobal(rect.center);
}

const ZLTextStyle _base =
    ZLTextStyle(textStyle: TextStyle(fontSize: 15, color: Colors.black));

void main() {
  testWidgets('tag taps dispatch per name and fall back to onTagTap',
      (WidgetTester tester) async {
    final List<String> taps = <String>[];
    const String text =
        'Read <h1>Agreement</h1>, <h2>Privacy</h2> and <h3>FAQ</h3>.';
    await tester.pumpWidget(_app(ZLTagRichLabel(
      text: text,
      style: _base,
      tagStyle: ZLTextStyle().color(Colors.blue),
      tagTapHandlers: <String, ZLTagTapCallback>{
        'h1': (ZLTagInfo info) => taps.add('h1:${info.text}')
      },
      onTagTap: (ZLTagInfo info) => taps.add('fallback:${info.name}'),
    )));
    final RenderZLText render = _render(tester);
    expect(render.content.string, 'Read Agreement, Privacy and FAQ.');

    await tester.tapAt(_centerOf(tester, const TextRange(start: 5, end: 14)));
    await tester.tapAt(_centerOf(tester, const TextRange(start: 16, end: 23)));
    await tester.tapAt(_centerOf(tester, const TextRange(start: 0, end: 4)));
    await tester.pump();
    expect(taps, <String>['h1:Agreement', 'fallback:h2']);
  });

  testWidgets('press highlight is applied while pressed',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(ZLTagRichLabel(
      text: 'Press <h1>here</h1> now',
      style: _base,
      highlightStyle: ZLTextStyle().backgroundColor(Colors.yellow),
      onTagTap: (_) {},
    )));
    final TestGesture gesture = await tester
        .startGesture(_centerOf(tester, const TextRange(start: 6, end: 10)));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_render(tester).content.styleAt(7)!.textStyle.backgroundColor,
        Colors.yellow);
    await gesture.up();
    await tester.pump();
    expect(
        _render(tester).content.styleAt(7)!.textStyle.backgroundColor, isNull);
  });

  testWidgets('rules: replacement text, inline widgets and taps',
      (WidgetTester tester) async {
    final List<String> taps = <String>[];
    await tester.pumpWidget(_app(ZLRichLabel(
      text: 'Hi @alice [smile] https://flutter.dev',
      style: _base,
      rules: <ZLRichRule>[
        ZLRichRule.regex('mention', r'@\w+', handler: (ZLRichRuleContext ctx) {
          ctx.addStyle(ZLTextStyle().color(Colors.purple));
          ctx.onTap = (ZLRichMatch m) => taps.add(m.text);
        }),
        ZLRichRule.regex('emoji', r'\[smile\]',
            handler: (ZLRichRuleContext ctx) {
          ctx.setWidget(ZLRichWidget.icon(Icons.face, size: 17));
          ctx.onTap = (ZLRichMatch m) => taps.add('emoji');
        }),
        ZLRichRule(
          name: 'link',
          pattern:
              ZLDataDetector(<ZLDataDetectorType>{ZLDataDetectorType.link}),
          handler: (ZLRichRuleContext ctx) {
            ctx.setText('🔗link', ZLTextStyle().color(Colors.blue));
            ctx.onTap = (ZLRichMatch m) =>
                taps.add((m.result as ZLDataDetectorResult).url.toString());
          },
        ),
      ],
    )));
    expect(_render(tester).content.string, 'Hi @alice \uFFFC 🔗link');
    expect(find.byIcon(Icons.face), findsOneWidget);
    await tester.tapAt(_centerOf(tester, const TextRange(start: 3, end: 9)));
    await tester.tap(find.byIcon(Icons.face));
    await tester.tapAt(_centerOf(tester, const TextRange(start: 12, end: 18)));
    await tester.pump();
    expect(taps, <String>['@alice', 'emoji', 'https://flutter.dev']);
  });

  testWidgets('tail truncation with expand / collapse tokens',
      (WidgetTester tester) async {
    final List<bool> changes = <bool>[];
    final ZLRichLabelController controller = ZLRichLabelController();
    final String long = List<String>.filled(30, 'word').join(' ');
    await tester.pumpWidget(_app(ZLTagRichLabel(
      text: long,
      style: _base,
      maxLines: 2,
      expandToken:
          ZLAttributedText('… more', style: ZLTextStyle().color(Colors.orange)),
      collapseToken: ZLAttributedText(' less'),
      onExpandChanged: changes.add,
      controller: controller,
    )));
    final RenderZLText render = _render(tester);
    expect(render.isTruncated, isTrue);
    expect(controller.isTruncated, isTrue);
    final double collapsedHeight = render.size.height;
    final Rect token = controller.expandTokenRect!;
    await tester.tapAt(render.localToGlobal(token.center));
    await tester.pump();
    expect(changes, <bool>[true]);
    expect(controller.isExpanded, isTrue);
    expect(_render(tester).isTruncated, isFalse);
    expect(_render(tester).size.height, greaterThan(collapsedHeight));
    expect(_render(tester).content.string.endsWith(' less'), isTrue);

    // Tap "less".
    final int length = _render(tester).content.length;
    await tester
        .tapAt(_centerOf(tester, TextRange(start: length - 4, end: length)));
    await tester.pump();
    expect(changes, <bool>[true, false]);
    expect(_render(tester).isTruncated, isTrue);
  });

  testWidgets('collapseThreshold keeps short texts expanded',
      (WidgetTester tester) async {
    final String text = List<String>.filled(25, 'word').join(' ');
    await tester.pumpWidget(_app(ZLRichLabel(
      text: text,
      style: _base,
      maxLines: 2,
      collapseThreshold: 10,
      expandToken: ZLAttributedText('… more'),
    )));
    expect(_render(tester).isTruncated, isFalse);
  });

  testWidgets('head and middle truncation on one line',
      (WidgetTester tester) async {
    for (final ZLTruncationMode mode in ZLTruncationMode.values) {
      await tester.pumpWidget(_app(ZLAttributedLabel(
        'START ${List<String>.filled(20, 'middle').join(' ')} END',
        style: _base,
        maxLines: 1,
        truncationMode: mode,
      )));
      final RenderZLText render = _render(tester);
      expect(render.isTruncated, isTrue, reason: mode.name);
      expect(render.lineCount, greaterThan(1));
    }
  });

  testWidgets('links, data detectors and long press',
      (WidgetTester tester) async {
    final List<String> events = <String>[];
    const String text = 'Visit https://flutter.dev or tap me now';
    await tester.pumpWidget(_app(ZLAttributedLabel(
      text,
      style: _base,
      dataDetectorTypes: const <ZLDataDetectorType>{ZLDataDetectorType.link},
      onLinkTap: (ZLLabelLink link) => events.add('tap ${link.url}'),
      onLinkLongPress: (ZLLabelLink link, Offset _) =>
          events.add('long ${link.url}'),
      links: <ZLLabelLink>[
        ZLLabelLink(
            range: const TextRange(start: 29, end: 35),
            onTap: (_) => events.add('tap me')),
      ],
    )));
    await tester.tapAt(_centerOf(tester, const TextRange(start: 6, end: 25)));
    await tester.tapAt(_centerOf(tester, const TextRange(start: 29, end: 35)));
    await tester
        .longPressAt(_centerOf(tester, const TextRange(start: 6, end: 25)));
    await tester.pump();
    expect(events, <String>[
      'tap https://flutter.dev',
      'tap me',
      'long https://flutter.dev'
    ]);
  });

  testWidgets('capsules, gradients and baseline offsets render',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(ZLTagRichLabel(
      text: '<grad>Gradient title</grad> <new>NEW</new> #topic# `code`',
      style: _base.withLineSpacing(6),
      tagConfiguration: ZLTagParserConfiguration.anyTags,
      tagStyles: <String, ZLTextStyle>{
        'grad': ZLTextStyle()
            .boldFont(22)
            .gradientColors(<Color>[Colors.pink, Colors.orange]),
        'new': ZLTextStyle()
            .boldFont(11)
            .color(Colors.white)
            .baseline(3)
            .withBackground(const ZLTextBackground(
                fillColor: Colors.deepOrange, cornerRadius: 4)),
      },
      rules: <ZLRichRule>[
        ZLRichRule.regex('topic', r'#[^#\s]+#',
            handler: (ZLRichRuleContext ctx) {
          ctx.addStyle(
              ZLTextStyle().color(Colors.purple).capsule(Colors.purple));
        }),
        ZLRichRule.regex('code', r'`([^`]+)`',
            handler: (ZLRichRuleContext ctx) {
          ctx.setText(
              ctx.group(1)!, ZLTextStyle().monospacedFont(13).codeBackground());
        }),
      ],
    )));
    expect(tester.takeException(), isNull);
    expect(_render(tester).content.string, 'Gradient title NEW #topic# code');
    expect(find.text('NEW'), findsOneWidget);
  });

  testWidgets('selection maps display text to raw text and copies',
      (WidgetTester tester) async {
    final List<String> copies = <String>[];
    final ZLRichLabelController controller = ZLRichLabelController();
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    await tester.pumpWidget(_app(ZLRichLabel(
      text: 'Hello @alice and world',
      style: _base,
      selectable: true,
      controller: controller,
      onCopy: (String text, bool raw) => copies.add('$raw:$text'),
      rules: <ZLRichRule>[
        ZLRichRule.regex('mention', r'@\w+', handler: (ZLRichRuleContext ctx) {
          ctx.setText('👤${ctx.matchedText.substring(1)}');
        }),
      ],
    )));
    expect(controller.displayText, 'Hello 👤alice and world');
    // Long press on the mention selects the whole match.
    await tester
        .longPressAt(_centerOf(tester, const TextRange(start: 6, end: 13)));
    await tester.pumpAndSettle();
    expect(controller.selectedRange, const TextRange(start: 6, end: 13));
    expect(controller.selectedText, '👤alice');
    expect(controller.selectedRawText, '@alice');
    expect(find.text('复制原文'), findsOneWidget);
    await tester.tap(find.text('复制原文'));
    await tester.pumpAndSettle();
    expect(copies, <String>['true:@alice']);
    expect(clipboard, '@alice');
    expect(controller.hasSelection, isFalse);

    controller.selectAll();
    await tester.pump();
    expect(controller.selectedRawText, 'Hello @alice and world');
    expect(
        controller.rawTextForDisplayRange(const TextRange(start: 8, end: 10)),
        '@alice');
  });

  testWidgets('render cache: highlight changes reuse handlers',
      (WidgetTester tester) async {
    final ZLRichLabelController controller = ZLRichLabelController();
    int calls = 0;
    final List<ZLRichRule> rules = <ZLRichRule>[
      ZLRichRule.regex('mention', r'@\w+', handler: (ZLRichRuleContext ctx) {
        calls++;
        ctx.onTap = (_) {};
      }),
    ];
    Widget build(Color highlight, String text) => _app(ZLRichLabel(
          text: text,
          rules: rules,
          style: _base,
          highlightStyle: ZLTextStyle().backgroundColor(highlight),
          controller: controller,
        ));
    await tester.pumpWidget(build(Colors.yellow, '@a @b @c'));
    expect(calls, 3);
    await tester.pumpWidget(build(Colors.blue, '@a @b @c'));
    expect(calls, 3);
    await tester.pumpWidget(build(Colors.blue, '@a @b @c @d'));
    expect(calls, 4);
    controller.setNeedsRebuild('mention');
    await tester.pump();
    expect(calls, 8);
    expect(controller.statistics.handlerCalls, greaterThan(0));
  });

  testWidgets('adjustsFontSizeToFit shrinks a single line',
      (WidgetTester tester) async {
    final ZLLabelController controller = ZLLabelController();
    await tester.pumpWidget(_app(
      ZLAttributedLabel(
        'Single line title that is long',
        style: const ZLTextStyle(textStyle: TextStyle(fontSize: 22)),
        maxLines: 1,
        adjustsFontSizeToFit: true,
        minimumScaleFactor: 0.3,
        controller: controller,
      ),
      width: 300,
    ));
    expect(controller.currentFontScale, lessThan(1));
    expect(controller.isTruncated, isFalse);
  });

  testWidgets('RTL content is detected', (WidgetTester tester) async {
    await tester
        .pumpWidget(_app(const ZLTagRichLabel(text: 'مرحبا <h1>بالعالم</h1>')));
    expect(_render(tester).textDirection, TextDirection.rtl);
  });

  testWidgets('onParsed reports tags after the frame',
      (WidgetTester tester) async {
    List<ZLTagInfo>? parsed;
    await tester.pumpWidget(_app(ZLTagRichLabel(
      text: '<b>x <i>y</i></b>',
      tagConfiguration: ZLTagParserConfiguration.anyTags,
      onParsed: (List<ZLTagInfo> tags) => parsed = tags,
    )));
    await tester.pump();
    expect(parsed!.map((ZLTagInfo t) => t.name), <String>['b', 'i']);
  });

  testWidgets('onParsed does not loop when the parent rebuilds with new rules',
      (WidgetTester tester) async {
    int reports = 0;
    await tester.pumpWidget(_app(StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => ZLTagRichLabel(
        text: 'Call <h1>13800138000</h1> now',
        // New rule objects on every build: the label parses again each time.
        rules: <ZLRichRule>[
          ZLRichRule.regex('phone', r'1\d{10}', priority: 20, handler: (_) {})
        ],
        onParsed: (_) => setState(() => reports++),
      ),
    )));
    await tester.pumpAndSettle();
    expect(reports, 1);
  });

  testWidgets('custom tag symbols and ZLBracketLabel',
      (WidgetTester tester) async {
    final List<String> taps = <String>[];
    await tester.pumpWidget(_app(ZLTagRichLabel(
      text: 'Read 【h1】Agreement【/h1】 and <h2>x</h2>',
      style: _base,
      tagOpenSymbol: '【',
      tagCloseSymbol: '】',
    )));
    expect(_render(tester).content.string, 'Read Agreement and <h2>x</h2>');

    await tester.pumpWidget(_app(ZLBracketLabel(
      text: 'Read [h1]Agreement[/h1] and [h2]Privacy[/h2].',
      style: _base,
      onTagTap: (ZLTagInfo info) => taps.add(info.name),
    )));
    expect(_render(tester).content.string, 'Read Agreement and Privacy.');
    await tester.tapAt(_centerOf(tester, const TextRange(start: 5, end: 14)));
    await tester.tapAt(_centerOf(tester, const TextRange(start: 19, end: 26)));
    await tester.pump();
    expect(taps, <String>['h1', 'h2']);
  });
}

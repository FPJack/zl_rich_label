import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zl_rich_label/zl_rich_label.dart';

void main() {
  group('ZLRichParser', () {
    test('higher priority wins, losing match is dropped as a whole', () {
      final List<ZLRichRule> rules = <ZLRichRule>[
        ZLRichRule.regex('number', r'\d+', priority: 1, handler: (_) {}),
        ZLRichRule.regex('phone', r'1\d{10}', priority: 20, handler: (_) {}),
      ];
      final List<ZLRichMatch> matches =
          ZLRichParser.resolve('call 13800138000 or 2024', rules);
      expect(matches.map((ZLRichMatch m) => m.rule.name),
          <String>['phone', 'number']);
      expect(matches.map((ZLRichMatch m) => m.text),
          <String>['13800138000', '2024']);
      expect(matches.map((ZLRichMatch m) => m.index), <int>[0, 1]);
    });

    test('same priority: earlier, then longer, then rule order', () {
      final List<ZLRichRule> rules = <ZLRichRule>[
        ZLRichRule.regex('bold', r'\*\*(.+?)\*\*', handler: (_) {}),
        ZLRichRule.regex('code', r'`([^`]+)`', handler: (_) {}),
      ];
      final List<ZLRichMatch> matches =
          ZLRichParser.resolve('**nested `x`** and `y`', rules);
      expect(matches.map((ZLRichMatch m) => m.rule.name),
          <String>['bold', 'code']);
      expect(matches.first.group(1), 'nested `x`');
    });

    test('named groups and segments', () {
      final ZLRichRule rule =
          ZLRichRule.regex('var', r'\{\{(?<key>\w+)\}\}', handler: (_) {});
      final List<ZLRichSegment> segments =
          ZLRichParser.segments('Hi {{name}}!', <ZLRichRule>[rule]);
      expect(segments.map((ZLRichSegment s) => s.text),
          <String>['Hi ', '{{name}}', '!']);
      expect(segments[1].match!.namedGroup('key'), 'name');
      expect(segments[1].match!.namedGroup('missing'), isNull);
    });

    test('resolves many matches quickly', () {
      final String text = List<String>.filled(5000, '@user #tag# word ').join();
      final List<ZLRichRule> rules = <ZLRichRule>[
        ZLRichRule.regex('mention', r'@\w+', handler: (_) {}),
        ZLRichRule.regex('topic', r'#\w+#', handler: (_) {}),
        ZLRichRule.regex('word', r'\w+', priority: -1, handler: (_) {}),
      ];
      final Stopwatch watch = Stopwatch()..start();
      final List<ZLRichMatch> matches = ZLRichParser.resolve(text, rules);
      expect(matches.length, 15000);
      expect(watch.elapsedMilliseconds, lessThan(2000));
    });
  });

  group('ZLTagParser', () {
    test('h tags: closing styles, case, tolerance', () {
      final List<ZLTagInfo> tags = ZLTagParser.tags(
          '<h>a</h> <h1>b<h1/> <H4>c</H4> <h1>x</h2> <h2>y <hx>z</hx>');
      expect(tags.map((ZLTagInfo t) => t.name), <String>['h', 'h1', 'h4']);
      expect(tags.map((ZLTagInfo t) => t.text), <String>['a', 'b', 'c']);
      expect(tags[1].level, 1);
      expect(tags[0].level, isNull);
    });

    test('without nesting only the innermost tag is kept', () {
      final List<ZLTagInfo> tags = ZLTagParser.tags('<h1>a<h2>b</h2>c</h1>');
      expect(tags.map((ZLTagInfo t) => t.raw), <String>['<h2>b</h2>']);
    });

    test('any tags: attributes, nesting, self closing, tolerance', () {
      const String source =
          '<b>bold <color value="#2196F3">blue <u>under</u></color></b><br/>'
          '<a href="https://x.com" target=_blank disabled>link</a> <b>open <i>tag</b> </u>';
      final List<ZLTagInfo> tags = ZLTagParser.tags(source,
          configuration: ZLTagParserConfiguration.anyTags);
      expect(tags.map((ZLTagInfo t) => t.name),
          <String>['b', 'color', 'u', 'br', 'a', 'b']);
      expect(tags[0].text, 'bold blue under');
      expect(tags[2].depth, 2);
      expect(tags[2].parent!.name, 'color');
      expect(tags[1].colorAttribute('value'), const Color(0xFF2196F3));
      expect(tags[4].attributes, <String, String>{
        'href': 'https://x.com',
        'target': '_blank',
        'disabled': ''
      });
      expect(tags[5].text, 'open <i>tag');
    });

    test('colors', () {
      expect(ZLTagInfo.colorFromString('#f00'), const Color(0xFFFF0000));
      expect(ZLTagInfo.colorFromString('00ff0080'), const Color(0x8000FF00));
      expect(ZLTagInfo.colorFromString('orange'), isNotNull);
      expect(ZLTagInfo.colorFromString('nope'), isNull);
    });

    test('simple h tag parser', () {
      final List<ZLTagSegment> segments =
          ZLTagParser.parseHTags('a <h1>b</h1> <h2>c');
      expect(
          segments
              .where((ZLTagSegment s) => s.isTag)
              .map((ZLTagSegment s) => s.text),
          <String>['b']);
    });
  });

  group('ZLDataDetector', () {
    test('links, phones, dates, addresses', () {
      final List<ZLDataDetectorResult> results =
          ZLDataDetector(ZLDataDetectorType.values.toSet()).detect(
              '网址 https://developer.apple.com，电话 010-12345678，日期 2026年10月1日 下午3点，地址 1 Infinite Loop, Cupertino, CA 95014。');
      expect(
          results.map((ZLDataDetectorResult r) => r.type), <ZLDataDetectorType>[
        ZLDataDetectorType.link,
        ZLDataDetectorType.phoneNumber,
        ZLDataDetectorType.date,
        ZLDataDetectorType.address,
      ]);
      expect(results[0].url.toString(), 'https://developer.apple.com');
      expect(results[1].phoneNumber, '01012345678');
      expect(results[2].date, DateTime(2026, 10, 1, 15));
    });
  });

  group('ZLAttributedText', () {
    test('substring / applyingStyle keep runs consistent', () {
      final ZLAttributedText text =
          ZLAttributedText('Hello ', style: ZLTextStyle().fontSize(10)) +
              ZLAttributedText.widget(ZLRichWidget(child: const SizedBox())) +
              ZLAttributedText('world');
      expect(text.length, 12);
      expect(text.substring(3, 8).string, 'lo \uFFFCw');
      final ZLAttributedText styled = text.applyingStyle(
          ZLTextStyle().bold(), const TextRange(start: 2, end: 9));
      expect(styled.string, text.string);
      expect(styled.styleAt(1)!.textStyle.fontWeight, isNull);
      expect(styled.styleAt(2)!.textStyle.fontWeight, FontWeight.bold);
      expect(styled.styleAt(9)!.textStyle.fontWeight, isNull);
    });

    test('style chains merge', () {
      final ZLTextStyle style = ZLTextStyle()
          .fontSize(15)
          .color(Colors.red)
          .underline()
          .strikethrough();
      expect(style.textStyle.fontSize, 15);
      expect(
          style.textStyle.decoration,
          TextDecoration.combine(<TextDecoration>[
            TextDecoration.underline,
            TextDecoration.lineThrough
          ]));
      final ZLTextStyle merged =
          style.merge(ZLTextStyle().color(Colors.blue).capsule(Colors.blue));
      expect(merged.textStyle.color, Colors.blue);
      expect(merged.textStyle.fontSize, 15);
      expect(merged.background, isNotNull);
      expect(ZLTextStyle.none.isEmpty, isTrue);
    });
  });

  group('custom tag symbols', () {
    List<String> raws(String source, String open, String close,
            {ZLTagParserConfiguration base = ZLTagParserConfiguration.hTags}) =>
        ZLTagParser.tags(source,
                configuration:
                    base.copyWith(openSymbol: open, closeSymbol: close))
            .map((ZLTagInfo t) => '${t.name}:${t.text}')
            .toList();

    test('[] 【】 {} and multi-char symbols', () {
      expect(raws('a [h]x[/h] [h1]y[h1/] <h>z</h>', '[', ']'),
          <String>['h:x', 'h1:y']);
      expect(raws('a 【h】x【/h】 【h2】y【/h2】', '【', '】'),
          <String>['h:x', 'h2:y']);
      expect(raws('a {h}x{/h}', '{', '}'), <String>['h:x']);
      expect(raws('a [[h]]x[[/h]]', '[[', ']]'), <String>['h:x']);
      expect(raws('a <h>x</h>', '<', '>'), <String>['h:x']);
    });

    test('attributes and nesting with custom symbols', () {
      final List<ZLTagInfo> tags = ZLTagParser.tags(
          '[b]bold [a href="x]y"]link[/a][/b]',
          configuration: ZLTagParserConfiguration.anyTags
              .copyWith(openSymbol: '[', closeSymbol: ']'));
      expect(tags.map((ZLTagInfo t) => t.name), <String>['b', 'a']);
      expect(tags[1].attribute('href'), 'x]y');
      expect(tags[1].text, 'link');
      expect(tags[0].text, 'bold link');
    });

    test('markup pattern name group uses the symbol length', () {
      final ZLTagMarkupPattern pattern = ZLTagMarkupPattern(
          ZLTagParserConfiguration.hTags
              .copyWith(openSymbol: '[[', closeSymbol: ']]'));
      final Match match = pattern.allMatches('a [[h1]]x[[/h1]]').single;
      expect(match.group(1), 'h1');
      expect(match.group(2), 'x');
    });
  });
}

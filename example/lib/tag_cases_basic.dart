import 'package:flutter/material.dart';
import 'package:zl_rich_label/zl_rich_label.dart';

import 'demo_common.dart';

/// Cases 1 – 16 of the iOS example: `ZLTagRichLabel` basics and the Arabic
/// (right-to-left) cases.
List<Widget> basicTagCases(TapLog log) => <Widget>[
      _case1(log),
      _case2(log),
      _case3(log),
      _case4(log),
      _case5(log),
      _case6(log),
      _case7(log),
      _case8(log),
      _case9(log),
      _case10(log),
      _CheckboxCase(
        log: log,
        title: '11. Widget 自带交互 (tappable: false)',
        source:
            '<h0>check</h0> I have read and agree to the <h1>User Agreement</h1> and <h2>Privacy Policy</h2>.',
      ),
      // Arabic (RTL)
      _case12(log),
      _case13(log),
      _case14(log),
      _case15(log),
      _CheckboxCase(
        log: log,
        title: '16. 阿拉伯语 + 勾选框 (tappable: false)',
        source:
            '<h0>check</h0> لقد قرأت وأوافق على <h1>اتفاقية المستخدم</h1> و<h2>سياسة الخصوصية</h2>.',
      ),
    ];

/// A tag case with the default configuration of the iOS `addCase`: base
/// style, top alignment, `onTagTap` → tap log, `onParsed` → card.
Widget _tagCase(
  TapLog log,
  String title,
  String source,
  ZLTagRichLabel Function(CaseHooks hooks) build, {
  bool tappable = true,
}) {
  return TagCase(
    title: title,
    source: source,
    log: log,
    tappable: tappable,
    builder: (BuildContext context, CaseHooks hooks) => build(hooks),
  );
}

/// 1. Styles per tag name (tagStyles).
Widget _case1(TapLog log) {
  const String source =
      'By logging in or registering an account, you agree to the '
      '<h1>User Agreement</h1> and <h2>Privacy Policy</h2>.';
  return _tagCase(log, '1. 按标签名区分样式（h1 / h2）', source, (CaseHooks hooks) {
    return ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      tagStyle: ZLTextStyle().systemFont(15, weight: FontWeight.w600),
      tagStyles: <String, ZLTextStyle>{
        'h1': ZLTextStyle().color(M.blue).underline(color: M.blue),
        'h2': ZLTextStyle().color(M.deepOrange),
      },
    );
  });
}

/// 2. Only `<h>`, styles by index (tagStyleBuilder).
Widget _case2(TapLog log) {
  const String source =
      'Fruits: <h>Apple</h>, <h>Banana<h/> and <h>Cherry</h>.';
  const List<Color> colors = <Color>[M.red, M.green, M.purple];
  return _tagCase(log, '2. 同名标签 <h>，按 index 区分样式', source, (CaseHooks hooks) {
    return ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      tagStyleBuilder: (ZLTagInfo info) =>
          ZLTextStyle().color(colors[info.index % colors.length]).boldFont(15),
    );
  });
}

/// 3. Several tag names, both closing forms, upper case.
Widget _case3(TapLog log) {
  const String source =
      '<h>Default</h>, <h1>Level one<h1/>, <h2>Level two</h2>, '
      '<h3>Level three<h3/> and <H4>Upper case</H4>.';
  return _tagCase(log, '3. h / h1 / h2 / h3 / H4，</hN> 与 <hN/> 闭合', source,
      (CaseHooks hooks) {
    return ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      tagStyle: ZLTextStyle().color(M.blue),
      tagStyles: <String, ZLTextStyle>{
        'h1': ZLTextStyle().boldFont(15).underline(),
        'h2': ZLTextStyle().color(M.green).fontSize(15).italic(),
        'h3': ZLTextStyle()
            .color(M.purple)
            .backgroundColor(const Color(0xFFEDE7F6)),
        'h4': ZLTextStyle().color(M.red).strikethrough(),
      },
    );
  });
}

/// 4. Taps per tag name (tagTapHandlers); tags without a handler use onTagTap.
Widget _case4(TapLog log) {
  const String title = '4. 按标签名区分点击（tagTapHandlers）';
  const String source = 'Read <h1>User Agreement</h1>, <h2>Privacy Policy</h2> '
      'and <h3>FAQ</h3> (h3 has no handler → onTagTap).';
  return _tagCase(log, title, source, (CaseHooks hooks) {
    return ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      tagStyles: <String, ZLTextStyle>{
        'h1': ZLTextStyle().color(M.blue),
        'h2': ZLTextStyle().color(M.deepOrange),
        'h3': ZLTextStyle().color(M.teal),
      },
      tagTapHandlers: <String, ZLTagTapCallback>{
        'h1': (ZLTagInfo info) => hooks.tap(info, 'h1 handler → 打开用户协议'),
        'h2': (ZLTagInfo info) => hooks.tap(info, 'h2 handler → 打开隐私政策'),
      },
    );
  });
}

/// 5. Press highlight per tag name (tagHighlightStyles).
Widget _case5(TapLog log) {
  const String source =
      'Press and hold: <h1>Yellow bg</h1> / <h2>Red text</h2> / '
      '<h3>No highlight</h3> / <h>Default grey</h>.';
  return _tagCase(log, '5. 按标签名区分按下高亮（长按查看）', source, (CaseHooks hooks) {
    return ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      tagStyle: ZLTextStyle().color(M.blue),
      // Default (<h>)
      highlightStyle: ZLTextStyle().backgroundColor(const Color(0xFFE0E0E0)),
      tagHighlightStyles: <String, ZLTextStyle>{
        'h1': ZLTextStyle().backgroundColor(const Color(0xFFFFF59D)),
        'h2': ZLTextStyle().color(M.red).underline(),
        'h3': ZLTextStyle.none, // no highlight
      },
    );
  });
}

/// 6. Error tolerance: brackets / mismatched / unclosed / nested / not h.
Widget _case6(TapLog log) {
  const String source =
      'Brackets kept: <h1>Terms[1]</h1>; mismatched: <h1>X</h2>; '
      'unclosed: <h2>Y; nested: <h1>a<h2>b</h2>c</h1>; not h: <hx>no</hx>.';
  return _tagCase(log, '6. 容错：[] 原样 / 不匹配 / 未闭合 / 嵌套', source,
      (CaseHooks hooks) {
    return ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      tagStyles: <String, ZLTextStyle>{
        'h1': ZLTextStyle().color(M.teal).boldFont(15),
        'h2': ZLTextStyle().color(M.pink).boldFont(15),
      },
    );
  });
}

/// An icon followed by `open + text + close`, tappable with the tag.
ZLAttributedText _iconTitle(IconData icon, ZLTagInfo info, ZLTextStyle style,
    String open, String close) {
  return ZLAttributedText.widget(ZLRichWidget.icon(icon, size: 16),
          style: style) +
      ZLAttributedText('$open${info.text}$close', style: style);
}

/// 7. tagSpanBuilder: icons per tag name.
Widget _case7(TapLog log) {
  const String source = 'Please read <h1>User Agreement</h1> and '
      '<h2>Privacy Policy</h2> carefully, or <h>skip</h>.';
  const Map<String, IconData> icons = <String, IconData>{
    'h1': Icons.description,
    'h2': Icons.shield
  };
  return _tagCase(log, '7. tagSpanBuilder 按标签名加图标', source, (CaseHooks hooks) {
    return ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      tagStyle: ZLTextStyle().color(M.indigo),
      // `null` uses the default style. The icon follows the text colour and is
      // tappable together with the tag.
      tagSpanBuilder: (ZLTagInfo info, ZLTextStyle style) {
        final IconData? icon = icons[info.name];
        return icon == null ? null : _iconTitle(icon, info, style, '《', '》');
      },
    );
  });
}

/// 8. Not tappable (no onTagTap / tagTapHandlers).
Widget _case8(TapLog log) {
  const String source =
      'Plain text. <h1>Not clickable</h1> and <h2>neither</h2>.';
  return _tagCase(log, '8. 无点击（无 onTagTap / tagTapHandlers）', source,
      tappable: false, (CaseHooks hooks) {
    return ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      tagStyles: <String, ZLTextStyle>{
        'h1': ZLTextStyle().color(M.brown),
        'h2': ZLTextStyle().color(M.grey),
      },
    );
  });
}

/// 9. maxLines = 2 with an ellipsis.
Widget _case9(TapLog log) {
  const String source =
      'This is a very long text to demonstrate the maxLines and '
      'overflow parameters. <h1>First</h1> link, some more words, '
      '<h2>Second</h2> link, and even more words that will be cut off '
      'here <h3>Hidden</h3>.';
  return _tagCase(log, '9. maxLines = 2 + 省略号', source, (CaseHooks hooks) {
    return ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      maxLines: 2,
      truncationMode: ZLTruncationMode.tail,
      tagStyle: ZLTextStyle().color(M.blue),
    );
  });
}

/// 10. tagWidgetBuilder: different inline widgets per tag name.
Widget _case10(TapLog log) {
  const String source = 'Replace: <h1>Follow</h1>  Before: <h2>Hot topic</h2>  '
      'After: <h3>Alice</h3>  Default: <h>Plain</h>';
  return _tagCase(log, '10. tagWidgetBuilder 按标签名自定义 View', source,
      (CaseHooks hooks) {
    return ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      tagStyle: ZLTextStyle().color(M.blue),
      tagWidgetBuilder: (ZLTagInfo info, ZLTextStyle style) =>
          switch (info.name) {
        'h1' => DemoWidgets.button(
            '+ ${info.text} #${info.index}'), // replaces the text
        'h2' => DemoWidgets.redDot(
            position: ZLRichWidgetPosition.before), // before the text
        'h3' => DemoWidgets.vipBadge(
            position: ZLRichWidgetPosition.after), // after the text
        _ => null, // default text
      },
    );
  });
}

/// 11 / 16. A checkbox handling its own taps (`tappable: false`). The state
/// lives here; the builder creates the widget from it.
class _CheckboxCase extends StatefulWidget {
  const _CheckboxCase(
      {required this.log, required this.title, required this.source});

  final TapLog log;
  final String title;
  final String source;

  @override
  State<_CheckboxCase> createState() => _CheckboxCaseState();
}

class _CheckboxCaseState extends State<_CheckboxCase> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return TagCase(
      title: widget.title,
      source: widget.source,
      log: widget.log,
      builder: (BuildContext context, CaseHooks hooks) => ZLTagRichLabel(
        text: widget.source,
        style: kBaseStyle,
        verticalAlignment: ZLVerticalAlignment.top,
        onTagTap: hooks.onTagTap,
        onParsed: hooks.onParsed,
        tagStyle: ZLTextStyle().color(M.blue),
        tagWidgetBuilder: (ZLTagInfo info, ZLTextStyle style) =>
            info.name == 'h0'
                ? DemoWidgets.checkbox(
                    checked: _agreed,
                    onChanged: () => setState(() => _agreed = !_agreed))
                : null,
      ),
    );
  }
}

// MARK: - Arabic (RTL)

/// 12. Arabic: styles and taps per tag name.
Widget _case12(TapLog log) {
  const String title = '12. 阿拉伯语：按标签名区分样式与点击';
  const String source = 'بتسجيل الدخول أو إنشاء حساب، فإنك توافق على '
      '<h1>اتفاقية المستخدم</h1> و<h2>سياسة الخصوصية</h2>.';
  return _tagCase(log, title, source, (CaseHooks hooks) {
    return ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      tagStyle: ZLTextStyle().systemFont(15, weight: FontWeight.w600),
      tagStyles: <String, ZLTextStyle>{
        'h1': ZLTextStyle().color(M.blue).underline(),
        'h2': ZLTextStyle().color(M.deepOrange),
      },
      tagTapHandlers: <String, ZLTagTapCallback>{
        'h1': (ZLTagInfo info) =>
            hooks.tap(info, 'h1 handler → اتفاقية المستخدم'),
        'h2': (ZLTagInfo info) =>
            hooks.tap(info, 'h2 handler → سياسة الخصوصية'),
      },
    );
  });
}

/// 13. Arabic mixed with English (bidirectional text).
Widget _case13(TapLog log) {
  const String source =
      'اقرأ <h1>Terms of Service</h1> ثم <h2>الأسئلة الشائعة</h2> '
      'وتواصل مع <h3>Support Team</h3> أو <h>نحن</h>.';
  return _tagCase(log, '13. 阿拉伯语 + 英文混排', source, (CaseHooks hooks) {
    return ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      tagStyle: ZLTextStyle().color(M.blue),
      tagStyles: <String, ZLTextStyle>{
        'h1': ZLTextStyle().boldFont(15).underline(),
        'h2': ZLTextStyle().backgroundColor(const Color(0xFFE0E0E0)),
        'h3': ZLTextStyle().color(M.green),
      },
    );
  });
}

/// 14. Arabic, maxLines = 2 with an ellipsis.
Widget _case14(TapLog log) {
  const String source =
      'هذا نص طويل جدًا لإظهار خاصية الحد الأقصى لعدد الأسطر. '
      '<h1>الرابط الأول</h1> بعض الكلمات الإضافية، '
      '<h2>الرابط الثاني</h2> والمزيد من الكلمات التي سيتم قطعها هنا '
      '<h3>مخفي</h3>.';
  return _tagCase(log, '14. 阿拉伯语 maxLines = 2 + 省略号', source,
      (CaseHooks hooks) {
    return ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      maxLines: 2,
      truncationMode: ZLTruncationMode.tail,
      tagStyle: ZLTextStyle().color(M.blue),
    );
  });
}

/// 15. Arabic with inline widgets / icons per tag name.
Widget _case15(TapLog log) {
  const String source = 'تابع: <h1>متابعة</h1>  جديد: <h2>موضوع رائج</h2>  '
      'مميز: <h3>علي</h3>  اقرأ <h4>الاتفاقية</h4>.';
  return _tagCase(log, '15. 阿拉伯语 + 自定义 Widget / 图标', source, (CaseHooks hooks) {
    return ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      tagStyle: ZLTextStyle().color(M.blue),
      tagSpanBuilder: (ZLTagInfo info, ZLTextStyle style) => info.name == 'h4'
          ? _iconTitle(Icons.description, info, style, '«', '»')
          : null,
      tagWidgetBuilder: (ZLTagInfo info, ZLTextStyle style) =>
          switch (info.name) {
        'h1' => DemoWidgets.button('+ ${info.text}'),
        'h2' => DemoWidgets.redDot(position: ZLRichWidgetPosition.before),
        'h3' => DemoWidgets.vipBadge(position: ZLRichWidgetPosition.after),
        _ => null,
      },
    );
  });
}

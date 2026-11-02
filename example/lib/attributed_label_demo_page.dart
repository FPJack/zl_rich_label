//
// Every feature of the low-level `ZLAttributedLabel` (no rules / tags: the
// text and the links are set directly). Port of the iOS
// `AttributedLabelDemoPage.swift`:
//   1. plain text following the style
//   2. rich runs: colour, font, underline, background, strikethrough, kern,
//      shadow, line spacing and first line indent
//   3. padding + vertical alignment
//   4. line limit and truncation (head / middle / tail, custom token)
//   5. links: `linkTo` runs, URL links, tap callbacks, custom link styles
//   6. data detectors (URL / phone / date / address)
//   7. long press on links
//   8. larger touch areas (`extendsLinkTouchArea`)
//   9. inactive link style while a dialog is shown
//  10. highlighted text colour
//  11. geometry: `characterIndexAt`, `boundingRectForRange`, self sizing
//  12. accessibility: every link is its own node
//  13. font fitting: `adjustsFontSizeToFit` + `minimumScaleFactor`
//  14. inline widgets (the `NSTextAttachment` images of iOS)
//
import 'package:flutter/material.dart';
import 'package:zl_rich_label/zl_rich_label.dart';

import 'demo_common.dart';

const Color _textColor = Color(0xFF212121);
const ZLTextStyle _style =
    ZLTextStyle(textStyle: TextStyle(fontSize: 15, color: _textColor));
const Color _lightPurple = Color(0xFFF3EDF7);

class AttributedLabelDemoPage extends StatefulWidget {
  const AttributedLabelDemoPage({super.key});

  @override
  State<AttributedLabelDemoPage> createState() =>
      _AttributedLabelDemoPageState();
}

class _AttributedLabelDemoPageState extends State<AttributedLabelDemoPage> {
  /// Last callback, shown at the top.
  String _event = '点击 / 长按链接，这里显示回调';

  void _log(String text) {
    debugPrint('[ZLAttributedLabel] $text');
    setState(() => _event = text);
  }

  /// `onLinkTap`: the counterpart of the iOS delegate callbacks.
  void _onLinkTap(ZLLabelLink link, String text) {
    final String linked = text.substring(link.range.start, link.range.end);
    final ZLDataDetectorResult? result = link.result;
    if (result != null) {
      final String type = switch (result.type) {
        ZLDataDetectorType.phoneNumber => '电话 ${result.phoneNumber}',
        ZLDataDetectorType.date => '日期 ${result.date}',
        ZLDataDetectorType.address => '地址',
        ZLDataDetectorType.email => '邮箱',
        ZLDataDetectorType.link => '链接 ${result.url}',
      };
      _log('onLinkTap：$type「$linked」');
    } else if (link.url != null) {
      _log('onLinkTap url: ${link.url}');
    } else {
      _log('onLinkTap「$linked」');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('ZLAttributedLabel')),
      body: Column(
        children: <Widget>[
          Container(
            key: const Key('eventBar'),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 44),
            color: _lightPurple,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: monoText(_event, fontSize: 12, color: Colors.black),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final Widget card in <Widget>[
                    const _PlainTextDemo(),
                    _attributesDemo(),
                    const _InsetsDemo(),
                    const _TruncationDemo(),
                    _linksDemo(),
                    _dataDetectorDemo(),
                    _longPressDemo(),
                    _TouchAreaDemo(onLog: _log),
                    _InactiveDemo(onLog: _log),
                    const _HighlightedDemo(),
                    _GeometryDemo(onLog: _log),
                    _accessibilityDemo(),
                    _FontFittingDemo(onLog: _log),
                    _AttachmentDemo(onLog: _log),
                  ]) ...<Widget>[card, const SizedBox(height: 16)],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MARK: 2. Rich runs

  Widget _attributesDemo() {
    final ZLTextStyle s = ZLTextStyle();
    final ZLAttributedText first =
        ZLAttributedText('颜色', style: s.color(M.pink)) +
            ZLAttributedText('、') +
            ZLAttributedText('粗体', style: s.bold()) +
            ZLAttributedText('、') +
            ZLAttributedText('大字号', style: s.fontSize(22)) +
            ZLAttributedText('、') +
            ZLAttributedText('下划线', style: s.underline()) +
            ZLAttributedText('、') +
            ZLAttributedText('背景色',
                style: s.backgroundColor(M.amber.withValues(alpha: 0.4))) +
            ZLAttributedText('、') +
            ZLAttributedText('删除线', style: s.strikethrough()) +
            ZLAttributedText('、') +
            ZLAttributedText('红色双删除线',
                style: s.strikethrough(
                    style: TextDecorationStyle.double, color: M.red)) +
            ZLAttributedText('、') +
            ZLAttributedText('字间距 kern', style: s.kern(4)) +
            ZLAttributedText('、') +
            ZLAttributedText('阴影', style: s.color(M.blue)) +
            ZLAttributedText('（shadow 写在 label 的 style 中，作用于整段）。\n');
    // Second paragraph: first line indent 30 (line spacing is a label-wide
    // value in Flutter, so it comes from the label style).
    final ZLAttributedText second = ZLAttributedText(
      '第二段：设置了行距 8、首行缩进 30，长文字折行后可以看到行距效果，未设置字体颜色的部分使用 label 的 style。',
      style: s.indent(30),
    );
    return _card(
      '2. 富文本属性 ZLAttributedLabel.rich',
      '下划线 / 删除线 / 背景色由 TextStyle 绘制；shadow 写在 label 的 style 中作为整段阴影；'
          'lineSpacing 是整个 label 的属性，firstLineIndent 作用于段落首行',
      <Widget>[
        ZLAttributedLabel.rich(
          first + second,
          style: _style.withLineSpacing(8).shadow(const Color(0x40000000),
              offset: const Offset(0, 1), blur: 2),
        ),
      ],
    );
  }

  // MARK: 5. Links

  Widget _linksDemo() {
    const String text = '1) linkTo 样式：Apple 官网。2) 带 url 的链接：GitHub。'
        '3) 带 onTap 的链接：点我计数。4) 自定义样式的 ZLLabelLink：橙色胶囊，按下变深。';
    final TextRange apple = _rangeOf(text, 'Apple 官网');
    final ZLAttributedText rich =
        ZLAttributedText(text.substring(0, apple.start)) +
            ZLAttributedText('Apple 官网',
                style:
                    ZLTextStyle().linkTo(Uri.parse('https://www.apple.com'))) +
            ZLAttributedText(text.substring(apple.end));
    return _card(
      '5. 链接',
      '没有 onTap 的链接回调 label 的 onLinkTap（对应 iOS 的 delegate）；设置了 onTap 的链接只回调 onTap。links 中后添加的优先响应',
      <Widget>[
        _CounterLinkLabel(
          text: rich,
          github: _rangeOf(text, 'GitHub'),
          counter: _rangeOf(text, '点我计数'),
          capsule: _rangeOf(text, '橙色胶囊'),
          onLog: _log,
          onLinkTap: (ZLLabelLink link) => _onLinkTap(link, text),
        ),
      ],
    );
  }

  // MARK: 6. Data detectors

  Widget _dataDetectorDemo() {
    const String text =
        '网址 https://developer.apple.com，电话 010-12345678，日期 2026年10月1日 下午3点，'
        '地址 1 Infinite Loop, Cupertino, CA 95014。';
    return _card(
      '6. 自动识别 dataDetectorTypes',
      'ZLDataDetector 识别网址 / 电话 / 日期 / 地址，点击回调 onLinkTap（link.result 为识别结果）',
      <Widget>[
        ZLAttributedLabel(
          text,
          style: _style,
          dataDetectorTypes: const <ZLDataDetectorType>{
            ZLDataDetectorType.link,
            ZLDataDetectorType.phoneNumber,
            ZLDataDetectorType.date,
            ZLDataDetectorType.address,
          },
          linkStyle: ZLTextStyle().color(M.teal).underline(),
          onLinkTap: (ZLLabelLink link) => _onLinkTap(link, text),
        ),
      ],
    );
  }

  // MARK: 7. Long press

  Widget _longPressDemo() {
    const String text =
        '长按 这个链接 触发 link.onLongPress；长按 另一个链接 回调 label 的 onLinkLongPress。轻点仍然是点击。';
    return _card(
      '7. 长按链接',
      '只在按在有长按回调的链接上时才识别长按，其他位置不影响外层的手势',
      <Widget>[
        ZLAttributedLabel(
          text,
          style: _style,
          links: <ZLLabelLink>[
            ZLLabelLink(
              range: _rangeOf(text, '这个链接'),
              onTap: (_) => _log('点击「这个链接」'),
              onLongPress: (_) => _log('link.onLongPress：长按「这个链接」'),
            ),
            // No onLongPress: long presses go to the label's onLinkLongPress.
            ZLLabelLink(
                range: _rangeOf(text, '另一个链接'),
                onTap: (_) => _log('点击「另一个链接」')),
          ],
          onLinkLongPress: (ZLLabelLink link, Offset location) => _log(
              'onLinkLongPress「${text.substring(link.range.start, link.range.end)}」'
              'at (${location.dx.toStringAsFixed(0)}, ${location.dy.toStringAsFixed(0)})'),
        ),
      ],
    );
  }

  // MARK: 12. Accessibility

  Widget _accessibilityDemo() {
    const String text =
        '开启 TalkBack / VoiceOver 后，这段文字是一个元素，用户协议 和 隐私政策 分别是可以单独聚焦、双击触发的链接。';
    final List<ZLLabelLink> links = <ZLLabelLink>[
      ZLLabelLink(range: _rangeOf(text, '用户协议'), onTap: (_) => _log('打开用户协议')),
      ZLLabelLink(
          range: _rangeOf(text, '隐私政策'),
          semanticsHint: '打开隐私政策页面',
          onTap: (_) => _log('打开隐私政策')),
    ];
    return _card(
      '12. 无障碍 Semantics',
      '有链接时 label 是一个语义容器：整段文字 + 每个链接（isLink、onTap）；ZLLabelLink.semanticsHint 为附加说明',
      <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              final List<String> names = <String>[
                '整段文字',
                for (final ZLLabelLink link in links)
                  '${text.substring(link.range.start, link.range.end)}（链接'
                      '${link.semanticsHint == null ? '' : '，hint: ${link.semanticsHint}'}）',
              ];
              _log('${names.length} 个语义节点：${names.join(' | ')}');
            },
            child: const Text('列出语义节点'),
          ),
        ),
        ZLAttributedLabel(text, style: _style, links: links),
      ],
    );
  }
}

TextRange _rangeOf(String text, String part) {
  final int start = text.indexOf(part);
  return TextRange(start: start, end: start + part.length);
}

/// Card: title, grey description, content.
Widget _card(String title, String detail, List<Widget> children) {
  return CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(detail,
            style: const TextStyle(fontSize: 12, color: Color(0x80000000))),
        const SizedBox(height: 12),
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 8),
          children[i]
        ],
      ],
    ),
  );
}

// MARK: - 1. Plain text

class _PlainTextDemo extends StatefulWidget {
  const _PlainTextDemo();

  @override
  State<_PlainTextDemo> createState() => _PlainTextDemoState();
}

class _PlainTextDemoState extends State<_PlainTextDemo> {
  int _font = 0;
  int _color = 0;
  int _align = 0;

  static final List<ZLTextStyle> _fonts = <ZLTextStyle>[
    ZLTextStyle().fontSize(15),
    ZLTextStyle().boldFont(18),
    ZLTextStyle().fontSize(13),
  ];
  static const List<Color> _colors = <Color>[
    _textColor,
    M.deepPurple,
    M.deepOrange
  ];
  static const List<TextAlign> _aligns = <TextAlign>[
    TextAlign.left,
    TextAlign.center,
    TextAlign.right
  ];

  @override
  Widget build(BuildContext context) {
    return _card('1. 纯文本',
        'ZLAttributedLabel("...")；修改 style / textAlign 后自动更新', <Widget>[
      Segmented(
          items: const <String>['15', '18 粗体', '13'],
          selected: _font,
          onChanged: (int i) => setState(() => _font = i)),
      Segmented(
          items: const <String>['深灰', '紫色', '橙色'],
          selected: _color,
          onChanged: (int i) => setState(() => _color = i)),
      Segmented(
          items: const <String>['左', '中', '右'],
          selected: _align,
          onChanged: (int i) => setState(() => _align = i)),
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        alignment: Alignment.topCenter,
        child: ZLAttributedLabel(
          '通过字符串创建纯文本 label：使用 style 中的字体、颜色，textAlign 控制对齐。'
          '之后修改这些属性，文字会自动按新属性重新排版。',
          style: _fonts[_font].color(_colors[_color]),
          textAlign: _aligns[_align],
        ),
      ),
    ]);
  }
}

// MARK: - 3. Padding + vertical alignment

class _InsetsDemo extends StatefulWidget {
  const _InsetsDemo();

  @override
  State<_InsetsDemo> createState() => _InsetsDemoState();
}

class _InsetsDemoState extends State<_InsetsDemo> {
  int _insets = 1;
  int _alignment = 0;

  static const List<EdgeInsets> _values = <EdgeInsets>[
    EdgeInsets.zero,
    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    EdgeInsets.symmetric(horizontal: 32, vertical: 24),
  ];

  @override
  Widget build(BuildContext context) {
    return _card(
      '3. 内边距 padding + 垂直对齐 verticalAlignment',
      '尺寸包含内边距；点击、截断、字符定位都按内边距偏移',
      <Widget>[
        Segmented(
            items: const <String>['0', '12 / 16', '24 / 32'],
            selected: _insets,
            onChanged: (int i) => setState(() => _insets = i)),
        Segmented(
            items: const <String>['top', 'center', 'bottom'],
            selected: _alignment,
            onChanged: (int i) => setState(() => _alignment = i)),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: const Color(0xFFEADDFF),
            child: SizedBox(
              height: 120,
              child: ZLAttributedLabel(
                'padding 内边距：背景铺满整个 label，文字在内边距以内排版。label 固定高度 120，verticalAlignment 决定文字在垂直方向的位置。',
                style: _style,
                padding: _values[_insets],
                verticalAlignment: ZLVerticalAlignment.values[_alignment],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// MARK: - 4. Truncation

class _TruncationDemo extends StatefulWidget {
  const _TruncationDemo();

  @override
  State<_TruncationDemo> createState() => _TruncationDemoState();
}

class _TruncationDemoState extends State<_TruncationDemo> {
  int _lines = 1;
  int _mode = 0;
  int _token = 0;

  @override
  Widget build(BuildContext context) {
    return _card('4. 行数与截断', '多行时只截断最后一行（尾部）；单行时头 / 中 / 尾都可用', <Widget>[
      Segmented(
          items: const <String>['1 行', '2 行', '不限'],
          selected: _lines,
          onChanged: (int i) => setState(() => _lines = i)),
      Segmented(
          items: const <String>['尾部', '头部', '中间'],
          selected: _mode,
          onChanged: (int i) => setState(() => _mode = i)),
      Segmented(
          items: const <String>['…', '…更多'],
          selected: _token,
          onChanged: (int i) => setState(() => _token = i)),
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        alignment: Alignment.topCenter,
        child: ZLAttributedLabel(
          'maxLines 限制行数，超出时按 truncationMode 截断最后一行：尾部（默认）、头部或中间。'
          'truncationToken 可以自定义截断符，例如「…更多」。这段文字足够长，会被截断。',
          style: _style,
          maxLines: const <int?>[1, 2, null][_lines],
          truncationMode: ZLTruncationMode.values[_mode],
          truncationToken: _token == 0
              ? null
              : ZLAttributedText('…更多',
                  style: ZLTextStyle().color(M.blue).fontSize(15)),
        ),
      ),
    ]);
  }
}

// MARK: - 5. Links (counter state)

class _CounterLinkLabel extends StatefulWidget {
  const _CounterLinkLabel({
    required this.text,
    required this.github,
    required this.counter,
    required this.capsule,
    required this.onLog,
    required this.onLinkTap,
  });

  final ZLAttributedText text;
  final TextRange github;
  final TextRange counter;
  final TextRange capsule;
  final ValueChanged<String> onLog;
  final void Function(ZLLabelLink link) onLinkTap;

  @override
  State<_CounterLinkLabel> createState() => _CounterLinkLabelState();
}

class _CounterLinkLabelState extends State<_CounterLinkLabel> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return ZLAttributedLabel.rich(
      widget.text,
      style: _style,
      // Default / pressed link styles.
      linkStyle: ZLTextStyle().color(M.blue).underline(),
      activeLinkStyle: ZLTextStyle().color(M.blue.withValues(alpha: 0.4)),
      onLinkTap: widget.onLinkTap,
      links: <ZLLabelLink>[
        // A URL link without onTap: the label's onLinkTap receives it.
        ZLLabelLink(
            range: widget.github,
            url: Uri.parse('https://github.com/FPJack/ZLRichLabel')),
        ZLLabelLink(
          range: widget.counter,
          onTap: (_) {
            _count += 1;
            widget.onLog('onTap 点击第 $_count 次');
          },
        ),
        // Custom style: orange capsule, darker when pressed.
        ZLLabelLink(
          range: widget.capsule,
          style:
              ZLTextStyle().color(Colors.white).backgroundColor(M.deepOrange),
          activeStyle: ZLTextStyle()
              .color(Colors.white)
              .backgroundColor(const Color(0xFFBF360C)),
          onTap: (ZLLabelLink link) => widget.onLog(
              '自定义 ZLLabelLink 点击，range = ${link.range.start}-${link.range.end}'),
        ),
      ],
    );
  }
}

// MARK: - 8. Touch area

class _TouchAreaDemo extends StatefulWidget {
  const _TouchAreaDemo({required this.onLog});

  final ValueChanged<String> onLog;

  @override
  State<_TouchAreaDemo> createState() => _TouchAreaDemoState();
}

class _TouchAreaDemoState extends State<_TouchAreaDemo> {
  bool _extends = false;

  @override
  Widget build(BuildContext context) {
    const String text = '行距较大时，按在两行之间的空白处不容易点中链接。打开 extendsLinkTouchArea 后，'
        '手指没有按在文字上时会向四周最多 15pt 查找 链接 ；按在普通文字上仍然只认这个字。';
    final int start = text.indexOf('链接 ；');
    return _card(
        '8. 扩大点击热区 extendsLinkTouchArea', '默认关闭；开启后点击小链接上下的空白也能命中', <Widget>[
      SwitchRow(
        label: 'extendsLinkTouchArea',
        value: _extends,
        onChanged: (bool value) {
          setState(() => _extends = value);
          widget.onLog('extendsLinkTouchArea = $value');
        },
      ),
      ZLAttributedLabel(
        text,
        style: _style.withLineSpacing(14),
        extendsLinkTouchArea: _extends,
        links: <ZLLabelLink>[
          ZLLabelLink(
              range: TextRange(start: start, end: start + 4),
              onTap: (_) => widget.onLog('点中了小链接')),
        ],
      ),
    ]);
  }
}

// MARK: - 9. Inactive links

class _InactiveDemo extends StatelessWidget {
  const _InactiveDemo({required this.onLog});

  final ValueChanged<String> onLog;

  @override
  Widget build(BuildContext context) {
    const String text =
        '弹出 dialog / bottom sheet 时 label 所在的路由不再是当前路由，链接 显示为 inactiveLinkStyle（灰色）。';
    final int start = text.indexOf('链接');
    return _card('9. 失活样式 inactiveLinkStyle',
        '为 null 时失活不改变样式；单个链接可用 ZLLabelLink.inactiveStyle', <Widget>[
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('链接变灰了吗？'),
              content: const Text('关闭后恢复'),
              actions: <Widget>[
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'))
              ],
            ),
          ),
          child: const Text('弹出 alert 查看失活样式'),
        ),
      ),
      ZLAttributedLabel(
        text,
        style: _style,
        inactiveLinkStyle: const ZLTextStyle(
            textStyle: TextStyle(
                color: Color(0xFF8E8E93), decoration: TextDecoration.none)),
        links: <ZLLabelLink>[
          ZLLabelLink(
              range: TextRange(start: start, end: start + 2),
              onTap: (_) => onLog('点击失活示例链接')),
        ],
      ),
    ]);
  }
}

// MARK: - 10. Highlighted

class _HighlightedDemo extends StatefulWidget {
  const _HighlightedDemo();

  @override
  State<_HighlightedDemo> createState() => _HighlightedDemoState();
}

class _HighlightedDemoState extends State<_HighlightedDemo> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    return _card('10. 高亮 highlightedTextColor',
        '与 UILabel 的 isHighlighted 一致（例如列表项选中时）', <Widget>[
      SwitchRow(
          label: 'highlighted',
          value: _highlighted,
          onChanged: (bool value) => setState(() => _highlighted = value)),
      AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: _highlighted ? M.indigo : Colors.transparent,
            borderRadius: BorderRadius.circular(8)),
        child: ZLAttributedLabel(
          'highlighted = true 时，全部文字使用 highlightedTextColor（例如 cell 选中时）。',
          style: _style.color(M.indigo),
          highlighted: _highlighted,
          highlightedTextColor: Colors.white,
        ),
      ),
    ]);
  }
}

// MARK: - 11. Geometry

class _GeometryDemo extends StatefulWidget {
  const _GeometryDemo({required this.onLog});

  final ValueChanged<String> onLog;

  @override
  State<_GeometryDemo> createState() => _GeometryDemoState();
}

class _GeometryDemoState extends State<_GeometryDemo> {
  static const String _text =
      '点击任意文字：characterIndexAt 得到字符下标，boundingRectForRange 框出这个字所在的词。'
      'label 按父级给的宽度计算自己的高度，不需要手动 sizeThatFits。';
  static final RegExp _wordChar = RegExp(r'[A-Za-z0-9_]');

  final ZLLabelController _controller = ZLLabelController();
  final GlobalKey _measuredKey = GlobalKey();
  Rect? _marker;
  Size? _measured;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _measure() {
    if (!mounted) return;
    final Size? size = _measuredKey.currentContext?.size;
    if (size != _measured) setState(() => _measured = size);
  }

  /// The word around [index]: a run of ASCII word characters, otherwise the
  /// character itself (Chinese has no spaces).
  TextRange _wordAt(int index) {
    if (!_wordChar.hasMatch(_text[index])) {
      return TextRange(start: index, end: index + 1);
    }
    int start = index;
    int end = index + 1;
    while (start > 0 && _wordChar.hasMatch(_text[start - 1])) {
      start--;
    }
    while (end < _text.length && _wordChar.hasMatch(_text[end])) {
      end++;
    }
    return TextRange(start: start, end: end);
  }

  void _onTap(TapUpDetails details) {
    final int? index = _controller.characterIndexAt(details.localPosition);
    if (index == null) {
      setState(() => _marker = null);
      widget.onLog('characterIndexAt = null（没有按在文字上）');
      return;
    }
    final TextRange word = _wordAt(index);
    final Rect? rect = _controller.boundingRectForRange(word);
    setState(() => _marker = rect);
    final String box = rect == null
        ? 'null'
        : '(${rect.left.round()}, ${rect.top.round()}, ${rect.width.round()} × ${rect.height.round()})';
    widget.onLog(
        'characterIndexAt = $index，词「${_text.substring(word.start, word.end)}」rect = $box');
  }

  @override
  Widget build(BuildContext context) {
    return _card('11. 尺寸与定位', '点击文字框出所在的词；label 的尺寸按「宽度 + 行数」计算并缓存', <Widget>[
      GestureDetector(
        onTapUp: _onTap,
        child: DecoratedBox(
          decoration:
              BoxDecoration(border: Border.all(color: const Color(0x1A000000))),
          child: Stack(
            children: <Widget>[
              ZLAttributedLabel(_text,
                  style: _style,
                  padding: const EdgeInsets.all(6),
                  controller: _controller),
              if (_marker != null)
                Positioned.fromRect(
                  rect: _marker!.inflate(1),
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: M.amber.withValues(alpha: 0.3),
                        border: Border.all(color: M.deepOrange),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
          return true;
        },
        child: SizeChangedLayoutNotifier(
          child: ColoredBox(
            color: _lightPurple,
            child: ZLAttributedLabel(
              key: _measuredKey,
              '这个 label 没有设置高度：它按父级给的宽度排版，高度（包含内边距）就是文字高度。',
              style: _style,
              padding: const EdgeInsets.all(8),
            ),
          ),
        ),
      ),
      monoText(_measured == null
          ? '测量中…'
          : '上面 label 的尺寸：${_measured!.width.toStringAsFixed(1)} × ${_measured!.height.toStringAsFixed(1)}（含 8pt 内边距）'),
    ]);
  }
}

// MARK: - 13. Font fitting

class _FontFittingDemo extends StatefulWidget {
  const _FontFittingDemo({required this.onLog});

  final ValueChanged<String> onLog;

  @override
  State<_FontFittingDemo> createState() => _FontFittingDemoState();
}

class _FontFittingDemoState extends State<_FontFittingDemo> {
  static const List<double> _rightPadding = <double>[0, 40, 80];
  static const List<double> _minimums = <double>[0.3, 0.5, 0.8, 0];

  final List<ZLLabelController> _controllers =
      List<ZLLabelController>.generate(3, (_) => ZLLabelController());
  int _width = 0;
  bool _adjusts = true;
  int _minimum = 1;
  String _info = '';

  @override
  void initState() {
    super.initState();
    _refreshInfo();
  }

  @override
  void dispose() {
    for (final ZLLabelController controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The scale is known after layout.
  void _refreshInfo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _info = <String>[
          for (int i = 0; i < 3; i++)
            'label${i + 1}: adjusts = $_adjusts, min = ${_minimums[_minimum].toStringAsFixed(1)}, '
                'scale = ${_controllers[i].currentFontScale.toStringAsFixed(2)}',
        ].join('\n');
      });
    });
  }

  void _update(VoidCallback change) {
    setState(change);
    _refreshInfo();
  }

  @override
  Widget build(BuildContext context) {
    const String single = '单行标题：宽度不够时整体缩小字号，链接 仍可点击';
    final int link = single.indexOf('链接');
    final double minimum = _minimums[_minimum];
    return _card(
      '13. 字号自适应 adjustsFontSizeToFit',
      '单行按宽度、多行按行数与高度缩小字体，最小到 minimumScaleFactor（为 0 时不缩小）；'
          '内嵌 widget 不缩放。切换宽度 / 开关 / 最小比例观察 scale',
      <Widget>[
        Segmented(
            items: const <String>['宽', '中', '窄'],
            selected: _width,
            onChanged: (int i) => _update(() => _width = i)),
        SwitchRow(
            label: 'adjustsFontSizeToFit',
            value: _adjusts,
            onChanged: (bool value) => _update(() => _adjusts = value)),
        Segmented(
          items: const <String>['min 0.3', '0.5', '0.8', '0(不缩)'],
          selected: _minimum,
          onChanged: (int i) => _update(() => _minimum = i),
        ),
        AnimatedPadding(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.only(right: _rightPadding[_width]),
          onEnd: _refreshInfo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ColoredBox(
                color: _lightPurple,
                child: ZLAttributedLabel(
                  single,
                  style: ZLTextStyle().boldFont(22).color(_textColor),
                  maxLines: 1,
                  adjustsFontSizeToFit: _adjusts,
                  minimumScaleFactor: minimum,
                  controller: _controllers[0],
                  links: <ZLLabelLink>[
                    ZLLabelLink(
                      range: TextRange(start: link, end: link + 2),
                      onTap: (_) => widget.onLog(
                          '缩小后点击链接，scale = ${_controllers[0].currentFontScale.toStringAsFixed(2)}'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ColoredBox(
                color: _lightPurple,
                child: ZLAttributedLabel(
                  '多行（maxLines = 2）：超过 2 行时缩小字号，尽量在 2 行内显示完整；'
                  '缩到 minimumScaleFactor 仍放不下时按尾部截断。这段文字比较长，用来观察缩放效果。',
                  style: ZLTextStyle().fontSize(18).color(_textColor),
                  maxLines: 2,
                  adjustsFontSizeToFit: _adjusts,
                  minimumScaleFactor: minimum,
                  controller: _controllers[1],
                ),
              ),
              const SizedBox(height: 8),
              ColoredBox(
                color: _lightPurple,
                child: SizedBox(
                  height: 60,
                  child: ZLAttributedLabel(
                    '不限行数 + 固定高度 60：文字高度超过 label 高度时缩小字号。富文本中的各段字体按同一比例缩小。',
                    style: ZLTextStyle().fontSize(18).color(_textColor),
                    verticalAlignment: ZLVerticalAlignment.top,
                    adjustsFontSizeToFit: _adjusts,
                    minimumScaleFactor: minimum,
                    controller: _controllers[2],
                  ),
                ),
              ),
            ],
          ),
        ),
        monoText(_info),
      ],
    );
  }
}

// MARK: - 14. Inline widgets

class _AttachmentDemo extends StatefulWidget {
  const _AttachmentDemo({required this.onLog});

  final ValueChanged<String> onLog;

  @override
  State<_AttachmentDemo> createState() => _AttachmentDemoState();
}

class _AttachmentDemoState extends State<_AttachmentDemo> {
  static const List<double> _sizes = <double>[14, 18, 28, 40];
  int _size = 1;
  int _taps = 0;

  /// A colourful badge that keeps its own colours (a non-template image on iOS).
  static Widget _badge(double height) => Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: height * 0.35),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: const LinearGradient(colors: <Color>[M.deepPurple, M.blue]),
        ),
        child: Text('VIP',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: height * 0.55,
                height: 1)),
      );

  @override
  Widget build(BuildContext context) {
    final double h = _sizes[_size];
    // Icons without a colour follow the text colour of their run.
    final ZLAttributedText star = ZLAttributedText.widget(
        ZLRichWidget.icon(Icons.star, size: h),
        style: ZLTextStyle().color(M.deepOrange));
    final ZLAttributedText badge =
        ZLAttributedText.widget(ZLRichWidget(child: _badge(h)));
    final ZLAttributedText heart = ZLAttributedText.widget(
        ZLRichWidget.icon(Icons.favorite, size: h),
        style: ZLTextStyle().color(Colors.red));
    final ZLAttributedText head = ZLAttributedText('图标跟随文字颜色 ') +
        star +
        ZLAttributedText('，彩色 widget 按原色 ') +
        badge +
        ZLAttributedText('，widget 也可以作为链接：');
    final int heartIndex = head.length;
    final ZLAttributedText text = head +
        heart +
        ZLAttributedText('（按下变浅）。widget 变大时行高跟着变高，文字按 widget 宽度重新换行。');

    final ZLAttributedText token =
        ZLAttributedText('… ', style: ZLTextStyle().color(M.blue)) +
            ZLAttributedText.widget(
                ZLRichWidget.icon(Icons.expand_circle_down, size: 16),
                style: ZLTextStyle().color(M.blue));

    return _card(
      '14. 行内 widget（iOS 的 NSTextAttachment）',
      'ZLRichWidget.icon 没有颜色时跟随所在文字的颜色（含按下样式）；尺寸固定或由 widget 自己计算；'
          '切换高度观察行高与换行',
      <Widget>[
        Segmented(
            items: const <String>['14', '18', '28', '40'],
            selected: _size,
            onChanged: (int i) => setState(() => _size = i)),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.topCenter,
          child: ZLAttributedLabel.rich(
            text,
            style: _style,
            links: <ZLLabelLink>[
              ZLLabelLink(
                range: TextRange(start: heartIndex, end: heartIndex + 1),
                style: ZLTextStyle.none,
                activeStyle:
                    ZLTextStyle().color(Colors.red.withValues(alpha: 0.35)),
                onTap: (_) {
                  setState(() => _taps += 1);
                  widget.onLog('点击 widget 链接 ❤️（第 $_taps 次）');
                },
              ),
            ],
          ),
        ),
        monoText('点击 ❤️ widget 链接：$_taps 次', fontSize: 12, color: Colors.black),
        ZLAttributedLabel(
          '单行截断：截断符 truncationToken 中也可以放 widget，这段文字足够长会被截断。',
          style: _style,
          maxLines: 1,
          truncationToken: token,
        ),
      ],
    );
  }
}

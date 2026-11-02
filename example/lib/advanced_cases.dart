import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zl_rich_label/zl_rich_label.dart';

import 'demo_common.dart';

/// Cases 24 – 31 of the iOS example: expand / collapse, long press / double
/// tap, selection, generic tags, capsules and gradients, padding, inline
/// widgets following the label size, `ZLTextStyle` chains.
List<Widget> advancedCases(TapLog log) => <Widget>[
      ..._case24(log),
      _Case24e(log: log),
      _Case25(log: log),
      _Case26(log: log),
      _case27(log),
      _case28(log),
      _case28b(log),
      _Case29(log: log),
      _Case30(log: log),
      _case31(log),
    ];

const String _long =
    '<h1>ZLRichLabel</h1> 支持「展开 / 收起」：内容超过 maxLines 行时，最后一行末尾显示可点击的「… 全文」，'
    '点击后展开全部内容，末尾出现「收起」。适用于动态、评论、商品详情等场景。'
    '展开状态可以保存在数据里，列表复用时直接设置 expanded，不会触发 onExpandChanged。'
    '<h2>#标签#</h2> 的点击和按下高亮不受影响。';

ZLTextStyle _tokenStyle(Color color) =>
    ZLTextStyle().color(color).fontWeight(FontWeight.w600);

// MARK: - 24. 展开 / 收起

List<Widget> _case24(TapLog log) {
  const String fourLines =
      '<h1>collapseThreshold = 5</h1>：maxLines 仍为 3，但内容不超过 5 行时完整显示、'
      '不出现「全文」，避免只折叠掉一两行。这段文字在手机宽度下大约 4 行，所以完整显示。';
  const List<(String, String, int)> cases = <(String, String, int)>[
    ('24. 展开 / 收起（收起时 3 行）', _long, 0),
    ('24b. 内容不足 3 行：不显示「全文」', '<h1>短内容</h1> 不会被截断，也不显示按钮。', 0),
    ('24c. collapseThreshold = 5：不超过 5 行完整显示', fourLines, 5),
    ('24d. collapseThreshold = 5：超过 5 行才折叠为 3 行', _long + _long, 5),
  ];
  return <Widget>[
    for (final (String title, String source, int threshold) in cases)
      TagCase(
        title: title,
        source: source,
        log: log,
        builder: (BuildContext context, CaseHooks hooks) => AnimatedSize(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.topCenter,
          child: ZLTagRichLabel(
            text: source,
            style: kBaseStyle,
            verticalAlignment: ZLVerticalAlignment.top,
            maxLines: 3,
            collapseThreshold: threshold,
            tagStyle: ZLTextStyle().color(M.blue),
            highlightStyle:
                ZLTextStyle().backgroundColor(const Color(0x14000000)),
            expandToken:
                ZLAttributedText('… 全文', style: _tokenStyle(M.deepOrange)),
            collapseToken:
                ZLAttributedText(' 收起', style: _tokenStyle(M.deepOrange)),
            onExpandChanged: (bool expanded) => hooks.event(
                'expand', expanded ? '全文' : '收起', 'onExpandChanged($expanded)'),
            onTagTap: hooks.onTagTap,
            onParsed: hooks.onParsed,
          ),
        ),
      ),
  ];
}

/// 24e. 外部决定是否展开 / 收起：设置 onExpandTokenTap 后点击按钮不再自动切换
class _Case24e extends StatefulWidget {
  const _Case24e({required this.log});

  final TapLog log;

  @override
  State<_Case24e> createState() => _Case24eState();
}

class _Case24eState extends State<_Case24e> {
  static const String _title = '24e. onExpandTokenTap：外部决定是否展开 / 收起';
  final ZLRichLabelController _controller = ZLRichLabelController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTokenTap(CaseHooks hooks, bool wantsExpand) {
    final String text = wantsExpand ? '全文' : '收起';
    hooks.event(
        'expandToken', text, 'onExpandTokenTap(wantsExpand: $wantsExpand)');
    showActionSheet(
      context,
      title: wantsExpand ? '展开全文？' : '收起？',
      message: '设置了 onExpandTokenTap：由外部决定，不设置时内部自动切换',
      items: <(String, VoidCallback)>[
        // 按默认方式切换，并回调 onExpandChanged
        (
          wantsExpand ? '展开（toggleExpanded）' : '收起（toggleExpanded）',
          _controller.toggleExpanded
        ),
        if (wantsExpand)
          ('跳转详情页（不展开）', () => hooks.event('expandToken', text, '跳转详情页')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return TagCase(
      title: _title,
      source: _long,
      log: widget.log,
      builder: (BuildContext context, CaseHooks hooks) => AnimatedSize(
        duration: const Duration(milliseconds: 250),
        alignment: Alignment.topCenter,
        child: ZLTagRichLabel(
          text: _long,
          style: kBaseStyle,
          verticalAlignment: ZLVerticalAlignment.top,
          maxLines: 3,
          tagStyle: ZLTextStyle().color(M.blue),
          expandToken: ZLAttributedText('… 全文', style: _tokenStyle(M.teal)),
          collapseToken: ZLAttributedText(' 收起', style: _tokenStyle(M.teal)),
          onExpandChanged: (bool expanded) => hooks.event(
              'expand', expanded ? '全文' : '收起', 'onExpandChanged($expanded)'),
          onExpandTokenTap: (bool wantsExpand) =>
              _onTokenTap(hooks, wantsExpand),
          onTagTap: hooks.onTagTap,
          onParsed: hooks.onParsed,
          controller: _controller,
        ),
      ),
    );
  }
}

// MARK: - 25. 长按 / 双击 / 扩大点击热区

/// 25. 长按菜单（复制 / 举报）、按命中区分的长按、双击、扩大点击热区
class _Case25 extends StatefulWidget {
  const _Case25({required this.log});

  final TapLog log;

  @override
  State<_Case25> createState() => _Case25State();
}

class _Case25State extends State<_Case25> {
  static const String _title = '25. 长按菜单 / 双击 / 扩大点击热区';
  static const String _source =
      'Long press blank text to copy or report. Long press <h1>User Agreement</h1> or @alice '
      'for their own menus, double tap to like ❤️. Tap slightly below @bob: extendsLinkTouchArea '
      'expands the touch area by up to 15pt.';

  /// Hearts flying up from double tap positions.
  final List<(Key, Offset)> _hearts = <(Key, Offset)>[];

  void _copy(CaseHooks hooks, String text, ZLTagInfo info) {
    Clipboard.setData(ClipboardData(text: text));
    hooks.tap(
        info, '已复制：${text.length > 40 ? '${text.substring(0, 40)}…' : text}');
  }

  @override
  Widget build(BuildContext context) {
    return TagCase(
      title: _title,
      source: _source,
      log: widget.log,
      builder: (BuildContext context, CaseHooks hooks) => Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          ZLTagRichLabel(
            text: _source,
            style: baseStyleWithLineSpacing(10),
            verticalAlignment: ZLVerticalAlignment.top,
            tagStyle: ZLTextStyle().color(M.blue),
            highlightStyle:
                ZLTextStyle().backgroundColor(const Color(0x14000000)),
            extendsLinkTouchArea: true,
            onTagTap: hooks.onTagTap,
            onParsed: hooks.onParsed,
            rules: <ZLRichRule>[
              // 规则命中自己的长按：只回调它，不再回调 onLongPress
              ZLRichRule.regex('mention', r'@\w+',
                  handler: (ZLRichRuleContext ctx) {
                ctx.addStyle(ZLTextStyle().color(M.purple).bold());
                ctx.onTap = (ZLRichMatch m) =>
                    hooks.ruleTap(m, 'mention onTap → 打开 ${m.text} 的主页');
                ctx.onLongPress = (ZLRichMatch m) {
                  final ZLTagInfo info = ruleInfo(m);
                  showActionSheet(context,
                      title: m.text,
                      items: <(String, VoidCallback)>[
                        ('复制 ${m.text}', () => _copy(hooks, m.text, info)),
                        (
                          '举报 ${m.text}',
                          () =>
                              hooks.tap(info, 'ctx.onLongPress → 举报 ${m.text}')
                        ),
                      ]);
                };
              }),
            ],
            // 标签的长按
            onTagLongPress: (ZLTagInfo info) => showActionSheet(
              context,
              title: '<${info.name}> ${info.text}',
              items: <(String, VoidCallback)>[
                ('复制「${info.text}」', () => _copy(hooks, info.text, info))
              ],
            ),
            // 其他位置的长按：复制原文 / 展示文字、举报
            onLongPress: (ZLRichGestureInfo gesture) {
              final ZLTagInfo info = ZLTagInfo(
                  index: gesture.characterIndex ?? -1,
                  name: 'long-press',
                  text: gesture.displayText,
                  raw: gesture.rawText);
              showActionSheet(context,
                  title: '长按位置字符下标：${gesture.characterIndex ?? 'null'}',
                  items: <(String, VoidCallback)>[
                    (
                      '复制原文（rawText）',
                      () => _copy(hooks, gesture.rawText, info)
                    ),
                    (
                      '复制展示文字（displayText）',
                      () => _copy(hooks, gesture.displayText, info)
                    ),
                    ('举报', () => hooks.tap(info, 'onLongPress → 举报')),
                  ]);
            },
            // 双击：设置后单击链接会等双击判定失败才触发（约 300ms）
            onDoubleTap: (ZLRichGestureInfo gesture) {
              final ZLTagInfo info = ZLTagInfo(
                  index: gesture.characterIndex ?? -1,
                  name: 'double-tap',
                  text: gesture.matchDisplayText ?? '',
                  raw: gesture.match?.text ?? '');
              hooks.tap(info,
                  'onDoubleTap → 点赞 ❤️（位置 ${gesture.location.dx.round()}, ${gesture.location.dy.round()}）');
              setState(() => _hearts.add((UniqueKey(), gesture.location)));
            },
          ),
          for (final (Key key, Offset position) in _hearts)
            Positioned(
              key: key,
              left: position.dx - 18,
              top: position.dy - 18,
              child: _FlyingHeart(
                onEnd: () => setState(() => _hearts
                    .removeWhere(((Key, Offset) heart) => heart.$1 == key)),
              ),
            ),
        ],
      ),
    );
  }
}

/// ❤️ that grows, moves up and fades out.
class _FlyingHeart extends StatelessWidget {
  const _FlyingHeart({required this.onEnd});

  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        onEnd: onEnd,
        builder: (BuildContext context, double t, Widget? child) => Opacity(
          opacity: 1 - t,
          child: Transform.translate(
            offset: Offset(0, -12 * t),
            child: Transform.scale(scale: 1 + 0.6 * t, child: child),
          ),
        ),
        child: const Text('❤️', style: TextStyle(fontSize: 28)),
      ),
    );
  }
}

// MARK: - 26. 选中复制

/// 26. 选中复制：长按选词、拖动 / 拖柄调整范围，菜单「复制 / 复制原文 / 全选」
class _Case26 extends StatefulWidget {
  const _Case26({required this.log});

  final TapLog log;

  @override
  State<_Case26> createState() => _Case26State();
}

class _Case26State extends State<_Case26> {
  static const String _title = '26. 选中复制（selectable）';
  static const String _source = '长按选中一个词，拖动手指或两端的拖柄调整范围 [smile]，松手弹出菜单：'
      '「复制」得到展示文字，「复制原文」得到 @alice 和 [smile] 的原始写法。'
      '点击 <h1>用户协议</h1> 仍然可以跳转，点击文字取消选中。';

  final ZLRichLabelController _controller = ZLRichLabelController();
  String _status = '长按文字开始选中';

  late final List<ZLRichRule> _rules = <ZLRichRule>[
    // 表情：选中后「复制」得到空（图标），「复制原文」得到 [smile]
    ZLRichRule.regex('emoji', r'\[smile\]', handler: (ZLRichRuleContext ctx) {
      ctx.setWidget(ZLRichWidget.icon(Icons.sentiment_satisfied_alt, size: 17),
          ZLTextStyle().color(M.orange));
    }),
    // @提及：展示为 👤alice，原文为 @alice（长按命中时整体选中）
    ZLRichRule.regex('mention', r'@\w+', handler: (ZLRichRuleContext ctx) {
      ctx.setText(
          '👤${ctx.matchedText.substring(1)}', ZLTextStyle().color(M.purple));
    }),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TagCase(
      title: _title,
      source: _source,
      log: widget.log,
      builder: (BuildContext context, CaseHooks hooks) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ZLTagRichLabel(
            text: _source,
            style: kBaseStyle,
            verticalAlignment: ZLVerticalAlignment.top,
            selectable: true,
            tagStyle: ZLTextStyle().color(M.blue),
            rules: _rules,
            onTagTap: hooks.onTagTap,
            onParsed: hooks.onParsed,
            controller: _controller,
            onSelectionChanged: (TextRange? range) => setState(() {
              _status = range == null
                  ? '未选中'
                  : 'selectedRange   = {${range.start}, ${range.end - range.start}}\n'
                      'selectedText    = "${_controller.selectedText ?? ''}"\n'
                      'selectedRawText = "${_controller.selectedRawText ?? ''}"';
            }),
            onCopy: (String text, bool isRaw) => hooks.event(
                isRaw ? 'copy-raw' : 'copy',
                text,
                isRaw ? 'onCopy → 复制原文' : 'onCopy → 复制展示文字'),
          ),
          const SizedBox(height: 8),
          monoText(_status, color: const Color(0x99000000)),
        ],
      ),
    );
  }
}

// MARK: - 27. 通用标签

/// SF Symbol names of the iOS example → Material icons.
const Map<String, IconData> _icons = <String, IconData>{
  'star.fill': Icons.star,
  'star': Icons.star_border,
  'heart.fill': Icons.favorite,
  'heart': Icons.favorite_border,
  'bell.fill': Icons.notifications,
};

/// 27. 通用标签：任意标签名、标签属性、嵌套、自闭合
Widget _case27(TapLog log) {
  const String title = '27. 通用标签（任意标签名 / 属性 / 嵌套）';
  const String source =
      '支持 <b>粗体</b>、<i>斜体</i>、<u>下划线</u>、<color value="#E91E63">任意颜色</color>、'
      '<size value="20">字号</size>。可以嵌套：<b>粗体里 <color value="#2196F3">蓝色 <u>加下划线</u></color></b>。'
      '链接 <a href="https://github.com">GitHub</a>，图标 <icon name="star.fill" color="orange"/>，'
      '换行<br/>容错：<b>未闭合的 <i>标签</b> 原样显示，多余的 </u> 也原样显示。';
  return TagCase(
    title: title,
    source: source,
    log: log,
    builder: (BuildContext context, CaseHooks hooks) => ZLTagRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      // 识别任意标签名，支持嵌套和自闭合（默认只识别 <h> / <hN>）
      tagConfiguration: ZLTagParserConfiguration.anyTags,
      tagStyles: <String, ZLTextStyle>{
        'b': ZLTextStyle().bold(),
        'i': ZLTextStyle().italic(),
        'u': ZLTextStyle().underline(),
        'a': ZLTextStyle().color(M.blue).underline(),
      },
      // 按属性设置样式：<color value="…">、<size value="…">
      tagStyleBuilder: (ZLTagInfo info) {
        ZLTextStyle style = ZLTextStyle.none;
        final Color? color =
            info.name == 'color' ? info.colorAttribute('value') : null;
        if (color != null) style = style.color(color);
        final double? size = info.name == 'size'
            ? double.tryParse(info.attribute('value') ?? '')
            : null;
        if (size != null) style = style.fontSize(size);
        return style;
      },
      // 自闭合标签：<br/> 换行
      tagSpanBuilder: (ZLTagInfo info, ZLTextStyle style) =>
          info.name == 'br' ? ZLAttributedText('\n', style: style) : null,
      // 自闭合标签：<icon name="…" color="…"/>
      tagWidgetBuilder: (ZLTagInfo info, ZLTextStyle style) {
        if (info.name != 'icon') return null;
        return ZLRichWidget.icon(
            _icons[info.attribute('name')] ?? Icons.help_outline,
            color: info.colorAttribute('color') ?? M.grey);
      },
      // <a> 读取 href；其他标签走 onTagTap（内层标签优先响应点击）
      tagTapHandlers: <String, ZLTagTapCallback>{
        'a': (ZLTagInfo info) =>
            hooks.tap(info, '打开 ${info.attribute('href') ?? ''}'),
      },
      onTagTap: (ZLTagInfo info) {
        final List<String> path = <String>[];
        for (ZLTagInfo? t = info; t != null; t = t.parent) {
          path.insert(0, '<${t.name}>');
        }
        hooks.tap(info, 'onTagTap  ${path.join(' › ')}');
      },
      tagHighlightStyles: const <String, ZLTextStyle>{
        'br': ZLTextStyle.none,
        'icon': ZLTextStyle.none
      },
      onParsed: hooks.onParsed,
    ),
  );
}

// MARK: - 28. 胶囊背景 / 渐变文字

/// 28. 胶囊背景（圆角背景 / 边框 / 内边距）与渐变文字，由 label 自己绘制
Widget _case28(TapLog log) {
  const String title = '28. 胶囊背景 / 渐变文字';
  const String source = '<grad>Flutter 富文本</grad> <new>NEW</new>\n'
      '话题：#iOS开发# #Flutter##Dart# 点击胶囊有按下效果。'
      '行内代码 `label.text = value` 和 `rebuild()`。'
      '<tag>只有边框</tag> <tag>Tag</tag> '
      '<rainbow>竖向渐变 + 跨行的长胶囊也能正确绘制，每一行单独一段</rainbow>，'
      '<pill>很长的胶囊文字在折行时会分成两段分别绘制</pill>。';
  return TagCase(
    title: title,
    source: source,
    log: log,
    builder: (BuildContext context, CaseHooks hooks) => ZLTagRichLabel(
      text: source,
      // 胶囊的垂直内边距不占行高，加一点行距避免上下行重叠
      style: baseStyleWithLineSpacing(6),
      verticalAlignment: ZLVerticalAlignment.top,
      tagConfiguration: ZLTagParserConfiguration.anyTags,
      tagStyles: <String, ZLTextStyle>{
        // 渐变标题
        'grad': ZLTextStyle()
            .boldFont(22)
            .gradientColors(<Color>[M.pink, M.orange, M.deepPurple]),
        // 实心小徽章
        'new': ZLTextStyle()
            .boldFont(11)
            .color(Colors.white)
            .baseline(3)
            .withBackground(const ZLTextBackground(
                fillColor: M.deepOrange,
                cornerRadius: 4,
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2))),
        // 只有边框
        'tag': ZLTextStyle()
            .color(M.teal)
            .fontSize(13)
            .withBackground(const ZLTextBackground(strokeColor: M.teal)),
        // 竖向渐变
        'rainbow': ZLTextStyle()
            .bold()
            .gradientColors(<Color>[M.blue, M.green], vertical: true),
        // 跨行的胶囊
        'pill': ZLTextStyle().color(M.indigo).capsule(M.indigo),
      },
      // 按下高亮：换成更深的胶囊
      tagHighlightStyles: <String, ZLTextStyle>{
        'tag': ZLTextStyle().withBackground(ZLTextBackground(
            fillColor: M.teal.withValues(alpha: 0.15), strokeColor: M.teal)),
        'pill': ZLTextStyle().withBackground(
            ZLTextBackground(fillColor: M.indigo.withValues(alpha: 0.3))),
      },
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      rules: <ZLRichRule>[
        // #话题#：胶囊 + 点击
        ZLRichRule.regex('topic', r'#[^#\s]+#',
            handler: (ZLRichRuleContext ctx) {
          ctx.addStyle(ZLTextStyle().color(M.purple).capsule(M.purple));
          ctx.highlightStyle = ZLTextStyle().withBackground(
              ZLTextBackground(fillColor: M.purple.withValues(alpha: 0.3)));
          ctx.onTap = (ZLRichMatch m) => hooks.ruleTap(m, '点击话题');
        }),
        // `代码`：去掉反引号，等宽字体 + 灰色背景 + 细边框
        ZLRichRule.regex('code', r'`([^`]+)`',
            handler: (ZLRichRuleContext ctx) {
          ctx.setText(
              ctx.group(1)!,
              ZLTextStyle()
                  .monospacedFont(13)
                  .color(M.deepOrange)
                  .codeBackground());
        }),
      ],
    ),
  );
}

/// 28b. 从右到左（阿拉伯语 / 希伯来语）与双向混排下的胶囊
Widget _case28b(TapLog log) {
  const String title = '28b. RTL / 双向混排的胶囊';
  const String source = 'مرحبا #سويفت# لغة برمجة قوية\n'
      'שלום #סוויפט# היא שפה\n'
      'كبسولتان متجاورتان: #iOS##سويفت# معا\n'
      'تعلم #Flutter# اليوم\n'
      'Learn #سويفت# today';
  return RuleCase(
    title: title,
    source: source,
    log: log,
    builder: (BuildContext context, CaseHooks hooks) => ZLRichLabel(
      text: source,
      style: baseStyleWithLineSpacing(8),
      verticalAlignment: ZLVerticalAlignment.top,
      controller: hooks.controller,
      rules: <ZLRichRule>[
        ZLRichRule.regex('topic', r'#[^#\s]+#',
            handler: (ZLRichRuleContext ctx) {
          ctx.addStyle(ZLTextStyle().color(M.purple).capsule(M.purple));
          ctx.highlightStyle = ZLTextStyle().withBackground(
              ZLTextBackground(fillColor: M.purple.withValues(alpha: 0.3)));
          ctx.onTap = (ZLRichMatch m) => hooks.ruleTap(m, '点击 RTL 胶囊');
        }),
      ],
    ),
  );
}

// MARK: - 29. 内边距

/// 29. 内边距 padding：文字、点击热区、行内 Widget、截断与「展开」都在内边距以内，高度包含内边距
class _Case29 extends StatefulWidget {
  const _Case29({required this.log});

  final TapLog log;

  @override
  State<_Case29> createState() => _Case29State();
}

class _Case29State extends State<_Case29> {
  static const String _title = '29. 内边距 padding';
  static const String _source =
      '设置 <h1>padding</h1> 后，背景铺满整个 label，文字在内边距以内排版 <h2>View</h2>。'
      '点击热区、行内 Widget、截断与「展开」都跟着偏移，自动高度会加上内边距。'
      '切换上面的内边距可以看到文字重新折行。@alice';
  static const List<(String, EdgeInsets)> _paddings = <(String, EdgeInsets)>[
    ('0', EdgeInsets.zero),
    ('8', EdgeInsets.all(8)),
    ('12 / 16', EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
    ('24', EdgeInsets.all(24)),
  ];

  int _selected = 2;
  late final CaseHooks _hooks = CaseHooks(
      caseName: _title, log: widget.log, tappable: true, onParsed: (_) {});

  @override
  Widget build(BuildContext context) {
    final ZLTextStyle tokenStyle = _tokenStyle(M.deepOrange);
    return DemoCard(
      title: _title,
      source: _source,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          hintText('padding（pt）'),
          const SizedBox(height: 8),
          Segmented(
            items: <String>[
              for (final (String label, EdgeInsets _) in _paddings) label
            ],
            selected: _selected,
            onChanged: (int i) => setState(() => _selected = i),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: const Color(0xFFEADDFF),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.topCenter,
                child: ZLTagRichLabel(
                  text: _source,
                  style: kBaseStyle,
                  padding: _paddings[_selected].$2,
                  verticalAlignment: ZLVerticalAlignment.top,
                  maxLines: 3,
                  tagStyle: ZLTextStyle().color(M.blue),
                  highlightStyle:
                      ZLTextStyle().backgroundColor(const Color(0x14000000)),
                  onTagTap: _hooks.onTagTap,
                  tagWidgetBuilder: (ZLTagInfo info, ZLTextStyle style) =>
                      info.name == 'h2'
                          ? ZLRichWidget(
                              child: Pill(info.text,
                                  color: M.deepPurple,
                                  fontSize: 11,
                                  bold: true))
                          : null,
                  rules: <ZLRichRule>[
                    ZLRichRule.regex('mention', r'@\w+',
                        handler: (ZLRichRuleContext ctx) {
                      ctx.addStyle(ZLTextStyle().color(M.purple));
                      ctx.onTap = (ZLRichMatch m) => _hooks.ruleTap(m, '点击 @');
                    }),
                  ],
                  expandToken: ZLAttributedText('… 全文', style: tokenStyle),
                  collapseToken: ZLAttributedText(' 收起', style: tokenStyle),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// MARK: - 30. 首 / 中 / 尾行内 Widget 跟随 label 尺寸

/// 30. 开头 / 中间 / 结尾插入行内 Widget，修改 label 宽度、对齐、内边距、行数后，Widget 自动跟随文字重新定位。
/// 下方实时比较每个 Widget 的位置与它在文字中占位符的位置（controller.boundingRectForRange）
class _Case30 extends StatefulWidget {
  const _Case30({required this.log});

  final TapLog log;

  @override
  State<_Case30> createState() => _Case30State();
}

class _Case30State extends State<_Case30> {
  static const String _title = '30. 首 / 中 / 尾行内 Widget 跟随 label 尺寸';
  static const String _source =
      '[avatar] 开头是头像 Widget，中间插入一个 [follow] 按钮和 [badge] 徽章，'
      '拖动下面的宽度滑块，后面的文字会重新折行，Widget 跟着文字一起移动，结尾是箭头 [arrow]';
  static const List<String> _order = <String>[
    'avatar',
    'follow',
    'badge',
    'arrow'
  ];
  static const Map<String, String> _names = <String, String>{
    'avatar': '头像',
    'follow': '按钮',
    'badge': '徽章',
    'arrow': '箭头'
  };

  final ZLRichLabelController _controller = ZLRichLabelController();
  late final CaseHooks _hooks = CaseHooks(
      caseName: _title, log: widget.log, tappable: true, onParsed: (_) {});
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{
    for (final String name in _order) name: GlobalKey()
  };

  double _ratio = 1;
  Duration _duration = Duration.zero;
  int _alignment = 0;
  int? _option;
  int? _maxLines;
  EdgeInsets _padding = EdgeInsets.zero;
  bool _followed = false;
  String _status = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Map<String, ZLRichWidget> _widgets() => <String, ZLRichWidget>{
        'avatar': ZLRichWidget(
          size: const Size(22, 22),
          child: Container(
            key: _keys['avatar'],
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: M.deepPurple, shape: BoxShape.circle),
            child: const Text('Z',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ),
        // 自己处理点击的按钮：标题变化后尺寸变化，label 自动重新排版
        'follow': ZLRichWidget(
          tappable: false,
          child: GestureDetector(
            key: _keys['follow'],
            onTap: _toggleFollow,
            child: Pill(_followed ? '✓ 已关注' : '+ 关注',
                color: _followed ? M.grey : M.blue,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                radius: 9),
          ),
        ),
        'badge': ZLRichWidget(
          child: Pill('LV.5',
              key: _keys['badge'],
              color: M.amber,
              fontSize: 10,
              bold: true,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1)),
        ),
        'arrow': ZLRichWidget(
          size: const Size(18, 18),
          child: Icon(Icons.arrow_circle_right,
              key: _keys['arrow'], size: 18, color: M.teal),
        ),
      };

  void _toggleFollow() {
    setState(() => _followed = !_followed);
    _hooks.tap(
        ZLTagInfo(
            index: 0,
            name: 'follow',
            text: _followed ? '✓ 已关注' : '+ 关注',
            raw: '[follow]'),
        '按钮自己处理点击，尺寸变化');
  }

  void _setRatio(double ratio, {Duration duration = Duration.zero}) =>
      setState(() {
        _ratio = ratio;
        _duration = duration;
      });

  Future<void> _animate() async {
    _setRatio(0.35, duration: const Duration(milliseconds: 800));
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) _setRatio(1, duration: const Duration(milliseconds: 800));
  }

  /// Compares every inline widget with its placeholder in the text.
  void _refreshStatus() {
    final RenderZLText? label = _controller.renderObject;
    if (label == null || !label.attached) return;
    final String display = _controller.displayText;
    final List<int> slots = <int>[
      for (int i = 0; i < display.length; i++)
        if (display.codeUnitAt(i) == 0xFFFC) i,
    ];
    final List<String> lines = <String>[
      'label ${label.size.width.round()} × ${label.size.height.round()}'
    ];
    bool allOK = true;
    for (int i = 0; i < _order.length && i < slots.length; i++) {
      final String name = _names[_order[i]]!;
      final RenderObject? object =
          _keys[_order[i]]!.currentContext?.findRenderObject();
      if (slots[i] >= label.visibleContentLength ||
          object is! RenderBox ||
          !object.attached) {
        lines.add('$name  已截断，隐藏');
        continue;
      }
      final Rect rect =
          object.localToGlobal(Offset.zero, ancestor: label) & object.size;
      final Rect? slot = _controller
          .boundingRectForRange(TextRange(start: slots[i], end: slots[i] + 1));
      final bool ok = slot != null &&
          (rect.left - slot.left).abs() <= 1 &&
          rect.center.dy >= slot.top - 1 &&
          rect.center.dy <= slot.bottom + 1;
      allOK = allOK && ok;
      lines.add(
          '$name  x=${rect.left.toStringAsFixed(1).padLeft(5)} y=${rect.top.toStringAsFixed(1).padLeft(5)}  '
          '${ok ? '✅ 与文字位置一致' : '❌ 偏离（占位 x=${slot?.left.round()} y=${slot?.top.round()}）'}');
    }
    lines.add(allOK ? '结论：所有 Widget 已跟随 label 尺寸更新' : '结论：有 Widget 位置未更新');
    final String status = lines.join('\n');
    if (status != _status) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    // 每次布局后比较位置（只有结果变化时才 setState）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshStatus();
    });
    final Map<String, ZLRichWidget> widgets = _widgets();
    const List<TextAlign> aligns = <TextAlign>[
      TextAlign.start,
      TextAlign.left,
      TextAlign.center,
      TextAlign.right
    ];
    return DemoCard(
      title: _title,
      source: _source,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          hintText('宽度（拖动滑块）/ 对齐 / 行数与内边距'),
          Slider(
              key: const Key('case30Slider'),
              min: 0.3,
              max: 1,
              value: _ratio,
              onChanged: (double v) => _setRatio(v)),
          Segmented(
            items: const <String>['自然', '左', '居中', '右'],
            selected: _alignment,
            onChanged: (int i) => setState(() => _alignment = i),
          ),
          const SizedBox(height: 8),
          Segmented(
            items: const <String>['不限行', '2 行', '内边距 0', '内边距 16'],
            selected: _option,
            onChanged: (int i) => setState(() {
              _option = i;
              switch (i) {
                case 0:
                  _maxLines = null;
                case 1:
                  _maxLines = 2;
                case 2:
                  _padding = EdgeInsets.zero;
                default:
                  _padding =
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
              }
            }),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: _animate,
                child: const Text('▶︎ 动画：宽度 100% → 35% → 100%')),
          ),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: _duration,
                curve: Curves.easeInOut,
                width: constraints.maxWidth * _ratio,
                color: const Color(0xFFEADDFF),
                onEnd: _refreshStatus,
                child: ZLRichLabel(
                  text: _source,
                  style: kBaseStyle,
                  textAlign: aligns[_alignment],
                  verticalAlignment: ZLVerticalAlignment.top,
                  maxLines: _maxLines,
                  padding: _padding,
                  controller: _controller,
                  rules: <ZLRichRule>[
                    ZLRichRule.regex('view', r'\[(\w+)\]',
                        handler: (ZLRichRuleContext ctx) {
                      final String key = ctx.group(1)!;
                      final ZLRichWidget? inline = widgets[key];
                      if (inline == null) return;
                      ctx.setWidget(inline);
                      ctx.onTap = (ZLRichMatch m) =>
                          _hooks.ruleTap(m, '点击 Widget $key');
                    }),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          monoText(_status, fontSize: 10),
        ],
      ),
    );
  }
}

// MARK: - 31. ZLTextStyle 链式配置

/// 31. ZLTextStyle 链式配置：style / tagStyles / 高亮 / 规则 ctx 中都直接链式书写
Widget _case31(TapLog log) {
  const String title = '31. ZLTextStyle 链式配置';
  const String source = '<title>链式配置样式</title> <new>NEW</new>\n'
      '正文 ZLTextStyle().fontSize(15).color(…).withLineSpacing(6)，<b>加粗</b>、<i>斜体</i>、<u>下划线</u>、<s>删除线</s>、'
      '<grad>渐变文字</grad>、<shadow>阴影</shadow>、<k>字间距</k>，规则里 #话题# 胶囊和 `code` 行内代码。';
  return TagCase(
    title: title,
    source: source,
    log: log,
    builder: (BuildContext context, CaseHooks hooks) => ZLTagRichLabel(
      text: source,
      tagConfiguration: ZLTagParserConfiguration.anyTags,
      // 正文
      style: ZLTextStyle()
          .fontSize(15)
          .color(const Color(0xDE000000))
          .withLineSpacing(6),
      verticalAlignment: ZLVerticalAlignment.top,
      // 按标签名：值也是链式书写
      tagStyles: <String, ZLTextStyle>{
        'title': ZLTextStyle()
            .boldFont(20)
            .gradientColors(<Color>[M.pink, M.orange, M.deepPurple]),
        'new': ZLTextStyle()
            .boldFont(11)
            .color(Colors.white)
            .baseline(3)
            .withBackground(const ZLTextBackground(
                fillColor: M.deepOrange, cornerRadius: 4)),
        'b': ZLTextStyle().boldFont(15).color(M.blue),
        'i': ZLTextStyle().italic(),
        'u': ZLTextStyle().underline(color: M.pink),
        's': ZLTextStyle().strikethrough().color(M.grey),
        'grad':
            ZLTextStyle().boldFont(15).gradientColors(<Color>[M.blue, M.green]),
        'shadow': ZLTextStyle().color(M.indigo).shadow(
            Colors.black.withValues(alpha: 0.3),
            offset: const Offset(1, 1)),
        'k': ZLTextStyle().kern(4).color(M.teal),
      },
      // 按下高亮
      highlightStyle: ZLTextStyle().backgroundColor(const Color(0x14000000)),
      onTagTap: hooks.onTagTap,
      onParsed: hooks.onParsed,
      // 规则 handler 中：ctx.addStyle / ctx.highlightStyle / ctx.setText
      rules: <ZLRichRule>[
        ZLRichRule.regex('topic', r'#[^#\s]+#',
            handler: (ZLRichRuleContext ctx) {
          ctx.addStyle(ZLTextStyle().color(M.purple).capsule(M.purple));
          ctx.highlightStyle = ZLTextStyle().withBackground(
              ZLTextBackground(fillColor: M.purple.withValues(alpha: 0.3)));
          ctx.onTap = (ZLRichMatch m) => hooks.ruleTap(m, '点击话题');
        }),
        ZLRichRule.regex('code', r'`([^`]+)`',
            handler: (ZLRichRuleContext ctx) {
          ctx.setText(
              ctx.group(1)!,
              ZLTextStyle()
                  .monospacedFont(13)
                  .color(M.deepOrange)
                  .codeBackground());
        }),
      ],
    ),
  );
}

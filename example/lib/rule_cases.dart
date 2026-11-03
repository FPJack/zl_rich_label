import 'package:flutter/material.dart';
import 'package:zl_rich_label/zl_rich_label.dart';

import 'demo_common.dart';

/// Cases 17 – 23 of the iOS example: custom rules (`ZLRichLabel`), rule /
/// tag priorities, inline widget size changes, dark mode / text scale and
/// the render / layout caches.
List<Widget> ruleCases(TapLog log) => <Widget>[
      _case17(log),
      _case18(log),
      ..._case19(log),
      _case20(log),
      _case21(log),
      _case22(log),
      _Case23(log: log),
    ];

// MARK: - 17. @提及 / #话题# / 链接

/// 17. Custom rules on the base `ZLRichLabel`: @mentions, #topics# and links
/// (a [ZLDataDetector] is a `Pattern`, the display text is replaced).
Widget _case17(TapLog log) {
  const String name = '17. ZLRichLabel 自定义规则：@提及 / #话题# / 链接';
  const String source =
      'Hi @alice and @bob_99, join #SwiftUI# talk: https://www.apple.com/swift';
  return RuleCase(
    title: name,
    source: source,
    log: log,
    builder: (BuildContext context, CaseHooks hooks) => ZLRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      controller: hooks.controller,
      rules: <ZLRichRule>[
        // @提及
        ZLRichRule.regex('mention', r'@\w+', priority: 10,
            handler: (ZLRichRuleContext ctx) {
          ctx.addStyle(
              ZLTextStyle().color(M.purple).fontWeight(FontWeight.w600));
          ctx.onTap = (ZLRichMatch match) =>
              hooks.ruleTap(match, 'mention → 打开 ${match.text} 的主页');
        }),
        // #话题#
        ZLRichRule.regex('topic', r'#[^#\s]+#', priority: 10,
            handler: (ZLRichRuleContext ctx) {
          ctx.addStyle(ZLTextStyle().color(M.deepOrange));
          ctx.highlightStyle =
              ZLTextStyle().backgroundColor(const Color(0xFFFFE0B2));
          ctx.onTap = (ZLRichMatch match) =>
              hooks.ruleTap(match, 'topic → 打开话题 ${match.text}');
        }),
        // 链接：ZLDataDetector 也是 Pattern，替换展示文字
        ZLRichRule(
          name: 'link',
          pattern:
              ZLDataDetector(<ZLDataDetectorType>{ZLDataDetectorType.link}),
          priority: 10,
          handler: (ZLRichRuleContext ctx) {
            ctx.setText('🔗网页链接', ZLTextStyle().color(M.blue).underline());
            ctx.onTap = (ZLRichMatch match) {
              final String url =
                  (match.result as ZLDataDetectorResult).url?.toString() ??
                      match.text;
              hooks.ruleTap(match, 'link → 打开 $url');
            };
          },
        ),
      ],
    ),
  );
}

// MARK: - 18. 表情 / 模板变量

/// 18. Replacing matches: `[smile]` becomes an inline icon (tappable),
/// `{{name}}` is looked up through a named capture group.
Widget _case18(TapLog log) {
  const String name = '18. ZLRichLabel 外部解析替换：[smile] 表情 / {{变量}}';
  const String source =
      'Hello {{name}} [smile], you have {{count}} new messages [heart][star]. Unknown: {{foo}} [xxx].';
  const Map<String, IconData> icons = <String, IconData>{
    'smile': Icons.sentiment_satisfied_alt,
    'heart': Icons.favorite,
    'star': Icons.star,
  };
  const Map<String, Color> colors = <String, Color>{
    'smile': M.orange,
    'heart': M.red,
    'star': M.amber
  };
  const Map<String, String> variables = <String, String>{
    'name': 'Alice',
    'count': '3'
  };
  return RuleCase(
    title: name,
    source: source,
    log: log,
    builder: (BuildContext context, CaseHooks hooks) => ZLRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      controller: hooks.controller,
      rules: <ZLRichRule>[
        // 表情：替换为图标（行内 widget），点击图标也能响应
        ZLRichRule.regex('emoji', r'\[(smile|heart|star)\]', priority: 5,
            handler: (ZLRichRuleContext ctx) {
          final String key = ctx.group(1)!;
          ctx.setWidget(ZLRichWidget.icon(icons[key]!,
              size: 17, color: colors[key] ?? M.grey));
          ctx.onTap = (ZLRichMatch match) =>
              hooks.ruleTap(match, 'emoji → ${match.group(1) ?? ''}');
        }),
        // 模板变量：命名捕获组取 key，外部查值后写回
        ZLRichRule.regex('variable', r'\{\{(?<key>\w+)\}\}', priority: 5,
            handler: (ZLRichRuleContext ctx) {
          final String key = ctx.namedGroup('key') ?? '';
          final String? value = variables[key];
          if (value != null) {
            ctx.setText(value, ZLTextStyle().boldFont(15).color(M.teal));
          } else {
            ctx.addStyle(ZLTextStyle().color(M.grey).strikethrough());
          }
        }),
      ],
    ),
  );
}

// MARK: - 19. 优先级

/// 19. Priorities: phone rule (20) vs the built-in `<h1>` tag (tagPriority)
/// vs number rule (1).
List<Widget> _case19(TapLog log) {
  const String source =
      'Call <h1>13800138000</h1> or 400-123-4567, order 2024.';

  Widget label(CaseHooks hooks, int tagPriority) => ZLTagRichLabel(
        text: source,
        style: kBaseStyle,
        verticalAlignment: ZLVerticalAlignment.top,
        onTagTap: hooks.onTagTap,
        onParsed: hooks.onParsed,
        tagPriority: tagPriority,
        tagStyle: ZLTextStyle().color(M.blue).underline(),
        rules: <ZLRichRule>[
          ZLRichRule.regex('phone', r'1\d{10}', priority: 20,
              handler: (ZLRichRuleContext ctx) {
            ctx.addStyle(ZLTextStyle().color(M.green).boldFont(15));
            ctx.onTap = (ZLRichMatch match) =>
                hooks.ruleTap(match, 'phone(20) → 拨打 ${match.text}');
          }),
          ZLRichRule.regex('number', r'\d+', priority: 1,
              handler: (ZLRichRuleContext ctx) {
            ctx.addStyle(
                ZLTextStyle().backgroundColor(const Color(0xFFE0E0E0)));
          }),
        ],
      );

  return <Widget>[
    // h1 与 phone 重叠，phone 优先级更高 → h1 整体作废，<h1> 原样显示
    TagCase(
      title: '19a. 优先级：phone(20) > h1(0) > number(1)?',
      source: source,
      log: log,
      builder: (BuildContext context, CaseHooks hooks) => label(hooks, 0),
    ),
    // h1 优先，内部的手机号不再被规则处理
    TagCase(
      title: '19b. 优先级：h1(100) > phone(20) > number(1)',
      source: source,
      log: log,
      builder: (BuildContext context, CaseHooks hooks) => label(hooks, 100),
    ),
  ];
}

// MARK: - 20. 简易 Markdown

/// 20. Only custom rules (base `ZLRichLabel`, `<h1>` is not parsed): a tiny
/// Markdown.
Widget _case20(TapLog log) {
  const String source =
      '<h1>not parsed</h1>, **bold**, ~~strike~~, `code` and **nested `x`**.';
  return RuleCase(
    title: '20. ZLRichLabel 简易 Markdown（<h> 不解析）',
    source: source,
    log: log,
    builder: (BuildContext context, CaseHooks hooks) => ZLRichLabel(
      text: source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      controller: hooks.controller,
      rules: <ZLRichRule>[
        // 长的 **...** 先占位（同优先级位置靠前 / 更长优先），内部的 `x` 不会再被处理
        ZLRichRule.regex('bold', r'\*\*(.+?)\*\*',
            handler: (ZLRichRuleContext ctx) {
          ctx.setText(ctx.group(1) ?? '', ZLTextStyle().boldFont(15));
        }),
        ZLRichRule.regex('strike', r'~~(.+?)~~',
            handler: (ZLRichRuleContext ctx) {
          ctx.setText(ctx.group(1) ?? '', ZLTextStyle().strikethrough());
        }),
        ZLRichRule.regex('code', r'`([^`]+)`',
            handler: (ZLRichRuleContext ctx) {
          ctx.setText(
            ctx.group(1) ?? '',
            ZLTextStyle()
                .monospacedFont(14)
                .backgroundColor(const Color(0xFFEEEEEE))
                .color(M.pink),
          );
        }),
      ],
    ),
  );
}

// MARK: - 21. 自定义 View 尺寸变化

/// 21. Inline widgets that change their size: the label lays the text out
/// again automatically.
Widget _case21(TapLog log) {
  const String source =
      'Tap the box <h1>box</h1> to resize it, tap <h2>like</h2> to add likes, '
      'the following text reflows automatically.';
  return TagCase(
    title: '21. 自定义 View 尺寸变化，自动刷新排版',
    source: source,
    log: log,
    builder: (BuildContext context, CaseHooks hooks) =>
        _Case21Label(source: source, hooks: hooks),
  );
}

class _Case21Label extends StatefulWidget {
  const _Case21Label({required this.source, required this.hooks});

  final String source;
  final CaseHooks hooks;

  @override
  State<_Case21Label> createState() => _Case21LabelState();
}

class _Case21LabelState extends State<_Case21Label> {
  double _boxWidth = 24;
  int _likes = 0;

  // In Flutter an inline widget that changes its size makes the label lay
  // out again by itself — nothing like `zl_setNeedsRichLabelLayout()` is
  // needed, the following text reflows on the next frame.
  void _growBox() {
    setState(() => _boxWidth = _boxWidth >= 120 ? 24 : _boxWidth + 32);
    widget.hooks.event('box', 'box', '色块宽度 → ${_boxWidth.toInt()}');
  }

  void _like() {
    setState(() => _likes += 1);
    widget.hooks.event('like', '👍 $_likes', '点赞计数文字变化，自动重新测量');
  }

  @override
  Widget build(BuildContext context) {
    return ZLTagRichLabel(
      text: widget.source,
      style: kBaseStyle,
      verticalAlignment: ZLVerticalAlignment.top,
      onTagTap: widget.hooks.onTagTap,
      onParsed: widget.hooks.onParsed,
      tagStyle: ZLTextStyle().color(M.blue),
      tagWidgetBuilder: (ZLTagInfo info, ZLTextStyle style) {
        switch (info.name) {
          case 'h1':
            // 固定尺寸的色块：点击后宽度变化（自己处理点击，不触发 onTagTap）
            return ZLRichWidget(
              size: Size(_boxWidth, 16),
              tappable: false,
              child: GestureDetector(
                key: const Key('case21-box'),
                onTap: _growBox,
                child: Container(
                  decoration: BoxDecoration(
                      color: M.orange, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            );
          case 'h2':
            // 自动尺寸（size 为 null）：文字变化后重新测量
            return ZLRichWidget(
              tappable: false,
              child: GestureDetector(
                key: const Key('case21-like'),
                onTap: _like,
                child: Pill('👍 $_likes', color: M.pink, radius: 9),
              ),
            );
        }
        return null;
      },
    );
  }
}

// MARK: - 22. 深色模式 / 文字大小

/// 22. Dark mode and text scale: handlers and builders run again when the
/// brightness or the text scale changes.
Widget _case22(TapLog log) {
  const String source =
      'Appearance: {mode}. Read the <h1>User Agreement</h1> <h2>NEW</h2>, '
      'text, tags and the badge follow dark mode and the system text size.';
  return TagCase(
    title: '22. 深色模式 / Dynamic Type',
    source: source,
    log: log,
    builder: (BuildContext context, CaseHooks hooks) =>
        _Case22Content(source: source, hooks: hooks),
  );
}

class _Case22Content extends StatefulWidget {
  const _Case22Content({required this.source, required this.hooks});

  final String source;
  final CaseHooks hooks;

  @override
  State<_Case22Content> createState() => _Case22ContentState();
}

class _Case22ContentState extends State<_Case22Content> {
  /// 0 跟随系统 / 1 浅色 / 2 深色
  int _appearance = 0;

  /// 文字大小：系统 / XS / L / XXXL / AX3
  int _size = 0;
  static const List<String> _sizeNames = <String>[
    '系统',
    'XS',
    'L',
    'XXXL',
    'AX3'
  ];
  static const List<double?> _scales = <double?>[null, 0.82, 1.0, 1.35, 2.0];

  bool _scalesText = true;

  // The rule object is kept: the label renders it again by itself when the
  // brightness or the text scale changes, and the handler reads the theme.
  static final ZLRichRule _modeRule =
      ZLRichRule.regex('mode', r'\{mode\}', handler: (ZLRichRuleContext ctx) {
    final bool dark = Theme.of(ctx.context!).brightness == Brightness.dark;
    ctx.setText(
      dark ? '🌙 Dark' : '☀️ Light',
      ZLTextStyle()
          .boldFont(15)
          .color(dark ? const Color(0x99EBEBF5) : const Color(0x993C3C43)),
    );
  });

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = switch (_appearance) {
      1 => Brightness.light,
      2 => Brightness.dark,
      _ => MediaQuery.platformBrightnessOf(context),
    };
    final bool dark = brightness == Brightness.dark;
    final MediaQueryData media = MediaQuery.of(context);
    final double? scale = _scales[_size];
    final TextScaler scaler =
        scale == null ? media.textScaler : TextScaler.linear(scale);

    final Widget label = ZLTagRichLabel(
      text: widget.source,
      verticalAlignment: ZLVerticalAlignment.top,
      // 关闭时不跟随文字大小（对应 adjustsFontForContentSizeCategory = false）
      textScaler: _scalesText ? null : TextScaler.noScaling,
      // 按预览区域的外观选择颜色（对应 UIColor.label 等动态颜色）
      style:
          ZLTextStyle().fontSize(15).color(dark ? Colors.white : Colors.black),
      tagStyle: ZLTextStyle()
          .color(dark ? const Color(0xFF90CAF9) : M.blue)
          .underline(),
      onTagTap: widget.hooks.onTagTap,
      onParsed: widget.hooks.onParsed,
      // 行内 widget 的文字通过 MediaQuery 自动跟随文字大小（对应 scaledFont）
      tagWidgetBuilder: (ZLTagInfo info, ZLTextStyle style) {
        if (info.name != 'h2') return null;
        final Widget badge = Pill(info.text,
            color: dark ? const Color(0xFFFF8A65) : M.deepOrange,
            fontSize: 10,
            bold: true,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1));
        return ZLRichWidget(
            child: _scalesText
                ? badge
                : MediaQuery.withNoTextScaling(child: badge));
      },
      // 规则 handler 也会重新执行：按当前外观返回不同内容
      rules: <ZLRichRule>[_modeRule],
    );

    // 预览区域：外观 / 字号的覆盖只作用在这里，不影响整个页面
    final Widget preview = Theme(
      data: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple, brightness: brightness)),
      child: MediaQuery(
        data:
            media.copyWith(textScaler: scaler, platformBrightness: brightness),
        child: Container(
          key: const Key('case22-preview'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: label,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Segmented(
          items: const <String>['跟随系统', '浅色', '深色'],
          selected: _appearance,
          onChanged: (int i) => setState(() => _appearance = i),
        ),
        const SizedBox(height: 8),
        Segmented(
            items: _sizeNames,
            selected: _size,
            onChanged: (int i) => setState(() => _size = i)),
        const SizedBox(height: 4),
        hintText('文字大小只覆盖预览区域；选「系统」则跟随系统设置的文字大小'),
        SwitchRow(
          label: 'adjustsFontForContentSizeCategory',
          value: _scalesText,
          onChanged: (bool v) => setState(() => _scalesText = v),
        ),
        preview,
      ],
    );
  }
}

// MARK: - 23. 性能：渲染缓存 / 排版缓存

/// 23. Performance: render results are cached per match while the rule
/// objects stay the same; layouts are cached per constraints.
class _Case23 extends StatefulWidget {
  const _Case23({required this.log});

  final TapLog log;

  @override
  State<_Case23> createState() => _Case23State();
}

class _Case23State extends State<_Case23> {
  static const String _name = '23. 性能：渲染缓存 / 排版缓存';
  static const int _count = 200;
  static const String _shownSource =
      '@user0 [smile] #topic0# @user1 [smile] #topic1# …（重复 $_count 次，共 ${_count * 3} 个命中）';

  final ZLRichLabelController _controller = ZLRichLabelController();
  String _text = List<String>.generate(
      _count, (int i) => '@user$i [smile] #topic${i % 10}# ').join();
  bool _mentionPurple = true;
  bool _highlightYellow = true;
  int _appended = 0;
  String _stats = '';

  // 规则对象保存在 State 中：对象不变，命中的渲染结果就会被缓存复用。
  late final List<ZLRichRule> _rules = <ZLRichRule>[
    ZLRichRule.regex('mention', r'@\w+', handler: (ZLRichRuleContext ctx) {
      // handler 依赖外部状态：变化后用 setNeedsRebuild('mention') 只刷新这条规则
      ctx.addStyle(ZLTextStyle().color(_mentionPurple ? M.purple : M.green));
      ctx.onTap = (ZLRichMatch match) =>
          widget.log.add(_name, ruleInfo(match), action: 'rule onTap');
    }),
    ZLRichRule.regex('emoji', r'\[smile\]', handler: (ZLRichRuleContext ctx) {
      // 图标不指定颜色：跟随文字颜色（橙色）
      ctx.setWidget(ZLRichWidget.icon(Icons.sentiment_satisfied_alt, size: 16));
      ctx.addStyle(ZLTextStyle().color(M.orange));
    }),
    ZLRichRule.regex('topic', r'#\w+#', handler: (ZLRichRuleContext ctx) {
      ctx.addStyle(ZLTextStyle().color(M.blue));
    }),
  ];

  @override
  void initState() {
    super.initState();
    final Stopwatch watch = Stopwatch()..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      watch.stop();
      if (mounted) setState(() => _stats = _describe('首次渲染', watch));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _describe(String title, Stopwatch watch) {
    final ZLLabelStatistics s = _controller.statistics;
    final List<ZLRichMatch> matches = _controller.matches;
    final int widgets =
        matches.where((ZLRichMatch m) => m.rule.name == 'emoji').length;
    final String ms = (watch.elapsedMicroseconds / 1000).toStringAsFixed(2);
    return '$title：$ms ms\n'
        'handler 执行 ${s.handlerCalls} 次，复用 ${s.reusedMatches} 个命中\n'
        '渲染 ${s.renders} 次，文本排版 ${s.textLayouts} 次，布局缓存命中 ${s.layoutCacheHits} 次\n'
        '当前命中 ${matches.length} 个，自定义 View $widgets 个';
  }

  /// Runs [action], waits for the frame and shows time + statistics.
  Future<void> _measure(String title, VoidCallback action) async {
    _controller.statistics.reset();
    final Stopwatch watch = Stopwatch()..start();
    action();
    await WidgetsBinding.instance.endOfFrame;
    watch.stop();
    if (mounted) setState(() => _stats = _describe(title, watch));
  }

  /// 按下高亮不影响 handler 输出：全部复用
  void _changeHighlight() {
    _measure(
        '改按下高亮', () => setState(() => _highlightYellow = !_highlightYellow));
  }

  /// 末尾追加：前面命中的位置和内容都没变，只渲染新增的命中
  void _append() {
    _appended += 1;
    _measure('末尾追加 @new$_appended',
        () => setState(() => _text = '$_text@new$_appended '));
  }

  /// handler 依赖的外部数据变了，只作废这条规则：表情和话题直接复用
  void _recolorMentions() {
    _measure("只刷新 @提及（setNeedsRebuild('mention')）", () {
      _mentionPurple = !_mentionPurple;
      _controller.setNeedsRebuild('mention');
    });
  }

  /// 强制全部重新执行（对比用）
  void _rebuild() => _measure('rebuild() 全部重新执行', _controller.rebuild);

  /// 同样的约束重复计算尺寸：不会重新排版文字（文本排版 0 次）
  void _layout100() {
    _measure('getDryLayout ×100', () {
      final RenderZLText? render = _controller.renderObject;
      if (render == null) return;
      final BoxConstraints constraints = render.constraints;
      for (int i = 0; i < 100; i++) {
        render.getDryLayout(constraints);
      }
    });
  }

  /// 解析器：1.5 万个命中按优先级去重，O(n log n)
  void _parse() {
    final String text = List<String>.filled(5000, '@user #tag# word ').join();
    final List<ZLRichRule> rules = <ZLRichRule>[
      ZLRichRule.regex('mention', r'@\w+', handler: (_) {}),
      ZLRichRule.regex('topic', r'#\w+#', handler: (_) {}),
      ZLRichRule.regex('word', r'\w+', priority: -1, handler: (_) {}),
    ];
    final Stopwatch watch = Stopwatch()..start();
    final List<ZLRichMatch> matches = ZLRichParser.resolve(text, rules);
    watch.stop();
    setState(() {
      _stats =
          'ZLRichParser.resolve：${(watch.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms\n'
          '文本 ${text.length} 字符，3 条规则，生效命中 ${matches.length} 个\n'
          '（含正则匹配耗时；label 未参与）';
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<(String, VoidCallback)> buttons = <(String, VoidCallback)>[
      ('改按下高亮', _changeHighlight),
      ('末尾追加文字', _append),
      ('只刷新 @提及', _recolorMentions),
      ('rebuild()', _rebuild),
      ('layout ×100', _layout100),
      ('解析 1.5 万命中', _parse),
    ];
    return DemoCard(
      title: _name,
      source: _shownSource,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          KeyedSubtree(
            child: ZLRichLabel(
              text: _text,
              rules: _rules,
              style: kBaseStyle,
              maxLines: 4,
              verticalAlignment: ZLVerticalAlignment.top,
              highlightStyle: ZLTextStyle().backgroundColor(
                  (_highlightYellow ? M.amber : M.blue).withValues(alpha: 0.4)),
              controller: _controller,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final (String title, VoidCallback action) in buttons)
                FilledButton.tonal(
                  onPressed: action,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: Text(title),
                ),
            ],
          ),
          const SizedBox(height: 8),
          monoText(_stats),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:zl_rich_label/zl_rich_label.dart';

/// Material colours used by the demos (same values as the iOS example).
abstract final class M {
  static const Color blue = Color(0xFF2196F3);
  static const Color deepOrange = Color(0xFFFF5722);
  static const Color red = Color(0xFFF44336);
  static const Color green = Color(0xFF4CAF50);
  static const Color purple = Color(0xFF9C27B0);
  static const Color deepPurple = Color(0xFF673AB7);
  static const Color orange = Color(0xFFFF9800);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color teal = Color(0xFF009688);
  static const Color pink = Color(0xFFE91E63);
  static const Color indigo = Color(0xFF3F51B5);
  static const Color brown = Color(0xFF795548);
  static const Color amber = Color(0xFFFFC107);
}

/// Plain text style of the demos.
const ZLTextStyle kBaseStyle =
    ZLTextStyle(textStyle: TextStyle(fontSize: 15, color: Color(0xDE000000)));

/// The same text style with extra line spacing.
ZLTextStyle baseStyleWithLineSpacing(double spacing) =>
    kBaseStyle.withLineSpacing(spacing);

// MARK: - Tap log

/// One tap (or other event) shown in the panel at the top.
class TapRecord {
  TapRecord(this.caseName, this.info, this.action) : time = DateTime.now();

  final String caseName;
  final ZLTagInfo info;
  final String action;
  final DateTime time;
}

/// Tap history shared by all cases of a page.
class TapLog extends ChangeNotifier {
  TapRecord? last;
  final List<TapRecord> history = <TapRecord>[];

  void add(String caseName, ZLTagInfo info, {String action = 'onTagTap（兜底）'}) {
    final TapRecord record = TapRecord(caseName, info, action);
    last = record;
    history.insert(0, record);
    if (history.length > 20) history.removeLast();
    debugPrint('[$caseName] $action -> $info');
    notifyListeners();
  }

  void clear() {
    last = null;
    history.clear();
    notifyListeners();
  }
}

/// A rule match shown in the tap panel.
ZLTagInfo ruleInfo(ZLRichMatch match) => ZLTagInfo(
    index: match.index,
    name: 'rule:${match.rule.name}',
    text: match.text,
    raw: match.text);

/// What a case builder gets: callbacks that report to the tap log.
class CaseHooks {
  CaseHooks(
      {required this.caseName,
      required this.log,
      required this.tappable,
      required this.onParsed,
      this.controller});

  final String caseName;
  final TapLog log;
  final bool tappable;

  /// Pass to `ZLTagRichLabel.onParsed`, the card shows the tags.
  final ValueChanged<List<ZLTagInfo>> onParsed;

  /// Controller of [RuleCase] labels (the card shows its matches).
  final ZLRichLabelController? controller;

  /// Default `onTagTap` of the case (`null` when the case is not tappable).
  ZLTagTapCallback? get onTagTap =>
      tappable ? (ZLTagInfo info) => log.add(caseName, info) : null;

  void tap(ZLTagInfo info, String action) =>
      log.add(caseName, info, action: action);

  void ruleTap(ZLRichMatch match, String action) =>
      log.add(caseName, ruleInfo(match), action: action);

  /// A synthetic event record (expand, copy, …).
  void event(String name, String text, String action,
          {int index = 0, String raw = ''}) =>
      log.add(
          caseName, ZLTagInfo(index: index, name: name, text: text, raw: raw),
          action: action);
}

// MARK: - Cards

/// White card with a shadow.
class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: child,
    );
  }
}

const TextStyle _hint = TextStyle(fontSize: 12, color: Color(0x73000000));
const TextStyle _mono = TextStyle(
    fontSize: 11,
    color: Color(0x8A000000),
    fontFamily: 'monospace',
    fontFamilyFallback: <String>['Menlo', 'Courier']);

/// Small hint text.
Widget hintText(String text) => Text(text, style: _hint);

/// Monospaced status text.
Widget monoText(String text,
        {double fontSize = 11, Color color = const Color(0xB3000000)}) =>
    Text(
      text,
      style: _mono.copyWith(fontSize: fontSize, color: color),
    );

/// One case: title + raw string + rendered result + parse results.
class DemoCard extends StatelessWidget {
  const DemoCard(
      {super.key,
      required this.title,
      required this.source,
      required this.child,
      this.tags,
      this.matches});

  final String title;
  final String source;
  final Widget child;

  /// `onParsed` result of tag cases.
  final List<ZLTagInfo>? tags;

  /// Effective matches of rule cases.
  final List<ZLRichMatch>? matches;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          hintText('原始字符串：'),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6)),
            child: SelectableText(
              source,
              style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontFamilyFallback: <String>['Menlo', 'Courier']),
            ),
          ),
          const SizedBox(height: 8),
          hintText('渲染效果：'),
          const SizedBox(height: 4),
          child,
          ..._parsed(),
        ],
      ),
    );
  }

  List<Widget> _parsed() {
    final List<ZLTagInfo>? tags = this.tags;
    final List<ZLRichMatch>? matches = this.matches;
    if (tags != null) {
      return <Widget>[
        const SizedBox(height: 8),
        hintText('onParsed 回调（共 ${tags.length} 个标签）：'),
        if (tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          monoText(tags.map((ZLTagInfo t) {
            final String indent = '    ' * t.depth;
            final List<String> keys = t.attributes.keys.toList()..sort();
            final String attrs = keys.isEmpty
                ? ''
                : '  attributes=${keys.map((String k) => '$k="${t.attributes[k]}"').join(' ')}';
            final String level =
                t.name.startsWith('h') ? '  level=${t.level ?? 'null'}' : '';
            return '$indent#${t.index}  <${t.name}>  text="${t.text}"$level$attrs';
          }).join('\n')),
        ],
      ];
    }
    if (matches != null) {
      return <Widget>[
        const SizedBox(height: 8),
        hintText('规则命中 matches（共 ${matches.length} 个）：'),
        if (matches.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          monoText(matches
              .map((ZLRichMatch m) =>
                  '#${m.index}  [${m.rule.name}]  text="${m.text}"  priority=${m.rule.priority}')
              .join('\n')),
        ],
      ];
    }
    return const <Widget>[];
  }
}

/// A tag case: the builder returns the content (usually a [ZLTagRichLabel]
/// using `hooks.onTagTap` and `hooks.onParsed`); the card shows the parsed
/// tags.
class TagCase extends StatefulWidget {
  const TagCase(
      {super.key,
      required this.title,
      required this.source,
      required this.log,
      this.tappable = true,
      required this.builder});

  final String title;
  final String source;
  final TapLog log;
  final bool tappable;
  final Widget Function(BuildContext context, CaseHooks hooks) builder;

  @override
  State<TagCase> createState() => _TagCaseState();
}

class _TagCaseState extends State<TagCase> {
  List<ZLTagInfo>? _tags;
  late final CaseHooks _hooks = CaseHooks(
    caseName: widget.title,
    log: widget.log,
    tappable: widget.tappable,
    onParsed: (List<ZLTagInfo> tags) {
      if (mounted) setState(() => _tags = tags);
    },
  );

  @override
  Widget build(BuildContext context) {
    return DemoCard(
        title: widget.title,
        source: widget.source,
        tags: _tags,
        child: widget.builder(context, _hooks));
  }
}

/// A rule case: the builder returns a [ZLRichLabel] using
/// `hooks.controller`; the card shows the effective matches.
class RuleCase extends StatefulWidget {
  const RuleCase(
      {super.key,
      required this.title,
      required this.source,
      required this.log,
      required this.builder});

  final String title;
  final String source;
  final TapLog log;
  final Widget Function(BuildContext context, CaseHooks hooks) builder;

  @override
  State<RuleCase> createState() => _RuleCaseState();
}

class _RuleCaseState extends State<RuleCase> {
  final ZLRichLabelController _controller = ZLRichLabelController();
  List<ZLRichMatch> _matches = const <ZLRichMatch>[];
  late final CaseHooks _hooks = CaseHooks(
    caseName: widget.title,
    log: widget.log,
    tappable: true,
    onParsed: (_) {},
    controller: _controller,
  );

  @override
  void initState() {
    super.initState();
    // Parsing is synchronous: read the matches after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _matches = _controller.matches);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoCard(
        title: widget.title,
        source: widget.source,
        matches: _matches,
        child: widget.builder(context, _hooks));
  }
}

/// Keeps a card alive in lazily built lists.
class KeepAliveCard extends StatefulWidget {
  const KeepAliveCard({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAliveCard> createState() => _KeepAliveCardState();
}

class _KeepAliveCardState extends State<KeepAliveCard>
    with AutomaticKeepAliveClientMixin<KeepAliveCard> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// MARK: - Tap panel & history

/// Top panel: everything about the last tap.
class TapInfoPanel extends StatelessWidget {
  const TapInfoPanel({super.key, required this.log});

  final TapLog log;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: log,
      builder: (BuildContext context, _) {
        final TapRecord? r = log.last;
        return Container(
          width: double.infinity,
          color: const Color(0xFFF3F0FA),
          padding: const EdgeInsets.all(12),
          child: r == null
              ? const Text('👆 点击下方任意高亮文字，这里会显示点击得到的所有信息',
                  style: TextStyle(fontSize: 14, color: Color(0x8A000000)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('最近点击 · ${r.caseName}\n动作：${r.action}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    _InfoTable(info: r.info),
                  ],
                ),
        );
      },
    );
  }
}

class _InfoTable extends StatelessWidget {
  const _InfoTable({required this.info});

  final ZLTagInfo info;

  @override
  Widget build(BuildContext context) {
    String q(String? s) => s == null ? 'null' : '"$s"';
    final List<(String, String)> rows = <(String, String)>[
      ('index', '${info.index}'),
      ('name', q(info.name)),
      ('level', '${info.level ?? 'null'}'),
      ('text', q(info.text)),
      ('raw', q(info.raw)),
    ];
    const TextStyle mono = TextStyle(
        fontSize: 13,
        fontFamily: 'monospace',
        fontFamilyFallback: <String>['Menlo', 'Courier']);
    return Text.rich(TextSpan(children: <InlineSpan>[
      for (int i = 0; i < rows.length; i++) ...<InlineSpan>[
        TextSpan(
            text: rows[i].$1.padRight(7),
            style: mono.copyWith(color: M.deepPurple)),
        TextSpan(
            text: rows[i].$2 + (i < rows.length - 1 ? '\n' : ''),
            style: mono.copyWith(color: Colors.black)),
      ],
    ]));
  }
}

/// Tap history card.
class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key, required this.log});

  final TapLog log;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: log,
      builder: (BuildContext context, _) {
        String two(int v) => v.toString().padLeft(2, '0');
        return CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('点击历史（${log.history.length}）',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (log.history.isEmpty)
                const Text('暂无',
                    style: TextStyle(fontSize: 14, color: Color(0x73000000)))
              else
                monoText(
                  log.history.map((TapRecord r) {
                    final String time =
                        '${two(r.time.hour)}:${two(r.time.minute)}:${two(r.time.second)}';
                    final String caseNo = r.caseName.split(' ').first;
                    return '$time  $caseNo <${r.info.name}> index=${r.info.index} text="${r.info.text}" action=${r.action}';
                  }).join('\n'),
                  color: Colors.black,
                ),
            ],
          ),
        );
      },
    );
  }
}

// MARK: - Demo widgets

/// A label with padding and a rounded background (`PaddingLabel` on iOS).
class Pill extends StatelessWidget {
  const Pill(this.text,
      {super.key,
      required this.color,
      this.fontSize = 12,
      this.bold = false,
      this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      this.radius = 4});

  final String text;
  final Color color;
  final double fontSize;
  final bool bold;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(radius)),
      child: Text(
        text,
        style: TextStyle(
            fontSize: fontSize,
            color: Colors.white,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            height: 1.2),
      ),
    );
  }
}

/// Inline widgets shared by several cases.
abstract final class DemoWidgets {
  /// Button style (replaces the text).
  static ZLRichWidget button(String title) => ZLRichWidget(
        child: Pill(title,
            color: M.blue,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            radius: 12),
      );

  /// Red dot with 4pt spacing.
  static ZLRichWidget redDot(
          {ZLRichWidgetPosition position = ZLRichWidgetPosition.before}) =>
      ZLRichWidget(
        size: const Size(12, 8),
        position: position,
        child: Center(
          child: Container(
              width: 8,
              height: 8,
              decoration:
                  const BoxDecoration(color: M.red, shape: BoxShape.circle)),
        ),
      );

  /// VIP badge with 4pt spacing.
  static ZLRichWidget vipBadge(
          {ZLRichWidgetPosition position = ZLRichWidgetPosition.after}) =>
      ZLRichWidget(
        position: position,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Pill('VIP',
              color: M.amber,
              fontSize: 10,
              bold: true,
              padding: EdgeInsets.symmetric(horizontal: 4)),
        ),
      );

  /// Checkbox handling its own taps (does not trigger the tag tap).
  static ZLRichWidget checkbox(
          {required bool checked, required VoidCallback onChanged}) =>
      ZLRichWidget(
        size: const Size(22, 18),
        tappable: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onChanged,
          child: Padding(
            padding: const EdgeInsets.only(left: 2, right: 2),
            child: Icon(
                checked ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
                color: checked ? M.green : M.grey),
          ),
        ),
      );
}

/// A segmented control (`UISegmentedControl`).
class Segmented extends StatelessWidget {
  const Segmented(
      {super.key,
      required this.items,
      required this.selected,
      required this.onChanged});

  final List<String> items;
  final int? selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<int>(
        segments: <ButtonSegment<int>>[
          for (int i = 0; i < items.length; i++)
            ButtonSegment<int>(
                value: i,
                label: Text(items[i], style: const TextStyle(fontSize: 12))),
        ],
        selected: selected == null ? <int>{} : <int>{selected!},
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        onSelectionChanged: (Set<int> value) {
          if (value.isNotEmpty) onChanged(value.first);
        },
      ),
    );
  }
}

/// A row with a label and a switch.
class SwitchRow extends StatelessWidget {
  const SwitchRow(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: monoText(label, fontSize: 12, color: Colors.black)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// Shows an action sheet with [items]; returns when closed.
Future<void> showActionSheet(BuildContext context,
    {required String title,
    String? message,
    required List<(String, VoidCallback)> items}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(message, style: _hint, textAlign: TextAlign.center),
            ),
          const SizedBox(height: 8),
          for (final (String label, VoidCallback action) in items)
            ListTile(
              title: Text(label, textAlign: TextAlign.center),
              onTap: () {
                Navigator.of(context).pop();
                action();
              },
            ),
          ListTile(
            title: const Text('取消',
                textAlign: TextAlign.center, style: TextStyle(color: M.grey)),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
}
